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

  // EventChannel에 StreamHandler 등록
  auto handler = std::make_unique<ZoomEventStreamHandler>();
  plugin->event_handler_ = handler.get();
  event_channel->SetStreamHandler(std::move(handler));

  method_channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

ZoomVideoSdkFlutterPlugin::ZoomVideoSdkFlutterPlugin() {}

ZoomVideoSdkFlutterPlugin::~ZoomVideoSdkFlutterPlugin() {
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
  }
  // Share
  else if (method == "share.startShareScreen") {
    HandleShareStartScreen(std::move(result));
  } else if (method == "share.startShareView") {
    HandleShareStartView(args, std::move(result));
  } else if (method == "share.stopShare") {
    HandleShareStop(std::move(result));
  } else if (method == "share.enableShareDeviceAudio") {
    HandleShareEnableDeviceAudio(args, std::move(result));
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

  auto err = sdk_->initialize(params);
  if (err == ZoomVideoSDKErrors_Success) {
    if (event_handler_) {
      sdk_->addListener(event_handler_);
    }
    result->Success();
  } else {
    result->Error("INIT_FAILED",
                  "SDK init failed: " + std::to_string(err));
  }
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

// MARK: - Audio

void ZoomVideoSdkFlutterPlugin::HandleAudioStartAudio(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto err = sdk_ ? sdk_->getAudioHelper()->startAudio()
                  : ZoomVideoSDKErrors_Uninitialize;
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("AUDIO_ERROR", "startAudio failed: " + std::to_string(err));
  }
}

void ZoomVideoSdkFlutterPlugin::HandleAudioStopAudio(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto err = sdk_ ? sdk_->getAudioHelper()->stopAudio()
                  : ZoomVideoSDKErrors_Uninitialize;
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("AUDIO_ERROR", "stopAudio failed: " + std::to_string(err));
  }
}

void ZoomVideoSdkFlutterPlugin::HandleAudioMuteAudio(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto userId = GetString(args, "userId");
  auto* user = FindUser(userId);
  if (!user) {
    result->Error("INVALID_ARGS", "User not found");
    return;
  }
  auto err = sdk_->getAudioHelper()->muteAudio(user);
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("AUDIO_ERROR", "muteAudio failed: " + std::to_string(err));
  }
}

void ZoomVideoSdkFlutterPlugin::HandleAudioUnmuteAudio(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto userId = GetString(args, "userId");
  auto* user = FindUser(userId);
  if (!user) {
    result->Error("INVALID_ARGS", "User not found");
    return;
  }
  auto err = sdk_->getAudioHelper()->unMuteAudio(user);
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("AUDIO_ERROR",
                  "unmuteAudio failed: " + std::to_string(err));
  }
}

void ZoomVideoSdkFlutterPlugin::HandleAudioEnableMicOriginalInput(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool enable = GetBool(args, "enable", false);
  auto err = sdk_ ? sdk_->getAudioSettingHelper()->enableMicOriginalInput(enable)
                  : ZoomVideoSDKErrors_Uninitialize;
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("AUDIO_ERROR",
                  "enableMicOriginalInput failed: " + std::to_string(err));
  }
}

void ZoomVideoSdkFlutterPlugin::HandleAudioSetNoiseSuppression(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto levelStr = GetString(args, "level", "auto_");
  ZoomVideoSDKSuppressBackgroundNoiseLevel level;
  if (levelStr == "low") level = ZoomVideoSDKSuppressBackgroundNoiseLevel_Low;
  else if (levelStr == "medium") level = ZoomVideoSDKSuppressBackgroundNoiseLevel_Medium;
  else if (levelStr == "high") level = ZoomVideoSDKSuppressBackgroundNoiseLevel_High;
  else level = ZoomVideoSDKSuppressBackgroundNoiseLevel_Auto;

  auto err = sdk_ ? sdk_->getAudioSettingHelper()->setSuppressBackgroundNoiseLevel(level)
                  : ZoomVideoSDKErrors_Uninitialize;
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("AUDIO_ERROR",
                  "setNoiseSuppression failed: " + std::to_string(err));
  }
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
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("VIDEO_ERROR", "startVideo failed: " + std::to_string(err));
  }
}

void ZoomVideoSdkFlutterPlugin::HandleVideoStopVideo(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto err = sdk_ ? sdk_->getVideoHelper()->stopVideo()
                  : ZoomVideoSDKErrors_Uninitialize;
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("VIDEO_ERROR", "stopVideo failed: " + std::to_string(err));
  }
}

void ZoomVideoSdkFlutterPlugin::HandleVideoSwitchCamera(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool success = sdk_ ? sdk_->getVideoHelper()->switchCamera() : false;
  if (success) {
    result->Success();
  } else {
    result->Error("VIDEO_ERROR", "switchCamera failed");
  }
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

// MARK: - Share

void ZoomVideoSdkFlutterPlugin::HandleShareStartScreen(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!sdk_) {
    result->Error("SHARE_ERROR", "SDK not initialized");
    return;
  }
  // Windows: startShareScreen에 monitorID 전달 (nullptr = 기본 모니터)
  ZoomVideoSDKShareOption option;
  auto err = sdk_->getShareHelper()->startShareScreen(nullptr, option);
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("SHARE_ERROR",
                  "startShareScreen failed: " + std::to_string(err));
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

  // windowId를 HWND로 변환
  HWND hwnd = reinterpret_cast<HWND>(
      static_cast<uintptr_t>(std::stoull(windowIdStr)));
  ZoomVideoSDKShareOption option;
  auto err = sdk_->getShareHelper()->startShareView(hwnd, option);
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("SHARE_ERROR",
                  "startShareView failed: " + std::to_string(err));
  }
}

void ZoomVideoSdkFlutterPlugin::HandleShareStop(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto err = sdk_ ? sdk_->getShareHelper()->stopShare()
                  : ZoomVideoSDKErrors_Uninitialize;
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("SHARE_ERROR", "stopShare failed: " + std::to_string(err));
  }
}

void ZoomVideoSdkFlutterPlugin::HandleShareEnableDeviceAudio(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool enable = GetBool(args, "enable", false);
  auto err = sdk_ ? sdk_->getShareHelper()->enableShareDeviceAudio(enable)
                  : ZoomVideoSDKErrors_Uninitialize;
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("SHARE_ERROR",
                  "enableShareDeviceAudio failed: " + std::to_string(err));
  }
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
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("CHAT_ERROR",
                  "sendChatToAll failed: " + std::to_string(err));
  }
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
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("CHAT_ERROR",
                  "sendChatToUser failed: " + std::to_string(err));
  }
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
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("RECORDING_ERROR",
                  "startCloudRecording failed: " + std::to_string(err));
  }
}

void ZoomVideoSdkFlutterPlugin::HandleRecordingStop(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto err = sdk_ ? sdk_->getRecordingHelper()->stopCloudRecording()
                  : ZoomVideoSDKErrors_Uninitialize;
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("RECORDING_ERROR",
                  "stopCloudRecording failed: " + std::to_string(err));
  }
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
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("VB_ERROR", "addItem failed: " + std::to_string(err));
  }
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
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("VB_ERROR", "setItem failed: " + std::to_string(err));
  }
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
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("VB_ERROR", "removeItem failed: " + std::to_string(err));
  }
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
  auto userId = GetString(args, "userId");
  auto* user = FindUser(userId);
  if (!user) {
    result->Error("INVALID_ARGS", "User not found");
    return;
  }
  bool success = sdk_->getUserHelper()->makeHost(user);
  if (success) {
    result->Success();
  } else {
    result->Error("USER_ERROR", "makeHost failed");
  }
}

void ZoomVideoSdkFlutterPlugin::HandleUserMakeManager(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto userId = GetString(args, "userId");
  auto* user = FindUser(userId);
  if (!user) {
    result->Error("INVALID_ARGS", "User not found");
    return;
  }
  bool success = sdk_->getUserHelper()->makeManager(user);
  if (success) {
    result->Success();
  } else {
    result->Error("USER_ERROR", "makeManager failed");
  }
}

void ZoomVideoSdkFlutterPlugin::HandleUserRevokeManager(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto userId = GetString(args, "userId");
  auto* user = FindUser(userId);
  if (!user) {
    result->Error("INVALID_ARGS", "User not found");
    return;
  }
  auto err = sdk_->getUserHelper()->revokeManager(user);
  if (err == ZoomVideoSDKErrors_Success) {
    result->Success();
  } else {
    result->Error("USER_ERROR",
                  "revokeManager failed: " + std::to_string(err));
  }
}

void ZoomVideoSdkFlutterPlugin::HandleUserRemove(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto userId = GetString(args, "userId");
  auto* user = FindUser(userId);
  if (!user) {
    result->Error("INVALID_ARGS", "User not found");
    return;
  }
  bool success = sdk_->getUserHelper()->removeUser(user);
  if (success) {
    result->Success();
  } else {
    result->Error("USER_ERROR", "removeUser failed");
  }
}

void ZoomVideoSdkFlutterPlugin::HandleUserChangeName(
    const flutter::EncodableMap* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto name = GetString(args, "name");
  auto userId = GetString(args, "userId");
  auto* user = FindUser(userId);
  if (!user || name.empty()) {
    result->Error("INVALID_ARGS", "name and userId required");
    return;
  }
  std::wstring wideName = Utf8ToWide(name);
  bool success = sdk_->getUserHelper()->changeName(wideName.c_str(), user);
  if (success) {
    result->Success();
  } else {
    result->Error("USER_ERROR", "changeName failed");
  }
}

}  // namespace zoom_video_sdk_flutter
