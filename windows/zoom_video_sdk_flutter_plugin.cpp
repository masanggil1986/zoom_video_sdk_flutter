#include "zoom_video_sdk_flutter_plugin.h"

#include <windows.h>

#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <string>

#include "zoom_serializer.h"
#include "zoom_video_sdk_session_info_interface.h"
#include "helpers/zoom_video_sdk_audio_helper_interface.h"
#include "helpers/zoom_video_sdk_audio_setting_interface.h"
#include "helpers/zoom_video_sdk_video_helper_interface.h"
#include "helpers/zoom_video_sdk_share_helper_interface.h"
#include "helpers/zoom_video_sdk_chat_helper_interface.h"
#include "helpers/zoom_video_sdk_recording_helper_interface.h"
#include "helpers/zoom_video_sdk_user_helper_interface.h"
#include "helpers/zoom_video_sdk_share_setting_interface.h"
// TODO(windows-verify): cmd 채널 헤더 경로/이름 확인. helpers/ 하위일 수도 있음
// (helpers/zoom_video_sdk_cmd_channel_interface.h). session/chat 인터페이스처럼
// 최상위에 있을 가능성이 높아 우선 top-level 경로로 둠.
#include "zoom_video_sdk_cmd_channel_interface.h"

namespace zoom_video_sdk_flutter {

// EncodableMap에서 string 값을 가져오는 헬퍼
static std::string GetString(const flutter::EncodableMap* args,
                             const std::string& key,
                             const std::string& defaultVal = "") {
  if (!args) return defaultVal;
  auto it = args->find(flutter::EncodableValue(key));
  if (it == args->end()) return defaultVal;
  auto* val = std::get_if<std::string>(&it->second);
  return val ? *val : defaultVal;
}

static bool GetBool(const flutter::EncodableMap* args, const std::string& key,
                    bool defaultVal = false) {
  if (!args) return defaultVal;
  auto it = args->find(flutter::EncodableValue(key));
  if (it == args->end()) return defaultVal;
  auto* val = std::get_if<bool>(&it->second);
  return val ? *val : defaultVal;
}

static int GetInt(const flutter::EncodableMap* args, const std::string& key,
                  int defaultVal = 0) {
  if (!args) return defaultVal;
  auto it = args->find(flutter::EncodableValue(key));
  if (it == args->end()) return defaultVal;
  auto* val = std::get_if<int32_t>(&it->second);
  return val ? *val : defaultVal;
}

static const flutter::EncodableMap* GetMap(const flutter::EncodableMap* args,
                                           const std::string& key) {
  if (!args) return nullptr;
  auto it = args->find(flutter::EncodableValue(key));
  if (it == args->end()) return nullptr;
  return std::get_if<flutter::EncodableMap>(&it->second);
}

// Dispatch a ZoomVideoSDKErrors outcome to a MethodResult. The result is
// consumed either way.
static void FinishResult(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
    ZoomVideoSDKErrors err, const std::string& errorCode,
    const std::string& opName) {
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error(errorCode, opName + " failed: " + std::to_string(err));
  }
}

// Dispatch a bool outcome (for SDK methods that return bool instead of an
// error code) to a MethodResult.
static void FinishResult(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
    bool success, const std::string& errorCode, const std::string& opName) {
  if (success) {
    result->Success();
  } else {
    result->Error(errorCode, opName + " failed");
  }
}

// static
void ZoomVideoSdkFlutterPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto method_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "zoom_video_sdk_flutter",
          &flutter::StandardMethodCodec::GetInstance());

  auto event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "zoom_video_sdk_flutter/events",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<ZoomVideoSdkFlutterPlugin>();
  plugin->texture_manager_ =
      std::make_unique<ZoomVideoTextureManager>(registrar->texture_registrar());
  if (auto* view = registrar->GetView()) {
    plugin->flutter_hwnd_ = view->GetNativeWindow();
  }

  // EventChannel에 StreamHandler 등록
  auto handler = std::make_unique<ZoomEventStreamHandler>();
  plugin->event_handler_ = handler.get();
  // When users/video/share change, retry pending texture subscriptions so
  // late-appearing video streams attach to their ZoomVideoView.
  ZoomVideoSdkFlutterPlugin* plugin_raw = plugin.get();
  handler->SetUserStateListener([plugin_raw]() {
    if (plugin_raw->texture_manager_ && plugin_raw->sdk_) {
      plugin_raw->texture_manager_->OnSessionStateChanged(plugin_raw->sdk_);
    }
  });
  event_channel->SetStreamHandler(std::move(handler));

  method_channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

ZoomVideoSdkFlutterPlugin::ZoomVideoSdkFlutterPlugin() {}

ZoomVideoSdkFlutterPlugin::~ZoomVideoSdkFlutterPlugin() {
  // Dispose textures (and thereby unsubscribe from any live pipes) before
  // tearing down the SDK itself — Dispose needs the SDK to verify which
  // pipes are still safe to unSubscribe from.
  if (texture_manager_) texture_manager_->DisposeAll(sdk_);
  if (sdk_) {
    sdk_->removeListener(event_handler_);
    sdk_->cleanup();
    DestroyZoomVideoSDKObj();
    sdk_ = nullptr;
  }
}

// MARK: - Dispatch

void ZoomVideoSdkFlutterPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& method = method_call.method_name();
  const auto* args = method_call.arguments()
      ? std::get_if<flutter::EncodableMap>(method_call.arguments())
      : nullptr;

  // SDK 라이프사이클
  if (method == "init") {
    HandleInit(args, std::move(result));
  } else if (method == "cleanup") {
    HandleCleanup(std::move(result));
  } else if (method == "joinSession") {
    HandleJoinSession(args, std::move(result));
  } else if (method == "leaveSession") {
    HandleLeaveSession(args, std::move(result));
  } else if (method == "getSessionInfo") {
    HandleGetSessionInfo(std::move(result));
  } else if (method == "getMyself") {
    HandleGetMyself(std::move(result));
  } else if (method == "getAllUsers") {
    HandleGetAllUsers(std::move(result));
  } else if (method == "getRemoteUsers") {
    HandleGetRemoteUsers(std::move(result));
  }
  // Command Channel
  else if (method == "cmd.sendCommand") {
    HandleSendCommand(args, std::move(result));
  }
  // Audio
  else if (method == "audio.startAudio") {
    HandleAudioStartAudio(std::move(result));
  } else if (method == "audio.stopAudio") {
    HandleAudioStopAudio(std::move(result));
  } else if (method == "audio.muteAudio") {
    HandleAudioMuteAudio(args, std::move(result));
  } else if (method == "audio.unmuteAudio") {
    HandleAudioUnmuteAudio(args, std::move(result));
  } else if (method == "audio.enableMicOriginalInput") {
    HandleAudioEnableMicOriginalInput(args, std::move(result));
  } else if (method == "audio.setNoiseSuppression") {
    HandleAudioSetNoiseSuppression(args, std::move(result));
  } else if (method == "audio.getAudioDeviceList") {
    HandleAudioGetDeviceList(std::move(result));
  } else if (method == "audio.selectAudioDevice") {
    HandleAudioSelectDevice(args, std::move(result));
  }
  // Video
  else if (method == "video.startVideo") {
    HandleVideoStartVideo(std::move(result));
  } else if (method == "video.stopVideo") {
    HandleVideoStopVideo(std::move(result));
  } else if (method == "video.switchCamera") {
    HandleVideoSwitchCamera(std::move(result));
  } else if (method == "video.getCameraList") {
    HandleVideoGetCameraList(std::move(result));
  } else if (method == "video.selectCamera") {
    HandleVideoSelectCamera(args, std::move(result));
  } else if (method == "video.setVideoQualityPreference") {
    HandleVideoSetQualityPreference(args, std::move(result));
  }
  // Video view
  else if (method == "videoView.create") {
    HandleVideoViewCreate(args, std::move(result));
  } else if (method == "videoView.dispose") {
    HandleVideoViewDispose(args, std::move(result));
  }
  // Share
  else if (method == "share.startShareScreen") {
    HandleShareStartScreen(args, std::move(result));
  } else if (method == "share.startShareView") {
    HandleShareStartView(args, std::move(result));
  } else if (method == "share.stopShare") {
    HandleShareStop(std::move(result));
  } else if (method == "share.enableShareDeviceAudio") {
    HandleShareEnableDeviceAudio(args, std::move(result));
  } else if (method == "share.enableOptimizeForSharedVideo") {
    HandleShareEnableOptimizeForVideo(args, std::move(result));
  } else if (method == "share.getShareSourceList") {
    HandleShareGetSourceList(std::move(result));
  }
  // Chat
  else if (method == "chat.sendChatToAll") {
    HandleChatSendToAll(args, std::move(result));
  } else if (method == "chat.sendChatToUser") {
    HandleChatSendToUser(args, std::move(result));
  } else if (method == "chat.isChatDisabled") {
    HandleChatIsDisabled(std::move(result));
  } else if (method == "chat.isPrivateChatDisabled") {
    HandleChatIsPrivateDisabled(std::move(result));
  }
  // Recording
  else if (method == "recording.canStartRecording") {
    HandleRecordingCanStart(std::move(result));
  } else if (method == "recording.startCloudRecording") {
    HandleRecordingStart(std::move(result));
  } else if (method == "recording.stopCloudRecording") {
    HandleRecordingStop(std::move(result));
  }
  // Virtual Background
  else if (method == "virtualBackground.isSupported") {
    HandleVBIsSupported(std::move(result));
  } else if (method == "virtualBackground.addItem") {
    HandleVBAddItem(args, std::move(result));
  } else if (method == "virtualBackground.getItemList") {
    HandleVBGetItemList(std::move(result));
  } else if (method == "virtualBackground.setItem") {
    HandleVBSetItem(args, std::move(result));
  } else if (method == "virtualBackground.removeItem") {
    HandleVBRemoveItem(args, std::move(result));
  } else if (method == "virtualBackground.getSelectedItem") {
    HandleVBGetSelectedItem(std::move(result));
  }
  // User Management
  else if (method == "user.makeHost") {
    HandleUserMakeHost(args, std::move(result));
  } else if (method == "user.makeManager") {
    HandleUserMakeManager(args, std::move(result));
  } else if (method == "user.revokeManager") {
    HandleUserRevokeManager(args, std::move(result));
  } else if (method == "user.removeUser") {
    HandleUserRemove(args, std::move(result));
  } else if (method == "user.changeName") {
    HandleUserChangeName(args, std::move(result));
  }
  // Unknown
  else {
    result->NotImplemented();
  }
}

// MARK: - Helpers

IZoomVideoSDKUser* ZoomVideoSdkFlutterPlugin::FindUser(
    const std::string& userId) {
  if (!sdk_) return nullptr;
  auto* session = sdk_->getSessionInfo();
  if (!session) return nullptr;

  std::wstring wideId = Utf8ToWide(userId);

  auto* myself = session->getMyself();
  if (myself) {
    auto* myId = myself->getUserID();
    if (myId && wideId == myId) return myself;
  }

  auto* remoteUsers = session->getRemoteUsers();
  if (remoteUsers) {
    for (int i = 0; i < remoteUsers->GetCount(); i++) {
      auto* user = remoteUsers->GetItem(i);
      auto* uid = user->getUserID();
      if (uid && wideId == uid) return user;
    }
  }
  return nullptr;
}

// MARK: - SDK Lifecycle

void ZoomVideoSdkFlutterPlugin::HandleInit(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!args) {
    result->Error("INVALID_ARGS", "Arguments required");
    return;
  }

  sdk_ = CreateZoomVideoSDKObj();
  if (!sdk_) {
    result->Error("INIT_FAILED", "Failed to create SDK object");
    return;
  }

  ZoomVideoSDKInitParams params;
  std::wstring domain = Utf8ToWide(GetString(args, "domain", "zoom.us"));
  params.domain = domain.c_str();
  params.enableLog = GetBool(args, "enableLog", true);
  // Match Flutter's per-monitor DPI awareness, and use heap-mode raw data
  // buffers — both needed to keep the share module stable under Flutter's
  // ANGLE/D3D11 renderer.
  params.permonitor_awareness_mode = true;
  params.videoRawDataMemoryMode = ZoomVideoSDKRawDataMemoryModeHeap;
  params.shareRawDataMemoryMode = ZoomVideoSDKRawDataMemoryModeHeap;

  auto err = sdk_->initialize(params);
  if (err == ZoomVideoSDKErrors_Success) {
    if (event_handler_) sdk_->addListener(event_handler_);
    // Prefer "Filtering" capture (modern GDI+composition with window
    // filtering). Auto mode probes DXGI paths that conflict with Flutter's
    // renderer on some systems.
    if (auto* shareSetting = sdk_->getShareSettingHelper()) {
      shareSetting->setScreenCaptureMode(
          ZoomVideoSDKScreenCaptureMode_Filtering);
    }
    result->Success();
  } else {
    result->Error("INIT_FAILED",
                  "SDK init failed: " + std::to_string(err));
  }
}

// SDK 자원 해제. cleanup 후 재초기화(init) 가능. 세션 중에는 호출 금지.
// cleanup()은 소멸자(~ZoomVideoSdkFlutterPlugin)에서도 호출하므로 시그니처 검증됨.
void ZoomVideoSdkFlutterPlugin::HandleCleanup(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (sdk_) sdk_->cleanup();
  result->Success();
}

void ZoomVideoSdkFlutterPlugin::HandleJoinSession(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!args || !sdk_) {
    result->Error("INVALID_ARGS", "Arguments required");
    return;
  }

  ZoomVideoSDKSessionContext ctx;
  std::wstring sessionName = Utf8ToWide(GetString(args, "sessionName"));
  std::wstring userName = Utf8ToWide(GetString(args, "userName"));
  std::wstring token = Utf8ToWide(GetString(args, "token"));
  std::wstring sessionPassword = Utf8ToWide(GetString(args, "sessionPassword"));

  ctx.sessionName = sessionName.c_str();
  ctx.userName = userName.c_str();
  ctx.token = token.c_str();
  if (!sessionPassword.empty()) {
    ctx.sessionPassword = sessionPassword.c_str();
  }

  auto* audioOpts = GetMap(args, "audioOptions");
  if (audioOpts) {
    ctx.audioOption.connect = GetBool(audioOpts, "connect", true);
    ctx.audioOption.mute = GetBool(audioOpts, "mute", false);
    ctx.audioOption.autoAdjustSpeakerVolume =
        GetBool(audioOpts, "autoAdjustSpeakerVolume", true);
  }

  auto* videoOpts = GetMap(args, "videoOptions");
  if (videoOpts) {
    ctx.videoOption.localVideoOn = GetBool(videoOpts, "localVideoOn", false);
  }

  auto timeoutIt = args->find(flutter::EncodableValue("sessionIdleTimeoutMins"));
  if (timeoutIt != args->end()) {
    auto* val = std::get_if<int32_t>(&timeoutIt->second);
    if (val) ctx.sessionIdleTimeoutMins = static_cast<unsigned int>(*val);
  }

  auto* session = sdk_->joinSession(ctx);
  if (session) {
    result->Success();
  } else {
    result->Error("JOIN_FAILED", "Failed to join session");
  }
}

void ZoomVideoSdkFlutterPlugin::HandleLeaveSession(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool endSession = GetBool(args, "endSession", false);
  if (sdk_) {
    sdk_->leaveSession(endSession);
  }
  result->Success();
}

void ZoomVideoSdkFlutterPlugin::HandleGetSessionInfo(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!sdk_) {
    result->Error("NO_SESSION", "No active session");
    return;
  }
  auto* session = sdk_->getSessionInfo();
  if (!session) {
    result->Error("NO_SESSION", "No active session");
    return;
  }
  result->Success(flutter::EncodableValue(SerializeSessionInfo(session)));
}

void ZoomVideoSdkFlutterPlugin::HandleGetMyself(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!sdk_ || !sdk_->getSessionInfo()) {
    result->Error("NO_SESSION", "No active session or user");
    return;
  }
  auto* myself = sdk_->getSessionInfo()->getMyself();
  if (!myself) {
    result->Error("NO_SESSION", "No active session or user");
    return;
  }
  result->Success(flutter::EncodableValue(SerializeUser(myself)));
}

void ZoomVideoSdkFlutterPlugin::HandleGetAllUsers(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!sdk_ || !sdk_->getSessionInfo()) {
    result->Error("NO_SESSION", "No active session");
    return;
  }
  auto* session = sdk_->getSessionInfo();
  flutter::EncodableList users;

  auto* myself = session->getMyself();
  if (myself) {
    users.push_back(flutter::EncodableValue(SerializeUser(myself)));
  }

  auto* remoteUsers = session->getRemoteUsers();
  if (remoteUsers) {
    for (int i = 0; i < remoteUsers->GetCount(); i++) {
      users.push_back(
          flutter::EncodableValue(SerializeUser(remoteUsers->GetItem(i))));
    }
  }

  result->Success(flutter::EncodableValue(users));
}

void ZoomVideoSdkFlutterPlugin::HandleGetRemoteUsers(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!sdk_ || !sdk_->getSessionInfo()) {
    result->Error("NO_SESSION", "No active session");
    return;
  }
  auto* remoteUsers = sdk_->getSessionInfo()->getRemoteUsers();
  result->Success(flutter::EncodableValue(SerializeUserList(remoteUsers)));
}

// MARK: - Command Channel

void ZoomVideoSdkFlutterPlugin::HandleSendCommand(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto command = GetString(args, "command");
  if (command.empty()) {
    result->Error("INVALID_ARGS", "command required");
    return;
  }
  // TODO(windows-verify): IZoomVideoSDK::getCmdChannel() 이름 확인.
  auto* cmdChannel = sdk_ ? sdk_->getCmdChannel() : nullptr;
  if (!cmdChannel) {
    result->Error("NO_SESSION", "command channel unavailable");
    return;
  }

  // receiverUserId가 비어 있으면 nullptr → 전체 broadcast.
  IZoomVideoSDKUser* receiver = nullptr;
  auto receiverUserId = GetString(args, "receiverUserId");
  if (!receiverUserId.empty()) {
    receiver = FindUser(receiverUserId);
    if (!receiver) {
      result->Error("USER_NOT_FOUND", "receiver not in session");
      return;
    }
  }

  std::wstring wideCmd = Utf8ToWide(command);
  // TODO(windows-verify): sendCommand(receiver, strCmd) 인자 순서 확인.
  auto err = cmdChannel->sendCommand(receiver, wideCmd.c_str());
  if (err != ZoomVideoSDKErrors_Success) {
    result->Error("SEND_COMMAND_FAILED",
                  "sendCommand failed: " + std::to_string(err));
    return;
  }
  result->Success();
}

// MARK: - Audio

void ZoomVideoSdkFlutterPlugin::HandleAudioStartAudio(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto err = sdk_ ? sdk_->getAudioHelper()->startAudio()
                  : ZoomVideoSDKErrors_Uninitialize;
  FinishResult(std::move(result), err, "AUDIO_ERROR", "startAudio");
}

void ZoomVideoSdkFlutterPlugin::HandleAudioStopAudio(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto err = sdk_ ? sdk_->getAudioHelper()->stopAudio()
                  : ZoomVideoSDKErrors_Uninitialize;
  FinishResult(std::move(result), err, "AUDIO_ERROR", "stopAudio");
}

void ZoomVideoSdkFlutterPlugin::HandleAudioMuteAudio(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto* user = FindUser(GetString(args, "userId"));
  if (!user) {
    result->Error("INVALID_ARGS", "User not found");
    return;
  }
  FinishResult(std::move(result), sdk_->getAudioHelper()->muteAudio(user),
               "AUDIO_ERROR", "muteAudio");
}

void ZoomVideoSdkFlutterPlugin::HandleAudioUnmuteAudio(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto* user = FindUser(GetString(args, "userId"));
  if (!user) {
    result->Error("INVALID_ARGS", "User not found");
    return;
  }
  FinishResult(std::move(result), sdk_->getAudioHelper()->unMuteAudio(user),
               "AUDIO_ERROR", "unmuteAudio");
}

void ZoomVideoSdkFlutterPlugin::HandleAudioEnableMicOriginalInput(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool enable = GetBool(args, "enable", false);
  auto err = sdk_
      ? sdk_->getAudioSettingHelper()->enableMicOriginalInput(enable)
      : ZoomVideoSDKErrors_Uninitialize;
  FinishResult(std::move(result), err, "AUDIO_ERROR",
               "enableMicOriginalInput");
}

void ZoomVideoSdkFlutterPlugin::HandleAudioSetNoiseSuppression(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto levelStr = GetString(args, "level", "auto_");
  ZoomVideoSDKSuppressBackgroundNoiseLevel level;
  if (levelStr == "low") {
    level = ZoomVideoSDKSuppressBackgroundNoiseLevel_Low;
  } else if (levelStr == "medium") {
    level = ZoomVideoSDKSuppressBackgroundNoiseLevel_Medium;
  } else if (levelStr == "high") {
    level = ZoomVideoSDKSuppressBackgroundNoiseLevel_High;
  } else {
    level = ZoomVideoSDKSuppressBackgroundNoiseLevel_Auto;
  }

  auto err = sdk_
      ? sdk_->getAudioSettingHelper()->setSuppressBackgroundNoiseLevel(level)
      : ZoomVideoSDKErrors_Uninitialize;
  FinishResult(std::move(result), err, "AUDIO_ERROR", "setNoiseSuppression");
}

void ZoomVideoSdkFlutterPlugin::HandleAudioGetDeviceList(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  flutter::EncodableList list;
  if (!sdk_) {
    result->Success(flutter::EncodableValue(list));
    return;
  }
  auto* helper = sdk_->getAudioHelper();
  if (!helper) {
    result->Success(flutter::EncodableValue(list));
    return;
  }

  auto* micList = helper->getMicList();
  if (micList) {
    for (int i = 0; i < micList->GetCount(); i++) {
      list.push_back(flutter::EncodableValue(
          SerializeMicDevice(micList->GetItem(i))));
    }
  }

  auto* speakerList = helper->getSpeakerList();
  if (speakerList) {
    for (int i = 0; i < speakerList->GetCount(); i++) {
      list.push_back(flutter::EncodableValue(
          SerializeSpeakerDevice(speakerList->GetItem(i))));
    }
  }

  result->Success(flutter::EncodableValue(list));
}

void ZoomVideoSdkFlutterPlugin::HandleAudioSelectDevice(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto deviceId = GetString(args, "deviceId");
  if (deviceId.empty()) {
    result->Error("INVALID_ARGS", "deviceId required");
    return;
  }
  if (!sdk_) {
    result->Error("AUDIO_ERROR", "Audio helper not available");
    return;
  }
  auto* helper = sdk_->getAudioHelper();
  if (!helper) {
    result->Error("AUDIO_ERROR", "Audio helper not available");
    return;
  }

  std::wstring wideDeviceId = Utf8ToWide(deviceId);

  // mic 목록에서 찾기
  auto* micList = helper->getMicList();
  if (micList) {
    for (int i = 0; i < micList->GetCount(); i++) {
      auto* device = micList->GetItem(i);
      if (wideDeviceId == device->getDeviceId()) {
        auto err = helper->selectMic(device->getDeviceId(),
                                     device->getDeviceName());
        if (err == ZoomVideoSDKErrors_Success) {
          result->Success();
          return;
        }
      }
    }
  }

  // speaker 목록에서 찾기
  auto* speakerList = helper->getSpeakerList();
  if (speakerList) {
    for (int i = 0; i < speakerList->GetCount(); i++) {
      auto* device = speakerList->GetItem(i);
      if (wideDeviceId == device->getDeviceId()) {
        auto err = helper->selectSpeaker(device->getDeviceId(),
                                         device->getDeviceName());
        if (err == ZoomVideoSDKErrors_Success) {
          result->Success();
          return;
        }
      }
    }
  }

  result->Error("AUDIO_ERROR", "Device not found: " + deviceId);
}

// MARK: - Video

void ZoomVideoSdkFlutterPlugin::HandleVideoStartVideo(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto err = sdk_ ? sdk_->getVideoHelper()->startVideo()
                  : ZoomVideoSDKErrors_Uninitialize;
  FinishResult(std::move(result), err, "VIDEO_ERROR", "startVideo");
}

void ZoomVideoSdkFlutterPlugin::HandleVideoStopVideo(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto err = sdk_ ? sdk_->getVideoHelper()->stopVideo()
                  : ZoomVideoSDKErrors_Uninitialize;
  FinishResult(std::move(result), err, "VIDEO_ERROR", "stopVideo");
}

void ZoomVideoSdkFlutterPlugin::HandleVideoSwitchCamera(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool success = sdk_ ? sdk_->getVideoHelper()->switchCamera() : false;
  FinishResult(std::move(result), success, "VIDEO_ERROR", "switchCamera");
}

void ZoomVideoSdkFlutterPlugin::HandleVideoGetCameraList(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  flutter::EncodableList list;
  if (sdk_) {
    auto* cameras = sdk_->getVideoHelper()->getCameraList();
    if (cameras) {
      for (int i = 0; i < cameras->GetCount(); i++) {
        list.push_back(flutter::EncodableValue(
            SerializeCameraDevice(cameras->GetItem(i))));
      }
    }
  }
  result->Success(flutter::EncodableValue(list));
}

void ZoomVideoSdkFlutterPlugin::HandleVideoSelectCamera(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto deviceId = GetString(args, "deviceId");
  if (deviceId.empty()) {
    result->Error("INVALID_ARGS", "deviceId required");
    return;
  }
  if (!sdk_) {
    result->Error("VIDEO_ERROR", "Video helper not available");
    return;
  }
  std::wstring wideId = Utf8ToWide(deviceId);
  bool success = sdk_->getVideoHelper()->selectCamera(wideId.c_str());
  FinishResult(std::move(result), success, "VIDEO_ERROR", "selectCamera");
}

void ZoomVideoSdkFlutterPlugin::HandleVideoSetQualityPreference(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!sdk_) {
    result->Error("VIDEO_ERROR", "Video helper not available");
    return;
  }
  auto modeStr = GetString(args, "mode", "balance");
  ZoomVideoSDKVideoPreferenceSetting pref;
  if (modeStr == "sharpness") {
    pref.mode = ZoomVideoSDKVideoPreferenceMode_Sharpness;
  } else if (modeStr == "smoothness") {
    pref.mode = ZoomVideoSDKVideoPreferenceMode_Smoothness;
  } else if (modeStr == "custom") {
    pref.mode = ZoomVideoSDKVideoPreferenceMode_Custom;
  } else {
    pref.mode = ZoomVideoSDKVideoPreferenceMode_Balance;
  }
  int minFr = GetInt(args, "minimumFrameRate", 0);
  int maxFr = GetInt(args, "maximumFrameRate", 0);
  pref.minimum_frame_rate = static_cast<uint32_t>(minFr < 0 ? 0 : minFr);
  pref.maximum_frame_rate = static_cast<uint32_t>(maxFr < 0 ? 0 : maxFr);

  auto err = sdk_->getVideoHelper()->setVideoQualityPreference(pref);
  FinishResult(std::move(result), err, "VIDEO_ERROR",
               "setVideoQualityPreference");
}

// MARK: - Video view (texture)

void ZoomVideoSdkFlutterPlugin::HandleVideoViewCreate(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto userId = GetString(args, "userId");
  auto kindStr = GetString(args, "kind", "video");
  if (userId.empty()) {
    result->Error("INVALID_ARGS", "userId required");
    return;
  }
  if (!texture_manager_) {
    result->Error("VIDEO_VIEW_ERROR", "Texture manager unavailable");
    return;
  }
  auto kind = (kindStr == "share") ? ZoomVideoTextureRenderer::Kind::Share
                                   : ZoomVideoTextureRenderer::Kind::Video;
  int64_t textureId = texture_manager_->Create(sdk_, userId, kind);
  result->Success(flutter::EncodableValue(textureId));
}

void ZoomVideoSdkFlutterPlugin::HandleVideoViewDispose(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!texture_manager_) {
    result->Success();
    return;
  }
  int64_t textureId = 0;
  auto it = args ? args->find(flutter::EncodableValue("textureId"))
                 : flutter::EncodableMap::const_iterator{};
  if (args && it != args->end()) {
    if (auto* v = std::get_if<int64_t>(&it->second)) textureId = *v;
    else if (auto* v32 = std::get_if<int32_t>(&it->second))
      textureId = *v32;
  }
  texture_manager_->Dispose(sdk_, textureId);
  result->Success();
}

// MARK: - Share

namespace {

// Brief share state summary for failure messages — enough to distinguish
// the common blockers (locked share, no multi-share, already sharing out)
// without dumping the whole environment.
std::string BuildShareDiagnostics(IZoomVideoSDKShareHelper* shareHelper) {
  if (!shareHelper) return "(no share helper)";
  return std::string("(sharingOut=") +
         (shareHelper->isSharingOut() ? "1" : "0") +
         " otherSharing=" + (shareHelper->isOtherSharing() ? "1" : "0") +
         " locked=" + (shareHelper->isShareLocked() ? "1" : "0") +
         " multiShare=" + (shareHelper->isMultiShareEnabled() ? "1" : "0") +
         ")";
}

// Enumerate monitors via Win32 and emit {sourceId, name, type:"screen"}.
BOOL CALLBACK MonitorEnumProc(HMONITOR hMonitor, HDC, LPRECT, LPARAM lParam) {
  auto* out = reinterpret_cast<flutter::EncodableList*>(lParam);
  MONITORINFOEXW info;
  info.cbSize = sizeof(info);
  if (!GetMonitorInfoW(hMonitor, &info)) return TRUE;

  std::string deviceId = WideToUtf8(info.szDevice);
  // Friendly name: fall back to device when DisplayDevice query fails.
  std::string name = deviceId;
  DISPLAY_DEVICEW dd;
  dd.cb = sizeof(dd);
  if (EnumDisplayDevicesW(info.szDevice, 0, &dd, 0)) {
    std::string friendly = WideToUtf8(dd.DeviceString);
    if (!friendly.empty()) {
      name = friendly +
             ((info.dwFlags & MONITORINFOF_PRIMARY) ? " (Primary)" : "");
    }
  }
  flutter::EncodableMap entry;
  entry[flutter::EncodableValue("sourceId")] =
      flutter::EncodableValue(deviceId);
  entry[flutter::EncodableValue("name")] = flutter::EncodableValue(name);
  entry[flutter::EncodableValue("type")] = flutter::EncodableValue("screen");
  out->push_back(flutter::EncodableValue(entry));
  return TRUE;
}

// Enumerate top-level visible windows with non-empty titles.
BOOL CALLBACK WindowEnumProc(HWND hwnd, LPARAM lParam) {
  if (!IsWindowVisible(hwnd) || GetWindow(hwnd, GW_OWNER) != nullptr) {
    return TRUE;
  }
  LONG style = GetWindowLongW(hwnd, GWL_STYLE);
  LONG exStyle = GetWindowLongW(hwnd, GWL_EXSTYLE);
  if ((style & WS_CHILD) || (exStyle & WS_EX_TOOLWINDOW)) {
    return TRUE;
  }
  int len = GetWindowTextLengthW(hwnd);
  if (len <= 0) return TRUE;
  // +1 for null terminator; GetWindowTextW writes at most nMaxCount chars
  // including the terminator.
  std::wstring title(static_cast<size_t>(len) + 1, L'\0');
  int copied = GetWindowTextW(hwnd, &title[0], len + 1);
  title.resize(static_cast<size_t>(copied));
  std::string titleUtf8 = WideToUtf8(title.c_str());
  if (titleUtf8.empty()) return TRUE;

  auto* out = reinterpret_cast<flutter::EncodableList*>(lParam);
  uintptr_t handleInt = reinterpret_cast<uintptr_t>(hwnd);
  flutter::EncodableMap entry;
  entry[flutter::EncodableValue("sourceId")] =
      flutter::EncodableValue(std::to_string(handleInt));
  entry[flutter::EncodableValue("name")] =
      flutter::EncodableValue(titleUtf8);
  entry[flutter::EncodableValue("type")] = flutter::EncodableValue("window");
  out->push_back(flutter::EncodableValue(entry));
  return TRUE;
}

ZoomVideoSDKShareOption BuildShareOption(const flutter::EncodableMap* map) {
  ZoomVideoSDKShareOption option;
  option.isWithDeviceAudio = GetBool(map, "withDeviceAudio", false);
  option.isOptimizeForSharedVideo =
      GetBool(map, "optimizeForSharedVideo", false);
  return option;
}

}  // namespace

void ZoomVideoSdkFlutterPlugin::HandleShareStartScreen(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!sdk_) {
    result->Error("SHARE_ERROR", "SDK not initialized");
    return;
  }
  auto option = BuildShareOption(GetMap(args, "option"));
  auto monitorIdUtf8 = GetString(args, "monitorId");
  // nullptr lets the SDK pick the primary display — that path is known-good.
  // Only pass an explicit monitor ID when the caller asked for a specific one.
  std::wstring monitorIdWide =
      monitorIdUtf8.empty() ? L"" : Utf8ToWide(monitorIdUtf8);
  const wchar_t* monitorId =
      monitorIdWide.empty() ? nullptr : monitorIdWide.c_str();

  // Force GDI-based Legacy capture. Zoom SDK's default (Auto) tries DirectX
  // paths that conflict with Flutter's ANGLE/D3D11 context and fail with
  // Internal_Error (2). Set proactively so we don't need a retry that
  // would trip Call_Too_Frequently (8) rate limiting.
  auto* shareHelper = sdk_->getShareHelper();
  auto err = shareHelper->startShareScreen(monitorId, option);
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("SHARE_ERROR",
                  "startShareScreen failed: " + std::to_string(err) + " " +
                      BuildShareDiagnostics(shareHelper));
  }
}



void ZoomVideoSdkFlutterPlugin::HandleShareStartView(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto windowIdStr = GetString(args, "windowId");
  if (windowIdStr.empty()) {
    result->Error("INVALID_ARGS", "windowId required");
    return;
  }
  if (!sdk_) {
    result->Error("SHARE_ERROR", "SDK not initialized");
    return;
  }

  HWND hwnd = nullptr;
  try {
    hwnd = reinterpret_cast<HWND>(
        static_cast<uintptr_t>(std::stoull(windowIdStr)));
  } catch (...) {
    result->Error("INVALID_ARGS", "windowId must be a numeric HWND");
    return;
  }
  auto option = BuildShareOption(GetMap(args, "option"));
  auto* shareHelper = sdk_->getShareHelper();
  if (!shareHelper) {
    result->Error("SHARE_ERROR", "Share helper not available");
    return;
  }
  if (!shareHelper->isShareViewValid(hwnd)) {
    result->Error("INVALID_ARGS",
                  "Window handle is not shareable (closed or not a top-level "
                  "visible window)");
    return;
  }
  auto err = shareHelper->startShareView(hwnd, option);
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("SHARE_ERROR",
                  "startShareView failed: " + std::to_string(err) + " " +
                      BuildShareDiagnostics(shareHelper));
  }
}

void ZoomVideoSdkFlutterPlugin::HandleShareStop(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto err = sdk_ ? sdk_->getShareHelper()->stopShare()
                  : ZoomVideoSDKErrors_Uninitialize;
  FinishResult(std::move(result), err, "SHARE_ERROR", "stopShare");
}

void ZoomVideoSdkFlutterPlugin::HandleShareEnableDeviceAudio(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool enable = GetBool(args, "enable", false);
  auto err = sdk_ ? sdk_->getShareHelper()->enableShareDeviceAudio(enable)
                  : ZoomVideoSDKErrors_Uninitialize;
  FinishResult(std::move(result), err, "SHARE_ERROR",
               "enableShareDeviceAudio");
}

void ZoomVideoSdkFlutterPlugin::HandleShareEnableOptimizeForVideo(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool enable = GetBool(args, "enable", false);
  auto err = sdk_ ? sdk_->getShareHelper()->enableOptimizeForSharedVideo(enable)
                  : ZoomVideoSDKErrors_Uninitialize;
  FinishResult(std::move(result), err, "SHARE_ERROR",
               "enableOptimizeForSharedVideo");
}

namespace {
struct WindowEnumCtx {
  flutter::EncodableList* out;
  HWND selfHwnd;
};

// Wrapper that skips the Flutter host window and its ancestors, then
// delegates to WindowEnumProc.
BOOL CALLBACK WindowEnumProcFiltered(HWND hwnd, LPARAM lParam) {
  auto* ctx = reinterpret_cast<WindowEnumCtx*>(lParam);
  if (ctx->selfHwnd) {
    HWND walker = hwnd;
    while (walker) {
      if (walker == ctx->selfHwnd) return TRUE;
      walker = GetParent(walker);
    }
  }
  return WindowEnumProc(hwnd, reinterpret_cast<LPARAM>(ctx->out));
}
}  // namespace

void ZoomVideoSdkFlutterPlugin::HandleShareGetSourceList(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  flutter::EncodableList sources;
  EnumDisplayMonitors(nullptr, nullptr, &MonitorEnumProc,
                      reinterpret_cast<LPARAM>(&sources));
  HWND selfTopLevel = flutter_hwnd_ ? GetAncestor(flutter_hwnd_, GA_ROOT)
                                    : nullptr;
  WindowEnumCtx ctx{&sources, selfTopLevel};
  EnumWindows(&WindowEnumProcFiltered, reinterpret_cast<LPARAM>(&ctx));
  result->Success(flutter::EncodableValue(sources));
}

// MARK: - Chat

void ZoomVideoSdkFlutterPlugin::HandleChatSendToAll(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto message = GetString(args, "message");
  if (message.empty()) {
    result->Error("INVALID_ARGS", "message required");
    return;
  }
  std::wstring wideMsg = Utf8ToWide(message);
  auto err = sdk_ ? sdk_->getChatHelper()->sendChatToAll(wideMsg.c_str())
                  : ZoomVideoSDKErrors_Uninitialize;
  FinishResult(std::move(result), err, "CHAT_ERROR", "sendChatToAll");
}

void ZoomVideoSdkFlutterPlugin::HandleChatSendToUser(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto userId = GetString(args, "userId");
  auto message = GetString(args, "message");
  auto* user = FindUser(userId);
  if (!user || message.empty()) {
    result->Error("INVALID_ARGS", "userId and message required");
    return;
  }
  std::wstring wideMsg = Utf8ToWide(message);
  auto err = sdk_->getChatHelper()->sendChatToUser(user, wideMsg.c_str());
  FinishResult(std::move(result), err, "CHAT_ERROR", "sendChatToUser");
}

void ZoomVideoSdkFlutterPlugin::HandleChatIsDisabled(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool disabled = sdk_ ? sdk_->getChatHelper()->isChatDisabled() : false;
  result->Success(flutter::EncodableValue(disabled));
}

void ZoomVideoSdkFlutterPlugin::HandleChatIsPrivateDisabled(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool disabled = sdk_ ? sdk_->getChatHelper()->isPrivateChatDisabled() : false;
  result->Success(flutter::EncodableValue(disabled));
}

// MARK: - Recording

void ZoomVideoSdkFlutterPlugin::HandleRecordingCanStart(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool canStart = sdk_
      ? (sdk_->getRecordingHelper()->canStartRecording() ==
         ZoomVideoSDKErrors_Success)
      : false;
  result->Success(flutter::EncodableValue(canStart));
}

void ZoomVideoSdkFlutterPlugin::HandleRecordingStart(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto err = sdk_ ? sdk_->getRecordingHelper()->startCloudRecording()
                  : ZoomVideoSDKErrors_Uninitialize;
  FinishResult(std::move(result), err, "RECORDING_ERROR",
               "startCloudRecording");
}

void ZoomVideoSdkFlutterPlugin::HandleRecordingStop(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto err = sdk_ ? sdk_->getRecordingHelper()->stopCloudRecording()
                  : ZoomVideoSDKErrors_Uninitialize;
  FinishResult(std::move(result), err, "RECORDING_ERROR",
               "stopCloudRecording");
}

// MARK: - Virtual Background

void ZoomVideoSdkFlutterPlugin::HandleVBIsSupported(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool supported = sdk_ && sdk_->getVideoHelper() != nullptr;
  result->Success(flutter::EncodableValue(supported));
}

void ZoomVideoSdkFlutterPlugin::HandleVBAddItem(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto filePath = GetString(args, "filePath");
  if (filePath.empty()) {
    result->Error("INVALID_ARGS", "filePath required");
    return;
  }
  if (!sdk_) {
    result->Error("VB_ERROR", "Video helper not available");
    return;
  }
  std::wstring widePath = Utf8ToWide(filePath);
  IVirtualBackgroundItem* item = nullptr;
  auto err = sdk_->getVideoHelper()->addVirtualBackgroundItem(
      widePath.c_str(), &item);
  if (err != ZoomVideoSDKErrors_Success) {
    result->Error("VB_ERROR", "addItem failed: " + std::to_string(err));
    return;
  }

  // 동기 out-param 반환값이 불안정할 수 있어, 목록에서 방금 추가된 항목
  // (imageName == 파일명, 또는 imagePath == 입력 경로)을 찾아 돌려준다.
  std::string fileName = filePath;
  auto slash = filePath.find_last_of("/\\");
  if (slash != std::string::npos) fileName = filePath.substr(slash + 1);

  auto* items = sdk_->getVideoHelper()->getVirtualBackgroundItemList();
  if (items) {
    for (int i = 0; i < items->GetCount(); i++) {
      auto* candidate = items->GetItem(i);
      std::string name = WideToUtf8(candidate->getImageName());
      std::string path = WideToUtf8(candidate->getImageFilePath());
      if (name == fileName || path == filePath) {
        result->Success(flutter::EncodableValue(
            SerializeVirtualBackgroundItem(candidate)));
        return;
      }
    }
  }
  // 추가는 성공했지만 목록에서 못 찾으면 no-value (Dart는 null로 해석).
  result->Success();
}

void ZoomVideoSdkFlutterPlugin::HandleVBGetItemList(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  flutter::EncodableList list;
  if (sdk_) {
    auto* items = sdk_->getVideoHelper()->getVirtualBackgroundItemList();
    if (items) {
      for (int i = 0; i < items->GetCount(); i++) {
        list.push_back(flutter::EncodableValue(
            SerializeVirtualBackgroundItem(items->GetItem(i))));
      }
    }
  }
  result->Success(flutter::EncodableValue(list));
}

void ZoomVideoSdkFlutterPlugin::HandleVBSetItem(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto imageName = GetString(args, "imageName");
  if (imageName.empty()) {
    result->Error("INVALID_ARGS", "imageName required");
    return;
  }
  if (!sdk_) {
    result->Error("VB_ERROR", "Video helper not available");
    return;
  }

  std::wstring wideName = Utf8ToWide(imageName);
  auto* items = sdk_->getVideoHelper()->getVirtualBackgroundItemList();
  if (!items) {
    result->Error("VB_ERROR", "Item not found");
    return;
  }

  IVirtualBackgroundItem* target = nullptr;
  for (int i = 0; i < items->GetCount(); i++) {
    auto* item = items->GetItem(i);
    if (wideName == item->getImageName()) {
      target = item;
      break;
    }
  }

  if (!target) {
    result->Error("VB_ERROR", "Item not found: " + imageName);
    return;
  }

  auto err = sdk_->getVideoHelper()->setVirtualBackgroundItem(target);
  FinishResult(std::move(result), err, "VB_ERROR", "setItem");
}

void ZoomVideoSdkFlutterPlugin::HandleVBRemoveItem(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto imageName = GetString(args, "imageName");
  if (imageName.empty()) {
    result->Error("INVALID_ARGS", "imageName required");
    return;
  }
  if (!sdk_) {
    result->Error("VB_ERROR", "Video helper not available");
    return;
  }

  std::wstring wideName = Utf8ToWide(imageName);
  auto* items = sdk_->getVideoHelper()->getVirtualBackgroundItemList();
  if (!items) {
    result->Error("VB_ERROR", "Item not found");
    return;
  }

  IVirtualBackgroundItem* target = nullptr;
  for (int i = 0; i < items->GetCount(); i++) {
    auto* item = items->GetItem(i);
    if (wideName == item->getImageName()) {
      target = item;
      break;
    }
  }

  if (!target) {
    result->Error("VB_ERROR", "Item not found: " + imageName);
    return;
  }

  auto err = sdk_->getVideoHelper()->removeVirtualBackgroundItem(target);
  FinishResult(std::move(result), err, "VB_ERROR", "removeItem");
}

void ZoomVideoSdkFlutterPlugin::HandleVBGetSelectedItem(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!sdk_) {
    result->Success();
    return;
  }
  auto* item = sdk_->getVideoHelper()->getSelectedVirtualBackgroundItem();
  if (!item) {
    result->Success();
    return;
  }
  result->Success(flutter::EncodableValue(
      SerializeVirtualBackgroundItem(item)));
}

// MARK: - User Management

void ZoomVideoSdkFlutterPlugin::HandleUserMakeHost(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto* user = FindUser(GetString(args, "userId"));
  if (!user) {
    result->Error("INVALID_ARGS", "User not found");
    return;
  }
  FinishResult(std::move(result), sdk_->getUserHelper()->makeHost(user),
               "USER_ERROR", "makeHost");
}

void ZoomVideoSdkFlutterPlugin::HandleUserMakeManager(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto* user = FindUser(GetString(args, "userId"));
  if (!user) {
    result->Error("INVALID_ARGS", "User not found");
    return;
  }
  FinishResult(std::move(result), sdk_->getUserHelper()->makeManager(user),
               "USER_ERROR", "makeManager");
}

void ZoomVideoSdkFlutterPlugin::HandleUserRevokeManager(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto* user = FindUser(GetString(args, "userId"));
  if (!user) {
    result->Error("INVALID_ARGS", "User not found");
    return;
  }
  FinishResult(std::move(result), sdk_->getUserHelper()->revokeManager(user),
               "USER_ERROR", "revokeManager");
}

void ZoomVideoSdkFlutterPlugin::HandleUserRemove(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto* user = FindUser(GetString(args, "userId"));
  if (!user) {
    result->Error("INVALID_ARGS", "User not found");
    return;
  }
  FinishResult(std::move(result), sdk_->getUserHelper()->removeUser(user),
               "USER_ERROR", "removeUser");
}

void ZoomVideoSdkFlutterPlugin::HandleUserChangeName(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto name = GetString(args, "name");
  auto* user = FindUser(GetString(args, "userId"));
  if (!user || name.empty()) {
    result->Error("INVALID_ARGS", "name and userId required");
    return;
  }
  std::wstring wideName = Utf8ToWide(name);
  bool success = sdk_->getUserHelper()->changeName(wideName.c_str(), user);
  FinishResult(std::move(result), success, "USER_ERROR", "changeName");
}

}  // namespace zoom_video_sdk_flutter
