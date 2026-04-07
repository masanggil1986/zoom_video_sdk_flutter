/// Zoom Video SDK Flutter plugin.
///
/// Provides a unified Dart API for the Zoom Video SDK across
/// Android, iOS, Windows, and macOS.
///
/// See `docs/DART_API_DESIGN.md` for full platform support details.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
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

/// Video rendering aspect mode.
enum ZoomVideoAspectMode { panAndScan, letterBox }

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
    this.domain = 'zoom.us',
    this.enableLog = true,
    this.appGroupId,
  });

  /// Zoom service domain.
  final String domain;

  /// Whether SDK logging is enabled.
  final bool enableLog;

  /// iOS App Group ID for screen sharing. Ignored on other platforms.
  final String? appGroupId;
}

/// Audio options for [ZoomJoinSessionConfig].
@immutable
class ZoomAudioOptions {
  const ZoomAudioOptions({this.connect = true, this.mute = false});

  /// Automatically connect audio on join.
  final bool connect;

  /// Start with microphone muted.
  final bool mute;
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
  Future<void> startAudio() {
    throw UnimplementedError('Not yet implemented');
  }

  /// Stops the audio engine.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> stopAudio() {
    throw UnimplementedError('Not yet implemented');
  }

  /// Mutes audio for the given user.
  ///
  /// Non-host callers can only mute themselves.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> muteAudio(String userId) {
    throw UnimplementedError('Not yet implemented');
  }

  /// Unmutes audio for the given user.
  ///
  /// Non-host callers can only unmute themselves.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> unmuteAudio(String userId) {
    throw UnimplementedError('Not yet implemented');
  }

  /// Enables or disables original microphone input (bypasses noise
  /// suppression and echo cancellation).
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> enableMicOriginalInput(bool enable) {
    throw UnimplementedError('Not yet implemented');
  }

  /// Sets the noise suppression level.
  ///
  /// Specific levels (`auto_`, `low`, `medium`, `high`) are documented for
  /// Windows/macOS. Android/iOS may support a subset.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> setNoiseSuppression(ZoomNoiseSuppression level) {
    throw UnimplementedError('Not yet implemented');
  }

  /// Returns the list of available audio input/output devices.
  ///
  /// Android auto-routes audio — the returned list may be empty or not
  /// meaningful. iOS has limited device control.
  ///
  /// **Platform support:** Android ⚠️ iOS ⚠️ Windows ✅ macOS ✅
  Future<List<ZoomAudioDevice>> getAudioDeviceList() {
    throw UnimplementedError('Not yet implemented');
  }

  /// Selects an audio device by ID.
  ///
  /// Android auto-routes audio — selection may have no effect.
  /// iOS has limited device control.
  ///
  /// **Platform support:** Android ⚠️ iOS ⚠️ Windows ✅ macOS ✅
  Future<void> selectAudioDevice(String deviceId) {
    throw UnimplementedError('Not yet implemented');
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
  Future<void> startVideo() {
    throw UnimplementedError('Not yet implemented');
  }

  /// Stops the local camera video.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> stopVideo() {
    throw UnimplementedError('Not yet implemented');
  }

  /// Switches between available cameras.
  ///
  /// On mobile, toggles front/back camera.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> switchCamera() {
    throw UnimplementedError('Not yet implemented');
  }

  /// Returns the list of available cameras. Desktop only.
  ///
  /// **Platform support:** Android ❌ iOS ❌ Windows ✅ macOS ✅
  ///
  /// Throws [UnimplementedError] on Android and iOS.
  Future<List<ZoomCameraDevice>> getCameraList() {
    _assertDesktopOnly('getCameraList()');
    throw UnimplementedError('Not yet implemented');
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
  /// On iOS, requires `appGroupId` in [ZoomInitConfig] and a Broadcast Upload
  /// Extension target. On Android, requires MediaProjection permission.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> startShareScreen() {
    throw UnimplementedError('Not yet implemented');
  }

  /// Shares a specific application window by its handle/ID. Desktop only.
  ///
  /// **Platform support:** Android ❌ iOS ❌ Windows ✅ macOS ✅
  ///
  /// Throws [UnimplementedError] on Android and iOS.
  Future<void> startShareView(String windowId) {
    _assertDesktopOnly('startShareView()');
    throw UnimplementedError('Not yet implemented');
  }

  /// Stops screen or window sharing.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> stopShare() {
    throw UnimplementedError('Not yet implemented');
  }

  /// Enables or disables sharing device audio alongside screen share.
  /// Desktop only.
  ///
  /// **Platform support:** Android ❌ iOS ❌ Windows ✅ macOS ✅
  ///
  /// Throws [UnimplementedError] on Android and iOS.
  Future<void> enableShareDeviceAudio(bool enable) {
    _assertDesktopOnly('enableShareDeviceAudio()');
    throw UnimplementedError('Not yet implemented');
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
  Future<void> sendChatToAll(String message) {
    throw UnimplementedError('Not yet implemented');
  }

  /// Sends a private chat message to a specific user.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> sendChatToUser(String userId, String message) {
    throw UnimplementedError('Not yet implemented');
  }

  /// Returns whether chat is disabled for the session.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<bool> isChatDisabled() {
    throw UnimplementedError('Not yet implemented');
  }

  /// Returns whether private (direct) chat is disabled.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<bool> isPrivateChatDisabled() {
    throw UnimplementedError('Not yet implemented');
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
  Future<bool> canStartRecording() {
    _assertDesktopOnly('canStartRecording()');
    throw UnimplementedError('Not yet implemented');
  }

  /// Starts cloud recording.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> startCloudRecording() {
    throw UnimplementedError('Not yet implemented');
  }

  /// Stops cloud recording.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> stopCloudRecording() {
    throw UnimplementedError('Not yet implemented');
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
  Future<bool> isSupported() {
    throw UnimplementedError('Not yet implemented');
  }

  /// Adds a virtual background image from a file path.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> addItem(String filePath) {
    throw UnimplementedError('Not yet implemented');
  }

  /// Returns all available virtual background items.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<List<ZoomVirtualBackgroundItem>> getItemList() {
    throw UnimplementedError('Not yet implemented');
  }

  /// Applies a virtual background by image name.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> setItem(String imageName) {
    throw UnimplementedError('Not yet implemented');
  }

  /// Removes a virtual background by image name.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> removeItem(String imageName) {
    throw UnimplementedError('Not yet implemented');
  }

  /// Returns the currently active virtual background, or `null` if none.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<ZoomVirtualBackgroundItem?> getSelectedItem() {
    throw UnimplementedError('Not yet implemented');
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
  Future<void> makeHost(String userId) {
    throw UnimplementedError('Not yet implemented');
  }

  /// Promotes the specified user to manager (co-host).
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> makeManager(String userId) {
    throw UnimplementedError('Not yet implemented');
  }

  /// Revokes manager role from the specified user.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> revokeManager(String userId) {
    throw UnimplementedError('Not yet implemented');
  }

  /// Removes the specified user from the session.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> removeUser(String userId) {
    throw UnimplementedError('Not yet implemented');
  }

  /// Changes the display name of the specified user.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> changeName(String name, String userId) {
    throw UnimplementedError('Not yet implemented');
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
/// await sdk.init(const ZoomInitConfig(domain: 'zoom.us'));
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
  }

  final MethodChannel _channel;
  final EventChannel _eventChannel;

  final StreamController<ZoomEvent> _eventController =
      StreamController<ZoomEvent>.broadcast();

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
  Future<void> init(ZoomInitConfig config) {
    throw UnimplementedError('Not yet implemented');
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
  Future<void> joinSession(ZoomJoinSessionConfig config) {
    throw UnimplementedError('Not yet implemented');
  }

  /// Leaves the current session.
  ///
  /// If [endSession] is `true` and the caller is the host, the session is
  /// ended for all participants.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<void> leaveSession({bool endSession = false}) {
    throw UnimplementedError('Not yet implemented');
  }

  /// Returns information about the current active session.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  ///
  /// Throws [PlatformException] if no session is active.
  Future<ZoomSessionInfo> getSessionInfo() {
    throw UnimplementedError('Not yet implemented');
  }

  // ---- Participants ----

  /// Returns the local user.
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<ZoomUser> getMyself() {
    throw UnimplementedError('Not yet implemented');
  }

  /// Returns all users in the session (including self).
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<List<ZoomUser>> getAllUsers() {
    throw UnimplementedError('Not yet implemented');
  }

  /// Returns all remote users in the session (excluding self).
  ///
  /// **Platform support:** Android ✅ iOS ✅ Windows ✅ macOS ✅
  Future<List<ZoomUser>> getRemoteUsers() {
    throw UnimplementedError('Not yet implemented');
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
