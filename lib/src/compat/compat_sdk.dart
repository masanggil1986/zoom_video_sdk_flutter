import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk.dart' as mobile;

import '../../zoom_video_sdk_flutter.dart' as plugin;
import 'compat_models.dart';

/// 이 빌드가 데스크톱 메서드채널 경로(zoom_video_sdk_flutter 네이티브)인지.
bool get isZoomDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows);

/// 테스트에서 mock 채널 위의 인스턴스를 주입하기 위한 시임.
@visibleForTesting
plugin.ZoomVideoSdk? debugDesktopSdkOverride;

plugin.ZoomVideoSdk get zoomDesktopSdk =>
    debugDesktopSdkOverride ?? _defaultDesktopSdk;

/// 데스크톱 경로 공용 SDK — 이벤트 채널 구독을 프로세스당 1회만 만든다(lazy).
final plugin.ZoomVideoSdk _defaultDesktopSdk = plugin.ZoomVideoSdk();

/// flutter_zoom_videosdk.InitConfig 와 동일(앱이 쓰는 필드만).
class InitConfig {
  const InitConfig({required this.domain, required this.enableLog});

  final String domain;
  final bool enableLog;
}

/// flutter_zoom_videosdk.JoinSessionConfig 와 동일.
class JoinSessionConfig {
  JoinSessionConfig({
    required this.sessionName,
    this.sessionPassword,
    required this.token,
    required this.userName,
    this.audioOptions,
    this.videoOptions,
    this.sessionIdleTimeoutMins,
  });

  final String? sessionName;
  final String? sessionPassword;
  final String? token;
  final String? userName;
  final Map<String, bool>? audioOptions;
  final Map<String, bool>? videoOptions;
  final num? sessionIdleTimeoutMins;
}

/// flutter_zoom_videosdk.ZoomVideoSdk 와 동일한 표면(앱이 쓰는 부분만).
/// 모바일은 공식 패키지로, 데스크톱은 zoom_video_sdk_flutter 네이티브로 위임.
class ZoomVideoSdk {
  factory ZoomVideoSdk() => _instance;
  ZoomVideoSdk._();
  static final ZoomVideoSdk _instance = ZoomVideoSdk._();

  static final mobile.ZoomVideoSdk _mobile = mobile.ZoomVideoSdk();

  final session = ZoomVideoSdkSession();
  final audioHelper = ZoomVideoSdkAudioHelper();
  final videoHelper = ZoomVideoSdkVideoHelper();
  final chatHelper = ZoomVideoSdkChatHelper();
  final cmdChannel = ZoomVideoSdkCmdChannel();
  final virtualBackgroundHelper = ZoomVideoSdkVirtualBackgroundHelper();

  Future<String> initSdk(InitConfig config) async {
    if (!isZoomDesktop) {
      return _mobile.initSdk(
        mobile.InitConfig(domain: config.domain, enableLog: config.enableLog),
      );
    }
    try {
      final domain = config.domain.startsWith('http')
          ? config.domain
          : 'https://${config.domain}';
      await zoomDesktopSdk.init(
        plugin.ZoomInitConfig(domain: domain, enableLog: config.enableLog),
      );
      return 'SDK initialized successfully';
    } on PlatformException catch (e) {
      final message = '${e.code}: ${e.message ?? ''}';
      // 모바일 패키지의 재초기화 신호 문자열 계약 유지 — 앱 ensureZoomSdkReady 가
      // 이 값을 보고 cleanup 후 재시도한다.
      if (message.contains('Wrong_Usage')) {
        return 'ZoomVideoSDKError_Wrong_Usage';
      }
      return message;
    }
  }

  Future<String> cleanup() async {
    if (!isZoomDesktop) return _mobile.cleanup();
    await zoomDesktopSdk.cleanup();
    return 'ZoomVideoSDKError_Success';
  }

  Future<String> joinSession(JoinSessionConfig config) async {
    if (!isZoomDesktop) {
      return _mobile.joinSession(
        mobile.JoinSessionConfig(
          sessionName: config.sessionName,
          sessionPassword: config.sessionPassword,
          token: config.token,
          userName: config.userName,
          audioOptions: config.audioOptions,
          videoOptions: config.videoOptions,
          sessionIdleTimeoutMins: config.sessionIdleTimeoutMins,
        ),
      );
    }
    // 데스크톱 네이티브 joinSession 은 요청 수락 시 즉시 resolve 하고 실제
    // 성공/실패는 이벤트로 온다. 모바일의 결과 문자열 계약을 지키기 위해
    // sessionJoined/error 첫 이벤트를 기다려 문자열로 변환한다.
    final outcome = Completer<plugin.ZoomEvent>();
    final eventSub = zoomDesktopSdk.events.listen((e) {
      if (!outcome.isCompleted &&
          (e is plugin.SessionJoinedEvent || e is plugin.ErrorEvent)) {
        outcome.complete(e);
      }
    });
    try {
      await zoomDesktopSdk.joinSession(
        plugin.ZoomJoinSessionConfig(
          sessionName: config.sessionName ?? '',
          userName: config.userName ?? '',
          token: config.token ?? '',
          sessionPassword: (config.sessionPassword?.isNotEmpty ?? false)
              ? config.sessionPassword
              : null,
          audioOptions: plugin.ZoomAudioOptions(
            connect: config.audioOptions?['connect'] ?? true,
            mute: config.audioOptions?['mute'] ?? false,
          ),
          videoOptions: plugin.ZoomVideoOptions(
            localVideoOn: config.videoOptions?['localVideoOn'] ?? false,
          ),
          sessionIdleTimeoutMins: config.sessionIdleTimeoutMins?.toInt(),
        ),
      );
    } on PlatformException catch (e) {
      await eventSub.cancel();
      return '${e.code}: ${e.message ?? ''}';
    }
    try {
      // 15초: 네이티브 join 은 보통 수 초 내 이벤트를 돌려준다. 타임아웃 시
      // 비성공 문자열을 돌려 앱의 기존 재시도 루프(최대 3회)가 이어받는다.
      final event = await outcome.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => const plugin.ErrorEvent(
          errorCode: plugin.ZoomErrorCode.unknown,
          message: 'join timeout',
        ),
      );
      if (event is plugin.SessionJoinedEvent) return 'join session success';
      final error = event as plugin.ErrorEvent;
      return 'ZoomVideoSDKError_${error.errorCode.name}';
    } finally {
      await eventSub.cancel();
    }
  }

  Future<String> leaveSession(bool endSession) async {
    if (!isZoomDesktop) return _mobile.leaveSession(endSession);
    await zoomDesktopSdk.leaveSession(endSession: endSession);
    return 'ZoomVideoSDKError_Success';
  }
}

class ZoomVideoSdkSession {
  Future<ZoomVideoSdkUser?> getMySelf() async {
    if (!isZoomDesktop) {
      final user = await mobile.ZoomVideoSdk().session.getMySelf();
      return user == null ? null : ZoomVideoSdkUser.fromMobile(user);
    }
    try {
      return ZoomVideoSdkUser.fromDesktop(await zoomDesktopSdk.getMyself());
    } on PlatformException catch (e) {
      // 세션 없음이 일반적이나 다른 채널 오류도 여기로 온다 — 디버그에서만 노출.
      if (kDebugMode) debugPrint('[zoom_compat] getMySelf failed: ${e.code}');
      return null; // 모바일과 동일하게 null
    }
  }

  Future<List<ZoomVideoSdkUser>?> getRemoteUsers() async {
    if (!isZoomDesktop) {
      final users = await mobile.ZoomVideoSdk().session.getRemoteUsers();
      return users?.map(ZoomVideoSdkUser.fromMobile).toList();
    }
    try {
      final users = await zoomDesktopSdk.getRemoteUsers();
      return users.map(ZoomVideoSdkUser.fromDesktop).toList();
    } on PlatformException catch (e) {
      // 세션 없음이 일반적이나 다른 채널 오류도 여기로 온다 — 디버그에서만 노출.
      if (kDebugMode) {
        debugPrint('[zoom_compat] getRemoteUsers failed: ${e.code}');
      }
      return null;
    }
  }
}

class ZoomVideoSdkAudioHelper {
  Future<String> muteAudio(String userId) async {
    if (!isZoomDesktop) {
      return mobile.ZoomVideoSdk().audioHelper.muteAudio(userId);
    }
    await zoomDesktopSdk.audioHelper.muteAudio(userId);
    return 'ZoomVideoSDKError_Success';
  }

  Future<String> unMuteAudio(String userId) async {
    if (!isZoomDesktop) {
      return mobile.ZoomVideoSdk().audioHelper.unMuteAudio(userId);
    }
    await zoomDesktopSdk.audioHelper.unmuteAudio(userId);
    return 'ZoomVideoSDKError_Success';
  }
}

class ZoomVideoSdkVideoHelper {
  Future<String> startVideo() async {
    if (!isZoomDesktop) return mobile.ZoomVideoSdk().videoHelper.startVideo();
    await zoomDesktopSdk.videoHelper.startVideo();
    return 'ZoomVideoSDKError_Success';
  }

  Future<String> stopVideo() async {
    if (!isZoomDesktop) return mobile.ZoomVideoSdk().videoHelper.stopVideo();
    await zoomDesktopSdk.videoHelper.stopVideo();
    return 'ZoomVideoSDKError_Success';
  }
}

class ZoomVideoSdkChatHelper {
  Future<String> sendChatToAll(String message) async {
    if (!isZoomDesktop) {
      return mobile.ZoomVideoSdk().chatHelper.sendChatToAll(message);
    }
    await zoomDesktopSdk.chatHelper.sendChatToAll(message);
    return 'ZoomVideoSDKError_Success';
  }
}

class ZoomVideoSdkCmdChannel {
  /// 공식 패키지와 동일한 인자 순서: (receiverId, strCmd).
  Future<String> sendCommand(String receiverId, String strCmd) async {
    if (!isZoomDesktop) {
      return mobile.ZoomVideoSdk().cmdChannel.sendCommand(receiverId, strCmd);
    }
    await zoomDesktopSdk.cmdHelper.sendCommand(
      strCmd,
      receiverUserId: receiverId.isEmpty ? null : receiverId,
    );
    return 'ZoomVideoSDKError_Success';
  }
}

class ZoomVideoSdkVirtualBackgroundHelper {
  static const _mobileChannel = MethodChannel('flutter_zoom_videosdk');

  Future<ZoomVideoSdkVirtualBackgroundItem?> addVirtualBackgroundItem(
    String filePath,
  ) async {
    if (!isZoomDesktop) {
      final item = await mobile.ZoomVideoSdk().virtualBackgroundHelper
          .addVirtualBackgroundItem(filePath);
      if (item == null) return null;
      return ZoomVideoSdkVirtualBackgroundItem(
        imageName: item.imageName,
        type: item.type,
        filePath: item.filePath,
      );
    }
    final item = await zoomDesktopSdk.virtualBackgroundHelper.addItem(filePath);
    if (item == null) return null;
    return ZoomVideoSdkVirtualBackgroundItem(
      imageName: item.imageName,
      type: _desktopTypeToMobile(item.type),
      filePath: item.imagePath,
    );
  }

  Future<void> setVirtualBackgroundItem(String imageName) async {
    if (!isZoomDesktop) {
      await mobile.ZoomVideoSdk().virtualBackgroundHelper
          .setVirtualBackgroundItem(imageName);
      return;
    }
    await zoomDesktopSdk.virtualBackgroundHelper.setItem(imageName);
  }

  Future<void> removeVirtualBackgroundItem(String imageName) async {
    if (!isZoomDesktop) {
      await mobile.ZoomVideoSdk().virtualBackgroundHelper
          .removeVirtualBackgroundItem(imageName);
      return;
    }
    await zoomDesktopSdk.virtualBackgroundHelper.removeItem(imageName);
  }

  /// 모바일 네이티브의 응답 이중 인코딩 버그(iOS) 워크어라운드 포함 —
  /// 앱이 채널을 직접 부르던 코드를 여기로 흡수한다.
  Future<List<ZoomVideoSdkVirtualBackgroundItem>>
  getVirtualBackgroundItemList() async {
    if (!isZoomDesktop) {
      final raw = await _mobileChannel.invokeMethod<String>(
        'getVirtualBackgroundItemList',
      );
      if (raw == null || raw.isEmpty) return const [];
      final outer = jsonDecode(raw) as List;
      return outer.map((e) {
        final m = (e is String ? jsonDecode(e) : e) as Map<String, dynamic>;
        return ZoomVideoSdkVirtualBackgroundItem(
          imageName: (m['imageName'] ?? '') as String,
          type: (m['type'] ?? '') as String,
          filePath: m['filePath'] as String?,
        );
      }).toList();
    }
    final items = await zoomDesktopSdk.virtualBackgroundHelper.getItemList();
    return [
      for (final item in items)
        ZoomVideoSdkVirtualBackgroundItem(
          imageName: item.imageName,
          type: _desktopTypeToMobile(item.type),
          filePath: item.imagePath,
        ),
    ];
  }

  static String _desktopTypeToMobile(String type) => switch (type) {
    'none' => 'ZoomVideoSDKVirtualBackgroundDataType_None',
    'blur' => 'ZoomVideoSDKVirtualBackgroundDataType_Blur',
    _ => 'ZoomVideoSDKVirtualBackgroundDataType_Image',
  };
}
