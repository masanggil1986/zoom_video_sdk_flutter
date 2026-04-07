#ifndef FLUTTER_PLUGIN_ZOOM_VIDEO_SDK_FLUTTER_PLUGIN_H_
#define FLUTTER_PLUGIN_ZOOM_VIDEO_SDK_FLUTTER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace zoom_video_sdk_flutter {

class ZoomVideoSdkFlutterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  ZoomVideoSdkFlutterPlugin();

  virtual ~ZoomVideoSdkFlutterPlugin();

  // Disallow copy and assign.
  ZoomVideoSdkFlutterPlugin(const ZoomVideoSdkFlutterPlugin&) = delete;
  ZoomVideoSdkFlutterPlugin& operator=(const ZoomVideoSdkFlutterPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace zoom_video_sdk_flutter

#endif  // FLUTTER_PLUGIN_ZOOM_VIDEO_SDK_FLUTTER_PLUGIN_H_
