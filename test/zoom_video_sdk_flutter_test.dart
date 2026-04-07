import 'package:flutter_test/flutter_test.dart';
import 'package:zoom_video_sdk_flutter/zoom_video_sdk_flutter.dart';

void main() {
  test('ZoomVideoSdk can be instantiated', () {
    final sdk = ZoomVideoSdk();
    expect(sdk.audioHelper, isNotNull);
    expect(sdk.videoHelper, isNotNull);
    expect(sdk.shareHelper, isNotNull);
    expect(sdk.chatHelper, isNotNull);
    expect(sdk.recordingHelper, isNotNull);
    expect(sdk.virtualBackgroundHelper, isNotNull);
    expect(sdk.userHelper, isNotNull);
    sdk.dispose();
  });

  test('Event stream getters do not throw', () {
    final sdk = ZoomVideoSdk();
    expect(sdk.events, isNotNull);
    expect(sdk.onSessionJoin, isNotNull);
    expect(sdk.onSessionLeave, isNotNull);
    expect(sdk.onUserJoined, isNotNull);
    expect(sdk.onUserLeft, isNotNull);
    expect(sdk.onUserVideoStatusChanged, isNotNull);
    expect(sdk.onUserAudioStatusChanged, isNotNull);
    expect(sdk.onUserActiveAudioChanged, isNotNull);
    expect(sdk.onChatMessageReceived, isNotNull);
    expect(sdk.onUserShareStatusChanged, isNotNull);
    expect(sdk.onUserHostChanged, isNotNull);
    expect(sdk.onUserManagerChanged, isNotNull);
    expect(sdk.onUserNameChanged, isNotNull);
    expect(sdk.onSessionNeedPassword, isNotNull);
    expect(sdk.onSessionPasswordWrong, isNotNull);
    expect(sdk.onError, isNotNull);
    sdk.dispose();
  });
}
