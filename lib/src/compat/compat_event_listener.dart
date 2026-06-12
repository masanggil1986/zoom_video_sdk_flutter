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
  StreamSubscription<dynamic> addListener(
    String event,
    void Function(dynamic data) handler,
  ) {
    if (!isZoomDesktop) {
      return mobile.ZoomVideoSdkEventListener().addListener(event, handler);
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
