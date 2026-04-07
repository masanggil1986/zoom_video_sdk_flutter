
import 'zoom_video_sdk_flutter_platform_interface.dart';

class ZoomVideoSdkFlutter {
  Future<String?> getPlatformVersion() {
    return ZoomVideoSdkFlutterPlatform.instance.getPlatformVersion();
  }
}
