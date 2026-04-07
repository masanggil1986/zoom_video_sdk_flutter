#include "include/zoom_video_sdk_flutter/zoom_video_sdk_flutter_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "zoom_video_sdk_flutter_plugin.h"

void ZoomVideoSdkFlutterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  zoom_video_sdk_flutter::ZoomVideoSdkFlutterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
