# Zoom Video SDK Reference

> Generated: 2026-04-07
> Sources: [Zoom Developer Docs](https://developers.zoom.us/docs/video-sdk/), [pub.dev](https://pub.dev/packages/flutter_zoom_videosdk), [Zoom Changelog](https://developers.zoom.us/changelog/)

---

## 1. SDK Versions

| Platform | Latest Version | Release Date |
|----------|---------------|--------------|
| Android | 2.5.5 | 2026-03-26 |
| iOS | 2.5.5 | 2026-03-16 |
| macOS | 2.5.5 | 2026-03-26 |
| Windows | 2.5.6 | 2026-04-06 |
| Web (JS) | 2.3.15 | 2026-03-08 |
| Flutter (wrapper) | 2.4.12 | 2026-02-12 |

**Note:** The Flutter package (`flutter_zoom_videosdk`) is an official Zoom wrapper around the native Android and iOS SDKs only. It does **not** include Web, Windows, or macOS support.

---

## 2. Platform Feature Matrix

| Feature | Android | iOS | Web | Windows | macOS |
|---------|---------|-----|-----|---------|-------|
| Session join / leave | ✅ | ✅ | ✅ | ✅ | ✅ |
| Audio (mute/unmute self) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Video (start/stop local) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Video rendering (remote) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Screen share (send) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Screen share (receive/view) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Chat (send/receive) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Participants list | ✅ | ✅ | ✅ | ✅ | ✅ |
| Cloud recording | ✅ | ✅ | ✅ | ✅ | ✅ |
| Virtual background | ✅ | ✅ | ⚠️ Partial | ✅ | ✅ |
| Host controls (mute/remove) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Event/callback system | ✅ Delegate | ✅ Delegate | ✅ EventEmitter | ✅ Delegate | ✅ Delegate |
| Camera switching | ✅ | ✅ | ✅ | ✅ | ✅ |
| Audio device selection | ✅ | ⚠️ Limited | ✅ | ✅ | ✅ |
| Noise suppression config | ✅ | ✅ | ❓ Unknown | ✅ | ✅ |
| Raw video/audio access | ✅ | ✅ | ❌ | ✅ | ✅ |
| Multi-camera support | ✅ | ✅ | ❌ | ✅ | ✅ |
| Simultaneous screen shares | ❓ Unknown | ❓ Unknown | ✅ | ✅ | ✅ |

**Web virtual background note:** Requires WebAssembly + SharedArrayBuffer support. Not available on all browsers/devices.

---

## 3. Per-Platform Integration Method

### 3.1 Android

| Item | Value |
|------|-------|
| Distribution | Bundled in Zoom SDK download (AAR/Maven via Zoom Marketplace) |
| Min SDK | `minSdkVersion 26` (Android 8.0) |
| Target SDK | `targetSdkVersion 35` |
| NDK | 27+ |
| Architectures | `armeabi-v7a`, `arm64-v8a` (x86/x86_64 dropped after v5.17.10) |

**Required permissions** (`AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<!-- Android 14+ foreground service types -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_PHONE_CALL" />
```

**Key classes:** `ZoomVideoSDK`, `ZoomVideoSDKInitParams`, `ZoomVideoSDKSessionContext`, `ZoomVideoSDKDelegate`

### 3.2 iOS

| Item | Value |
|------|-------|
| Distribution | Zoom SDK download (framework from Zoom Marketplace) |
| Min iOS | 15.0 |
| Architectures | 64-bit only (no x86 simulator since v2.5.0) |
| Xcode | Latest recommended |

**Required permissions** (`Info.plist`):
- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`
- Apple privacy manifest and code signatures required

**Screen sharing** requires App Group ID configuration (`appGroupId`) and a Broadcast Upload Extension target.

**Key classes:** `ZoomVideoSDK`, `ZoomVideoSDKInitParams`, `ZoomVideoSDKSessionContext`, `ZoomVideoSDKDelegate`

### 3.3 Web (JavaScript)

| Item | Value |
|------|-------|
| npm package | `@zoom/videosdk` |
| CDN | `https://source.zoom.us/videosdk/zoom-video-{version}.min.js` |
| Latest version | 2.3.15 |
| Install | `npm install @zoom/videosdk --save` |
| Import | `import ZoomVideo from '@zoom/videosdk'` |
| CDN global | `window.WebVideoSDK.default` |

**Requirements:**
- UTF-8 charset meta tag required
- Browser: Chrome 89+, Firefox 78+, Safari 14+, Edge 89+ (recommended: Chrome latest)
- One session per browser tab
- Up to 5,000 users per session
- Desktop: up to 25 simultaneous videos; Mobile: up to 9
- Max video quality: 720p

**Key objects:** `ZoomVideo` (static factory), `client` (session), `stream` (MediaStream helper), `chat` (ChatClient), `cloudRecording` (RecordingClient)

### 3.4 Windows

| Item | Value |
|------|-------|
| Distribution | Direct download from Zoom Marketplace (ZIP with DLLs/libs) |
| Min OS | Windows 10 |
| IDE | Visual Studio 2019+ with "Desktop development with C++" workload |
| Architectures | x86, x64 |

**Key C++ interfaces:**
- `IZoomVideoSDK` — main SDK singleton
- `IZoomVideoSDKSession` — active session
- `IZoomVideoSDKUser` — participant
- `IZoomVideoSDKDelegate` — event callbacks
- `IZoomVideoSDKVideoHelper` — video control
- `IZoomVideoSDKAudioHelper` — audio control
- `IZoomVideoSDKShareHelper` — screen share
- `IZoomVideoSDKChatHelper` — chat
- `IZoomVideoSDKRecordingHelper` — cloud recording
- `IZoomVideoSDKUserHelper` — host controls
- `IZoomVideoSDKRawDataPipe` / `IZoomVideoSDKRawDataPipeDelegate` — raw video frames (YUV I420)

### 3.5 macOS

| Item | Value |
|------|-------|
| Distribution | Direct download from Zoom Marketplace (framework) |
| Min OS | macOS 10.15 (Catalina) |
| Xcode | 16.1+ |
| Note | For macOS 26 / Xcode 26+, may need to remove `-ld_classic` from linker flags |

**Required entitlements:**
- `com.apple.security.device.camera`
- `com.apple.security.device.audio-input`
- Network (outgoing connections)
- App Sandbox entitlements as needed

**Key classes (Objective-C / Swift):**
- `ZMVideoSDK` — main SDK singleton (`ZMVideoSDK.shared()`)
- `ZMVideoSDKSessionContext` — session config
- `ZMVideoSDKSession` — active session
- `ZMVideoSDKUser` — participant
- `ZMVideoSDKDelegate` — protocol for event callbacks
- `ZMVideoSDKVideoHelper` — video control
- `ZMVideoSDKAudioHelper` — audio control
- `ZMVideoSDKShareHelper` — screen share
- `ZMVideoSDKChatHelper` — chat
- `ZMVideoSDKRecordingHelper` — cloud recording
- `ZMVideoSDKUserHelper` — host controls

### 3.6 Flutter (Existing Wrapper)

| Item | Value |
|------|-------|
| pub.dev package | `flutter_zoom_videosdk` |
| Version | 2.4.12 |
| Platforms | Android, iOS only |
| Dependencies | `flutter_hooks ^0.20.3`, `plugin_platform_interface ^2.1.6` |
| Publisher | zoom.us (verified) |
| License | Proprietary (Zoom Video SDK Terms of Use) |

**pubspec.yaml:**
```yaml
dependencies:
  flutter_zoom_videosdk: ^1.12.10
```

> Note: The pub.dev listing shows 2.4.12 but the get-started guide references `^1.12.10`. The native SDK files (Android/iOS) are **not included** in the Flutter wrapper and must be downloaded separately from the Zoom Marketplace.

---

## 4. Core API Surface

### 4.1 Session Management

#### Flutter (Dart)
```dart
import 'package:flutter_zoom_videosdk/native/zoom_videosdk.dart';

var zoom = ZoomVideoSdk();

// Initialize
zoom.initSdk(InitConfig(domain: "zoom.us", enableLog: true));

// Join
JoinSessionConfig config = JoinSessionConfig(
  sessionName: "name",       // max 150 chars
  userName: "user",          // max 200 chars
  token: "JWT",
  sessionPassword: "pass",   // optional, max 10 chars
  audioOption: SDKAudioOptions(connect: true, mute: true),
  videoOption: SDKVideoOptions(localVideoOn: true),
);
await zoom.joinSession(config);

// Leave — method not documented in Flutter wrapper; likely zoom.leaveSession()
```

**Events (Flutter):**
```dart
var eventListener = ZoomVideoSdkEventListener();
eventListener.addEventListener();
EventEmitter emitter = eventListener.eventEmitter;

eventListener.addListener(EventType.onSessionJoin, (data) async { ... });
eventListener.addListener(EventType.onSessionLeave, (data) async { ... });
eventListener.addListener(EventType.onUserJoin, (data) async { ... });
eventListener.addListener(EventType.onUserLeave, (data) async { ... });
eventListener.addListener(EventType.onError, (data) async { ... });
```

#### Web (JavaScript)
```javascript
const client = ZoomVideo.createClient();
await client.init('en-US', 'Global', { patchJsMedia: true });
await client.join(sessionName, jwt, userName, passcode);
const stream = client.getMediaStream();

client.leave();       // leave
client.leave(true);   // end session (host only)
ZoomVideo.destroyClient();
```

#### Windows (C++)
```cpp
IZoomVideoSDKSession* pSession = m_pVideoSDK->joinSession(sessionContext);
m_pVideoSDK->leaveSession(false);  // false = leave, true = end
```

#### macOS (Swift)
```swift
let ctx = ZMVideoSDKSessionContext()
ctx.token = jwt; ctx.sessionName = name; ctx.userName = user
let session = ZMVideoSDK.shared()?.joinSession(ctx)
ZMVideoSDK.shared()?.leaveSession(false)
```

### 4.2 Audio

| Operation | Flutter | Web | Windows | macOS |
|-----------|---------|-----|---------|-------|
| Start audio | `zoom.audioHelper.startAudio()` | `stream.startAudio()` | `pAudioHelper->startAudio()` | `audioHelper.startAudio()` |
| Stop audio | `zoom.audioHelper.stopAudio()` | `stream.stopAudio()` | `pAudioHelper->stopAudio()` | `audioHelper.stopAudio()` |
| Mute | `zoom.audioHelper.muteAudio(userId)` | `stream.muteAudio()` | `pAudioHelper->muteAudio(pUser)` | `audioHelper.muteAudio(user)` |
| Unmute | `zoom.audioHelper.unmuteAudio(userId)` | `stream.unmuteAudio()` | `pAudioHelper->unMuteAudio(pUser)` | `audioHelper.unMuteAudio(user)` |
| Original input | `zoom.audioSettingHelper.enableMicOriginalInput(bool)` | N/A | `audioSettingHelper->enableMicOriginalInput(bool)` | `audioSettingHelper.enableMicOriginalInput(bool)` |

**Audio status (Flutter):**
```dart
user.audioStatus.isMuted();
user.audioStatus.isTalking();
user.audioStatus.getAudioType();
```

**Web audio events:** `auto-play-audio-failed`, `host-ask-unmute-audio`, `active-speaker`

**Native callbacks:** `onUserAudioStatusChanged`, `onUserActiveAudioChanged`

### 4.3 Video

| Operation | Flutter | Web | Windows | macOS |
|-----------|---------|-----|---------|-------|
| Start video | (via VideoView widget) | `stream.startVideo()` | `pVideoHelper->startVideo()` | `videoHelper.startVideo()` |
| Stop video | (via VideoView widget) | `stream.stopVideo()` | `pVideoHelper->stopVideo()` | `videoHelper.stopVideo()` |
| Switch camera | `multiCameraIndex` param | `stream.switchCamera(deviceId)` | `pVideoHelper->switchCamera()` | `videoHelper.switchCamera()` |
| Camera list | N/A | `stream.getCameraList()` | `pVideoHelper->getCameraList()` | `videoHelper.getCameraList()` |

**Flutter video rendering:**
```dart
// Uses platform views (AndroidView / UiKitView)
VideoView(
  user: user,
  sharing: false,
  preview: false,
  focused: true,
  hasMultiCamera: false,
  multiCameraIndex: "0",
  videoAspect: "PanAndScan",
  fullScreen: false,
)
```

**Web video rendering:**
```javascript
const element = await stream.attachVideo(userId, resolution);
document.querySelector('container').appendChild(element);
// Uses <video-player-container> / <video-player> custom elements
await stream.detachVideo(userId);
```

**Native (Windows/macOS) video rendering:** Raw data pipeline
- Subscribe: `user.getVideoPipe().subscribe(resolution, delegate)`
- Receive: `onRawDataFrameReceived(YUVRawDataI420* data)` — provides Y/U/V buffers, width, height, rotation
- Unsubscribe: `user.getVideoPipe().unSubscribe(delegate)`

### 4.4 Screen Sharing

| Operation | Flutter | Web | Windows | macOS |
|-----------|---------|-----|---------|-------|
| Start share | `zoom.shareHelper.startShareScreen()` | `stream.startShareScreen(element)` | `pShareHelper->startShareScreen(monitorId)` | `shareHelper.startShareScreen(displayId, option)` |
| Share window | N/A (mobile) | N/A | `pShareHelper->startShareView(hWnd)` | `shareHelper.startShareView(windowId, option)` |
| Stop share | `zoom.shareHelper.stopShare()` | `stream.stopShareScreen()` | `pShareHelper->stopShare()` | `shareHelper.stopShare()` |
| Share w/ audio | N/A | N/A | `pShareHelper->enableShareDeviceAudio(true)` | `shareHelper.enableShareDeviceAudio(true)` |

**Web receive share:**
```javascript
client.on('active-share-change', async (payload) => {
  const element = await stream.attachShareView(payload.userId);
  container.appendChild(element);
});
```

**Native receive share:** Subscribe to `user.getSharePipe()` — same raw data pipeline as video.

**Flutter receive share:** Set `sharing: true` on `VideoView` widget.

### 4.5 Chat

| Operation | Flutter | Web | Windows | macOS |
|-----------|---------|-----|---------|-------|
| Send to all | `chatHelper.sendChatToAll(msg)` | `chat.sendToAll(msg)` | `pChatHelper->sendChatToAll(msg)` | `chatHelper.sendChatToAll(msg)` |
| Send to user | `chatHelper.sendChatToUser(userId, msg)` | `chat.send(msg, userId)` | `pChatHelper->sendChatToUser(pUser, msg)` | `chatHelper.sendChat(to: user, content: msg)` |
| Chat disabled? | `chatHelper.isChatDisabled` | N/A | `pChatHelper->isChatDisabled()` | `chatHelper.isChatDisabled()` |
| Private disabled? | `chatHelper.isPrivateChatDisabled()` | N/A | `pChatHelper->isPrivateChatDisabled()` | `chatHelper.isPrivateChatDisabled()` |
| History | N/A | `chat.getHistory()` | N/A | N/A |

**Message limit:** 10,000 bytes binary; recommended 1,000 characters.

**Receive event:**
- Flutter: `EventType.onChatNewMessageNotify` → `ZoomVideoSdkChatMessage`
- Web: `client.on('chat-on-message', callback)` → `{ message, sender, receiver }`
- Windows: `onChatNewMessageNotify(pChatHelper, messageItem)` → `IZoomVideoSDKChatMessage`
- macOS: `onChatNewMessageNotify(_:message:)` → `ZMVideoSDKChatMessage`

**Message properties:** `content`, `sendUser`, `receiverUser`, `isChatToAll`, `isSelfSend`, `timeStamp`

### 4.6 Cloud Recording

| Operation | Flutter | Web | Windows | macOS |
|-----------|---------|-----|---------|-------|
| Helper | `zoom.recordingHelper` | `client.getRecordingClient()` | `m_pVideoSDK->getRecordingHelper()` | `ZMVideoSDK.shared().getRecordingHelper()` |
| Can record? | N/A | N/A | `canStartRecording()` | `canStartRecording()` |
| Start | `recordingHelper.startCloudRecording()` | `cloudRecording.startCloudRecording()` | `pRecordHelper->startCloudRecording()` | `recordingHelper.startCloudRecording()` |
| Stop | `recordingHelper.stopCloudRecording()` | `cloudRecording.stopCloudRecording()` | `pRecordHelper->stopCloudRecording()` | `recordingHelper.stopCloudRecording()` |

**Prerequisites:** Video SDK account + Cloud Recording Storage Plan. JWT must set `cloud_recording_option: 1`.

**Transcript/summary options** (JWT `cloud_recording_transcript_option`):
- `0` — none (default)
- `1` — transcript only
- `2` — transcript + summary

**Max recording resolution:** 720p (Web), 1080p (macOS), unknown for others.

**REST API alternative:** `PATCH https://api.zoom.us/v2/videosdk/sessions/{sessionId}/events` with `{"method": "recording.start"}` or `{"method": "recording.stop"}`

### 4.7 Virtual Background

| Operation | Flutter | Web | Windows | macOS |
|-----------|---------|-----|---------|-------|
| Supported? | `isSupportVirtualBackground()` | ⚠️ Requires WASM+SAB | N/A (assumed yes) | N/A (assumed yes) |
| Add item | `addVirtualBackgroundItem(filePath)` | N/A | `addVirtualBackgroundItem(path, &item)` | `addVirtualBackgroundItem(path, &item)` |
| List items | `getVirtualBackgroundItemList()` | N/A | `getVirtualBackgroundItemList()` | `getVirtualBackgroundItemList()` |
| Set/apply | `setVirtualBackgroundItem(imageName)` | N/A | `setVirtualBackgroundItem(item)` | `setVirtualBackgroundItem(item)` |
| Remove | `removeVirtualBackgroundItem(imageName)` | N/A | `removeVirtualBackgroundItem(item)` | `removeVirtualBackgroundItem(item)` |
| Get selected | `getSelectedVirtualBackgroundItem()` | N/A | `getSelectedVirtualBackgroundItem()` | `getSelectedVirtualBackgroundItem()` |

**Flutter helper:** `ZoomVideoSdkVirtualBackgroundHelper`
**Windows:** Methods on `IZoomVideoSDKVideoHelper`
**macOS:** Methods on `ZMVideoSDKVideoHelper`
**Web:** Virtual background API details were not accessible (404); likely uses a separate module or requires additional configuration.

### 4.8 Host Controls / User Management

| Operation | Flutter | Web | Windows | macOS |
|-----------|---------|-----|---------|-------|
| Make host | N/A | `client.makeHost(userId)` | `pUserHelper->makeHost(pUser)` | `userHelper.makeHost(user)` |
| Make manager | N/A | `client.makeManager(userId)` | `pUserHelper->makeManager(pUser)` | `userHelper.makeManager(user)` |
| Revoke manager | N/A | `client.revokeManager(userId)` | `pUserHelper->revokeManager(pUser)` | `userHelper.revokeManager(user)` |
| Remove user | N/A | `client.removeUser(userId)` | `pUserHelper->removeUser(pUser)` | `userHelper.remove(user)` |
| Change name | N/A | `client.changeName(name, userId)` | `pUserHelper->changeName(name, pUser)` | `userHelper.changeName(name, user: user)` |
| Get myself | N/A | `client.getCurrentUserInfo()` | `sessionInfo->getMyself()` | `sessionInfo.getMySelf()` |
| Get all users | N/A | `client.getAllUser()` | `sessionInfo->getAllUsers()` | N/A |
| Get remote users | N/A | N/A | `session->getRemoteUsers()` | `sessionInfo.getRemoteUsers()` |

**Roles:**
- **Host** (JWT `role: 1`): Full control — mute others, remove, transfer host, end session, lock screen sharing
- **Manager** (co-host): Remove participants, change names, mute audio, lock screen sharing
- **Participant** (JWT `role: 0`): View own and others' info

### 4.9 Event / Callback System

| Platform | Mechanism | Key Events |
|----------|-----------|------------|
| Flutter | `ZoomVideoSdkEventListener` + `EventEmitter` (events_emitter package) | `onSessionJoin`, `onSessionLeave`, `onUserJoin`, `onUserLeave`, `onUserVideoStatusChanged`, `onUserAudioStatusChanged`, `onChatNewMessageNotify`, `onError` |
| Web | `client.on(eventName, callback)` | `peer-video-state-change`, `active-speaker`, `chat-on-message`, `active-share-change`, `peer-share-state-change`, `passively-stop-share`, `auto-play-audio-failed`, `host-ask-unmute-audio` |
| Windows | `IZoomVideoSDKDelegate` interface (C++ virtual methods) | `onSessionJoin`, `onSessionLeave`, `onError`, `onUserJoin`, `onUserLeave`, `onUserVideoStatusChanged`, `onUserAudioStatusChanged`, `onUserShareStatusChanged`, `onChatNewMessageNotify`, `onSessionNeedPassword`, `onSessionPasswordWrong` |
| macOS | `ZMVideoSDKDelegate` protocol (Obj-C/Swift) | Same as Windows + `onUserHostChanged`, `onUserNameChanged`, `onUserManagerChanged` |

---

## 5. Flutter Plugin Architecture Notes

### 5.1 Unified Dart API — Feasible Features

These features have consistent APIs across all target platforms and can be exposed with a single Dart interface:

| Feature | Dart API | Notes |
|---------|----------|-------|
| Init SDK | `ZoomVideoSdk.init(config)` | `domain`, `enableLog` common to all |
| Join session | `ZoomVideoSdk.joinSession(config)` | `sessionName`, `userName`, `token`, `password`, audio/video options |
| Leave session | `ZoomVideoSdk.leaveSession(end: bool)` | `end` = true for host to end session |
| Start/stop audio | `audioHelper.startAudio()` / `.stopAudio()` | |
| Mute/unmute | `audioHelper.mute(userId)` / `.unmute(userId)` | Web uses self-only; native uses any user |
| Start/stop video | `videoHelper.startVideo()` / `.stopVideo()` | |
| Send chat | `chatHelper.sendToAll(msg)` / `.sendToUser(userId, msg)` | |
| Cloud recording | `recordingHelper.start()` / `.stop()` | Requires cloud recording plan |
| Virtual background | `virtualBgHelper.add/set/remove/list()` | Web support limited |
| Host controls | `userHelper.makeHost/makeManager/remove(userId)` | |

### 5.2 Platform-Specific Features

| Feature | Platform | Notes |
|---------|----------|-------|
| Video rendering | All | Android/iOS use PlatformView; Web uses custom HTML elements; Windows/macOS use raw YUV data pipeline — needs per-platform render strategy |
| Screen share (send) | Desktop only | Mobile requires OS-level Broadcast Extension (iOS) or MediaProjection (Android) with separate setup |
| Screen share (window) | Windows, macOS | `startShareView(windowId)` — desktop only |
| Share device audio | Windows, macOS | Not available on mobile or web |
| Raw video/audio data | Android, iOS, Windows, macOS | Not available on Web |
| Audio device selection | Web, Windows, macOS | iOS has limited control; Android auto-routes |
| Noise suppression levels | Windows, macOS | `Auto`, `Low`, `Medium`, `High` |
| `appGroupId` | iOS only | Required for screen sharing |
| Foreground service types | Android 14+ only | Required for background audio/screen share |

### 5.3 Recommended Dart API Design

```dart
// Entry point
class ZoomVideoSdk {
  Future<void> init(ZoomVideoSdkConfig config);
  Future<ZoomVideoSdkSession> joinSession(JoinSessionConfig config);
  Future<void> leaveSession({bool endSession = false});

  ZoomVideoSdkAudioHelper get audioHelper;
  ZoomVideoSdkVideoHelper get videoHelper;
  ZoomVideoSdkShareHelper get shareHelper;
  ZoomVideoSdkChatHelper get chatHelper;
  ZoomVideoSdkRecordingHelper get recordingHelper;
  ZoomVideoSdkVirtualBackgroundHelper get virtualBackgroundHelper;
  ZoomVideoSdkUserHelper get userHelper;

  // Event streams (preferred over callback listeners)
  Stream<SessionEvent> get onSessionJoin;
  Stream<SessionEvent> get onSessionLeave;
  Stream<UserEvent> get onUserJoin;
  Stream<UserEvent> get onUserLeave;
  Stream<VideoStatusEvent> get onUserVideoStatusChanged;
  Stream<AudioStatusEvent> get onUserAudioStatusChanged;
  Stream<ChatMessageEvent> get onChatMessageReceived;
  Stream<ShareStatusEvent> get onShareStatusChanged;
  Stream<ZoomError> get onError;
}

// Config objects
class ZoomVideoSdkConfig {
  final String domain; // "zoom.us"
  final bool enableLog;
  final String? appGroupId; // iOS only
}

class JoinSessionConfig {
  final String sessionName;
  final String userName;
  final String token; // JWT
  final String? sessionPassword;
  final AudioOptions? audioOptions;
  final VideoOptions? videoOptions;
  final int? sessionIdleTimeoutMins;
}

// User model
class ZoomVideoSdkUser {
  final String userId;
  final String userName;
  final bool isHost;
  final bool isManager;
  ZoomVideoSdkAudioStatus get audioStatus;
  ZoomVideoSdkVideoStatus get videoStatus;
}

// Video rendering — platform-specific widget
class ZoomVideoView extends StatelessWidget {
  final ZoomVideoSdkUser user;
  final bool isShareView;
  final ZoomVideoAspectMode aspectMode;
}
```

### 5.4 Platform Method Channel Strategy

| Platform | Channel Type | Implementation Language |
|----------|-------------|----------------------|
| Android | MethodChannel + PlatformView | Kotlin |
| iOS | MethodChannel + PlatformView | Swift |
| Web | dart:js_interop / package:web | Dart (JS interop wrapping @zoom/videosdk) |
| Windows | MethodChannel + Texture/PlatformView | C++ |
| macOS | MethodChannel + PlatformView | Swift |

**Federated plugin structure recommended:**
```
zoom_video_sdk_flutter/              # App-facing package
zoom_video_sdk_flutter_platform_interface/  # Platform interface
zoom_video_sdk_flutter_android/      # Android impl
zoom_video_sdk_flutter_ios/          # iOS impl
zoom_video_sdk_flutter_web/          # Web impl
zoom_video_sdk_flutter_windows/      # Windows impl
zoom_video_sdk_flutter_macos/        # macOS impl
```

### 5.5 Known Limitations & Gotchas

1. **Native SDK not bundled:** The Android/iOS native SDKs are downloaded separately from Zoom Marketplace and must be manually integrated. This will also apply to Windows and macOS SDKs.

2. **Web video rendering:** Uses custom HTML elements (`<video-player-container>`) rather than `<canvas>` — Flutter web will need `HtmlElementView` or similar.

3. **Windows raw video:** Provides YUV I420 frames via callback — Flutter Windows will need `Texture` widget with pixel buffer updates.

4. **macOS Xcode 26 compatibility:** May require removing `-ld_classic` linker flag.

5. **iOS screen sharing:** Requires a separate Broadcast Upload Extension target with matching `appGroupId`.

6. **Android 14+ foreground services:** Five new foreground service type permissions needed.

7. **Web session limit:** One session per browser tab.

8. **Chat message size:** 10,000 bytes max (all platforms).

9. **JWT security:** SDK keys/secrets must never be embedded in client code. JWT generation should be server-side.

10. **Existing Flutter wrapper (`flutter_zoom_videosdk`):** Uses `events_emitter` + `flutter_hooks` — a new plugin should use Dart `Stream`s instead for idiomatic Flutter/Riverpod integration.

---

## 6. Open Questions

1. **Exact native SDK download URLs / artifact names** — The docs reference "Zoom Marketplace" downloads but don't provide direct URLs or Maven/CocoaPods/NuGet coordinates. Need to verify if any platform SDK is available via a package manager or only as a manual download.

2. **Web virtual background API** — The `/virtual-background/` and `/virtual-bg/` pages returned 404. Need to verify the exact API surface for Web virtual backgrounds.

3. **Flutter wrapper `leaveSession` method** — Not documented on the get-started page. Need to verify the exact method name and signature.

4. **Host controls in Flutter wrapper** — The existing `flutter_zoom_videosdk` package doesn't document `makeHost`, `makeManager`, `removeUser` methods. Need to verify if they exist or are missing.

5. **Windows SDK distribution** — Is it available via NuGet, vcpkg, or only as a ZIP download? Documentation is unclear.

6. **macOS SDK distribution** — Is it available via CocoaPods or Swift Package Manager, or only as a direct framework download?

7. **Web noise suppression API** — Not found in documentation. May not be configurable on Web.

8. **Simultaneous screen shares** — Confirmed for Web (`simultaneousShareView`). Unclear for native Android/iOS.

9. **Android Gradle dependency string** — The docs don't show a Maven coordinate. Need to verify if the Android SDK is distributed via Maven Central or only bundled in the ZIP download.

10. **Flutter SDK version discrepancy** — pub.dev shows `2.4.12` but the get-started guide references `^1.12.10`. Need to clarify which is correct and whether the major version bump indicates a breaking API change.

11. **Recording max resolution** — Confirmed 720p for Web, 1080p for macOS. Unknown for Android, iOS, Windows.

12. **Web SDK recommended version** — Docs mention upgrading to 2.3.15+ for Chrome compatibility. Verify this is indeed the latest.
