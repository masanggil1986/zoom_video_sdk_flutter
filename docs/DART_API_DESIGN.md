# Dart API Design — zoom_video_sdk_flutter

> Last updated: 2026-04-23
> Based on: [ZOOM_SDK_REFERENCE.md](./ZOOM_SDK_REFERENCE.md)
> Target platforms: Android, iOS, Windows, macOS

---

## 1. Design Principles

### Unsupported Features

Methods that are **never supported** on a given platform throw `UnimplementedError` at
runtime with a descriptive message:

```dart
throw UnimplementedError(
  'startShareView() is not supported on Android. '
  'See docs/DART_API_DESIGN.md for platform support details.'
);
```

The check uses `defaultTargetPlatform` so it works in tests and on device. A private
helper `_assertPlatformSupported()` centralises this logic.

Features that are **partially supported** (e.g. audio device selection on iOS) are
still callable — the doc comment notes the limitation and callers decide how to handle
the reduced capability.

### Platform Differences

Every public method and event carries a `/// **Platform support:**` line in its doc
comment showing per-platform status. The consolidated table in section 5 provides a
single-page overview.

### Event / Callback Strategy

- **Streams only.** No callback-based listeners.
- A single `Stream<ZoomEvent> get events` exposes all events via a `sealed class`.
- Typed convenience getters (`onSessionJoin`, `onUserJoined`, etc.) filter
  the main stream with `Stream.where().cast<T>()`.
- Events are broadcast streams — multiple listeners are safe.
- `dispose()` closes all stream controllers.

### Null Safety and Error Handling

- Full sound null safety. No `dynamic` types.
- Optional values use `?` with sensible defaults. Never use `!`.
- SDK-level errors surface via the `onError` event stream (`ErrorEvent` containing
  `ZoomErrorCode`).
- Platform method calls return `Future<T>` and may throw:
  - `UnimplementedError` — unsupported platform or not yet implemented.
  - `PlatformException` — native SDK returned an error.

---

## 2. Data Models

### Enums

#### `ZoomErrorCode`

Error codes surfaced by the native SDKs.

```dart
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
```

#### `ZoomAudioType`

```dart
enum ZoomAudioType { voip, telephony, none }
```

#### `ZoomShareStatus`

```dart
enum ZoomShareStatus { started, stopped, paused }
```

#### `ZoomVideoAspectMode`

```dart
enum ZoomVideoAspectMode { panAndScan, letterBox }
```

#### `ZoomNoiseSuppression`

Documented for Windows/macOS. Android/iOS may map to a subset.

```dart
enum ZoomNoiseSuppression { auto_, low, medium, high }
```

### Configuration Classes

#### `ZoomInitConfig`

| Field | Type | Required | Platform notes |
|-------|------|----------|----------------|
| `domain` | `String` | No (default `'zoom.us'`) | All |
| `enableLog` | `bool` | No (default `true`) | All |
| `appGroupId` | `String?` | No | iOS only — required for screen sharing |

```dart
const config = ZoomInitConfig(
  domain: 'zoom.us',
  enableLog: true,
  appGroupId: 'group.com.example.app', // iOS only
);
```

#### `ZoomJoinSessionConfig`

| Field | Type | Required | Constraint |
|-------|------|----------|------------|
| `sessionName` | `String` | Yes | Max 150 chars |
| `userName` | `String` | Yes | Max 200 chars |
| `token` | `String` | Yes | Server-generated JWT |
| `sessionPassword` | `String?` | No | Max 10 chars |
| `audioOptions` | `ZoomAudioOptions?` | No | |
| `videoOptions` | `ZoomVideoOptions?` | No | |
| `sessionIdleTimeoutMins` | `int?` | No | |

```dart
const config = ZoomJoinSessionConfig(
  sessionName: 'my-session',
  userName: 'Alice',
  token: '<jwt>',
  audioOptions: ZoomAudioOptions(connect: true, mute: false),
  videoOptions: ZoomVideoOptions(localVideoOn: true),
);
```

#### `ZoomAudioOptions`

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `connect` | `bool` | `true` | Auto-connect audio on join |
| `mute` | `bool` | `false` | Start muted |
| `autoAdjustSpeakerVolume` | `bool` | `true` | macOS/Windows only — auto-raise speaker volume if muted/low at join |

#### `ZoomVideoOptions`

| Field | Type | Default |
|-------|------|---------|
| `localVideoOn` | `bool` | `false` |

#### `ZoomShareOption`

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `withDeviceAudio` | `bool` | `false` | Include system audio in the share stream (desktop only) |
| `optimizeForSharedVideo` | `bool` | `false` | Prefer frame rate over clarity — use when sharing video |

### Model Classes

#### `ZoomUser`

| Field | Type | Notes |
|-------|------|-------|
| `userId` | `String` | Unique within session |
| `userName` | `String` | Display name |
| `isHost` | `bool` | |
| `isManager` | `bool` | Co-host |
| `audioStatus` | `ZoomAudioStatus?` | Null before audio starts |
| `videoStatus` | `ZoomVideoStatus?` | Null before video starts |

```dart
const user = ZoomUser(
  userId: '123',
  userName: 'Alice',
  isHost: true,
  audioStatus: ZoomAudioStatus(isMuted: false, isTalking: true, audioType: ZoomAudioType.voip),
  videoStatus: ZoomVideoStatus(isOn: true, hasSource: true),
);
```

#### `ZoomSessionInfo`

| Field | Type |
|-------|------|
| `sessionName` | `String` |
| `sessionId` | `String` |
| `sessionPassword` | `String?` |
| `host` | `ZoomUser?` |

#### `ZoomAudioStatus`

| Field | Type |
|-------|------|
| `isMuted` | `bool` |
| `isTalking` | `bool` |
| `audioType` | `ZoomAudioType` |

#### `ZoomVideoStatus`

| Field | Type |
|-------|------|
| `isOn` | `bool` |
| `hasSource` | `bool` |

#### `ZoomChatMessage`

| Field | Type |
|-------|------|
| `content` | `String` |
| `senderUser` | `ZoomUser` |
| `receiverUser` | `ZoomUser?` |
| `isChatToAll` | `bool` |
| `isSelfSend` | `bool` |
| `timestamp` | `DateTime` |

Max message size: 10,000 bytes (all platforms).

#### `ZoomAudioDevice`

| Field | Type |
|-------|------|
| `deviceId` | `String` |
| `deviceName` | `String` |

#### `ZoomCameraDevice`

| Field | Type |
|-------|------|
| `deviceId` | `String` |
| `deviceName` | `String` |

#### `ZoomVirtualBackgroundItem`

| Field | Type |
|-------|------|
| `imageName` | `String` |
| `imagePath` | `String` |

#### `ZoomShareSource`

| Field | Type | Notes |
|-------|------|-------|
| `sourceId` | `String` | Opaque id — pass to `startShareScreen(monitorId:)` or `startShareView(windowId)` |
| `name` | `String` | Monitor label or window title |
| `type` | `ZoomShareSourceType` | `screen` or `window` |

### `ZoomEvent` (sealed class)

```dart
sealed class ZoomEvent {}

final class SessionJoinedEvent extends ZoomEvent {}

final class SessionLeftEvent extends ZoomEvent {}

final class UserJoinedEvent extends ZoomEvent {
  final List<ZoomUser> users;
}

final class UserLeftEvent extends ZoomEvent {
  final List<ZoomUser> users;
}

final class UserVideoStatusChangedEvent extends ZoomEvent {
  final ZoomUser user;
}

final class UserAudioStatusChangedEvent extends ZoomEvent {
  final ZoomUser user;
}

final class UserActiveAudioChangedEvent extends ZoomEvent {
  final List<ZoomUser> activeUsers;
}

final class ChatMessageReceivedEvent extends ZoomEvent {
  final ZoomChatMessage message;
}

final class UserShareStatusChangedEvent extends ZoomEvent {
  final ZoomUser user;
  final ZoomShareStatus status;
}

final class UserHostChangedEvent extends ZoomEvent {
  final ZoomUser newHost;
}

final class UserManagerChangedEvent extends ZoomEvent {
  final ZoomUser user;
  final bool isManager;
}

final class UserNameChangedEvent extends ZoomEvent {
  final ZoomUser user;
}

final class SessionNeedPasswordEvent extends ZoomEvent {}

final class SessionPasswordWrongEvent extends ZoomEvent {}

final class ErrorEvent extends ZoomEvent {
  final ZoomErrorCode errorCode;
  final String? message;
}
```

---

## 3. Main API Class: `ZoomVideoSdk`

### Initialization

#### `init`

```dart
Future<void> init(ZoomInitConfig config)
```

Initializes the Zoom Video SDK. Must be called before any other method.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

**Returns:** Completes on success.
**Throws:** `PlatformException` if initialization fails.

```dart
final sdk = ZoomVideoSdk();
await sdk.init(const ZoomInitConfig(domain: 'zoom.us'));
```

### Session

#### `joinSession`

```dart
Future<void> joinSession(ZoomJoinSessionConfig config)
```

Joins a video session with the given configuration. The JWT `token` must be generated
server-side.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

**Returns:** Completes when the join request is sent. Listen to `onSessionJoin` for
confirmation.
**Throws:** `PlatformException` on failure (invalid token, network error, etc.).

```dart
await sdk.joinSession(const ZoomJoinSessionConfig(
  sessionName: 'standup',
  userName: 'Alice',
  token: jwt,
));
```

#### `leaveSession`

```dart
Future<void> leaveSession({bool endSession = false})
```

Leaves the current session. If `endSession` is `true` and the caller is the host,
the session is ended for all participants.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

```dart
await sdk.leaveSession(); // leave
await sdk.leaveSession(endSession: true); // host ends session
```

#### `getSessionInfo`

```dart
Future<ZoomSessionInfo> getSessionInfo()
```

Returns information about the current active session.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

**Throws:** `PlatformException` if no session is active.

### Audio

Audio methods are on the `audioHelper` accessor.

#### `audioHelper.startAudio`

```dart
Future<void> startAudio()
```

Starts the audio engine (connects microphone and speaker).

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `audioHelper.stopAudio`

```dart
Future<void> stopAudio()
```

Stops the audio engine.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `audioHelper.muteAudio`

```dart
Future<void> muteAudio(String userId)
```

Mutes audio for the given user. Non-host callers can only mute themselves.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `audioHelper.unmuteAudio`

```dart
Future<void> unmuteAudio(String userId)
```

Unmutes audio for the given user. Non-host callers can only unmute themselves.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `audioHelper.enableMicOriginalInput`

```dart
Future<void> enableMicOriginalInput(bool enable)
```

Enables or disables original microphone input (bypasses noise suppression / echo
cancellation).

Native SDKs expose this via a separate `audioSettingHelper`. This design consolidates
it into `ZoomAudioHelper` for simplicity (per reference section 5.3).

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `audioHelper.setNoiseSuppression`

```dart
Future<void> setNoiseSuppression(ZoomNoiseSuppression level)
```

Sets the noise suppression level.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

Note: Specific levels (`auto_`, `low`, `medium`, `high`) are documented for
Windows/macOS. Android/iOS may support a subset.

#### `audioHelper.getAudioDeviceList`

```dart
Future<List<ZoomAudioDevice>> getAudioDeviceList()
```

Returns the list of available audio input/output devices.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ⚠️ Auto-routes | ⚠️ Limited | ✅ | ✅ |

Android auto-routes audio and may not return a meaningful list.
iOS has limited device control.

#### `audioHelper.selectAudioDevice`

```dart
Future<void> selectAudioDevice(String deviceId)
```

Selects an audio device by ID.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ⚠️ Auto-routes | ⚠️ Limited | ✅ | ✅ |

### Video

Video methods are on the `videoHelper` accessor.

#### `videoHelper.startVideo`

```dart
Future<void> startVideo()
```

Starts the local camera video.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `videoHelper.stopVideo`

```dart
Future<void> stopVideo()
```

Stops the local camera video.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `videoHelper.switchCamera`

```dart
Future<void> switchCamera()
```

Switches between available cameras. On mobile, toggles front/back camera.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `videoHelper.getCameraList`

```dart
Future<List<ZoomCameraDevice>> getCameraList()
```

Returns the list of available cameras. Desktop only.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ❌ | ❌ | ✅ | ✅ |

**Throws:** `UnimplementedError` on Android/iOS.

#### `videoHelper.selectCamera`

```dart
Future<void> selectCamera(String deviceId)
```

Selects a camera by device ID. On mobile, use `switchCamera()` to toggle front/back.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ❌ | ❌ | ✅ | ✅ |

**Throws:** `UnimplementedError` on Android/iOS.

#### `videoHelper.setVideoQualityPreference`

```dart
Future<void> setVideoQualityPreference(
  ZoomVideoPreferenceMode mode, {
  int minimumFrameRate = 0,
  int maximumFrameRate = 0,
})
```

Sets the camera video quality preference. For `ZoomVideoPreferenceMode.custom`, supply
`minimumFrameRate`/`maximumFrameRate` (valid range: 0–30, `min <= max`).

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

### Video / Share View (`ZoomVideoView`)

```dart
ZoomVideoView({required String userId, ZoomVideoKind kind = ZoomVideoKind.video})
```

Widget that renders a user's camera feed or screen share. On macOS it wraps
`AppKitView` (platform view); on Windows it's a Flutter `Texture` driven by a
native raw-data subscription. Android/iOS currently show a black placeholder.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ❌ | ❌ | ✅ | ✅ |

> **Windows self-share note:** Subscribing to the local user's own share pipe
> crashes the SDK on teardown, so `ZoomVideoView(kind: share)` shows a black
> placeholder when `userId` is the local user. Remote shares render normally.

### Screen Share

Screen share methods are on the `shareHelper` accessor.

#### `shareHelper.startShareScreen`

```dart
Future<void> startShareScreen({
  String? monitorId,
  ZoomShareOption? option,
})
```

Starts screen sharing. On desktop, `monitorId` from `getShareSourceList()` picks a
specific display; omit for the primary display. On iOS, requires `appGroupId` in
`ZoomInitConfig` and a Broadcast Upload Extension. On Android, requires
MediaProjection permission.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `shareHelper.startShareView`

```dart
Future<void> startShareView(String windowId, {ZoomShareOption? option})
```

Shares a specific application window by its handle (Windows: HWND as decimal string;
macOS: CGWindowID). Desktop only.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ❌ | ❌ | ✅ | ✅ |

**Throws:** `UnimplementedError` on Android/iOS.

```dart
final sources = await sdk.shareHelper.getShareSourceList();
final window = sources.firstWhere((s) => s.type == ZoomShareSourceType.window);
await sdk.shareHelper.startShareView(window.sourceId);
```

#### `shareHelper.getShareSourceList`

```dart
Future<List<ZoomShareSource>> getShareSourceList()
```

Enumerates shareable monitors and top-level application windows. Desktop only.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ❌ | ❌ | ✅ | ✅ |

**Throws:** `UnimplementedError` on Android/iOS.

#### `shareHelper.stopShare`

```dart
Future<void> stopShare()
```

Stops screen/window sharing.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `shareHelper.enableShareDeviceAudio`

```dart
Future<void> enableShareDeviceAudio(bool enable)
```

Enables or disables sharing device audio alongside screen share. Desktop only.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ❌ | ❌ | ✅ | ✅ |

**Throws:** `UnimplementedError` on Android/iOS.

#### `shareHelper.enableOptimizeForSharedVideo`

```dart
Future<void> enableOptimizeForSharedVideo(bool enable)
```

Toggles "optimize for video" on an active share — prioritizes frame rate over
still-frame clarity. A screen/window share must already be running. Desktop only.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ❌ | ❌ | ✅ | ✅ |

**Throws:** `UnimplementedError` on Android/iOS.

### Participants

#### `getMyself`

```dart
Future<ZoomUser> getMyself()
```

Returns the local user.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `getAllUsers`

```dart
Future<List<ZoomUser>> getAllUsers()
```

Returns all users in the session (including self).

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `getRemoteUsers`

```dart
Future<List<ZoomUser>> getRemoteUsers()
```

Returns all remote users in the session (excluding self).

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

### Chat

Chat methods are on the `chatHelper` accessor.

#### `chatHelper.sendChatToAll`

```dart
Future<void> sendChatToAll(String message)
```

Sends a chat message to all participants. Max 10,000 bytes.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `chatHelper.sendChatToUser`

```dart
Future<void> sendChatToUser(String userId, String message)
```

Sends a private chat message to a specific user.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `chatHelper.isChatDisabled`

```dart
Future<bool> isChatDisabled()
```

Returns whether chat is disabled for the session.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `chatHelper.isPrivateChatDisabled`

```dart
Future<bool> isPrivateChatDisabled()
```

Returns whether private (direct) chat is disabled.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

### Cloud Recording

Recording methods are on the `recordingHelper` accessor.

Requires a Video SDK account with Cloud Recording Storage Plan. JWT must include
`cloud_recording_option: 1`.

#### `recordingHelper.canStartRecording`

```dart
Future<bool> canStartRecording()
```

Checks whether the current user can start cloud recording. Desktop only.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ❌ | ❌ | ✅ | ✅ |

**Throws:** `UnimplementedError` on Android/iOS.

#### `recordingHelper.startCloudRecording`

```dart
Future<void> startCloudRecording()
```

Starts cloud recording.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `recordingHelper.stopCloudRecording`

```dart
Future<void> stopCloudRecording()
```

Stops cloud recording.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

### Virtual Background

Virtual background methods are on the `virtualBackgroundHelper` accessor.

#### `virtualBackgroundHelper.isSupported`

```dart
Future<bool> isSupported()
```

Returns whether virtual backgrounds are supported on the current device.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `virtualBackgroundHelper.addItem`

```dart
Future<void> addItem(String filePath)
```

Adds a virtual background image from a file path.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `virtualBackgroundHelper.getItemList`

```dart
Future<List<ZoomVirtualBackgroundItem>> getItemList()
```

Returns all available virtual background items.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `virtualBackgroundHelper.setItem`

```dart
Future<void> setItem(String imageName)
```

Applies a virtual background by image name.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `virtualBackgroundHelper.removeItem`

```dart
Future<void> removeItem(String imageName)
```

Removes a virtual background by image name.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `virtualBackgroundHelper.getSelectedItem`

```dart
Future<ZoomVirtualBackgroundItem?> getSelectedItem()
```

Returns the currently active virtual background, or `null` if none.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

### Host Controls

Host control methods are on the `userHelper` accessor. Requires host or manager role.

**Implementation note:** The existing Flutter wrapper (`flutter_zoom_videosdk`) does not
expose host control methods. Windows has `IZoomVideoSDKUserHelper` and macOS has
`ZMVideoSDKUserHelper`. Android/iOS native SDKs support host controls per the feature
matrix (reference section 2), but exact native API names are not documented in the
reference.

#### `userHelper.makeHost`

```dart
Future<void> makeHost(String userId)
```

Transfers host role to the specified user.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `userHelper.makeManager`

```dart
Future<void> makeManager(String userId)
```

Promotes the specified user to manager (co-host).

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `userHelper.revokeManager`

```dart
Future<void> revokeManager(String userId)
```

Revokes manager role from the specified user.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `userHelper.removeUser`

```dart
Future<void> removeUser(String userId)
```

Removes the specified user from the session.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

#### `userHelper.changeName`

```dart
Future<void> changeName(String name, String userId)
```

Changes the display name of the specified user.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

### Cleanup / Dispose

#### `dispose`

```dart
void dispose()
```

Releases SDK resources and closes all event stream controllers.
Must be called when the SDK is no longer needed.

| Android | iOS | Windows | macOS |
|---------|-----|---------|-------|
| ✅ | ✅ | ✅ | ✅ |

---

## 4. Event Streams

All events are emitted on the unified `Stream<ZoomEvent> events` stream.
Typed convenience getters filter the main stream.

| Stream getter | Type | Fires when | Android | iOS | Windows | macOS |
|---------------|------|------------|---------|-----|---------|-------|
| `onSessionJoin` | `SessionJoinedEvent` | Local user successfully joins session | ✅ | ✅ | ✅ | ✅ |
| `onSessionLeave` | `SessionLeftEvent` | Local user leaves or is removed from session | ✅ | ✅ | ✅ | ✅ |
| `onUserJoined` | `UserJoinedEvent` | One or more remote users join the session | ✅ | ✅ | ✅ | ✅ |
| `onUserLeft` | `UserLeftEvent` | One or more remote users leave the session | ✅ | ✅ | ✅ | ✅ |
| `onUserVideoStatusChanged` | `UserVideoStatusChangedEvent` | A user's video status changes (on/off) | ✅ | ✅ | ✅ | ✅ |
| `onUserAudioStatusChanged` | `UserAudioStatusChangedEvent` | A user's audio status changes (mute/unmute) | ✅ | ✅ | ✅ | ✅ |
| `onUserActiveAudioChanged` | `UserActiveAudioChangedEvent` | Active speaker list changes | ✅ | ✅ | ✅ | ✅ |
| `onChatMessageReceived` | `ChatMessageReceivedEvent` | A chat message is received | ✅ | ✅ | ✅ | ✅ |
| `onUserShareStatusChanged` | `UserShareStatusChangedEvent` | A user's screen share status changes | ✅ | ✅ | ✅ | ✅ |
| `onUserHostChanged` | `UserHostChangedEvent` | Host role is transferred | ✅ | ✅ | ✅ | ✅ |
| `onUserManagerChanged` | `UserManagerChangedEvent` | A user's manager (co-host) status changes | ✅ | ✅ | ✅ | ✅ |
| `onUserNameChanged` | `UserNameChangedEvent` | A user's display name changes | ✅ | ✅ | ✅ | ✅ |
| `onSessionNeedPassword` | `SessionNeedPasswordEvent` | Session requires a password to join | ✅ | ✅ | ✅ | ✅ |
| `onSessionPasswordWrong` | `SessionPasswordWrongEvent` | Provided session password is incorrect | ✅ | ✅ | ✅ | ✅ |
| `onError` | `ErrorEvent` | An SDK error occurs | ✅ | ✅ | ✅ | ✅ |

All events are supported on all 4 platforms. The native SDKs share the same delegate
pattern (`ZoomVideoSDKDelegate` / `IZoomVideoSDKDelegate` / `ZMVideoSDKDelegate`).

---

## 5. Platform Support Summary Table

| API method / event | Android | iOS | Windows | macOS |
|--------------------|---------|-----|---------|-------|
| **Initialization** | | | | |
| `init(config)` | ✅ | ✅ | ✅ | ✅ |
| `dispose()` | ✅ | ✅ | ✅ | ✅ |
| **Session** | | | | |
| `joinSession(config)` | ✅ | ✅ | ✅ | ✅ |
| `leaveSession()` | ✅ | ✅ | ✅ | ✅ |
| `getSessionInfo()` | ✅ | ✅ | ✅ | ✅ |
| `getMyself()` | ✅ | ✅ | ✅ | ✅ |
| `getAllUsers()` | ✅ | ✅ | ✅ | ✅ |
| `getRemoteUsers()` | ✅ | ✅ | ✅ | ✅ |
| **Audio** | | | | |
| `audioHelper.startAudio()` | ✅ | ✅ | ✅ | ✅ |
| `audioHelper.stopAudio()` | ✅ | ✅ | ✅ | ✅ |
| `audioHelper.muteAudio(userId)` | ✅ | ✅ | ✅ | ✅ |
| `audioHelper.unmuteAudio(userId)` | ✅ | ✅ | ✅ | ✅ |
| `audioHelper.enableMicOriginalInput(bool)` | ✅ | ✅ | ✅ | ✅ |
| `audioHelper.setNoiseSuppression(level)` | ✅ | ✅ | ✅ | ✅ |
| `audioHelper.getAudioDeviceList()` | ⚠️ Auto-routes | ⚠️ Limited | ✅ | ✅ |
| `audioHelper.selectAudioDevice(deviceId)` | ⚠️ Auto-routes | ⚠️ Limited | ✅ | ✅ |
| **Video** | | | | |
| `videoHelper.startVideo()` | ✅ | ✅ | ✅ | ✅ |
| `videoHelper.stopVideo()` | ✅ | ✅ | ✅ | ✅ |
| `videoHelper.switchCamera()` | ✅ | ✅ | ✅ | ✅ |
| `videoHelper.getCameraList()` | ❌ | ❌ | ✅ | ✅ |
| `videoHelper.selectCamera(deviceId)` | ❌ | ❌ | ✅ | ✅ |
| `videoHelper.setVideoQualityPreference(mode, ...)` | ✅ | ✅ | ✅ | ✅ |
| `ZoomVideoView(userId, kind)` widget | ❌ | ❌ | ✅ | ✅ |
| **Screen Share** | | | | |
| `shareHelper.startShareScreen({monitorId, option})` | ✅ | ✅ | ✅ | ✅ |
| `shareHelper.startShareView(windowId, {option})` | ❌ | ❌ | ✅ | ✅ |
| `shareHelper.getShareSourceList()` | ❌ | ❌ | ✅ | ✅ |
| `shareHelper.stopShare()` | ✅ | ✅ | ✅ | ✅ |
| `shareHelper.enableShareDeviceAudio(bool)` | ❌ | ❌ | ✅ | ✅ |
| `shareHelper.enableOptimizeForSharedVideo(bool)` | ❌ | ❌ | ✅ | ✅ |
| **Chat** | | | | |
| `chatHelper.sendChatToAll(msg)` | ✅ | ✅ | ✅ | ✅ |
| `chatHelper.sendChatToUser(userId, msg)` | ✅ | ✅ | ✅ | ✅ |
| `chatHelper.isChatDisabled()` | ✅ | ✅ | ✅ | ✅ |
| `chatHelper.isPrivateChatDisabled()` | ✅ | ✅ | ✅ | ✅ |
| **Cloud Recording** | | | | |
| `recordingHelper.canStartRecording()` | ❌ | ❌ | ✅ | ✅ |
| `recordingHelper.startCloudRecording()` | ✅ | ✅ | ✅ | ✅ |
| `recordingHelper.stopCloudRecording()` | ✅ | ✅ | ✅ | ✅ |
| **Virtual Background** | | | | |
| `virtualBackgroundHelper.isSupported()` | ✅ | ✅ | ✅ | ✅ |
| `virtualBackgroundHelper.addItem(path)` | ✅ | ✅ | ✅ | ✅ |
| `virtualBackgroundHelper.getItemList()` | ✅ | ✅ | ✅ | ✅ |
| `virtualBackgroundHelper.setItem(name)` | ✅ | ✅ | ✅ | ✅ |
| `virtualBackgroundHelper.removeItem(name)` | ✅ | ✅ | ✅ | ✅ |
| `virtualBackgroundHelper.getSelectedItem()` | ✅ | ✅ | ✅ | ✅ |
| **Host Controls** | | | | |
| `userHelper.makeHost(userId)` | ✅ | ✅ | ✅ | ✅ |
| `userHelper.makeManager(userId)` | ✅ | ✅ | ✅ | ✅ |
| `userHelper.revokeManager(userId)` | ✅ | ✅ | ✅ | ✅ |
| `userHelper.removeUser(userId)` | ✅ | ✅ | ✅ | ✅ |
| `userHelper.changeName(name, userId)` | ✅ | ✅ | ✅ | ✅ |
| **Events** | | | | |
| `onSessionJoin` | ✅ | ✅ | ✅ | ✅ |
| `onSessionLeave` | ✅ | ✅ | ✅ | ✅ |
| `onUserJoined` | ✅ | ✅ | ✅ | ✅ |
| `onUserLeft` | ✅ | ✅ | ✅ | ✅ |
| `onUserVideoStatusChanged` | ✅ | ✅ | ✅ | ✅ |
| `onUserAudioStatusChanged` | ✅ | ✅ | ✅ | ✅ |
| `onUserActiveAudioChanged` | ✅ | ✅ | ✅ | ✅ |
| `onChatMessageReceived` | ✅ | ✅ | ✅ | ✅ |
| `onUserShareStatusChanged` | ✅ | ✅ | ✅ | ✅ |
| `onUserHostChanged` | ✅ | ✅ | ✅ | ✅ |
| `onUserManagerChanged` | ✅ | ✅ | ✅ | ✅ |
| `onUserNameChanged` | ✅ | ✅ | ✅ | ✅ |
| `onSessionNeedPassword` | ✅ | ✅ | ✅ | ✅ |
| `onSessionPasswordWrong` | ✅ | ✅ | ✅ | ✅ |
| `onError` | ✅ | ✅ | ✅ | ✅ |

**Legend:** ✅ Full support — ⚠️ Partial (see note) — ❌ Not supported (throws `UnimplementedError`)

### Partial Support Notes

| Entry | Note |
|-------|------|
| `audioHelper.getAudioDeviceList()` on Android | OS auto-routes audio; list may be empty or not meaningful |
| `audioHelper.getAudioDeviceList()` on iOS | Limited device control; only some devices exposed |
| `audioHelper.selectAudioDevice()` on Android | OS auto-routes; selection may have no effect |
| `audioHelper.selectAudioDevice()` on iOS | Limited device control |

---

## 6. What Throws `UnimplementedError`

Methods that are **structurally unsupported** on certain platforms perform a runtime
platform check and throw `UnimplementedError` before reaching native code.

| Method | Throws on |
|--------|-----------|
| `videoHelper.getCameraList()` | Android, iOS |
| `videoHelper.selectCamera(deviceId)` | Android, iOS |
| `shareHelper.startShareView(windowId)` | Android, iOS |
| `shareHelper.getShareSourceList()` | Android, iOS |
| `shareHelper.enableShareDeviceAudio(enable)` | Android, iOS |
| `shareHelper.enableOptimizeForSharedVideo(enable)` | Android, iOS |
| `recordingHelper.canStartRecording()` | Android, iOS |

Each throws `UnimplementedError('<method>() is not supported on <platform>. See docs/DART_API_DESIGN.md for platform support details.')`.
