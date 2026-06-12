import 'dart:async';

import 'package:flutter_zoom_videosdk/native/zoom_videosdk_event_listener.dart'
    as mobile;

import '../../zoom_video_sdk_flutter.dart' as plugin;
import 'compat_sdk.dart';

/// flutter_zoom_videosdk.EventType 문자열 상수(앱이 쓰는 부분집합).
class EventType {
  static const onSessionJoin = 'onSessionJoin';
  static const onSessionLeave = 'onSessionLeave';
  static const onUserJoin = 'onUserJoin';
  static const onUserLeave = 'onUserLeave';
  static const onUserVideoStatusChanged = 'onUserVideoStatusChanged';
  static const onUserAudioStatusChanged = 'onUserAudioStatusChanged';
  static const onChatNewMessageNotify = 'onChatNewMessageNotify';
  static const onCommandReceived = 'onCommandReceived';
  static const onError = 'onError';
}

class ZoomVideoSdkEventListener {
  /// 모바일 공식 리스너는 생성 시마다 EventChannel 핸들러를 재등록해 마지막
  /// 인스턴스만 이벤트를 받는다(last-wins). 모든 addListener 가 하나의 공식
  /// 인스턴스를 공유해 멀티플렉싱되도록 단일 인스턴스를 유지한다.
  static final mobile.ZoomVideoSdkEventListener _mobileListener =
      mobile.ZoomVideoSdkEventListener();

  StreamSubscription<dynamic> addListener(
    String event,
    void Function(dynamic data) handler,
  ) {
    if (!isZoomDesktop) {
      return _mobileListener.addListener(event, handler);
    }
    return zoomDesktopSdk.events
        .map(_toMobileShape)
        .where((mapped) => mapped != null && mapped.$1 == event)
        .map((mapped) => mapped!.$2)
        .listen(handler);
  }

  /// 데스크톱 typed 이벤트 → 모바일 패키지가 emit 하는 (이벤트명, data) 모양.
  /// 앱이 payload 를 읽는 이벤트는 chat(message)/command(command) 뿐 —
  /// 나머지는 빈 map 으로 충분하다(앱은 콜백에서 _sync 만 호출).
  (String, Map<String, dynamic>)? _toMobileShape(plugin.ZoomEvent event) {
    return switch (event) {
      plugin.SessionJoinedEvent() => (EventType.onSessionJoin, const {}),
      plugin.SessionLeftEvent() => (EventType.onSessionLeave, const {}),
      plugin.UserJoinedEvent() => (EventType.onUserJoin, const {}),
      plugin.UserLeftEvent() => (EventType.onUserLeave, const {}),
      plugin.UserVideoStatusChangedEvent() => (
        EventType.onUserVideoStatusChanged,
        const {},
      ),
      plugin.UserAudioStatusChangedEvent() => (
        EventType.onUserAudioStatusChanged,
        const {},
      ),
      plugin.ChatMessageReceivedEvent(:final message) => (
        EventType.onChatNewMessageNotify,
        {
          'message': {
            'messageID': message.messageId,
            'content': message.content,
            'senderUser': {
              'userId': message.senderUser.userId,
              'userName': message.senderUser.userName,
              'isHost': message.senderUser.isHost,
            },
            'isChatToAll': message.isChatToAll,
            'isSelfSend': message.isSelfSend,
            'timestamp': message.timestamp.millisecondsSinceEpoch,
          },
        },
      ),
      plugin.CommandReceivedEvent(:final senderId, :final command) => (
        EventType.onCommandReceived,
        // latent key drift: 공식 모바일 payload 는 발신자를 'sender' 키로 주지만
        // 여기선 'senderId' 로 emit 한다. 앱은 'command' 만 읽어 현재는 무해.
        {'command': command, 'senderId': senderId},
      ),
      plugin.ErrorEvent(:final errorCode, :final message) => (
        EventType.onError,
        {'errorType': errorCode.name, 'message': message},
      ),
      _ => null,
    };
  }
}
