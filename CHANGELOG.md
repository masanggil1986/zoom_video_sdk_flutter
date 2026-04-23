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
- Windows share capture is forced to `Filtering` mode and self-share pipe
  subscription is skipped to avoid SDK teardown crashes.
