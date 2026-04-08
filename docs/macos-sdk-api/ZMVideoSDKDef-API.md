# ZMVideoSDKDef API Documentation

## Module Information
- Module: Zoom Video SDK Constants
- Platform: macOS
- Language: Objective-C
- Version: 2.5.5
- Header File: `ZMVideoSDKDef.h`

## JSON callback fields (`ZMVideoSDKDef-API.json`)

Definitions only; no per-API zmVideoSDKDelegateCallbacks. Enum values are referenced from delegate and helper docs.

Column semantics: see the paired `*-API.json` (`async`, `zmVideoSDKDelegateCallbacks`, `callbackFieldDoc`, and per-API notes).

## Overview
`ZMVideoSDKDef.h` is the shared type-definition module for Zoom Video SDK Objective-C on macOS.

It contains enum contracts consumed by almost all helpers, delegates, and callback payloads.  
This document covers **all enums** from the header, keeps deprecated values documented, and marks platform-specific notes where comments indicate platform limits.

## Lifecycle
### Prerequisites
1. SDK headers imported.
2. Corresponding helper/delegate APIs used by the app.

### Availability Boundary
- These enum definitions are compile-time contracts.
- Runtime availability depends on the specific helper/module using each enum.

### Confirmed Session-Leave Side Effect
- No direct side effect in this module (definitions only).

### Confirmed Host-Transfer Side Effect
- No direct side effect in this module (definitions only).

## State Machine
This module has no standalone runtime state machine.  
State transitions are defined by feature modules that reference these enums.

## Type Definitions (All Enums)

### Numeric layout notes (discontinuity / non-zero base)

- **`ZMVideoSDKErrors`**: Integer values are **not** a single contiguous 0…N sequence. The header assigns **segment bases** per error category; **gaps between segments** are large; within a segment, values usually increment by **+1** from the anchor. Example anchors (match `ZMVideoSDKDef.h`): `0` general/success baseline, `1001` authorization, `1500` join session, `2001` session module, `3000` audio, `4000` video, `5000` live stream, `5500` phone, `6001` raw data, `7001` sharing, `7500` file transfer, `7600` spotlight, `7700` cleanup-while-in-session guard, etc. In app logic, **always compare using symbolic constants**; do not assume consecutive cases differ by 1 in numeric value (not true across segments).
- **`ZMVideoSDKCanvasType`**: Values start at **`1`** (`VideoData = 1`, `ShareData = 2`). There is **no case with raw value `0`**; do not treat `0` as a valid canvas type.

See **`ZMVideoSDKDef-API.json`**: `enumSpecialNumericLayout` and `enumRawValues`.

### Core and Common
- `ZMVideoSDKErrors`
- `ZMVideoSDKShareStatus`
- `ZMVideoSDKLiveStreamStatus`
- `ZMVideoSDKRawDataType`
- `ZMVideoSDKResolution`
- `ZMVideoSDKRawDataMemoryMode`
- `ZMVideoSDKRawDataStatus`
- `ZMVideoSDKAudioType`
- `ZMVideoRotation`
- `ZMVideoSDKVideoPreferenceMode`

### Recording / Phone / CRC
- `ZMRecordingStatus`
- `ZMVideoSDKCameraControlRequestType`
- `ZMPhoneStatus`
- `ZMPhoneFailedReason`
- `ZMVideoSDKCRCProtocol`
- `ZMVideoSDKCRCCallStatus`

### Audio / Device / Share / Video
- `ZMVideoSDKSuppressBackgroundNoiseLevel`
- `ZMVideoSDKEchoCancellationLevel`
- `ZMVideoSDKMultiCameraStreamStatus`
- `ZMVideoSDKMicTestStatus`
- `ZMVideoSDKAudioDeviceType`
- `ZMVideoSDKAudioDeviceStatus`
- `ZMVideoSDKShareType`
- `ZMVideoSDKShareCapturePauseReason`
- `ZMVideoSDKVideoSourceDataMode`
- `ZMVideoSDKVideoAspect`
- `ZMVideoSDKCanvasType` (raw: **1** = VideoData, **2** = ShareData; no `0`)
- `ZMVideoSDKFrameDataFormat`
- `ZMVideoSDKScreenCaptureMode`
- `ZMVideoSDKPreferVideoResolution`
- `ZMVideoSDKSharePreprocessType`
- `ZMVideoSDKShareSetting`

### Chat / Annotation / File Transfer / Network
- `ZMVideoSDKChatMessageDeleteType`
- `ZMVideoSDKChatPrivilegeType`
- `ZMVideoSDKAnnotationToolType`
- `ZMVideoSDKAnnotationClearType`
- `ZMVideoSDKFileTransferStatus`
- `ZMVideoSDKNetworkStatus`
- `ZMVideoSDKDataType`
- `ZMVideoSDKStatisticsDirection`

### Session / Subsession / Whiteboard / Broadcast / RTMS
- `ZMVideoSDKSessionLeaveReason`
- `ZMVideoSDKSubSessionStatus`
- `ZMVideoSDKSessionType`
- `ZMVideoSDKUserHelpRequestResult`
- `ZMVideoSDKWhiteboardStatus`
- `ZMVideoSDKExportFormat`
- `ZMVideoSDKBroadcastControlStatus`
- `ZMVideoSDKStreamingJoinStatus`
- `ZMVideoSDKLiveStreamLayout`
- `ZMVideoSDKLiveStreamCloseCaption`
- `ZMVideoSDKRealTimeMediaStreamsStatus`
- `ZMVideoSDKRealTimeMediaStreamsFailReason`

### Misc Feature Contracts
- `ZMVideoSDKLiveTranscriptionStatus`
- `ZMVideoSDKLiveTranscriptionOperationType`
- `ZMVideoSDKVirtualBackgroundDataType`
- `ZMVideoSDKDialInNumType`
- `ZMVideoSDKConsentType`
- `ZMVideoSDKSubscribeFailReason`
- `ZMVideoSDKAudioChannel`

## Deprecated and Platform-Specific Notes
- Deprecated enum values are intentionally kept for compatibility and migration guidance.
- Platform-specific note in header:
  - `ZMVideoSDKErrors_Session_Bluetooth_SCO_Connection_Failed` is marked as Android-only by comment.

## Error Handling
### `ZMVideoSDKErrors` numeric gaps
Error codes are grouped by **range**; numeric values are **not contiguous** between ranges. When parsing logs or comparing across versions, do not infer meaning from “adjacent” integers; rely on symbolic names and this documentation.

### General Guidance for `ZMVideoSDKErrors`
- `Invalid_Parameter`: fix input before retry.
- `Session_No_Rights`: acquire required role/permission before retry.
- `Call_Too_Frequently`: avoid immediate retry; apply backoff.
- `Dont_Support_Feature` / `No_Impl`: treat as non-retryable in current capability context.
- `Load_Module_Error` / `Internal_Error`: retry only after module/session recovery.

## Rules
- Do not hardcode numeric enum values in app logic unless explicitly required.
- Prefer symbolic names (`ZMVideoSDKErrors_*`, etc.) for forward compatibility.
- Keep deprecated values handled defensively when parsing historical/legacy paths.

## Examples
### Example 1: Error-class based retry policy
```objective-c
switch (err) {
    case ZMVideoSDKErrors_Invalid_Parameter:
    case ZMVideoSDKErrors_Session_No_Rights:
        // fix inputs or permission, then retry
        break;
    case ZMVideoSDKErrors_Call_Too_Frequently:
        // backoff and retry later
        break;
    case ZMVideoSDKErrors_Dont_Support_Feature:
    case ZMVideoSDKErrors_No_Impl:
        // treat as non-retryable in current context
        break;
    default:
        break;
}
```

### Example 2: Prefer symbolic enum over numeric checks
```objective-c
if (status == ZMVideoSDKStreamingJoinStatus_Joined) {
    // joined streaming
}
```

Structured snippets: this module's **`*-API.json`** → `examples` and `codeSnippets`.
