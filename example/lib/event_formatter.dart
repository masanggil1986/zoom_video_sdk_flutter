import 'package:zoom_video_sdk_flutter/zoom_video_sdk_flutter.dart';

/// Formats a [ZoomEvent] as a one-line human-readable description for the
/// example app's event log.
String formatEvent(ZoomEvent e) {
  return switch (e) {
    SessionJoinedEvent() => 'Session joined',
    SessionLeftEvent() => 'Session left',
    UserJoinedEvent(:final users) =>
      'User joined: ${users.map(_userLabel).join(', ')}',
    UserLeftEvent(:final users) =>
      'User left: ${users.map(_userLabel).join(', ')}',
    UserVideoStatusChangedEvent(:final user) =>
      'Video status: ${_userLabel(user)} → ${_videoLabel(user.videoStatus)}',
    UserAudioStatusChangedEvent(:final user) =>
      'Audio status: ${_userLabel(user)} → ${_audioLabel(user.audioStatus)}',
    UserActiveAudioChangedEvent(:final activeUsers) =>
      'Active speakers: ${activeUsers.map((u) => u.userName).join(', ')}',
    ChatMessageReceivedEvent(:final message) => _chatLabel(message),
    UserShareStatusChangedEvent(:final user, :final status) =>
      'Share: ${user.userName} → ${status.name}',
    UserHostChangedEvent(:final newHost) =>
      'Host changed: ${_userLabel(newHost)}',
    UserManagerChangedEvent(:final user, :final isManager) =>
      'Manager: ${user.userName} → ${isManager ? 'granted' : 'revoked'}',
    UserNameChangedEvent(:final user) =>
      'Name changed: ${user.userName} (${user.userId})',
    SessionNeedPasswordEvent() => 'Session needs password',
    SessionPasswordWrongEvent() => 'Session password wrong',
    ErrorEvent(:final errorCode, :final message) =>
      message == null
          ? 'Error: ${errorCode.name}'
          : 'Error: ${errorCode.name} — $message',
    CommandReceivedEvent(:final senderId, :final command) =>
      'Command from $senderId: $command',
  };
}

String _userLabel(ZoomUser u) => '${u.userName} (${u.userId})';

String _videoLabel(ZoomVideoStatus? v) {
  if (v == null) return '-';
  return v.isOn ? 'on' : 'off';
}

String _audioLabel(ZoomAudioStatus? a) {
  if (a == null) return '-';
  if (a.isMuted) return 'muted';
  if (a.isTalking) return 'talking';
  return 'unmuted';
}

String _chatLabel(ZoomChatMessage m) {
  if (m.isChatToAll) {
    return 'Chat (to all) from ${m.senderUser.userName}: ${m.content}';
  }
  final receiverName = m.receiverUser?.userName ?? '?';
  return 'Chat (private to $receiverName) from ${m.senderUser.userName}: ${m.content}';
}
