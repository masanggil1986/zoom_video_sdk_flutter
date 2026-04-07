import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'zoom_video_sdk_flutter_platform_interface.dart';

/// An implementation of [ZoomVideoSdkFlutterPlatform] that uses method channels.
class MethodChannelZoomVideoSdkFlutter extends ZoomVideoSdkFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('zoom_video_sdk_flutter');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
