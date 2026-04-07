import 'package:flutter_test/flutter_test.dart';
import 'package:zoom_video_sdk_flutter/zoom_video_sdk_flutter.dart';
import 'package:zoom_video_sdk_flutter/zoom_video_sdk_flutter_platform_interface.dart';
import 'package:zoom_video_sdk_flutter/zoom_video_sdk_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockZoomVideoSdkFlutterPlatform
    with MockPlatformInterfaceMixin
    implements ZoomVideoSdkFlutterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final ZoomVideoSdkFlutterPlatform initialPlatform = ZoomVideoSdkFlutterPlatform.instance;

  test('$MethodChannelZoomVideoSdkFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelZoomVideoSdkFlutter>());
  });

  test('getPlatformVersion', () async {
    ZoomVideoSdkFlutter zoomVideoSdkFlutterPlugin = ZoomVideoSdkFlutter();
    MockZoomVideoSdkFlutterPlatform fakePlatform = MockZoomVideoSdkFlutterPlatform();
    ZoomVideoSdkFlutterPlatform.instance = fakePlatform;

    expect(await zoomVideoSdkFlutterPlugin.getPlatformVersion(), '42');
  });
}
