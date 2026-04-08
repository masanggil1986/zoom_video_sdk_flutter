# ZMVideoSDKVideoHelper API Documentation

## Module Information
- **Module:** Video Helper
- **Platform:** macOS
- **Language:** Objective-C
- **Version:** 2.5.5
- **Header:** `ZMVideoSDKVideoHelper.h`

## JSON callback fields (`ZMVideoSDKVideoHelper-API.json`)

zmVideoSDKDelegateCallbacks / zmVideoSDKDelegateCallbacksMayFollow: ZMVideoSDKDelegate.h. otherProtocolCallbacks: listener protocols (e.g. ZMVideoSDKRawDataPipeDelegate). State transitions describe raw-data path in trigger text, supplements zm* with timing context only.

Column semantics: see the paired `*-API.json` (`async`, `zmVideoSDKDelegateCallbacks`, `callbackFieldDoc`, and per-API notes).

## Overview
Video helper: **meeting send path** (start/stop local video, multi-camera send, spotlight, etc.) and **camera control / PTZ** (`canControlCamera:`, `turnCamera*`, `zoomCamera*`) are **session-scoped** (`isInSession`); **preview and virtual background** (raw/NSView preview, add/remove/list/select VB) are available **after SDK init without joining a session**—no `isInSession` required for those flows. Also: video quality preference, aspect ratio, mirror (canvas), alpha-channel mode. Supporting types: `ZMVideoSDKVirtualBackgroundItem`, `ZMVideoSDKCameraDevice`, `ZMVideoSDKPreferenceSetting`. Obtain the helper via `[[ZMVideoSDK sharedVideoSDK] getVideoHelper]`. Raw preview frames use `ZMVideoSDKRawDataPipeDelegate`; see **ZMVideoSDKRawDataPipeDelegate-API** for callback lifetime and threading.

## Lifecycle

### Prerequisites
1. `[[ZMVideoSDK sharedVideoSDK] initialize:]` succeeded.
2. **In session only (`isInSession`):** sending camera video (`startVideo` / `stopVideo`), **ControlCamera** (`canControlCamera:` and all PTZ APIs: `turnCamera*` / `zoomCamera*`), multi-camera **send** paths, spotlight, and other meeting-send flows.
3. **Not in session:** You can use **camera preview** (`startVideoPreview:…`, `startVideoCanvasPreview:…`, matching `stop*`) and **virtual background** APIs (`add` / `remove` / `getVirtualBackgroundItemList` / `set` / `getSelected`) to preview and choose VB—**no session join required** (helper non-nil after init).
4. **Edge cases:** `rotateMyVideo:` when not in session still depends on an active preview pipeline (e.g. canvas preview). Camera list availability follows core. On `onSessionLeave`, stop preview and drop session assumptions; clean up listeners and avoid holding stale `ZMVideoSDKVirtualBackgroundItem` references if core invalidates them.

### Entry / exit
- **Available:** After init—preview + VB configuration without join; after join, full meeting video + spotlight paths as applicable.
- **Invalidate:** On `onSessionLeave`, stop preview (`stopVideoPreview:` / `stopVideoCanvasPreview:`), and avoid calling session-only APIs until rejoin.

## Type definitions

### ZMVideoSDKVirtualBackgroundItem
- `imageFilePath`, `imageName`, `type` (`ZMVideoSDKVirtualBackgroundDataType`), `canVirtualBackgroundBeDeleted` (readonly).
- Managed together with SDK VB list; use instances returned from `addVirtualBackgroundItem:imageItem:` or refreshed list behavior.

### ZMVideoSDKCameraDevice
- `deviceID`, `deviceName`, `isSelectedDevice`, `isSelectedAsMultiCamera`, `isRunningAsMultiCamera`.

### ZMVideoSDKPreferenceSetting
- `mode` (`ZMVideoSDKVideoPreferenceMode`): Balance, Quality, etc.; **Custom** uses `minimumFrameRate` / `maximumFrameRate` (0–30 per header; min &lt; max for custom; out-of-range uses SDK defaults).

## APIs (by category)

### Local video on/off
| Method | Returns | Notes |
|--------|---------|--------|
| `-startVideo` | `ZMVideoSDKErrors` | Start sending camera video. |
| `-stopVideo` | `ZMVideoSDKErrors` | Stop sending. |

### Orientation & camera selection
| Method | Returns | Notes |
|--------|---------|--------|
| `-rotateMyVideo:` | `BOOL` | In session: core rotation. **Not in session:** requires internal preview pipeline (canvas preview active); otherwise may return NO. |
| `-switchCamera` | `BOOL` | Next camera; refreshes canvas preview binding when applicable. |
| `-selectCamera:` | `BOOL` | **NO** if `cameraDeviceID` nil/empty. |
| `-getNumberOfCameras` | `unsigned int` | 0 if helper unavailable. |
| `-getCameraList` | `NSArray` or nil | nil if no devices or helper nil. |

### PTZ / ControlCamera (pan/tilt/zoom)
**Session:** **required** — `canControlCamera:` and all PTZ control APIs are **in-session only** (`isInSession`). Not for pre-join preview-only flows.

All require `range` in **[10, 100]**; otherwise **`ZMVideoSDKErrors_Invalid_Parameter`**. Optional `deviceID`: nil/empty = main camera.

| Method | Returns |
|--------|---------|
| `-canControlCamera:deviceID:` | `ZMVideoSDKErrors`; sets `*canControl`. **Only read `*canControl` after Success.** |
| `-turnCameraLeft:deviceID:` | `ZMVideoSDKErrors` |
| `-turnCameraRight:deviceID:` | `ZMVideoSDKErrors` |
| `-turnCameraUp:deviceID:` | `ZMVideoSDKErrors` |
| `-turnCameraDown:deviceID:` | `ZMVideoSDKErrors` |
| `-zoomCameraIn:deviceID:` | `ZMVideoSDKErrors` |
| `-zoomCameraOut:deviceID:` | `ZMVideoSDKErrors` |

### Video quality preference
| Method | Returns | Notes |
|--------|---------|--------|
| `-setVideoQualityPreference:` | `ZMVideoSDKErrors` | nil `preferenceSetting` → `Invalid_Parameter`. Custom mode passes min/max frame rate to core. |

### Multi-camera stream
| Method | Returns | Notes |
|--------|---------|--------|
| `-enableMultiStreamVideo:customDeviceName:` | `BOOL` | Empty `cameraDeviceID` → NO. |
| `-disableMultiStreamVideo:` | `BOOL` | |
| `-muteMultiStreamVideo:` / `-unmuteMultiStreamVideo:` | `BOOL` | |
| `-getDeviceIDByMyPipe:` | `NSString` or nil | Maps local multi-camera raw pipe to device ID; nil if pipe unknown. |

### Preview — raw data
**Session:** **not required** for preview start/stop—use after init (e.g. pre-join settings UI).

| Method | Returns | Notes |
|--------|---------|--------|
| `-startVideoPreview:deviceID:resolution:` | `ZMVideoSDKErrors` | **Preferred.** nil listener → `Invalid_Parameter`. |
| `-startVideoPreview:deviceID:` | Deprecated; defaults resolution to **1080p**. |
| `-stopVideoPreview:` | `ZMVideoSDKErrors` | Same delegate instance as start. |

### Preview — NSView
**Session:** **not required**—canvas preview works after init without join.

| Method | Returns | Notes |
|--------|---------|--------|
| `-startVideoCanvasPreview:deviceID:` | `ZMVideoSDKErrors` | nil view → `Invalid_Parameter`. |
| `-stopVideoCanvasPreview:` | `ZMVideoSDKErrors` | No canvas or nil view → `Wrong_Usage` / `Invalid_Parameter`. |

### Virtual background
**Session:** **not required**—you can add/remove/list/select VB after init, including before join, to preview and choose a background.

| Method | Returns | Notes |
|--------|---------|--------|
| `-addVirtualBackgroundItem:imageItem:` | `ZMVideoSDKErrors` | Path must be non-empty and a **valid image** (wrapper validates). |
| `-removeVirtualBackgroundItem:` | `ZMVideoSDKErrors` | Item must exist in SDK-tracked list. |
| `-getVirtualBackgroundItemList` | Array or nil | Populated from core on first access pattern. |
| `-setVirtualBackgroundItem:` | `ZMVideoSDKErrors` | |
| `-getSelectedVirtualBackgroundItem` | Object or nil | |

### Aspect ratio & mirror & alpha
| Method | Returns | Notes |
|--------|---------|--------|
| `-isOriginalAspectRatioEnabled` / `-enableOriginalAspectRatio:` | BOOL | Header: with video source and non-None data mode, original aspect is default. |
| `-mirrorMyVideo:` | `ZMVideoSDKErrors` | **Canvas only** (per header). |
| `-isMyVideoMirrored` | BOOL | |
| `-isDeviceSupportAlphaChannelMode` / `-canEnableAlphaChannelMode` | BOOL | |
| `-enableAlphaChannelMode:` | `ZMVideoSDKErrors` | |
| `-isAlphaChannelModeEnabled` | BOOL | |

### Spotlight
| Method | Returns | Notes |
|--------|---------|--------|
| `-spotLightVideo:` / `-unSpotLightVideo:` | `ZMVideoSDKErrors` | nil user or user not in session map → `Invalid_Parameter`. Host/co-host rules per session policy. |
| `-unSpotlightAllVideos` | `ZMVideoSDKErrors` | |
| `-getSpotlightedVideoUserList` | Array or nil | |

## Delegate callbacks (ZMVideoSDKDelegate)
- **`onUserVideoStatusChanged:userList:`** — Video on/off or related user video changes. Thread not guaranteed; dispatch UI work to main.
- **`onSpotlightVideoChanged:userList:`** — Spotlight list changed. Same threading caution.

## Common errors (wrapper-visible)
- **`ZMVideoSDKErrors_Internal_Error`:** Underlying `getVideoHelper` nil or internal cast/pipe failure.
- **`ZMVideoSDKErrors_Invalid_Parameter`:** nil/empty IDs, bad PTZ range, invalid image path, nil listener, nil user for spotlight, etc.
- **`ZMVideoSDKErrors_Wrong_Usage`:** e.g. stop canvas preview without active canvas.
- Core may also return session/permission/feature errors (`Session_No_Rights`, `Dont_Support_Feature`, etc.) — handle generically and refresh state from delegate.

## Rules
1. **Preview:** Call `stopVideoPreview:` with the **same** `listener` before release or session leave.
2. **PTZ:** Always validate `range` ∈ [10, 100] before call (wrapper rejects otherwise).
3. **Spotlight:** Only pass `ZMVideoSDKUser` from the current session (e.g. from session/user helpers).
4. **VB items:** After `removeVirtualBackgroundItem:`, do not use the removed wrapper object for `setVirtualBackgroundItem:`.

## Examples
- Start video after join: `[[[ZMVideoSDK sharedVideoSDK] getVideoHelper] startVideo]`.
- Select camera: `[[[ZMVideoSDK sharedVideoSDK] getVideoHelper] selectCamera:deviceID]`.
- Raw preview: `startVideoPreview:delegate deviceID:nil resolution:ZMVideoSDKResolution_720P` then `stopVideoPreview:delegate` on teardown.

Structured patterns are in **`ZMVideoSDKVideoHelper-API.json`** (`examples`, `codeSnippets`). Customer-facing JSON does not include internal demo paths.
