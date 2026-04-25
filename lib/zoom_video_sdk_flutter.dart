/// Zoom Video SDK Flutter plugin.
///
/// Provides a unified Dart API for the Zoom Video SDK across
/// Android, iOS, Windows, and macOS.
///
/// See `docs/DART_API_DESIGN.md` for full platform support details.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Error codes surfaced by the native Zoom Video SDK.
enum ZoomErrorCode {
  success,
  unknown,
  invalidParameter,
  notInitialized,
  authenticationFailed,
  noSession,
  sessionAlreadyInProgress,
  sessionJoinFailed,
  sessionLeaveFailed,
  sessionPasswordRequired,
  sessionPasswordWrong,
  audioStartFailed,
  audioStopFailed,
  videoStartFailed,
  videoStopFailed,
  shareStartFailed,
  shareStopFailed,
  chatSendFailed,
  chatDisabled,
  recordingStartFailed,
  recordingStopFailed,
  virtualBackgroundNotSupported,
  networkError,
  permissionDenied,
}

/// Audio connection type.
enum ZoomAudioType { voip, telephony, none }

/// Screen sharing status.
enum ZoomShareStatus { started, stopped, paused }

/// Type of a shareable source.
enum ZoomShareSourceType { screen, window }

/// Video rendering aspect mode.
enum ZoomVideoAspectMode { panAndScan, letterBox }

/// Camera video quality preference mode.
///
/// Web SDK's `stream.updateSharedVideoQuality` has no direct native equivalent;
/// this controls the *camera* video quality preference on desktop.
enum ZoomVideoPreferenceMode {
  /// Balanced between sharpness and smoothness.
  balance,

  /// Prioritize clarity — may reduce frame rate.
  sharpness,

  /// Prioritize smooth motion — may reduce resolution.
  smoothness,

  /// Custom frame-rate bounds (supply `minimumFrameRate`/`maximumFrameRate`).
  custom,
}

/// Noise suppression level.
///
/// All four levels are documented for Windows/macOS.
/// Android/iOS may support a subset.
enum ZoomNoiseSuppression {
  /// SDK chooses the appropriate level.
  auto_,

  low,
  medium,
  high,
}

// ---------------------------------------------------------------------------
// Configuration classes
// ---------------------------------------------------------------------------

/// Configuration for [ZoomVideoSdk.init].
@immutable
class ZoomInitConfig {
  /// Creates an init configuration.
  ///
  /// [appGroupId] is required on iOS for screen sharing
  /// (Broadcast Upload Extension).
  const ZoomInitConfig({
    this.domain = 'https://zoom.us',
    this.enableLog = true,
    this.appGroupId,
  });

  /// Zoom service domain. Must include scheme (e.g. `https://zoom.us`).
  final String domain;

  /// Whether SDK logging is enabled.
  final bool enableLog;

  /// iOS App Group ID for screen sharing. Ignored on other platforms.
  final String? appGroupId;
}

/// Audio options for [ZoomJoinSessionConfig].
@immutable
class ZoomAudioOptions {
  const ZoomAudioOptions({
    this.connect = true,
    this.mute = false,
    this.autoAdjustSpeakerVolume = true,
  });

  /// Automatically connect audio on join.
  final bool connect;

  /// Start with microphone muted.
  final bool mute;

  /// When `true`, the SDK automatically raises speaker volume if it is muted
  /// or too low on join. macOS/Windows only.
  final bool autoAdjustSpeakerVolume;
}

/// Video options for [ZoomJoinSessionConfig].
@immutable
class ZoomVideoOptions {
  const ZoomVideoOptions({this.localVideoOn = false});

  /// Automatically start local camera on join.
  final bool localVideoOn;
}

/// Configuration for [ZoomVideoSdk.joinSession].
@immutable
class ZoomJoinSessionConfig {
  const ZoomJoinSessionConfig({
    required this.sessionName,
    required this.userName,
    required this.token,
    this.sessionPassword,
    this.audioOptions,
    this.videoOptions,
    this.sessionIdleTimeoutMins,
  });

  /// Session name. Max 150 characters.
  final String sessionName;

  /// Display name. Max 200 characters.
  final String userName;

  /// Server-generated JWT token.
  final String token;

  /// Optional session password. Max 10 characters.
  final String? sessionPassword;

  /// Audio options applied on join.
  final ZoomAudioOptions? audioOptions;

  /// Video options applied on join.
  final ZoomVideoOptions? videoOptions;

  /// Session idle timeout in minutes.
  final int? sessionIdleTimeoutMins;
}

// ---------------------------------------------------------------------------
// Model classes
// ---------------------------------------------------------------------------

/// A user (participant) in a Zoom Video SDK session.
@immutable
class ZoomUser {
  const ZoomUser({
    required this.userId,
    required this.userName,
    this.isHost = false,
    this.isManager = false,
    this.audioStatus,
    this.videoStatus,
    this.isSharing = false,
  });

  /// Unique identifier within the session.
  final String userId;

  /// Display name.
  final String userName;

  /// Whether this user is the session host.
  final bool isHost;

  /// Whether this user is a manager (co-host).
  final bool isManager;

  /// Current audio status, or `null` if audio has not started.
  final ZoomAudioStatus? audioStatus;

  /// Current video status, or `null` if video has not started.
  final ZoomVideoStatus? videoStatus;

  /// Whether this user currently has an active screen share.
  ///
  /// Populated by `getAllUsers` / `getRemoteUsers` so late joiners can
  /// detect an in-progress share they would otherwise miss (the SDK only
  /// fires `userShareStatusChanged` on transitions). Currently only
  /// reported on Windows; defaults to `false` elsewhere.
  final bool isSharing;
}

/// Audio status of a [ZoomUser].
@immutable
class ZoomAudioStatus {
  const ZoomAudioStatus({
    required this.isMuted,
    required this.isTalking,
    required this.audioType,
  });

  final bool isMuted;
  final bool isTalking;
  final ZoomAudioType audioType;
}

/// Video status of a [ZoomUser].
@immutable
class ZoomVideoStatus {
  const ZoomVideoStatus({required this.isOn, required this.hasSource});

  /// Whether the camera is actively sending video.
  final bool isOn;

  /// Whether a video source (camera) is available.
  final bool hasSource;
}

/// Information about the current session.
@immutable
class ZoomSessionInfo {
  const ZoomSessionInfo({
    required this.sessionName,
    required this.sessionId,
    this.sessionPassword,
    this.host,
  });

  final String sessionName;
  final String sessionId;
  final String? sessionPassword;
  final ZoomUser? host;
}

/// A chat message exchanged in a session.
@immutable
class ZoomChatMessage {
  const ZoomChatMessage({
    required this.content,
    required this.senderUser,
    this.receiverUser,
    required this.isChatToAll,
    required this.isSelfSend,
    required this.timestamp,
  });

  /// Message content. Max 10,000 bytes.
  final String content;

  final ZoomUser senderUser;

  /// `null` when [isChatToAll] is `true`.
  final ZoomUser? receiverUser;

  final bool isChatToAll;
  final bool isSelfSend;
  final DateTime timestamp;
}

/// An audio input/output device.
@immutable
class ZoomAudioDevice {
  const ZoomAudioDevice({required this.deviceId, required this.deviceName});

  final String deviceId;
  final String deviceName;
}

/// A camera device.
@immutable
class ZoomCameraDevice {
  const ZoomCameraDevice({required this.deviceId, required this.deviceName});

  final String deviceId;
  final String deviceName;
}

/// Options applied when starting a share.
///
/// Native macOS/Windows SDKs only expose these two flags for share quality —
/// there is no direct resolution setting.
@immutable
class ZoomShareOption {
  const ZoomShareOption({
    this.withDeviceAudio = false,
    this.optimizeForSharedVideo = false,
  });

  /// Include system (device) audio in the share stream. Desktop only.
  final bool withDeviceAudio;

  /// Prioritize smooth motion over still-frame clarity — use when sharing
  /// video content. Trades detail for higher frame rate.
  final bool optimizeForSharedVideo;

  Map<String, dynamic> toMap() => {
    'withDeviceAudio': withDeviceAudio,
    'optimizeForSharedVideo': optimizeForSharedVideo,
  };
}

/// A shareable source (monitor or application window). Desktop only.
@immutable
class ZoomShareSource {
  const ZoomShareSource({
    required this.sourceId,
    required this.name,
    required this.type,
  });

  /// Opaque ID — pass back to [ZoomShareHelper.startShareScreen] (for
  /// [ZoomShareSourceType.screen]) or [ZoomShareHelper.startShareView]
  /// (for [ZoomShareSourceType.window]).
  final String sourceId;

  /// Display name (monitor label or window title).
  final String name;

  final ZoomShareSourceType type;
}

/// A virtual background item.
@immutable
class ZoomVirtualBackgroundItem {
  const ZoomVirtualBackgroundItem({
    required this.imageName,
    required this.imagePath,
  });

  final String imageName;
  final String imagePath;
}

// ---------------------------------------------------------------------------
// Video rendering
// ---------------------------------------------------------------------------

/// What the [ZoomVideoView] should render.
enum ZoomVideoKind {
  /// The user's camera feed.
  video,

  /// The user's active screen share.
  share,
}

/// Widget that renders a Zoom user's video or share canvas.
///
/// Internally backed by a platform view (macOS) or a Flutter `Texture`
/// driven by a native raw-data subscription (Windows). On platforms without
/// a video view implementation, a black placeholder is shown.
///
/// **Platform support:** Android ❌ iOS ❌ Windows ✅ macOS ✅
class ZoomVideoView extends StatefulWidget {
  const ZoomVideoView({
    super.key,
    required this.userId,
    this.kind = ZoomVideoKind.video,
  });

  final String userId;
  final ZoomVideoKind kind;

  @override
  State<ZoomVideoView> createState() => _ZoomVideoViewState();
}

class _ZoomVideoViewState extends State<ZoomVideoView> {
  static const String _viewType = 'zoom_video_sdk_flutter/video_view';
  static const MethodChannel _channel = MethodChannel('zoom_video_sdk_flutter');

  int? _textureId;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _createWindowsTexture();
    }
  }

  @override
  void didUpdateWidget(covariant ZoomVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (defaultTargetPlatform == TargetPlatform.windows &&
        (oldWidget.userId != widget.userId || oldWidget.kind != widget.kind)) {
      _disposeWindowsTexture();
      _createWindowsTexture();
    }
  }

  @override
  void dispose() {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _disposeWindowsTexture();
    }
    super.dispose();
  }

  Future<void> _createWindowsTexture() async {
    try {
      final id = await _channel.invokeMethod<int>('videoView.create', {
        'userId': widget.userId,
        'kind': widget.kind.name,
      });
      if (!mounted) {
        if (id != null) {
          await _channel.invokeMethod<void>('videoView.dispose', {
            'textureId': id,
          });
        }
        return;
      }
      setState(() => _textureId = id);
    } on PlatformException {
      // Fall through to black placeholder.
    }
  }

  void _disposeWindowsTexture() {
    final id = _textureId;
    _textureId = null;
    if (id == null) return;
    _channel.invokeMethod<void>('videoView.dispose', {'textureId': id});
  }

  @override
  Widget build(BuildContext context) {
    final params = {'userId': widget.userId, 'kind': widget.kind.name};
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return AppKitView(
        viewType: _viewType,
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.windows) {
      final id = _textureId;
      if (id == null) return const ColoredBox(color: Colors.black);
      return ColoredBox(
        color: Colors.black,
        child: Texture(textureId: id),
      );
    }
    return const ColoredBox(color: Colors.black);
  }
}

// ---------------------------------------------------------------------------
// Events (sealed class hierarchy)
// ---------------------------------------------------------------------------

/// Base class for all Zoom Video SDK events.
///
/// Use pattern matching (Dart 3 `switch`) to handle specific event types.
sealed class ZoomEvent {
  const ZoomEvent();
}

/// Fired when the local user successfully joins a session.
///
/// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
final class SessionJoinedEvent extends ZoomEvent {
  const SessionJoinedEvent();
}

/// Fired when the local user leaves or is removed from a session.
///
/// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
final class SessionLeftEvent extends ZoomEvent {
  const SessionLeftEvent();
}

/// Fired when one or more remote users join the session.
///
/// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
final class UserJoinedEvent extends ZoomEvent {
  const UserJoinedEvent({required this.users});
  final List<ZoomUser> users;
}

/// Fired when one or more remote users leave the session.
///
/// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
final class UserLeftEvent extends ZoomEvent {
  const UserLeftEvent({required this.users});
  final List<ZoomUser> users;
}

/// Fired when a user's video status changes (on/off).
///
/// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
final class UserVideoStatusChangedEvent extends ZoomEvent {
  const UserVideoStatusChangedEvent({required this.user});
  final ZoomUser user;
}

/// Fired when a user's audio status changes (mute/unmute).
///
/// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
final class UserAudioStatusChangedEvent extends ZoomEvent {
  const UserAudioStatusChangedEvent({required this.user});
  final ZoomUser user;
}

/// Fired when the active speaker list changes.
///
/// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
final class UserActiveAudioChangedEvent extends ZoomEvent {
  const UserActiveAudioChangedEvent({required this.activeUsers});
  final List<ZoomUser> activeUsers;
}

/// Fired when a chat message is received.
///
/// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
final class ChatMessageReceivedEvent extends ZoomEvent {
  const ChatMessageReceivedEvent({required this.message});
  final ZoomChatMessage message;
}

/// Fired when a user's screen share status changes.
///
/// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
final class UserShareStatusChangedEvent extends ZoomEvent {
  const UserShareStatusChangedEvent({required this.user, required this.status});

  final ZoomUser user;
  final ZoomShareStatus status;
}

/// Fired when the host role is transferred to a different user.
///
/// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
final class UserHostChangedEvent extends ZoomEvent {
  const UserHostChangedEvent({required this.newHost});
  final ZoomUser newHost;
}

/// Fired when a user's manager (co-host) status changes.
///
/// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
final class UserManagerChangedEvent extends ZoomEvent {
  const UserManagerChangedEvent({required this.user, required this.isManager});

  final ZoomUser user;
  final bool isManager;
}

/// Fired when a user's display name changes.
///
/// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
final class UserNameChangedEvent extends ZoomEvent {
  const UserNameChangedEvent({required this.user});
  final ZoomUser user;
}

/// Fired when the session requires a password to join.
///
/// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
final class SessionNeedPasswordEvent extends ZoomEvent {
  const SessionNeedPasswordEvent();
}

/// Fired when the provided session password is incorrect.
///
/// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
final class SessionPasswordWrongEvent extends ZoomEvent {
  const SessionPasswordWrongEvent();
}

/// Fired when an SDK error occurs.
///
/// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
final class ErrorEvent extends ZoomEvent {
  const ErrorEvent({required this.errorCode, this.message});
  final ZoomErrorCode errorCode;
  final String? message;
}

// ---------------------------------------------------------------------------
// Helper classes
// ---------------------------------------------------------------------------

/// Audio controls for the Zoom Video SDK.
///
/// Access via [ZoomVideoSdk.audioHelper].
class ZoomAudioHelper {
  ZoomAudioHelper(this._channel);

  final MethodChannel _channel;

  /// Starts the audio engine (connects microphone and speaker).
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> startAudio() async {
    await _channel.invokeMethod<void>('audio.startAudio');
  }

  /// Stops the audio engine.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> stopAudio() async {
    await _channel.invokeMethod<void>('audio.stopAudio');
  }

  /// Mutes audio for the given user.
  ///
  /// Non-host callers can only mute themselves.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> muteAudio(String userId) async {
    await _channel.invokeMethod<void>('audio.muteAudio', {'userId': userId});
  }

  /// Unmutes audio for the given user.
  ///
  /// Non-host callers can only unmute themselves.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> unmuteAudio(String userId) async {
    await _channel.invokeMethod<void>('audio.unmuteAudio', {'userId': userId});
  }

  /// Enables or disables original microphone input (bypasses noise
  /// suppression and echo cancellation).
  ///
  /// Native SDKs expose this via a separate `audioSettingHelper`.
  /// This class consolidates it for simplicity.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> enableMicOriginalInput(bool enable) async {
    await _channel.invokeMethod<void>('audio.enableMicOriginalInput', {
      'enable': enable,
    });
  }

  /// Sets the noise suppression level.
  ///
  /// Specific levels (`auto_`, `low`, `medium`, `high`) are documented for
  /// Windows/macOS. Android/iOS may support a subset.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> setNoiseSuppression(ZoomNoiseSuppression level) async {
    await _channel.invokeMethod<void>('audio.setNoiseSuppression', {
      'level': level.name,
    });
  }

  /// Returns the list of available audio input/output devices.
  ///
  /// Android auto-routes audio — the returned list may be empty or not
  /// meaningful. iOS has limited device control.
  ///
  /// **Platform support:** Android ⚠️ iOS ⚠️ Windows ✅ macOS ✅
  Future<List<ZoomAudioDevice>> getAudioDeviceList() async {
    final result = await _channel.invokeListMethod<Map>(
      'audio.getAudioDeviceList',
    );
    return (result ?? []).map((m) {
      final map = Map<String, dynamic>.from(m);
      return ZoomAudioDevice(
        deviceId: map['deviceId'] as String,
        deviceName: map['deviceName'] as String,
      );
    }).toList();
  }

  /// Selects an audio device by ID.
  ///
  /// Android auto-routes audio — selection may have no effect.
  /// iOS has limited device control.
  ///
  /// **Platform support:** Android ⚠️ iOS ⚠️ Windows ✅ macOS ✅
  Future<void> selectAudioDevice(String deviceId) async {
    await _channel.invokeMethod<void>('audio.selectAudioDevice', {
      'deviceId': deviceId,
    });
  }
}

/// Video controls for the Zoom Video SDK.
///
/// Access via [ZoomVideoSdk.videoHelper].
class ZoomVideoHelper {
  ZoomVideoHelper(this._channel);

  final MethodChannel _channel;

  /// Starts the local camera video.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> startVideo() async {
    await _channel.invokeMethod<void>('video.startVideo');
  }

  /// Stops the local camera video.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> stopVideo() async {
    await _channel.invokeMethod<void>('video.stopVideo');
  }

  /// Switches between available cameras.
  ///
  /// On mobile, toggles front/back camera.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> switchCamera() async {
    await _channel.invokeMethod<void>('video.switchCamera');
  }

  /// Sets the camera video quality preference (balance/sharpness/smoothness
  /// or custom frame-rate bounds).
  ///
  /// For [ZoomVideoPreferenceMode.custom], [minimumFrameRate] and
  /// [maximumFrameRate] must be in `[0, 30]` and `min <= max`.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> setVideoQualityPreference(
    ZoomVideoPreferenceMode mode, {
    int minimumFrameRate = 0,
    int maximumFrameRate = 0,
  }) async {
    await _channel.invokeMethod<void>('video.setVideoQualityPreference', {
      'mode': mode.name,
      'minimumFrameRate': minimumFrameRate,
      'maximumFrameRate': maximumFrameRate,
    });
  }

  /// Selects a camera by device ID. Desktop only.
  ///
  /// On mobile, use [switchCamera] to toggle front/back.
  ///
  /// **Platform support:** Android ❌ iOS ❌ Windows ✅ macOS ✅
  ///
  /// Throws [UnimplementedError] on Android and iOS.
  Future<void> selectCamera(String deviceId) async {
    _assertDesktopOnly('selectCamera()');
    await _channel.invokeMethod<void>('video.selectCamera', {
      'deviceId': deviceId,
    });
  }

  /// Returns the list of available cameras. Desktop only.
  ///
  /// **Platform support:** Android ❌ iOS ❌ Windows ✅ macOS ✅
  ///
  /// Throws [UnimplementedError] on Android and iOS.
  Future<List<ZoomCameraDevice>> getCameraList() async {
    _assertDesktopOnly('getCameraList()');
    final result = await _channel.invokeListMethod<Map>('video.getCameraList');
    return (result ?? []).map((m) {
      final map = Map<String, dynamic>.from(m);
      return ZoomCameraDevice(
        deviceId: map['deviceId'] as String,
        deviceName: map['deviceName'] as String,
      );
    }).toList();
  }
}

/// Screen share controls for the Zoom Video SDK.
///
/// Access via [ZoomVideoSdk.shareHelper].
class ZoomShareHelper {
  ZoomShareHelper(this._channel);

  final MethodChannel _channel;

  /// Starts screen sharing.
  ///
  /// On desktop, pass [monitorId] from [getShareSourceList] to pick a specific
  /// display. If omitted, the main display is used.
  ///
  /// On iOS, requires `appGroupId` in [ZoomInitConfig] and a Broadcast Upload
  /// Extension target. On Android, requires MediaProjection permission.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> startShareScreen({
    String? monitorId,
    ZoomShareOption? option,
  }) async {
    await _channel.invokeMethod<void>('share.startShareScreen', {
      'monitorId': ?monitorId,
      if (option != null) 'option': option.toMap(),
    });
  }

  /// Enumerates shareable monitors and application windows. Desktop only.
  ///
  /// **Platform support:** Android ❌ iOS ❌ Windows ✅ macOS ✅
  ///
  /// Throws [UnimplementedError] on Android and iOS.
  Future<List<ZoomShareSource>> getShareSourceList() async {
    _assertDesktopOnly('getShareSourceList()');
    final result = await _channel.invokeListMethod<Map>(
      'share.getShareSourceList',
    );
    return (result ?? []).map((m) {
      final map = Map<String, dynamic>.from(m);
      return ZoomShareSource(
        sourceId: map['sourceId'] as String,
        name: map['name'] as String,
        type: ZoomShareSourceType.values.firstWhere(
          (t) => t.name == map['type'],
          orElse: () => ZoomShareSourceType.window,
        ),
      );
    }).toList();
  }

  /// Shares a specific application window by its handle/ID. Desktop only.
  ///
  /// **Platform support:** Android ❌ iOS ❌ Windows ✅ macOS ✅
  ///
  /// Throws [UnimplementedError] on Android and iOS.
  Future<void> startShareView(
    String windowId, {
    ZoomShareOption? option,
  }) async {
    _assertDesktopOnly('startShareView()');
    await _channel.invokeMethod<void>('share.startShareView', {
      'windowId': windowId,
      if (option != null) 'option': option.toMap(),
    });
  }

  /// Stops screen or window sharing.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> stopShare() async {
    await _channel.invokeMethod<void>('share.stopShare');
  }

  /// Toggles "optimize for video" on an active share — prioritizes frame rate
  /// over still-frame detail.
  ///
  /// **Precondition:** a screen or window share is currently running.
  /// Returns an error otherwise.
  ///
  /// **Platform support:** Android ❌ iOS ❌ Windows ✅ macOS ✅
  ///
  /// Throws [UnimplementedError] on Android and iOS.
  Future<void> enableOptimizeForSharedVideo(bool enable) async {
    _assertDesktopOnly('enableOptimizeForSharedVideo()');
    await _channel.invokeMethod<void>('share.enableOptimizeForSharedVideo', {
      'enable': enable,
    });
  }

  /// Enables or disables sharing device audio alongside screen share.
  /// Desktop only.
  ///
  /// **Platform support:** Android ❌ iOS ❌ Windows ✅ macOS ✅
  ///
  /// Throws [UnimplementedError] on Android and iOS.
  Future<void> enableShareDeviceAudio(bool enable) async {
    _assertDesktopOnly('enableShareDeviceAudio()');
    await _channel.invokeMethod<void>('share.enableShareDeviceAudio', {
      'enable': enable,
    });
  }
}

/// Chat controls for the Zoom Video SDK.
///
/// Access via [ZoomVideoSdk.chatHelper].
class ZoomChatHelper {
  ZoomChatHelper(this._channel);

  final MethodChannel _channel;

  /// Sends a chat message to all participants.
  ///
  /// Max message size: 10,000 bytes.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> sendChatToAll(String message) async {
    await _channel.invokeMethod<void>('chat.sendChatToAll', {
      'message': message,
    });
  }

  /// Sends a private chat message to a specific user.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> sendChatToUser(String userId, String message) async {
    await _channel.invokeMethod<void>('chat.sendChatToUser', {
      'userId': userId,
      'message': message,
    });
  }

  /// Returns whether chat is disabled for the session.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<bool> isChatDisabled() async {
    final result = await _channel.invokeMethod<bool>('chat.isChatDisabled');
    return result ?? false;
  }

  /// Returns whether private (direct) chat is disabled.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<bool> isPrivateChatDisabled() async {
    final result = await _channel.invokeMethod<bool>(
      'chat.isPrivateChatDisabled',
    );
    return result ?? false;
  }
}

/// Cloud recording controls for the Zoom Video SDK.
///
/// Requires a Video SDK account with Cloud Recording Storage Plan.
/// JWT must include `cloud_recording_option: 1`.
///
/// Access via [ZoomVideoSdk.recordingHelper].
class ZoomRecordingHelper {
  ZoomRecordingHelper(this._channel);

  final MethodChannel _channel;

  /// Checks whether the current user can start cloud recording. Desktop only.
  ///
  /// **Platform support:** Android ❌ iOS ❌ Windows ✅ macOS ✅
  ///
  /// Throws [UnimplementedError] on Android and iOS.
  Future<bool> canStartRecording() async {
    _assertDesktopOnly('canStartRecording()');
    final result = await _channel.invokeMethod<bool>(
      'recording.canStartRecording',
    );
    return result ?? false;
  }

  /// Starts cloud recording.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> startCloudRecording() async {
    await _channel.invokeMethod<void>('recording.startCloudRecording');
  }

  /// Stops cloud recording.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> stopCloudRecording() async {
    await _channel.invokeMethod<void>('recording.stopCloudRecording');
  }
}

/// Virtual background controls for the Zoom Video SDK.
///
/// Access via [ZoomVideoSdk.virtualBackgroundHelper].
class ZoomVirtualBackgroundHelper {
  ZoomVirtualBackgroundHelper(this._channel);

  final MethodChannel _channel;

  /// Returns whether virtual backgrounds are supported on the current device.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<bool> isSupported() async {
    final result = await _channel.invokeMethod<bool>(
      'virtualBackground.isSupported',
    );
    return result ?? false;
  }

  /// Adds a virtual background image from a file path.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> addItem(String filePath) async {
    await _channel.invokeMethod<void>('virtualBackground.addItem', {
      'filePath': filePath,
    });
  }

  /// Returns all available virtual background items.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<List<ZoomVirtualBackgroundItem>> getItemList() async {
    final result = await _channel.invokeListMethod<Map>(
      'virtualBackground.getItemList',
    );
    return (result ?? []).map((m) {
      final map = Map<String, dynamic>.from(m);
      return ZoomVirtualBackgroundItem(
        imageName: map['imageName'] as String,
        imagePath: map['imagePath'] as String,
      );
    }).toList();
  }

  /// Applies a virtual background by image name.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> setItem(String imageName) async {
    await _channel.invokeMethod<void>('virtualBackground.setItem', {
      'imageName': imageName,
    });
  }

  /// Removes a virtual background by image name.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> removeItem(String imageName) async {
    await _channel.invokeMethod<void>('virtualBackground.removeItem', {
      'imageName': imageName,
    });
  }

  /// Returns the currently active virtual background, or `null` if none.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<ZoomVirtualBackgroundItem?> getSelectedItem() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'virtualBackground.getSelectedItem',
    );
    if (result == null) return null;
    return ZoomVirtualBackgroundItem(
      imageName: result['imageName'] as String,
      imagePath: result['imagePath'] as String,
    );
  }
}

/// Host / user management controls for the Zoom Video SDK.
///
/// Requires host or manager role.
///
/// Access via [ZoomVideoSdk.userHelper].
class ZoomUserHelper {
  ZoomUserHelper(this._channel);

  final MethodChannel _channel;

  /// Transfers host role to the specified user.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> makeHost(String userId) async {
    await _channel.invokeMethod<void>('user.makeHost', {'userId': userId});
  }

  /// Promotes the specified user to manager (co-host).
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> makeManager(String userId) async {
    await _channel.invokeMethod<void>('user.makeManager', {'userId': userId});
  }

  /// Revokes manager role from the specified user.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> revokeManager(String userId) async {
    await _channel.invokeMethod<void>('user.revokeManager', {'userId': userId});
  }

  /// Removes the specified user from the session.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> removeUser(String userId) async {
    await _channel.invokeMethod<void>('user.removeUser', {'userId': userId});
  }

  /// Changes the display name of the specified user.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> changeName(String name, String userId) async {
    await _channel.invokeMethod<void>('user.changeName', {
      'name': name,
      'userId': userId,
    });
  }
}

// ---------------------------------------------------------------------------
// Main SDK class
// ---------------------------------------------------------------------------

/// Entry point for the Zoom Video SDK Flutter plugin.
///
/// Usage:
/// ```dart
/// final sdk = ZoomVideoSdk();
/// await sdk.init(const ZoomInitConfig(domain: 'https://zoom.us'));
/// await sdk.joinSession(ZoomJoinSessionConfig(
///   sessionName: 'my-session',
///   userName: 'Alice',
///   token: jwt,
/// ));
///
/// sdk.onSessionJoin.listen((_) => print('Joined!'));
/// sdk.onError.listen((e) => print('Error: ${e.errorCode}'));
///
/// // When done:
/// await sdk.leaveSession();
/// sdk.dispose();
/// ```
class ZoomVideoSdk {
  /// Creates a new [ZoomVideoSdk] instance.
  ZoomVideoSdk()
    : _channel = const MethodChannel('zoom_video_sdk_flutter'),
      _eventChannel = const EventChannel('zoom_video_sdk_flutter/events') {
    _audioHelper = ZoomAudioHelper(_channel);
    _videoHelper = ZoomVideoHelper(_channel);
    _shareHelper = ZoomShareHelper(_channel);
    _chatHelper = ZoomChatHelper(_channel);
    _recordingHelper = ZoomRecordingHelper(_channel);
    _virtualBackgroundHelper = ZoomVirtualBackgroundHelper(_channel);
    _userHelper = ZoomUserHelper(_channel);

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen((
      dynamic event,
    ) {
      final map = Map<String, dynamic>.from(event as Map);
      final zoomEvent = _decodeEvent(map);
      if (zoomEvent != null) _eventController.add(zoomEvent);
    });
  }

  final MethodChannel _channel;
  final EventChannel _eventChannel;

  final StreamController<ZoomEvent> _eventController =
      StreamController<ZoomEvent>.broadcast();

  late final StreamSubscription<dynamic> _eventSubscription;

  late final ZoomAudioHelper _audioHelper;
  late final ZoomVideoHelper _videoHelper;
  late final ZoomShareHelper _shareHelper;
  late final ZoomChatHelper _chatHelper;
  late final ZoomRecordingHelper _recordingHelper;
  late final ZoomVirtualBackgroundHelper _virtualBackgroundHelper;
  late final ZoomUserHelper _userHelper;

  // ---- Helpers ----

  /// Audio controls (start, stop, mute, unmute, device selection).
  ZoomAudioHelper get audioHelper => _audioHelper;

  /// Video controls (start, stop, switch camera).
  ZoomVideoHelper get videoHelper => _videoHelper;

  /// Screen share controls (start, stop, share window).
  ZoomShareHelper get shareHelper => _shareHelper;

  /// Chat controls (send messages, check disabled state).
  ZoomChatHelper get chatHelper => _chatHelper;

  /// Cloud recording controls (start, stop).
  ZoomRecordingHelper get recordingHelper => _recordingHelper;

  /// Virtual background controls (add, set, remove, list).
  ZoomVirtualBackgroundHelper get virtualBackgroundHelper =>
      _virtualBackgroundHelper;

  /// Host / user management controls (make host, remove user, etc.).
  ZoomUserHelper get userHelper => _userHelper;

  // ---- Initialization ----

  /// Initializes the Zoom Video SDK. Must be called before any other method.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  ///
  /// Throws [PlatformException] if initialization fails.
  Future<void> init(ZoomInitConfig config) async {
    await _channel.invokeMethod<void>('init', {
      'domain': config.domain,
      'enableLog': config.enableLog,
      if (config.appGroupId != null) 'appGroupId': config.appGroupId,
    });
  }

  // ---- Session ----

  /// Joins a video session with the given configuration.
  ///
  /// The JWT [ZoomJoinSessionConfig.token] must be generated server-side.
  /// Listen to [onSessionJoin] for join confirmation.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  ///
  /// Throws [PlatformException] on failure (invalid token, network error, etc.).
  Future<void> joinSession(ZoomJoinSessionConfig config) async {
    await _channel.invokeMethod<void>('joinSession', {
      'sessionName': config.sessionName,
      'userName': config.userName,
      'token': config.token,
      if (config.sessionPassword != null)
        'sessionPassword': config.sessionPassword,
      if (config.audioOptions != null)
        'audioOptions': {
          'connect': config.audioOptions!.connect,
          'mute': config.audioOptions!.mute,
          'autoAdjustSpeakerVolume':
              config.audioOptions!.autoAdjustSpeakerVolume,
        },
      if (config.videoOptions != null)
        'videoOptions': {'localVideoOn': config.videoOptions!.localVideoOn},
      if (config.sessionIdleTimeoutMins != null)
        'sessionIdleTimeoutMins': config.sessionIdleTimeoutMins,
    });
  }

  /// Leaves the current session.
  ///
  /// If [endSession] is `true` and the caller is the host, the session is
  /// ended for all participants.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> leaveSession({bool endSession = false}) async {
    await _channel.invokeMethod<void>('leaveSession', {
      'endSession': endSession,
    });
  }

  /// Returns information about the current active session.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  ///
  /// Throws [PlatformException] if no session is active.
  Future<ZoomSessionInfo> getSessionInfo() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'getSessionInfo',
    );
    return _decodeSessionInfo(result!);
  }

  // ---- Participants ----

  /// Returns the local user.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<ZoomUser> getMyself() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('getMyself');
    return _decodeUser(result!);
  }

  /// Returns all users in the session (including self).
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<List<ZoomUser>> getAllUsers() async {
    final result = await _channel.invokeListMethod<Map>('getAllUsers');
    return (result ?? [])
        .map((m) => _decodeUser(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Returns all remote users in the session (excluding self).
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<List<ZoomUser>> getRemoteUsers() async {
    final result = await _channel.invokeListMethod<Map>('getRemoteUsers');
    return (result ?? [])
        .map((m) => _decodeUser(Map<String, dynamic>.from(m)))
        .toList();
  }

  // ---- Event streams ----

  /// Unified event stream. All SDK events are emitted here.
  ///
  /// Use the typed convenience getters below to filter by event type.
  Stream<ZoomEvent> get events => _eventController.stream;

  /// Fires when the local user successfully joins a session.
  Stream<SessionJoinedEvent> get onSessionJoin =>
      events.where((e) => e is SessionJoinedEvent).cast<SessionJoinedEvent>();

  /// Fires when the local user leaves or is removed from a session.
  Stream<SessionLeftEvent> get onSessionLeave =>
      events.where((e) => e is SessionLeftEvent).cast<SessionLeftEvent>();

  /// Fires when one or more remote users join the session.
  Stream<UserJoinedEvent> get onUserJoined =>
      events.where((e) => e is UserJoinedEvent).cast<UserJoinedEvent>();

  /// Fires when one or more remote users leave the session.
  Stream<UserLeftEvent> get onUserLeft =>
      events.where((e) => e is UserLeftEvent).cast<UserLeftEvent>();

  /// Fires when a user's video status changes (on/off).
  Stream<UserVideoStatusChangedEvent> get onUserVideoStatusChanged => events
      .where((e) => e is UserVideoStatusChangedEvent)
      .cast<UserVideoStatusChangedEvent>();

  /// Fires when a user's audio status changes (mute/unmute).
  Stream<UserAudioStatusChangedEvent> get onUserAudioStatusChanged => events
      .where((e) => e is UserAudioStatusChangedEvent)
      .cast<UserAudioStatusChangedEvent>();

  /// Fires when the active speaker list changes.
  Stream<UserActiveAudioChangedEvent> get onUserActiveAudioChanged => events
      .where((e) => e is UserActiveAudioChangedEvent)
      .cast<UserActiveAudioChangedEvent>();

  /// Fires when a chat message is received.
  Stream<ChatMessageReceivedEvent> get onChatMessageReceived => events
      .where((e) => e is ChatMessageReceivedEvent)
      .cast<ChatMessageReceivedEvent>();

  /// Fires when a user's screen share status changes.
  Stream<UserShareStatusChangedEvent> get onUserShareStatusChanged => events
      .where((e) => e is UserShareStatusChangedEvent)
      .cast<UserShareStatusChangedEvent>();

  /// Fires when the host role is transferred to a different user.
  Stream<UserHostChangedEvent> get onUserHostChanged => events
      .where((e) => e is UserHostChangedEvent)
      .cast<UserHostChangedEvent>();

  /// Fires when a user's manager (co-host) status changes.
  Stream<UserManagerChangedEvent> get onUserManagerChanged => events
      .where((e) => e is UserManagerChangedEvent)
      .cast<UserManagerChangedEvent>();

  /// Fires when a user's display name changes.
  Stream<UserNameChangedEvent> get onUserNameChanged => events
      .where((e) => e is UserNameChangedEvent)
      .cast<UserNameChangedEvent>();

  /// Fires when the session requires a password to join.
  Stream<SessionNeedPasswordEvent> get onSessionNeedPassword => events
      .where((e) => e is SessionNeedPasswordEvent)
      .cast<SessionNeedPasswordEvent>();

  /// Fires when the provided session password is incorrect.
  Stream<SessionPasswordWrongEvent> get onSessionPasswordWrong => events
      .where((e) => e is SessionPasswordWrongEvent)
      .cast<SessionPasswordWrongEvent>();

  /// Fires when an SDK error occurs.
  Stream<ErrorEvent> get onError =>
      events.where((e) => e is ErrorEvent).cast<ErrorEvent>();

  // ---- Cleanup ----

  /// Releases SDK resources and closes all event stream controllers.
  ///
  /// Must be called when the SDK is no longer needed.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  void dispose() {
    _eventSubscription.cancel();
    _eventController.close();
  }
}

// ---------------------------------------------------------------------------
// Platform assertion helpers
// ---------------------------------------------------------------------------

/// Throws [UnimplementedError] if the current platform is Android or iOS.
void _assertDesktopOnly(String methodName) {
  final platform = defaultTargetPlatform;
  if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
    throw UnimplementedError(
      '$methodName is not supported on ${platform.name}. '
      'See docs/DART_API_DESIGN.md for platform support details.',
    );
  }
}

// ---------------------------------------------------------------------------
// Deserialization helpers (private)
// ---------------------------------------------------------------------------

ZoomEvent? _decodeEvent(Map<String, dynamic> map) {
  final type = map['eventType'] as String;
  final data = Map<String, dynamic>.from(map['data'] as Map? ?? {});

  return switch (type) {
    'sessionJoined' => const SessionJoinedEvent(),
    'sessionLeft' => const SessionLeftEvent(),
    'userJoined' => UserJoinedEvent(
      users: _decodeUserList(data['users'] as List),
    ),
    'userLeft' => UserLeftEvent(users: _decodeUserList(data['users'] as List)),
    'userVideoStatusChanged' => UserVideoStatusChangedEvent(
      user: _decodeUser(Map<String, dynamic>.from(data['user'] as Map)),
    ),
    'userAudioStatusChanged' => UserAudioStatusChangedEvent(
      user: _decodeUser(Map<String, dynamic>.from(data['user'] as Map)),
    ),
    'userActiveAudioChanged' => UserActiveAudioChangedEvent(
      activeUsers: _decodeUserList(data['activeUsers'] as List),
    ),
    'chatMessageReceived' => ChatMessageReceivedEvent(
      message: _decodeChatMessage(
        Map<String, dynamic>.from(data['message'] as Map),
      ),
    ),
    'userShareStatusChanged' => UserShareStatusChangedEvent(
      user: _decodeUser(Map<String, dynamic>.from(data['user'] as Map)),
      status: ZoomShareStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => ZoomShareStatus.stopped,
      ),
    ),
    'userHostChanged' => UserHostChangedEvent(
      newHost: _decodeUser(Map<String, dynamic>.from(data['newHost'] as Map)),
    ),
    'userManagerChanged' => UserManagerChangedEvent(
      user: _decodeUser(Map<String, dynamic>.from(data['user'] as Map)),
      isManager: data['isManager'] as bool,
    ),
    'userNameChanged' => UserNameChangedEvent(
      user: _decodeUser(Map<String, dynamic>.from(data['user'] as Map)),
    ),
    'sessionNeedPassword' => const SessionNeedPasswordEvent(),
    'sessionPasswordWrong' => const SessionPasswordWrongEvent(),
    'error' => ErrorEvent(
      errorCode: ZoomErrorCode.values.firstWhere(
        (c) => c.name == data['errorCode'],
        orElse: () => ZoomErrorCode.unknown,
      ),
      message: data['message'] as String?,
    ),
    _ => null,
  };
}

List<ZoomUser> _decodeUserList(List<dynamic> list) {
  return list
      .map((u) => _decodeUser(Map<String, dynamic>.from(u as Map)))
      .toList();
}

ZoomUser _decodeUser(Map<String, dynamic> map) {
  return ZoomUser(
    userId: map['userId'] as String,
    userName: map['userName'] as String,
    isHost: map['isHost'] as bool? ?? false,
    isManager: map['isManager'] as bool? ?? false,
    audioStatus: map['audioStatus'] != null
        ? _decodeAudioStatus(
            Map<String, dynamic>.from(map['audioStatus'] as Map),
          )
        : null,
    videoStatus: map['videoStatus'] != null
        ? _decodeVideoStatus(
            Map<String, dynamic>.from(map['videoStatus'] as Map),
          )
        : null,
    isSharing: map['isSharing'] as bool? ?? false,
  );
}

ZoomAudioStatus _decodeAudioStatus(Map<String, dynamic> map) {
  return ZoomAudioStatus(
    isMuted: map['isMuted'] as bool,
    isTalking: map['isTalking'] as bool,
    audioType: ZoomAudioType.values.firstWhere(
      (t) => t.name == map['audioType'],
      orElse: () => ZoomAudioType.none,
    ),
  );
}

ZoomVideoStatus _decodeVideoStatus(Map<String, dynamic> map) {
  return ZoomVideoStatus(
    isOn: map['isOn'] as bool,
    hasSource: map['hasSource'] as bool,
  );
}

ZoomSessionInfo _decodeSessionInfo(Map<String, dynamic> map) {
  return ZoomSessionInfo(
    sessionName: map['sessionName'] as String,
    sessionId: map['sessionId'] as String,
    sessionPassword: map['sessionPassword'] as String?,
    host: map['host'] != null
        ? _decodeUser(Map<String, dynamic>.from(map['host'] as Map))
        : null,
  );
}

ZoomChatMessage _decodeChatMessage(Map<String, dynamic> map) {
  return ZoomChatMessage(
    content: map['content'] as String,
    senderUser: _decodeUser(
      Map<String, dynamic>.from(map['senderUser'] as Map),
    ),
    receiverUser: map['receiverUser'] != null
        ? _decodeUser(Map<String, dynamic>.from(map['receiverUser'] as Map))
        : null,
    isChatToAll: map['isChatToAll'] as bool,
    isSelfSend: map['isSelfSend'] as bool,
    timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
  );
}
