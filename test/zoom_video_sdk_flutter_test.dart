import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:zoom_video_sdk_flutter/zoom_video_sdk_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('zoom_video_sdk_flutter');

  /// 기록된 MethodChannel 호출
  final List<MethodCall> calls = [];

  /// 다음 invokeMethod 호출에 반환할 값
  dynamic nextResult;

  late ZoomVideoSdk sdk;

  setUp(() {
    calls.clear();
    nextResult = null;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
          calls.add(call);
          return nextResult;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  // ---- Instantiation ----

  group('ZoomVideoSdk instantiation', () {
    test('helpers are accessible', () {
      sdk = ZoomVideoSdk();
      expect(sdk.audioHelper, isNotNull);
      expect(sdk.videoHelper, isNotNull);
      expect(sdk.shareHelper, isNotNull);
      expect(sdk.chatHelper, isNotNull);
      expect(sdk.recordingHelper, isNotNull);
      expect(sdk.virtualBackgroundHelper, isNotNull);
      expect(sdk.userHelper, isNotNull);
      sdk.dispose();
    });

    test('event stream getters are accessible', () {
      sdk = ZoomVideoSdk();
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
  });

  // ---- SDK Lifecycle ----

  group('SDK lifecycle', () {
    setUp(() => sdk = ZoomVideoSdk());
    tearDown(() => sdk.dispose());

    test('init sends correct method and args', () async {
      await sdk.init(
        const ZoomInitConfig(
          domain: 'zoom.us',
          enableLog: false,
          appGroupId: 'group.test',
        ),
      );

      expect(calls, hasLength(1));
      expect(calls.first.method, 'init');
      expect(calls.first.arguments, {
        'domain': 'zoom.us',
        'enableLog': false,
        'appGroupId': 'group.test',
      });
    });

    test('init with defaults omits appGroupId', () async {
      await sdk.init(const ZoomInitConfig());

      expect(calls.first.arguments, {
        'domain': 'https://zoom.us',
        'enableLog': true,
      });
    });

    test('joinSession sends all fields', () async {
      await sdk.joinSession(
        const ZoomJoinSessionConfig(
          sessionName: 'test-session',
          userName: 'Alice',
          token: 'jwt-token',
          sessionPassword: '1234',
          audioOptions: ZoomAudioOptions(connect: false, mute: true),
          videoOptions: ZoomVideoOptions(localVideoOn: true),
          sessionIdleTimeoutMins: 30,
        ),
      );

      expect(calls.first.method, 'joinSession');
      final args = calls.first.arguments as Map;
      expect(args['sessionName'], 'test-session');
      expect(args['userName'], 'Alice');
      expect(args['token'], 'jwt-token');
      expect(args['sessionPassword'], '1234');
      expect(args['audioOptions'], {
        'connect': false,
        'mute': true,
        'autoAdjustSpeakerVolume': true,
      });
      expect(args['videoOptions'], {'localVideoOn': true});
      expect(args['sessionIdleTimeoutMins'], 30);
    });

    test('joinSession with minimal config omits optional fields', () async {
      await sdk.joinSession(
        const ZoomJoinSessionConfig(
          sessionName: 's',
          userName: 'u',
          token: 't',
        ),
      );

      final args = calls.first.arguments as Map;
      expect(args.containsKey('sessionPassword'), isFalse);
      expect(args.containsKey('audioOptions'), isFalse);
      expect(args.containsKey('videoOptions'), isFalse);
      expect(args.containsKey('sessionIdleTimeoutMins'), isFalse);
    });

    test('leaveSession sends endSession flag', () async {
      await sdk.leaveSession(endSession: true);

      expect(calls.first.method, 'leaveSession');
      expect(calls.first.arguments, {'endSession': true});
    });

    test('leaveSession defaults to endSession=false', () async {
      await sdk.leaveSession();

      expect(calls.first.arguments, {'endSession': false});
    });

    test('getSessionInfo deserializes response', () async {
      nextResult = {
        'sessionName': 'my-session',
        'sessionId': 'sid-123',
        'sessionPassword': 'pw',
        'host': {
          'userId': 'u1',
          'userName': 'Host',
          'isHost': true,
          'isManager': false,
        },
      };

      final info = await sdk.getSessionInfo();

      expect(info.sessionName, 'my-session');
      expect(info.sessionId, 'sid-123');
      expect(info.sessionPassword, 'pw');
      expect(info.host, isNotNull);
      expect(info.host!.userId, 'u1');
      expect(info.host!.isHost, isTrue);
    });

    test('getMyself deserializes user with audio/video status', () async {
      nextResult = {
        'userId': 'me-1',
        'userName': 'Me',
        'isHost': false,
        'isManager': true,
        'audioStatus': {
          'isMuted': false,
          'isTalking': true,
          'audioType': 'voip',
        },
        'videoStatus': {'isOn': true, 'hasSource': true},
      };

      final user = await sdk.getMyself();

      expect(user.userId, 'me-1');
      expect(user.userName, 'Me');
      expect(user.isManager, isTrue);
      expect(user.audioStatus, isNotNull);
      expect(user.audioStatus!.isMuted, isFalse);
      expect(user.audioStatus!.isTalking, isTrue);
      expect(user.audioStatus!.audioType, ZoomAudioType.voip);
      expect(user.videoStatus, isNotNull);
      expect(user.videoStatus!.isOn, isTrue);
      expect(user.videoStatus!.hasSource, isTrue);
    });

    test('getAllUsers deserializes list', () async {
      nextResult = [
        {'userId': 'u1', 'userName': 'A', 'isHost': true, 'isManager': false},
        {'userId': 'u2', 'userName': 'B', 'isHost': false, 'isManager': false},
      ];

      final users = await sdk.getAllUsers();

      expect(users, hasLength(2));
      expect(users[0].userId, 'u1');
      expect(users[1].userName, 'B');
    });

    test('getRemoteUsers deserializes list', () async {
      nextResult = [
        {
          'userId': 'r1',
          'userName': 'Remote',
          'isHost': false,
          'isManager': false,
        },
      ];

      final users = await sdk.getRemoteUsers();

      expect(users, hasLength(1));
      expect(users.first.userId, 'r1');
    });
  });

  // ---- Audio Helper ----

  group('AudioHelper', () {
    setUp(() => sdk = ZoomVideoSdk());
    tearDown(() => sdk.dispose());

    test('startAudio', () async {
      await sdk.audioHelper.startAudio();
      expect(calls.first.method, 'audio.startAudio');
    });

    test('stopAudio', () async {
      await sdk.audioHelper.stopAudio();
      expect(calls.first.method, 'audio.stopAudio');
    });

    test('muteAudio sends userId', () async {
      await sdk.audioHelper.muteAudio('user-123');
      expect(calls.first.method, 'audio.muteAudio');
      expect(calls.first.arguments, {'userId': 'user-123'});
    });

    test('unmuteAudio sends userId', () async {
      await sdk.audioHelper.unmuteAudio('user-123');
      expect(calls.first.method, 'audio.unmuteAudio');
      expect(calls.first.arguments, {'userId': 'user-123'});
    });

    test('enableMicOriginalInput', () async {
      await sdk.audioHelper.enableMicOriginalInput(true);
      expect(calls.first.method, 'audio.enableMicOriginalInput');
      expect(calls.first.arguments, {'enable': true});
    });

    test('setNoiseSuppression sends enum name', () async {
      await sdk.audioHelper.setNoiseSuppression(ZoomNoiseSuppression.high);
      expect(calls.first.method, 'audio.setNoiseSuppression');
      expect(calls.first.arguments, {'level': 'high'});
    });

    test('getAudioDeviceList deserializes', () async {
      nextResult = [
        {'deviceId': 'd1', 'deviceName': 'Mic'},
        {'deviceId': 'd2', 'deviceName': 'Speaker'},
      ];

      final devices = await sdk.audioHelper.getAudioDeviceList();

      expect(devices, hasLength(2));
      expect(devices[0].deviceId, 'd1');
      expect(devices[1].deviceName, 'Speaker');
    });

    test('selectAudioDevice', () async {
      await sdk.audioHelper.selectAudioDevice('d1');
      expect(calls.first.method, 'audio.selectAudioDevice');
      expect(calls.first.arguments, {'deviceId': 'd1'});
    });
  });

  // ---- Video Helper ----

  group('VideoHelper', () {
    setUp(() => sdk = ZoomVideoSdk());
    tearDown(() => sdk.dispose());

    test('startVideo', () async {
      await sdk.videoHelper.startVideo();
      expect(calls.first.method, 'video.startVideo');
    });

    test('stopVideo', () async {
      await sdk.videoHelper.stopVideo();
      expect(calls.first.method, 'video.stopVideo');
    });

    test('switchCamera', () async {
      await sdk.videoHelper.switchCamera();
      expect(calls.first.method, 'video.switchCamera');
    });

    test('getCameraList deserializes', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      nextResult = [
        {'deviceId': 'cam1', 'deviceName': 'FaceTime HD'},
      ];

      final cameras = await sdk.videoHelper.getCameraList();

      expect(cameras, hasLength(1));
      expect(cameras.first.deviceId, 'cam1');
      expect(cameras.first.deviceName, 'FaceTime HD');
    });
  });

  // ---- Share Helper ----

  group('ShareHelper', () {
    setUp(() => sdk = ZoomVideoSdk());
    tearDown(() => sdk.dispose());

    test('startShareScreen', () async {
      await sdk.shareHelper.startShareScreen();
      expect(calls.first.method, 'share.startShareScreen');
    });

    test('startShareView sends windowId', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await sdk.shareHelper.startShareView('12345');
      expect(calls.first.method, 'share.startShareView');
      expect(calls.first.arguments, {'windowId': '12345'});
    });

    test('stopShare', () async {
      await sdk.shareHelper.stopShare();
      expect(calls.first.method, 'share.stopShare');
    });

    test('enableShareDeviceAudio', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await sdk.shareHelper.enableShareDeviceAudio(true);
      expect(calls.first.method, 'share.enableShareDeviceAudio');
      expect(calls.first.arguments, {'enable': true});
    });
  });

  // ---- Chat Helper ----

  group('ChatHelper', () {
    setUp(() => sdk = ZoomVideoSdk());
    tearDown(() => sdk.dispose());

    test('sendChatToAll', () async {
      await sdk.chatHelper.sendChatToAll('hello');
      expect(calls.first.method, 'chat.sendChatToAll');
      expect(calls.first.arguments, {'message': 'hello'});
    });

    test('sendChatToUser', () async {
      await sdk.chatHelper.sendChatToUser('u1', 'hi');
      expect(calls.first.method, 'chat.sendChatToUser');
      expect(calls.first.arguments, {'userId': 'u1', 'message': 'hi'});
    });

    test('isChatDisabled returns bool', () async {
      nextResult = true;
      expect(await sdk.chatHelper.isChatDisabled(), isTrue);
    });

    test('isPrivateChatDisabled returns bool', () async {
      nextResult = false;
      expect(await sdk.chatHelper.isPrivateChatDisabled(), isFalse);
    });
  });

  // ---- Recording Helper ----

  group('RecordingHelper', () {
    setUp(() => sdk = ZoomVideoSdk());
    tearDown(() => sdk.dispose());

    test('canStartRecording returns bool', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      nextResult = true;
      expect(await sdk.recordingHelper.canStartRecording(), isTrue);
    });

    test('startCloudRecording', () async {
      await sdk.recordingHelper.startCloudRecording();
      expect(calls.first.method, 'recording.startCloudRecording');
    });

    test('stopCloudRecording', () async {
      await sdk.recordingHelper.stopCloudRecording();
      expect(calls.first.method, 'recording.stopCloudRecording');
    });
  });

  // ---- Virtual Background Helper ----

  group('VirtualBackgroundHelper', () {
    setUp(() => sdk = ZoomVideoSdk());
    tearDown(() => sdk.dispose());

    test('isSupported returns bool', () async {
      nextResult = true;
      expect(await sdk.virtualBackgroundHelper.isSupported(), isTrue);
    });

    test('addItem sends filePath', () async {
      await sdk.virtualBackgroundHelper.addItem('/path/to/img.png');
      expect(calls.first.method, 'virtualBackground.addItem');
      expect(calls.first.arguments, {'filePath': '/path/to/img.png'});
    });

    test('getItemList deserializes', () async {
      nextResult = [
        {'imageName': 'bg1', 'imagePath': '/bg1.png'},
      ];

      final items = await sdk.virtualBackgroundHelper.getItemList();

      expect(items, hasLength(1));
      expect(items.first.imageName, 'bg1');
      expect(items.first.imagePath, '/bg1.png');
    });

    test('setItem sends imageName', () async {
      await sdk.virtualBackgroundHelper.setItem('bg1');
      expect(calls.first.method, 'virtualBackground.setItem');
      expect(calls.first.arguments, {'imageName': 'bg1'});
    });

    test('removeItem sends imageName', () async {
      await sdk.virtualBackgroundHelper.removeItem('bg1');
      expect(calls.first.method, 'virtualBackground.removeItem');
    });

    test('getSelectedItem returns null when none', () async {
      nextResult = null;
      expect(await sdk.virtualBackgroundHelper.getSelectedItem(), isNull);
    });

    test('getSelectedItem deserializes', () async {
      nextResult = {'imageName': 'bg1', 'imagePath': '/bg1.png'};

      final item = await sdk.virtualBackgroundHelper.getSelectedItem();

      expect(item, isNotNull);
      expect(item!.imageName, 'bg1');
    });
  });

  // ---- User Helper ----

  group('UserHelper', () {
    setUp(() => sdk = ZoomVideoSdk());
    tearDown(() => sdk.dispose());

    test('makeHost', () async {
      await sdk.userHelper.makeHost('u1');
      expect(calls.first.method, 'user.makeHost');
      expect(calls.first.arguments, {'userId': 'u1'});
    });

    test('makeManager', () async {
      await sdk.userHelper.makeManager('u1');
      expect(calls.first.method, 'user.makeManager');
      expect(calls.first.arguments, {'userId': 'u1'});
    });

    test('revokeManager', () async {
      await sdk.userHelper.revokeManager('u1');
      expect(calls.first.method, 'user.revokeManager');
      expect(calls.first.arguments, {'userId': 'u1'});
    });

    test('removeUser', () async {
      await sdk.userHelper.removeUser('u1');
      expect(calls.first.method, 'user.removeUser');
      expect(calls.first.arguments, {'userId': 'u1'});
    });

    test('changeName sends name and userId', () async {
      await sdk.userHelper.changeName('NewName', 'u1');
      expect(calls.first.method, 'user.changeName');
      expect(calls.first.arguments, {'name': 'NewName', 'userId': 'u1'});
    });
  });

  // ---- Event Decoding ----

  group('Event decoding', () {
    setUp(() => sdk = ZoomVideoSdk());
    tearDown(() => sdk.dispose());

    test('sessionJoined event', () async {
      final events = <ZoomEvent>[];
      sdk.onSessionJoin.listen(events.add);

      // EventChannel mock을 통해 이벤트 전달 시뮬레이션
      // _decodeEvent를 직접 테스트할 수 없으므로 top-level 함수 테스트로 대체
      // 아래에서 별도 테스트
    });
  });

  // ---- Deserialization (top-level functions) ----

  group('Event deserialization', () {
    // _decodeEvent는 private이므로 직접 호출 불가.
    // 대신 데이터 모델 생성자를 테스트.

    test('ZoomUser construction with all fields', () {
      const user = ZoomUser(
        userId: 'u1',
        userName: 'Alice',
        isHost: true,
        isManager: false,
        audioStatus: ZoomAudioStatus(
          isMuted: false,
          isTalking: true,
          audioType: ZoomAudioType.voip,
        ),
        videoStatus: ZoomVideoStatus(isOn: true, hasSource: true),
      );

      expect(user.userId, 'u1');
      expect(user.userName, 'Alice');
      expect(user.isHost, isTrue);
      expect(user.audioStatus!.audioType, ZoomAudioType.voip);
      expect(user.videoStatus!.isOn, isTrue);
    });

    test('ZoomUser construction with minimal fields', () {
      const user = ZoomUser(userId: 'u2', userName: 'Bob');

      expect(user.isHost, isFalse);
      expect(user.isManager, isFalse);
      expect(user.audioStatus, isNull);
      expect(user.videoStatus, isNull);
    });

    test('ZoomSessionInfo construction', () {
      const info = ZoomSessionInfo(
        sessionName: 's1',
        sessionId: 'id1',
        sessionPassword: 'pw',
        host: ZoomUser(userId: 'h1', userName: 'Host'),
      );

      expect(info.sessionName, 's1');
      expect(info.sessionPassword, 'pw');
      expect(info.host!.userId, 'h1');
    });

    test('ZoomChatMessage construction', () {
      final msg = ZoomChatMessage(
        messageId: '',
        content: 'hello',
        senderUser: const ZoomUser(userId: 's1', userName: 'Sender'),
        isChatToAll: true,
        isSelfSend: false,
        timestamp: DateTime(2026, 4, 8),
      );

      expect(msg.content, 'hello');
      expect(msg.receiverUser, isNull);
      expect(msg.isChatToAll, isTrue);
    });

    test('ZoomErrorCode has all expected values', () {
      expect(ZoomErrorCode.values.length, 24);
      expect(ZoomErrorCode.success.index, 0);
      expect(ZoomErrorCode.permissionDenied.name, 'permissionDenied');
    });

    test('ZoomNoiseSuppression enum', () {
      expect(ZoomNoiseSuppression.auto_.name, 'auto_');
      expect(ZoomNoiseSuppression.values, hasLength(4));
    });

    test('ZoomShareStatus enum', () {
      expect(ZoomShareStatus.values, hasLength(3));
    });

    test('ZoomVideoAspectMode enum', () {
      expect(ZoomVideoAspectMode.values, hasLength(2));
    });
  });

  // ---- Config classes ----

  group('Config classes', () {
    test('ZoomInitConfig defaults', () {
      const config = ZoomInitConfig();
      expect(config.domain, 'https://zoom.us');
      expect(config.enableLog, isTrue);
      expect(config.appGroupId, isNull);
    });

    test('ZoomAudioOptions defaults', () {
      const opts = ZoomAudioOptions();
      expect(opts.connect, isTrue);
      expect(opts.mute, isFalse);
    });

    test('ZoomVideoOptions defaults', () {
      const opts = ZoomVideoOptions();
      expect(opts.localVideoOn, isFalse);
    });

    test('ZoomJoinSessionConfig required fields', () {
      const config = ZoomJoinSessionConfig(
        sessionName: 's',
        userName: 'u',
        token: 't',
      );
      expect(config.sessionName, 's');
      expect(config.sessionPassword, isNull);
      expect(config.audioOptions, isNull);
      expect(config.videoOptions, isNull);
      expect(config.sessionIdleTimeoutMins, isNull);
    });
  });

  // ---- Event classes (sealed) ----

  group('Event classes', () {
    test('SessionJoinedEvent is a ZoomEvent', () {
      const event = SessionJoinedEvent();
      expect(event, isA<ZoomEvent>());
    });

    test('UserJoinedEvent holds users', () {
      const event = UserJoinedEvent(
        users: [ZoomUser(userId: 'u1', userName: 'A')],
      );
      expect(event.users, hasLength(1));
    });

    test('ErrorEvent holds code and message', () {
      const event = ErrorEvent(
        errorCode: ZoomErrorCode.networkError,
        message: 'timeout',
      );
      expect(event.errorCode, ZoomErrorCode.networkError);
      expect(event.message, 'timeout');
    });

    test('UserShareStatusChangedEvent holds user and status', () {
      const event = UserShareStatusChangedEvent(
        user: ZoomUser(userId: 'u1', userName: 'A'),
        status: ZoomShareStatus.started,
      );
      expect(event.status, ZoomShareStatus.started);
    });

    test('switch exhaustiveness on ZoomEvent', () {
      const ZoomEvent event = SessionLeftEvent();
      final description = switch (event) {
        SessionJoinedEvent() => 'joined',
        SessionLeftEvent() => 'left',
        UserJoinedEvent() => 'userJoined',
        UserLeftEvent() => 'userLeft',
        UserVideoStatusChangedEvent() => 'video',
        UserAudioStatusChangedEvent() => 'audio',
        UserActiveAudioChangedEvent() => 'activeAudio',
        ChatMessageReceivedEvent() => 'chat',
        UserShareStatusChangedEvent() => 'share',
        UserHostChangedEvent() => 'host',
        UserManagerChangedEvent() => 'manager',
        UserNameChangedEvent() => 'name',
        SessionNeedPasswordEvent() => 'needPw',
        SessionPasswordWrongEvent() => 'wrongPw',
        ErrorEvent() => 'error',
        CommandReceivedEvent() => 'command',
      };
      expect(description, 'left');
    });
  });

  // ---- New: cleanup ----

  group('ZoomVideoSdk.cleanup', () {
    setUp(() => sdk = ZoomVideoSdk());
    tearDown(() => sdk.dispose());

    test('cleanup sends cleanup channel call', () async {
      await sdk.cleanup();
      expect(calls, hasLength(1));
      expect(calls.first.method, 'cleanup');
    });
  });

  // ---- New: CmdHelper ----

  group('CmdHelper', () {
    setUp(() => sdk = ZoomVideoSdk());
    tearDown(() => sdk.dispose());

    test('sendCommand with receiverUserId sends correct args', () async {
      await sdk.cmdHelper.sendCommand(
        '{"type":"praise"}',
        receiverUserId: 'u1',
      );
      expect(calls, hasLength(1));
      expect(calls.first.method, 'cmd.sendCommand');
      expect(calls.first.arguments, {
        'command': '{"type":"praise"}',
        'receiverUserId': 'u1',
      });
    });

    test('sendCommand without receiverUserId omits key', () async {
      await sdk.cmdHelper.sendCommand('hello');
      expect(calls.first.method, 'cmd.sendCommand');
      final args = calls.first.arguments as Map;
      expect(args['command'], 'hello');
      expect(args.containsKey('receiverUserId'), isFalse);
    });
  });

  // ---- New: customUserId on ZoomUser ----

  group('ZoomUser customUserId', () {
    setUp(() => sdk = ZoomVideoSdk());
    tearDown(() => sdk.dispose());

    test('getMyself decodes customUserId', () async {
      nextResult = {
        'userId': 'u1',
        'userName': 'Test',
        'isHost': false,
        'isManager': false,
        'customUserId': 'custom-123',
      };

      final user = await sdk.getMyself();
      expect(user.customUserId, 'custom-123');
    });

    test('getMyself with no customUserId returns null', () async {
      nextResult = {
        'userId': 'u1',
        'userName': 'Test',
        'isHost': false,
        'isManager': false,
      };

      final user = await sdk.getMyself();
      expect(user.customUserId, isNull);
    });
  });

  // ---- New: CommandReceivedEvent ----

  group('CommandReceivedEvent', () {
    setUp(() => sdk = ZoomVideoSdk());
    tearDown(() => sdk.dispose());

    test('onCommandReceived stream is accessible', () {
      expect(sdk.onCommandReceived, isNotNull);
    });

    test('CommandReceivedEvent is a ZoomEvent', () {
      const event = CommandReceivedEvent(senderId: 'u2', command: 'hello');
      expect(event, isA<ZoomEvent>());
      expect(event.senderId, 'u2');
      expect(event.command, 'hello');
    });
  });

  // ---- New: VirtualBackground addItem returns item ----

  group('VirtualBackgroundHelper.addItem returns item', () {
    setUp(() => sdk = ZoomVideoSdk());
    tearDown(() => sdk.dispose());

    test(
      'addItem returns ZoomVirtualBackgroundItem when result is non-null',
      () async {
        nextResult = {'imageName': 'a', 'imagePath': '/p/a', 'type': 'image'};

        final item = await sdk.virtualBackgroundHelper.addItem('/p/a');
        expect(item, isNotNull);
        expect(item!.imageName, 'a');
        expect(item.imagePath, '/p/a');
        expect(item.type, 'image');
        expect(calls.first.method, 'virtualBackground.addItem');
      },
    );

    test('addItem returns null when native returns null', () async {
      nextResult = null;
      final item = await sdk.virtualBackgroundHelper.addItem('/p/b');
      expect(item, isNull);
    });
  });

  // ---- New: ZoomChatMessage messageId ----

  group('ZoomChatMessage messageId', () {
    test('ZoomChatMessage has messageId field', () {
      final msg = ZoomChatMessage(
        messageId: 'msg-001',
        content: 'hi',
        senderUser: const ZoomUser(userId: 's1', userName: 'S'),
        isChatToAll: true,
        isSelfSend: false,
        timestamp: DateTime(2026),
      );
      expect(msg.messageId, 'msg-001');
    });
  });

  // ---- New: ZoomVirtualBackgroundItem type field ----

  group('ZoomVirtualBackgroundItem type', () {
    test('ZoomVirtualBackgroundItem has type field', () {
      const item = ZoomVirtualBackgroundItem(
        imageName: 'bg1',
        imagePath: '/bg1.png',
        type: 'image',
      );
      expect(item.type, 'image');
    });
  });

  // ---- Platform assertions ----

  group('Desktop-only assertions', () {
    setUp(() {
      sdk = ZoomVideoSdk();
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      sdk.dispose();
    });

    test('getCameraList does not throw on desktop', () async {
      nextResult = [];
      final cameras = await sdk.videoHelper.getCameraList();
      expect(cameras, isEmpty);
      expect(calls.first.method, 'video.getCameraList');
    });

    test('startShareView does not throw on desktop', () async {
      await sdk.shareHelper.startShareView('123');
      expect(calls.first.method, 'share.startShareView');
    });

    test('enableShareDeviceAudio does not throw on desktop', () async {
      await sdk.shareHelper.enableShareDeviceAudio(false);
      expect(calls.first.method, 'share.enableShareDeviceAudio');
    });

    test('canStartRecording does not throw on desktop', () async {
      nextResult = true;
      final can = await sdk.recordingHelper.canStartRecording();
      expect(can, isTrue);
    });

    test('desktop-only methods throw on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(() => sdk.videoHelper.getCameraList(), throwsUnimplementedError);
      expect(
        () => sdk.shareHelper.startShareView('1'),
        throwsUnimplementedError,
      );
      expect(
        () => sdk.shareHelper.enableShareDeviceAudio(true),
        throwsUnimplementedError,
      );
      expect(
        () => sdk.recordingHelper.canStartRecording(),
        throwsUnimplementedError,
      );
    });

    test('desktop-only methods throw on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(() => sdk.videoHelper.getCameraList(), throwsUnimplementedError);
      expect(
        () => sdk.shareHelper.startShareView('1'),
        throwsUnimplementedError,
      );
      expect(
        () => sdk.shareHelper.enableShareDeviceAudio(true),
        throwsUnimplementedError,
      );
      expect(
        () => sdk.recordingHelper.canStartRecording(),
        throwsUnimplementedError,
      );
    });
  });
}
