## 0.1.0

**Command channel**
- `cmdHelper.sendCommand(String receiverId, String content)` — sends a session-scoped
  command message to a specific user or broadcast (`receiverId: ''`).
- `commandReceived` event stream fires when a command arrives.
- Desktop only (`UnimplementedError` on Android/iOS per section 6).

**Cleanup**
- `cleanup()` — tears down the native SDK cleanly after `leaveSession`. Desktop only.

**Richer serialization**
- `ZoomUser` now carries `customUserId` (server-assigned opaque id).
- `ZoomChatMessage` now carries `messageId`.
- `ZoomVirtualBackgroundItem` now carries a `type` field (`image`/`blur`/`none`).
- `virtualBackgroundHelper.addItem()` now returns `ZoomVirtualBackgroundItem`
  (the newly created item, including its auto-assigned `imageName`).

**macOS camera TCC pre-trigger**
- `videoHelper.triggerCameraPermission()` — fires the macOS TCC camera-access dialog
  before the first `startVideo()`, avoiding a late-permission popup mid-session.

**Windows parity**
- Windows-side method-channel handlers wired for all new features
  (build-verify pending; functionality mirrors macOS implementation).

**Compat library**
- New `package:zoom_video_sdk_flutter/compat.dart` — a
  `flutter_zoom_videosdk`-compatible facade. tuit apps import a single path and
  dispatch to the official mobile package on Android/iOS and to this plugin's
  method channel on macOS/Windows. See section 7 of `docs/DART_API_DESIGN.md`.

---

## 0.0.1

Initial pre-release.

**Platforms**
- Android, iOS, macOS, Windows (64-bit).
- Tested against Zoom Video SDK 2.5.5 (macOS) and 2.5.7 (Windows).

**Core**
- Session lifecycle: `init`, `joinSession`, `leaveSession`, `getSessionInfo`,
  `getMyself`, `getAllUsers`, `getRemoteUsers`.
- Audio: start/stop, mute, noise suppression, original-mic input, device
  list/selection (desktop).
- Video: start/stop, `switchCamera`, `selectCamera` / `getCameraList`
  (desktop), `setVideoQualityPreference`.
- Screen share: `startShareScreen(monitorId:)`, `startShareView(windowId)`,
  `getShareSourceList`, `enableShareDeviceAudio`,
  `enableOptimizeForSharedVideo` (desktop).
- Chat, cloud recording, virtual background, host/user management.
- `ZoomVideoView` widget — platform view on macOS, Flutter `Texture` on
  Windows.
- Sealed `ZoomEvent` stream with typed convenience getters
  (`onSessionJoin`, `onUserJoined`, `onError`, …).

**Notes**
- Native Zoom Video SDK binaries are not redistributed — see the `Native SDK
  Setup` section in `README.md` for per-platform download and placement.
- iOS screen sharing requires `appGroupId` and a Broadcast Upload Extension.
- Windows share capture is forced to `Filtering` mode. Self-share rendering is
  skipped on both Windows and macOS — Windows to avoid an SDK teardown crash,
  macOS for UX consistency.
