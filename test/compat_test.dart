import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoom_video_sdk_flutter/compat.dart';
import 'package:zoom_video_sdk_flutter/zoom_video_sdk_flutter.dart' as plugin;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('zoom_video_sdk_flutter');
  const eventChannel = EventChannel('zoom_video_sdk_flutter/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final calls = <MethodCall>[];
  late StreamController<Object?> nativeEvents;
  Object? Function(MethodCall call)? onCall; // 테스트별 응답 오버라이드

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    calls.clear();
    onCall = null;
    nativeEvents = StreamController<Object?>.broadcast();
    messenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (args, sink) {
          nativeEvents.stream.listen(sink.success);
        },
      ),
    );
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      calls.add(call);
      return onCall?.call(call);
    });
    // 데스크톱 경로가 mock 채널 위에서 새로 만든 인스턴스를 쓰도록 주입.
    debugDesktopSdkOverride = plugin.ZoomVideoSdk();
  });

  tearDown(() async {
    debugDesktopSdkOverride?.dispose();
    debugDesktopSdkOverride = null;
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockStreamHandler(eventChannel, null);
    await nativeEvents.close();
    debugDefaultTargetPlatformOverride = null;
  });

  const initConfig = InitConfig(domain: 'zoom.us', enableLog: false);

  test('initSdk 성공 → 모바일 계약 문자열', () async {
    expect(
      await ZoomVideoSdk().initSdk(initConfig),
      'SDK initialized successfully',
    );
    expect(calls.single.method, 'init');
    final args = Map<String, dynamic>.from(calls.single.arguments as Map);
    expect(args['domain'], 'https://zoom.us'); // 스킴 보정
  });

  test('initSdk Wrong_Usage → 모바일 계약 문자열', () async {
    onCall = (call) => throw PlatformException(
      code: 'INIT_FAILED',
      message: 'SDK init failed: ZMVideoSDKErrors_Wrong_Usage',
    );
    expect(
      await ZoomVideoSdk().initSdk(initConfig),
      'ZoomVideoSDKError_Wrong_Usage',
    );
  });

  test('cleanup → cleanup 채널 + Success 문자열', () async {
    expect(await ZoomVideoSdk().cleanup(), 'ZoomVideoSDKError_Success');
    expect(calls.single.method, 'cleanup');
  });

  JoinSessionConfig joinConfig() => JoinSessionConfig(
    sessionName: 'lesson-1',
    token: 'jwt',
    userName: 'Tutor',
    sessionPassword: '',
    audioOptions: {'connect': true, 'mute': false},
    videoOptions: {'localVideoOn': true},
    sessionIdleTimeoutMins: 40,
  );

  test('joinSession: sessionJoined 이벤트 → join session success', () async {
    final future = ZoomVideoSdk().joinSession(joinConfig());
    await Future<void>.delayed(Duration.zero); // joinSession 채널 호출까지 진행
    nativeEvents.add({'eventType': 'sessionJoined', 'data': {}});
    expect(await future, 'join session success');
    expect(calls.single.method, 'joinSession');
  });

  test('joinSession: error 이벤트 → 비성공 문자열', () async {
    final future = ZoomVideoSdk().joinSession(joinConfig());
    await Future<void>.delayed(Duration.zero);
    nativeEvents.add({
      'eventType': 'error',
      'data': {'errorCode': 'sessionJoinFailed', 'message': 'no host'},
    });
    final result = await future;
    expect(result.toLowerCase(), isNot('join session success'));
    expect(result, contains('sessionJoinFailed'));
  });

  test('leaveSession → Success 문자열 + endSession 전달', () async {
    expect(
      await ZoomVideoSdk().leaveSession(false),
      'ZoomVideoSDKError_Success',
    );
    expect(calls.single.method, 'leaveSession');
    expect((calls.single.arguments as Map)['endSession'], false);
  });

  test('session.getMySelf → compat user (customUserId·status 스냅샷)', () async {
    onCall = (call) => call.method == 'getMyself'
        ? {
            'userId': 'u1',
            'userName': 'Me',
            'isHost': true,
            'customUserId': 'stu-9',
            'videoStatus': {'isOn': true, 'hasSource': true},
            'audioStatus': {
              'isMuted': false,
              'isTalking': false,
              'audioType': 'voip',
            },
          }
        : null;
    final me = await ZoomVideoSdk().session.getMySelf();
    expect(me!.userId, 'u1');
    expect(me.customUserId, 'stu-9');
    expect(await me.videoStatus!.isOn(), isTrue);
    expect(await me.audioStatus!.isMuted(), isFalse);
  });

  test('cmdChannel.sendCommand → cmd.sendCommand 채널', () async {
    await ZoomVideoSdk().cmdChannel.sendCommand('u2', '{"type":"praise"}');
    expect(calls.single.method, 'cmd.sendCommand');
    expect((calls.single.arguments as Map)['receiverUserId'], 'u2');
  });

  test('이벤트 리스너: chat 이벤트 → 모바일 data 모양', () async {
    final received = Completer<dynamic>();
    final sub = ZoomVideoSdkEventListener().addListener(
      EventType.onChatNewMessageNotify,
      received.complete,
    );
    nativeEvents.add({
      'eventType': 'chatMessageReceived',
      'data': {
        'message': {
          'messageId': 'm1',
          'content': 'hi',
          'senderUser': {'userId': 'u2', 'userName': 'Stu', 'isHost': false},
          'isChatToAll': true,
          'isSelfSend': false,
          'timestamp': 1700000000000,
        },
      },
    });
    final data = await received.future;
    final msg = ZoomVideoSdkChatMessage.fromJson(
      Map<String, dynamic>.from(data['message'] as Map),
    );
    expect(msg.messageID, 'm1');
    expect(msg.content, 'hi');
    expect(msg.senderUser.userName, 'Stu');
    expect(msg.isSelfSend, isFalse);
    expect(msg.timestamp, 1700000000000);
    await sub.cancel();
  });

  test('이벤트 리스너: command 이벤트 → data["command"]', () async {
    final received = Completer<dynamic>();
    final sub = ZoomVideoSdkEventListener().addListener(
      EventType.onCommandReceived,
      received.complete,
    );
    nativeEvents.add({
      'eventType': 'commandReceived',
      'data': {'senderId': 'u1', 'command': '{"type":"praise","emoji":"👏"}'},
    });
    final data = await received.future;
    expect(data['command'], '{"type":"praise","emoji":"👏"}');
    await sub.cancel();
  });

  test('모바일 경로: 두 이벤트에 등록한 두 리스너가 모두 이벤트를 받는다', () async {
    // last-wins 회귀 방지: 모바일 공식 리스너는 생성 시마다 EventChannel 을
    // 재등록하므로, addListener 마다 새 인스턴스를 만들면 마지막 구독만 살아남는다.
    // 공식 패키지의 이벤트 채널('eventListener')을 mock 해 두 리스너가 서로 다른
    // 이벤트를 각각 수신하는지 검증한다(구 코드는 첫 리스너가 0건 → 실패).
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const officialEventChannel = EventChannel('eventListener');
    MockStreamHandlerEventSink? sink;
    messenger.setMockStreamHandler(
      officialEventChannel,
      MockStreamHandler.inline(onListen: (args, s) => sink = s),
    );
    try {
      final sessionJoin = Completer<dynamic>();
      final userJoin = Completer<dynamic>();
      final sub1 = ZoomVideoSdkEventListener().addListener(
        EventType.onSessionJoin,
        sessionJoin.complete,
      );
      final sub2 = ZoomVideoSdkEventListener().addListener(
        EventType.onUserJoin,
        userJoin.complete,
      );
      // 공식 패키지 payload 모양: {'name': eventType, 'message': data}
      sink!.success({'name': EventType.onSessionJoin, 'message': {}});
      sink!.success({'name': EventType.onUserJoin, 'message': {}});
      await sessionJoin.future.timeout(const Duration(seconds: 1));
      await userJoin.future.timeout(const Duration(seconds: 1));
      await sub1.cancel();
      await sub2.cancel();
    } finally {
      messenger.setMockStreamHandler(officialEventChannel, null);
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    }
  });

  test('VB: getVirtualBackgroundItemList 가 모바일 type 문자열로 매핑', () async {
    onCall = (call) => call.method == 'virtualBackground.getItemList'
        ? [
            {'imageName': 'blurX', 'imagePath': '', 'type': 'blur'},
            {'imageName': 'img1', 'imagePath': '/p/1', 'type': 'image'},
          ]
        : null;
    final items = await ZoomVideoSdk().virtualBackgroundHelper
        .getVirtualBackgroundItemList();
    expect(items.first.type, 'ZoomVideoSDKVirtualBackgroundDataType_Blur');
    expect(items.last.type, 'ZoomVideoSDKVirtualBackgroundDataType_Image');
  });
}
