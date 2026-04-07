import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'zoom_video_sdk_flutter_method_channel.dart';

abstract class ZoomVideoSdkFlutterPlatform extends PlatformInterface {
  /// Constructs a ZoomVideoSdkFlutterPlatform.
  ZoomVideoSdkFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static ZoomVideoSdkFlutterPlatform _instance =
      MethodChannelZoomVideoSdkFlutter();

  /// The default instance of [ZoomVideoSdkFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelZoomVideoSdkFlutter].
  static ZoomVideoSdkFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ZoomVideoSdkFlutterPlatform] when
  /// they register themselves.
  static set instance(ZoomVideoSdkFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
