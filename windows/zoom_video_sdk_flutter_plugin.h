#ifndef FLUTTER_PLUGIN_ZOOM_VIDEO_SDK_FLUTTER_PLUGIN_H_
#define FLUTTER_PLUGIN_ZOOM_VIDEO_SDK_FLUTTER_PLUGIN_H_

#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/texture_registrar.h>

#include <memory>

#include "zoom_video_sdk_api.h"
#include "zoom_video_sdk_interface.h"
#include "zoom_event_stream_handler.h"
#include "zoom_video_texture_renderer.h"

USING_ZOOM_VIDEO_SDK_NAMESPACE

namespace zoom_video_sdk_flutter {

class ZoomVideoSdkFlutterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  ZoomVideoSdkFlutterPlugin();
  virtual ~ZoomVideoSdkFlutterPlugin();

  ZoomVideoSdkFlutterPlugin(const ZoomVideoSdkFlutterPlugin&) = delete;
  ZoomVideoSdkFlutterPlugin& operator=(const ZoomVideoSdkFlutterPlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  IZoomVideoSDK* sdk_ = nullptr;
  ZoomEventStreamHandler* event_handler_ = nullptr;
  std::unique_ptr<ZoomVideoTextureManager> texture_manager_;
  // Top-level HWND of the Flutter host window — used to exclude our own
  // window from share source enumeration.
  HWND flutter_hwnd_ = nullptr;

  // SDK에서 userId로 유저 객체를 찾는 헬퍼
  IZoomVideoSDKUser* FindUser(const std::string& userId);

  // 메서드별 핸들러
  void HandleInit(const flutter::EncodableMap* args,
                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleCleanup(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleJoinSession(const flutter::EncodableMap* args,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleLeaveSession(const flutter::EncodableMap* args,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleGetSessionInfo(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleGetMyself(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleGetAllUsers(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleGetRemoteUsers(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Command Channel
  void HandleSendCommand(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Audio
  void HandleAudioStartAudio(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleAudioStopAudio(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleAudioMuteAudio(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleAudioUnmuteAudio(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleAudioEnableMicOriginalInput(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleAudioSetNoiseSuppression(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleAudioGetDeviceList(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleAudioSelectDevice(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Video
  void HandleVideoStartVideo(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleVideoStopVideo(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleVideoSwitchCamera(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleVideoGetCameraList(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleVideoSelectCamera(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleVideoSetQualityPreference(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Video view (texture-based rendering)
  void HandleVideoViewCreate(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleVideoViewDispose(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Share
  void HandleShareStartScreen(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleShareStartView(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleShareStop(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleShareEnableDeviceAudio(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleShareEnableOptimizeForVideo(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleShareGetSourceList(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Chat
  void HandleChatSendToAll(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleChatSendToUser(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleChatIsDisabled(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleChatIsPrivateDisabled(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Recording
  void HandleRecordingCanStart(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleRecordingStart(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleRecordingStop(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Virtual Background
  void HandleVBIsSupported(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleVBAddItem(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleVBGetItemList(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleVBSetItem(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleVBRemoveItem(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleVBGetSelectedItem(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // User Management
  void HandleUserMakeHost(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleUserMakeManager(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleUserRevokeManager(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleUserRemove(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleUserChangeName(const flutter::EncodableMap* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace zoom_video_sdk_flutter

#endif  // FLUTTER_PLUGIN_ZOOM_VIDEO_SDK_FLUTTER_PLUGIN_H_
