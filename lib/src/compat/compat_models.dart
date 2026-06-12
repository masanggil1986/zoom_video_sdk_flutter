import 'package:flutter_zoom_videosdk/native/zoom_videosdk_audio_status.dart'
    as mobile_audio;
import 'package:flutter_zoom_videosdk/native/zoom_videosdk_user.dart'
    as mobile_user;
import 'package:flutter_zoom_videosdk/native/zoom_videosdk_video_status.dart'
    as mobile_video;

import '../../zoom_video_sdk_flutter.dart' as plugin;

/// flutter_zoom_videosdk 의 ZoomVideoSdkUser 와 동일한 모양(앱이 쓰는 필드만).
/// 모바일은 살아있는 status 객체에 위임, 데스크톱은 조회 시점 스냅샷 값.
class ZoomVideoSdkUser {
  ZoomVideoSdkUser._({
    required this.userId,
    required this.userName,
    required this.isHost,
    this.customUserId,
    this.videoStatus,
    this.audioStatus,
  });

  factory ZoomVideoSdkUser.fromMobile(mobile_user.ZoomVideoSdkUser user) =>
      ZoomVideoSdkUser._(
        userId: user.userId,
        userName: user.userName,
        isHost: user.isHost,
        customUserId: user.customUserId,
        videoStatus: user.videoStatus == null
            ? null
            : ZoomVideoSdkVideoStatus._mobile(user.videoStatus!),
        audioStatus: user.audioStatus == null
            ? null
            : ZoomVideoSdkAudioStatus._mobile(user.audioStatus!),
      );

  factory ZoomVideoSdkUser.fromDesktop(plugin.ZoomUser user) =>
      ZoomVideoSdkUser._(
        userId: user.userId,
        userName: user.userName,
        isHost: user.isHost,
        customUserId: user.customUserId,
        videoStatus: ZoomVideoSdkVideoStatus._value(
          user.videoStatus?.isOn ?? false,
        ),
        audioStatus: ZoomVideoSdkAudioStatus._value(
          user.audioStatus?.isMuted ?? true,
        ),
      );

  /// 이벤트 payload(map) 파싱용 — 부분 정보만 올 수 있어 관대하게 읽는다.
  factory ZoomVideoSdkUser.fromJson(Map<String, dynamic> json) =>
      ZoomVideoSdkUser._(
        userId: (json['userId'] ?? '') as String,
        userName: (json['userName'] ?? '') as String,
        isHost: json['isHost'] as bool? ?? false,
        customUserId: json['customUserId'] as String?,
      );

  final String userId;
  final String userName;
  final bool isHost;
  final String? customUserId;
  final ZoomVideoSdkVideoStatus? videoStatus;
  final ZoomVideoSdkAudioStatus? audioStatus;
}

class ZoomVideoSdkVideoStatus {
  ZoomVideoSdkVideoStatus._mobile(mobile_video.ZoomVideoSdkVideoStatus status)
    : _mobile = status,
      _snapshot = null;
  ZoomVideoSdkVideoStatus._value(bool isOn) : _mobile = null, _snapshot = isOn;

  final mobile_video.ZoomVideoSdkVideoStatus? _mobile;
  final bool? _snapshot;

  Future<bool> isOn() => _mobile?.isOn() ?? Future.value(_snapshot ?? false);
}

class ZoomVideoSdkAudioStatus {
  ZoomVideoSdkAudioStatus._mobile(mobile_audio.ZoomVideoSdkAudioStatus status)
    : _mobile = status,
      _snapshot = null;
  ZoomVideoSdkAudioStatus._value(bool isMuted)
    : _mobile = null,
      _snapshot = isMuted;

  final mobile_audio.ZoomVideoSdkAudioStatus? _mobile;
  final bool? _snapshot;

  Future<bool> isMuted() =>
      _mobile?.isMuted() ?? Future.value(_snapshot ?? true);
}

/// flutter_zoom_videosdk 의 ZoomVideoSdkChatMessage 와 동일한 모양(쓰는 필드만).
class ZoomVideoSdkChatMessage {
  ZoomVideoSdkChatMessage._({
    required this.messageID,
    required this.content,
    required this.senderUser,
    this.isSelfSend,
    this.timestamp,
  });

  factory ZoomVideoSdkChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['senderUser'];
    return ZoomVideoSdkChatMessage._(
      // 모바일 네이티브는 'messageID', 데스크톱 compat 매핑은 'messageId' 키.
      messageID: (json['messageID'] ?? json['messageId'] ?? '') as String,
      content: (json['content'] ?? '') as String,
      senderUser: sender is Map
          ? ZoomVideoSdkUser.fromJson(Map<String, dynamic>.from(sender))
          : ZoomVideoSdkUser.fromJson(const {}),
      isSelfSend: json['isSelfSend'] as bool?,
      timestamp: (json['timestamp'] as num?)?.toInt(),
    );
  }

  final String messageID;
  final String content;
  final ZoomVideoSdkUser senderUser;
  final bool? isSelfSend;
  final int? timestamp;
}

/// flutter_zoom_videosdk 의 ZoomVideoSdkVirtualBackgroundItem 과 동일한 모양.
/// [type] 은 모바일 네이티브 문자열 기준('ZoomVideoSDKVirtualBackgroundDataType_*').
class ZoomVideoSdkVirtualBackgroundItem {
  const ZoomVideoSdkVirtualBackgroundItem({
    required this.imageName,
    required this.type,
    this.filePath,
  });

  final String imageName;
  final String type;
  final String? filePath;
}
