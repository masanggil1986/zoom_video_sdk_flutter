# ZMVideoSDKShareHelper API Documentation

## Module Information

| Field | Value |
|-------|-------|
| **Module** | Share Helper (types and protocols in the same header) |
| **Platform** | macOS |
| **Language** | Objective-C |
| **Version** | 2.5.5 |
| **Header** | `ZMVideoSDKShareHelper.h` |
| **Related** | `ZMVideoSDKDef.h`, `ZMVideoSDKDelegate.h`, `ZMVideoSDKAnnotationHelper.h`, `ZMVideoSDKRemoteControlHelper.h`, `ZMVideoSDKWhiteboardHelper.h`, **[ZMVideoSDKVideoCanvas](./ZMVideoSDKVideoCanvas-API.md)** (share canvas via `ZMVideoSDKShareAction`) |

## JSON callback fields (`ZMVideoSDKShareHelper-API.json`)

zmVideoSDKDelegateCallbacks / zmVideoSDKDelegateCallbacksMayFollow: ZMVideoSDKDelegate (ZMVideoSDKDelegate.h). otherProtocolCallbacks: non-delegate protocols (ZMVideoSDKShareSource, ZMVideoSDKSharePreprocessor, ZMVideoSDKRawDataPipeDelegate). shareSettingBoolArgToEnum: maps BOOL argument to ZMVideoSDKShareSetting enum for onShareSettingChanged: (separate field from zmVideoSDKDelegateCallbacks).

Column semantics: see the paired `*-API.json` (`async`, `zmVideoSDKDelegateCallbacks`, `callbackFieldDoc`, and per-API notes).

## Overview

`ZMVideoSDKShareHelper` manages screen, window, application, and multi-monitor sharing, computer-audio-only share, second-camera share, external (custom) video/audio share, optional YUV preprocessing, annotation helpers, local playback of shared audio raw data, and whiteboard helper access. Obtain it with `[[ZMVideoSDK sharedVideoSDK] getShareHelper]` after a successful `initialize:`. Register `ZMVideoSDKDelegate` before starting share to observe status and failures.

## Lifecycle

### Prerequisites

1. **ZMVideoSDK** initialized successfully (`initialize:`).
2. User **in session** (`onSessionJoin` / `isInSession`) for starting/stopping share and most controls.
3. **ZMVideoSDKDelegate** registered for share-related callbacks.

### Session leave (`onSessionLeave`)

After leave, do not use the share helper, `ZMVideoSDKShareAction` instances, annotation helpers, or raw-data pipes from the previous session. Destroy annotation helpers before leave when possible.

### Host change (`onUserHostChanged:userHelper:user:`)

Host or co-host role may change. APIs **`lockShare:`** and **`enableMultiShare:`** require host/co-host privileges in typical sessions; non-authorized callers receive **`ZMVideoSDKErrors_NO_PERMISSION`**. Re-query **`isShareLocked`**, **`isMultiShareEnabled`**, and handle **`onShareSettingChanged:`** when policy updates. BOOL→`ZMVideoSDKShareSetting` and delegate columns: see **JSON callback fields** above.

## State machine (local user share-out)

| State | Meaning |
|-------|---------|
| **Idle** | Current user is not sending share (`isSharingOut` == NO). |
| **Sharing** | User is actively sharing (window/screen/app/camera/external/audio per type). |
| **Paused** | Share capture paused (`pauseShare`); resume with `resumeShare`. |

Transitions: start APIs (on success + delegate), `stopShare`, `pauseShare` / `resumeShare`, session leave, and host policy (e.g. disabling multi-share while multiple users share may stop shares). For start/stop/pause/resume, **`ZMVideoSDKErrors_Success` does not replace delegate confirmation**—treat `onUserShareStatusChanged` (and `onShareStopped` when preprocessing) as the source of truth for share status. Same idea for `lockShare:` / `enableMultiShare:` and `onShareSettingChanged:`.

## Types (summary)

- **ZMVideoSDKShareOption** — `isWithDeviceAudio`, `isOptimizeForSharedVideo`.
- **ZMVideoSDKSharePreprocessParam** — `type` (screen/view/process), `monitorID`, `windowID`, `processID`.
- **ZMVideoSDKShareAction** — per-share `shareSourceId`, `shareStatus`, `shareType`, pause reason, subscribe fail reason, annotation privilege; **`getShareCanvas`** returns **`ZMVideoSDKVideoCanvas`** for NSView rendering — see **[ZMVideoSDKVideoCanvas-API](./ZMVideoSDKVideoCanvas-API.md)**; also pipe, remote control.
- **ZMVideoSDKShareSetting** (see `ZMVideoSDKDef.h`) — `None`, `LockedShare`, `SingleShare`, `MultiShare`.

## APIs — Start share

| Method | Description |
|--------|-------------|
| `startShareView:shareOption:` | Share a window (`CGWindowID`). |
| `startShareApplication:shareOption:` | Share by application `pid_t`. |
| `startShareScreen:shareOption:` | Share one display (`CGDirectDisplayID`). |
| `startShareMultiScreen:shareOption:` | Share multiple displays (`NSArray` of `NSNumber`). |
| `startShareComputerAudio` | Computer audio only. |
| `startShare2ndCamera:` | Second camera; must differ from primary video camera. |
| `startSharingExternalSource:audioSource:isPlaying:` | Custom video + optional audio; `isPlaying` controls local playback of shared audio. |
| `startSharePureAudioSource:isPlaying:` | External audio-only share. |
| `startShareWithPreprocessing:sharePreprocessor:` | Share with preprocessing pipeline. |

**Deprecated:** `startSharingExternalSource:audioSource:`, `startSharePureAudioSource:` (no `isPlaying`), `subscribeMyShareCamera:`, `unSubscribeMyShareCamera` — use `startSharingExternalSource:audioSource:isPlaying:`, `startSharePureAudioSource:isPlaying:`, and **`ZMVideoSDKRawDataPipe`** subscribe/unSubscribe for second-camera raw data.

## APIs — Stop / pause

| Method | Description |
|--------|-------------|
| `stopShare` | Stops view/screen-related share; preprocessor receives `onShareStopped` when applicable. |
| `pauseShare` / `resumeShare` | Pause / resume capture. |

## APIs — Query

| Method | Description |
|--------|-------------|
| `isShareViewValid:` | Whether the window can be shared. |
| `isSharingOut` | Current user is sharing. |
| `isScreenSharingOut` | Current user is sharing screen. |
| `isOtherSharing` | Another participant is sharing. |
| `isShareLocked` | Share locked by host policy. |
| `isMultiShareEnabled` | Multi-share enabled. |
| `isShareDeviceAudioEnabled` | Reflects `enableShareDeviceAudio:`, not `startShareComputerAudio`. |
| `isOptimizeForSharedVideoEnabled` | Video optimization flag. |
| `isAnnotationFeatureSupport` | Annotation available. |
| `isViewerAnnotationDisabled` | Viewer annotation off (share owner query). |

## APIs — Host policy

| Method | Description |
|--------|-------------|
| `lockShare:` | Lock/unlock share. Header: host only; session layer may allow co-host. Success may fire `onShareSettingChanged:`. |
| `enableMultiShare:` | Enable/disable simultaneous share. **Warning:** disabling while two or more users are sharing stops all shares. |

### `onShareSettingChanged:` (when driven by these APIs)

| Call (success) | `setting` |
|----------------|-----------|
| `lockShare:YES` | `ZMVideoSDKShareSetting_LockedShare` |
| `lockShare:NO` | `ZMVideoSDKShareSetting_SingleShare` |
| `enableMultiShare:YES` | `ZMVideoSDKShareSetting_MultiShare` |
| `enableMultiShare:NO` | `ZMVideoSDKShareSetting_SingleShare` |

Policy may also change from host transfer or server sync; same callback applies.

## APIs — Share options during share

| Method | Description |
|--------|-------------|
| `enableShareDeviceAudio:` | Toggle computer sound during share. **Precondition:** user must be in an active screen/window-type share path (not valid when only sharing pure computer audio — expect `Wrong_Usage`). |
| `enableOptimizeForSharedVideo:` | Toggle frame-rate optimization for video-heavy content. **Precondition:** not while sharing pure computer audio only (`Wrong_Usage`). |

## APIs — Annotation

| Method | Description |
|--------|-------------|
| `disableViewerAnnotation:` | Share owner only. |
| `createAnnotationHelper:` | `nil` view = self-share. Returns `nil` if aspect is `ZMVideoSDKVideoAspect_Full_Filled`. |
| `destroyAnnotationHelper:` | Tear down helper. |
| `setAnnotationVanishingToolTime:vanishingTime:` | Own share; display 0–15000 ms; vanishing 1001–15000 ms. |
| `getAnnotationVanishingToolTime:vanishingTime:` | Own share; out params on Success. |

## APIs — Audio playback / whiteboard

| Method | Description |
|--------|-------------|
| `enablePlaySharingAudioRawdata:` | Local playback of shared audio raw stream. |
| `getWhiteboardHelper` | Whiteboard helper or `nil`. |

## Callbacks — `ZMVideoSDKDelegate` (share-related)

Invoked on the **main thread** unless your SDK documentation states otherwise.

| Callback | Purpose |
|----------|---------|
| `onUserShareStatusChanged:user:shareAction:` | Share start/pause/resume/stop for a user. |
| `onShareContentSizeChanged:user:shareAction:` | Content size (e.g. first frame). |
| `onShareContentChanged:user:shareAction:` | Share type change. |
| `onUnsharingWindowsChanged:shareHelper:user:shareAction:` | Excluded windows (`NSNumber` wrapping `CGWindowID`). |
| `onSharingActiveMonitorChanged:shareHelper:user:shareAction:` | Active monitors for share. |
| `onFailedToStartShare:user:` | Start share failed. |
| `onShareSettingChanged:` | Share policy / setting changed. |
| `onShareCanvasSubscribeFail:user:view:shareAction:` | Canvas subscribe failed. |
| `onSharedAudioRawDataReceived:` | Incoming shared audio raw data. **Thread:** not guaranteed main; dispatch to main for UI. |
| `onUserHostChanged:userHelper:user:` | Host change — refresh policy UI and eligibility. |

**Deprecated:** `onShareNetworkStatusChanged:isSendingShare:` — use `onUserNetworkStatusChanged:level:user:`.

Related: `onAnnotationPrivilegeChange:shareAction:`, remote control callbacks with `shareAction`, `onUserWhiteboardShareStatusChanged:whiteboardHelper:`.

## Callbacks — `ZMVideoSDKSharePreprocessor`

- `onCapturedRawDataReceived:sharePreprocessSender:` — process YUV and call `sendPreprocessedData:` on `sender` during the callback.
- `onShareStopped` — after `stopShare`; clean up preprocessing state.

## Callbacks — `ZMVideoSDKShareSource` / `ZMVideoSDKShareAudioSource`

- Video: `onShareSendStarted:`, `onShareSendStopped`.
- Audio: `onStartSendAudio:`, `onStopSendAudio`. Audio samples: even `dataLength`; rates 44100, 48000, 50000, 50400.

## Error handling

Check every **`ZMVideoSDKErrors`** return. Common codes include **`Success`**, **`Invalid_Parameter`**, **`Wrong_Usage`**, **`NO_PERMISSION`**, **`Dont_Support_Feature`**, **`Internal_Error`**, **`SessionService_Invalid`**, **`Session_Share_Conflict_With_Whiteboard`**, **`Load_Module_Error`**. Full set: **`ZMVideoSDKDef.h`**.

- Do not retry **`NO_PERMISSION`** or **`Dont_Support_Feature`** without fixing role or session type.
- After **`Wrong_Usage`**, fix preconditions (e.g. in session, correct share mode) before retry.

## Examples

### Window share with device audio

```objc
ZMVideoSDKShareHelper *sh = [[ZMVideoSDK sharedVideoSDK] getShareHelper];
ZMVideoSDKShareOption *opt = [[ZMVideoSDKShareOption alloc] init];
opt.isWithDeviceAudio = YES;
ZMVideoSDKErrors e = [sh startShareView:windowID shareOption:opt];
```

### Stop share

```objc
[sh stopShare];
```

## Examples

Structured snippets: this module's **`*-API.json`** → `examples` and `codeSnippets`.
