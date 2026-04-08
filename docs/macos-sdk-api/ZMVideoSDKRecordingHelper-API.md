# ZMVideoSDKRecordingHelper API Documentation

## Module Information
- Module: Recording Helper
- Platform: macOS
- Language: Objective-C
- Version: 2.5.5
- Header File: `ZMVideoSDKRecordingHelper.h`

## JSON callback fields (`ZMVideoSDKRecordingHelper-API.json`)

zmVideoSDKDelegateCallbacks: ZMVideoSDKDelegate (ZMVideoSDKDelegate.h). Recording state transitions follow onCloudRecordingStatus:recordingConsentHandler:.

Column semantics: see the paired `*-API.json` (`async`, `zmVideoSDKDelegateCallbacks`, `callbackFieldDoc`, and per-API notes).

## Overview
`ZMVideoSDKRecordingHelper` controls cloud recording in a Zoom Video SDK session. Cloud recording requires a valid add-on plan and the feature enabled on the Zoom Web portal. Start, stop, pause, and resume are asynchronous; the actual state is confirmed only via `ZMVideoSDKDelegate` **`onCloudRecordingStatus:recordingConsentHandler:`** (see **JSON callback fields** above). When the user must accept or decline recording consent, a `ZMVideoSDKRecordingConsentHandler` is provided in that callback; the app must call `accept` or `decline` during the callback and must not retain the handler.

## Lifecycle

### Prerequisites
1. SDK initialized and session joined.
2. Cloud recording add-on plan and cloud recording feature enabled on the Zoom Web portal.
3. Helper obtained from `[ZMVideoSDK getRecordingHelper]`. If the helper is unavailable (e.g. session service not ready), all APIs return `ZMVideoSDKErrors_SessionService_Invalid`.

### Entry and Exit
- **Entry:** Helper is available after session join when `getRecordingHelper` returns non-nil. Use `canStartRecording` to check if the current user can start recording (plan, portal, and role).
- **Exit:** After session leave, the helper or recording state may be invalid. Do not rely on `getCloudRecordingStatus` or in-flight operations after leave.

### Implicit Side Effects
- **onSessionLeave:** When the user leaves the session, any in-flight start/stop/pause/resume request may be cancelled. There is no guarantee that a corresponding `onCloudRecordingStatus:recordingConsentHandler:` will fire for the final state. Recording state is undefined after leave; do not call recording APIs or rely on status.
- **onUserHostChanged:** When the host role is transferred, `canStartRecording` may change (e.g. only host can start). The app should re-query `canStartRecording` after `onUserHostChanged` before enabling start/stop UI.

### Role and Permission
- Starting cloud recording typically requires host (or co-host) role; use `canStartRecording` to determine if the current user can start. Stop/pause/resume may also be role-restricted depending on meeting settings. Re-check after `onUserHostChanged`.

## Type Definitions

### ZMRecordingStatus
- **ZMRecording_Start** — Recording has successfully started or resumed.
- **ZMRecording_Stop** — Recording has stopped.
- **ZMRecording_DiskFull** — Recording failed due to insufficient storage; user may need to free space or purchase storage.
- **ZMRecording_Pause** — Recording has paused.
- **ZMRecording_Connecting** — Recording is connecting (e.g. after `startCloudRecording`).

## State Machine

### States
- **Stop (Idle):** No recording. Allowed: `startCloudRecording`, `canStartRecording`, `getCloudRecordingStatus:`. Forbidden: `pauseCloudRecording`, `resumeCloudRecording` (no active recording).
- **Connecting:** Start requested, waiting for server. Allowed: `getCloudRecordingStatus:`, optionally `stopCloudRecording` (to cancel). Forbidden: `startCloudRecording` (already in progress).
- **Start (Recording):** Recording is active. Allowed: `pauseCloudRecording`, `stopCloudRecording`, `getCloudRecordingStatus:`. Forbidden: `startCloudRecording`.
- **Pause:** Recording is paused. Allowed: `resumeCloudRecording`, `stopCloudRecording`, `getCloudRecordingStatus:`. Forbidden: `startCloudRecording`, `pauseCloudRecording`.
- **DiskFull:** Recording failed due to storage. Allowed: `stopCloudRecording`, `getCloudRecordingStatus:`. Forbidden: `startCloudRecording`, `pauseCloudRecording`, `resumeCloudRecording`. This state does not auto-transition to Stop; the app should call `stopCloudRecording` and inform the user to free storage.

### State Transition Timing
- When `startCloudRecording` returns `ZMVideoSDKErrors_Success`, the state does **not** change immediately; it changes only when `onCloudRecordingStatus:recordingConsentHandler:` is called (e.g. with `ZMRecording_Connecting` then `ZMRecording_Start`).
- Same for `stopCloudRecording`, `pauseCloudRecording`, `resumeCloudRecording`: Success means request accepted; actual state update is via the callback.
- `getCloudRecordingStatus:` returns the current status synchronously (when it returns Success, the out-parameter holds the current state).

### Query Method
- **getCloudRecordingStatus:** Returns `ZMRecording_Stop`, `ZMRecording_Connecting`, `ZMRecording_Start`, `ZMRecording_Pause`, or `ZMRecording_DiskFull` in the provided `ZMRecordingStatus*` on success.

## APIs

### `- (ZMVideoSDKErrors)canStartRecording`
- **Description:** Checks whether the current user meets the requirements to start cloud recording (add-on plan, Web portal feature, and typically host/co-host role).
- **Return:** `ZMVideoSDKErrors_Success` if the user can start; otherwise an error (e.g. no permission, feature not supported).
- **Preconditions:** Session joined; helper available (otherwise returns `SessionService_Invalid`).
- **Typical error codes:** `ZMVideoSDKErrors_SessionService_Invalid`, `ZMVideoSDKErrors_Session_No_Rights`, `ZMVideoSDKErrors_Dont_Support_Feature`, `ZMVideoSDKErrors_Session_Not_Started`. See `ZMVideoSDKDef.h` for full list.
- **Common mistakes:** Assuming Success means recording will start without calling `startCloudRecording`; not re-checking after `onUserHostChanged`.

### `- (ZMVideoSDKErrors)startCloudRecording`
- **Description:** Requests to start cloud recording. The operation is asynchronous; confirm actual start via `onCloudRecordingStatus:recordingConsentHandler:` (e.g. status `ZMRecording_Start`). If consent is required, the handler is provided in the same callback.
- **Return:** `ZMVideoSDKErrors_Success` means the request was accepted, not that recording has started.
- **Preconditions:** Session joined; `canStartRecording` returns Success; helper available. Ideally current status is Stop (otherwise may get `Wrong_Usage` or similar).
- **Delegate (JSON `zmVideoSDKDelegateCallbacks`):** `onCloudRecordingStatus:recordingConsentHandler:` (may fire with `ZMRecording_Connecting` then `ZMRecording_Start`, and optionally a consent handler).
- **Typical error codes:** `ZMVideoSDKErrors_SessionService_Invalid`, `ZMVideoSDKErrors_Session_No_Rights`, `ZMVideoSDKErrors_Session_Not_Started`, `ZMVideoSDKErrors_Wrong_Usage`, `ZMVideoSDKErrors_Call_Too_Frequently`, `ZMVideoSDKErrors_Dont_Support_Feature`, `ZMVideoSDKErrors_Internal_Error`.
- **Common mistakes:** Assuming Success means recording started; not handling `onCloudRecordingStatus:recordingConsentHandler:`; not calling `accept` or `decline` on the consent handler when provided; not checking `canStartRecording` first.

### `- (ZMVideoSDKErrors)stopCloudRecording`
- **Description:** Requests to stop cloud recording. Actual stop is confirmed via `onCloudRecordingStatus:recordingConsentHandler:` (e.g. status `ZMRecording_Stop`).
- **Return:** Success means request accepted.
- **Preconditions:** Session joined; helper available.
- **Delegate (JSON `zmVideoSDKDelegateCallbacks`):** `onCloudRecordingStatus:recordingConsentHandler:`.
- **Typical error codes:** Same as start (e.g. `SessionService_Invalid`, `Session_Not_Started`, `Wrong_Usage`).
- **Common mistakes:** Assuming Success means recording has stopped; not handling callback.

### `- (ZMVideoSDKErrors)pauseCloudRecording`
- **Description:** Pauses ongoing cloud recording. Actual pause is confirmed via callback (status `ZMRecording_Pause`).
- **Return:** Success means request accepted.
- **Preconditions:** Session joined; recording should be in Start state (otherwise may get `Wrong_Usage`).
- **Delegate (JSON `zmVideoSDKDelegateCallbacks`):** `onCloudRecordingStatus:recordingConsentHandler:`.
- **Common mistakes:** Calling when not recording; assuming Success means paused immediately.

### `- (ZMVideoSDKErrors)resumeCloudRecording`
- **Description:** Resumes paused cloud recording. Actual resume is confirmed via callback (status `ZMRecording_Start`).
- **Return:** Success means request accepted.
- **Preconditions:** Session joined; recording should be in Pause state.
- **Delegate (JSON `zmVideoSDKDelegateCallbacks`):** `onCloudRecordingStatus:recordingConsentHandler:`.
- **Common mistakes:** Calling when not paused; assuming Success means resumed immediately.

### `- (ZMVideoSDKErrors)getCloudRecordingStatus:(ZMRecordingStatus*)recordStatus`
- **Description:** Gets the current cloud recording status. On success, the status is written to `recordStatus`.
- **Parameters:** `recordStatus` must be non-nil; on success it receives one of `ZMRecording_Start`, `ZMRecording_Stop`, `ZMRecording_Pause`, `ZMRecording_Connecting`, `ZMRecording_DiskFull`.
- **Return:** `ZMVideoSDKErrors_Success` if the request succeeded and status was written; otherwise an error (e.g. `SessionService_Invalid`, `Invalid_Parameter` if `recordStatus` is nil).
- **Preconditions:** Session joined; helper available; `recordStatus` non-nil.
- **Common mistakes:** Passing nil; relying on status after session leave.

## Callbacks (ZMVideoSDKDelegate)

### `onCloudRecordingStatus:recordingConsentHandler:`
- **Signature:** `- (void)onCloudRecordingStatus:(ZMRecordingStatus)status recordingConsentHandler:(ZMVideoSDKRecordingConsentHandler* _Nullable)handler`
- **When:** Fired when cloud recording status changes (e.g. after start/stop/pause/resume requests, or when consent is required).
- **Thread:** Main thread.
- **Parameters:**
  - **status:** The new recording status (Start, Stop, Pause, Connecting, DiskFull). This is the source of truth for state; update UI and allowed actions based on it.
  - **handler:** When non-nil, the user must accept or decline cloud recording. Valid only during this callback; call `accept` or `decline` once and do not retain. See `ZMVideoSDKRecordingConsentHandler-API.md`.
- **State transitions:** Use `status` to drive state (e.g. Start → Recording, Stop → Idle, Pause → Paused, DiskFull → DiskFull). When `status` is Start, control APIs such as `pauseCloudRecording` and `stopCloudRecording` become valid; when Stop, `startCloudRecording` becomes valid.
- **Triggered by:** `startCloudRecording`, `stopCloudRecording`, `pauseCloudRecording`, `resumeCloudRecording`, or server/consent flow.
- **Must handle:** When `handler` is non-nil, the app must call either `accept` or `decline` during the callback.

## Error Handling

### General
- A return of `ZMVideoSDKErrors_Success` from start/stop/pause/resume does **not** guarantee the operation completed; confirm via `onCloudRecordingStatus:recordingConsentHandler:`.
- After session leave, do not rely on recording status or retry recording APIs until re-joined.

### By Error Code
- **ZMVideoSDKErrors_SessionService_Invalid:** Helper or session service unavailable. Do not retry until session is valid and helper is available again.
- **ZMVideoSDKErrors_Session_No_Rights:** Current user does not have permission (e.g. not host). Do not retry unless role changes; re-check after `onUserHostChanged`.
- **ZMVideoSDKErrors_Session_Not_Started:** Not in session. Ensure session join succeeded before calling recording APIs.
- **ZMVideoSDKErrors_Wrong_Usage:** Invalid state for the operation (e.g. start when already recording). Check current status with `getCloudRecordingStatus:` and only call when state allows.
- **ZMVideoSDKErrors_Call_Too_Frequently:** Rate limit. Use backoff (e.g. wait and re-check status) before retrying; do not immediate-loop retry.
- **ZMVideoSDKErrors_Dont_Support_Feature:** Meeting or account does not support cloud recording. Do not retry without plan/portal change.
- **ZMVideoSDKErrors_Invalid_Parameter:** Invalid argument (e.g. nil `recordStatus` for `getCloudRecordingStatus:`). Fix parameter and retry.
- **ZMVideoSDKErrors_Internal_Error:** Internal failure. May retry after checking session health.

### Retry Guidelines
- Do not retry immediately on failure; check state and error code first.
- For `Call_Too_Frequently`, wait (e.g. 500 ms or more), then check `getCloudRecordingStatus`; if status allows, retry once.
- For `Session_No_Rights` or `Dont_Support_Feature`, do not retry without user/account change.

## Rules
- Handle `ZMVideoSDKRecordingConsentHandler` in the same delegate call when provided; call `accept` or `decline` and do not retain the handler.
- Re-check `canStartRecording` and host role after `onUserHostChanged` before enabling start/stop UI.
- Do not rely on `getCloudRecordingStatus` or in-flight operation results after session leave.
- Do not assume Success from start/stop/pause/resume means the operation completed; always use the callback for final state.

## Examples

### Example 1: Start cloud recording (happy path)
1. Precondition: SDK initialized, session joined, delegate set.
2. Get helper and check `canStartRecording`; if not Success, show error and return.
3. Optionally check `getCloudRecordingStatus:` to ensure status is Stop.
4. Call `startCloudRecording`; if return is not Success, handle error.
5. In `onCloudRecordingStatus:recordingConsentHandler:`, when status is `ZMRecording_Start`, update UI to “Recording”. If `handler` is non-nil, call `accept` or `decline` during the callback.

```objective-c
ZMVideoSDKRecordingHelper *helper = [[ZMVideoSDK sharedVideoSDK] getRecordingHelper];
if (!helper) return;
if ([helper canStartRecording] != ZMVideoSDKErrors_Success) {
    // Show "Cannot start recording" (no permission or feature)
    return;
}
ZMRecordingStatus current;
if ([helper getCloudRecordingStatus:&current] == ZMVideoSDKErrors_Success && current != ZMRecording_Stop) {
    return; // Already recording or connecting
}
ZMVideoSDKErrors err = [helper startCloudRecording];
if (err != ZMVideoSDKErrors_Success) {
    // Handle SessionService_Invalid, Session_No_Rights, etc.
    return;
}
// Wait for onCloudRecordingStatus:recordingConsentHandler: (e.g. ZMRecording_Start)
// In delegate: if (handler) { [handler accept]; } or [handler decline];
```

### Example 2: Handle consent in callback
```objective-c
- (void)onCloudRecordingStatus:(ZMRecordingStatus)status
       recordingConsentHandler:(ZMVideoSDKRecordingConsentHandler *)handler {
    switch (status) {
        case ZMRecording_Start:
            if (handler) {
                [handler accept]; // or [handler decline];
            }
            break;
        case ZMRecording_Stop:
        case ZMRecording_Pause:
        case ZMRecording_Connecting:
        case ZMRecording_DiskFull:
            break;
    }
}
```

### Example 3: Error handling and retry (rate limit)
```objective-c
ZMVideoSDKErrors err = [helper startCloudRecording];
if (err == ZMVideoSDKErrors_Call_Too_Frequently) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        ZMRecordingStatus s;
        if ([helper getCloudRecordingStatus:&s] == ZMVideoSDKErrors_Success && s == ZMRecording_Stop) {
            [helper startCloudRecording];
        }
    });
} else if (err != ZMVideoSDKErrors_Success) {
    // Show error for SessionService_Invalid, Session_No_Rights, etc.
}
```

### Example 4: Pause and resume
```objective-c
// When recording (status Start): pause
[helper pauseCloudRecording];
// In callback when status == ZMRecording_Pause: enable Resume button
// When paused: resume
[helper resumeCloudRecording];
// In callback when status == ZMRecording_Start: update UI to Recording
```

### Example 5: Handle DiskFull
When `onCloudRecordingStatus:recordingConsentHandler:` reports `ZMRecording_DiskFull`, inform the user to free storage or purchase more. Call `stopCloudRecording` to clean up; confirm via callback (status `ZMRecording_Stop`).

## Examples

Structured snippets: this module's **`*-API.json`** → `examples` and `codeSnippets`.
