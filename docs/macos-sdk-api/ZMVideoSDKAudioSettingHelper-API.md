# AudioSettingHelper API Documentation

## Module Information
- Module: Audio Setting Helper
- Platform: macOS
- Language: Objective-C
- Version: 2.5.5
- Header File: `ZMVideoSDKAudioSettingHelper.h`

## JSON callback fields (`ZMVideoSDKAudioSettingHelper-API.json`)

Device and test notifications often use ZMVideoSDKDelegate audio callbacks; see ZMVideoSDKAudioHelper-API.json.

Column semantics: see the paired `*-API.json` (`async`, `zmVideoSDKDelegateCallbacks`, `callbackFieldDoc`, and per-API notes).

## Overview
This module provides two helper objects:
- `ZMVideoSDKAudioSettingHelper`: controls advanced audio options (noise suppression, original sound, stereo, echo cancellation, auto mic gain).
- `ZMVideoSDKAudioDeviceTestHelper`: tests microphone/speaker devices and reports test volume/status callbacks.

All APIs in this header are synchronous request APIs returning `ZMVideoSDKErrors`.

## Lifecycle
### Prerequisites
1. SDK must be initialized.
2. Acquire helper via:
   - `[[ZMVideoSDK sharedVideoSDK] getAudioSettingHelper]`
   - `[[ZMVideoSDK sharedVideoSDK] getAudioDeviceTestHelper]`
3. Session join is not a strict prerequisite for all APIs (per confirmed product rule).

### Entry / Exit
- N/A for module availability boundary.
- `onSessionJoin` / `onSessionLeave` are informational lifecycle callbacks only, not required gates for calling this module's APIs.

### Role Requirements
- No host/manager role restriction for this module.

### Implicit Side Effects (confirmed)
- `onSessionLeave`: behavior is not forced to invalidate this module; APIs remain callable.
- `onUserHostChanged`: no behavior change for this module.

## State Machine
### Functional States
1. **SDKNotInitialized**: helper unavailable.
2. **ReadyNoSession**: helper available and callable; session not joined.
3. **InSession**: helper available and callable; session joined.
4. **MicTest_CanTest**: idle/ready to record.
5. **MicTest_Recording**: recording test audio.
6. **MicTest_CanPlay**: recording complete and ready for playback.
7. **SpeakerTest_Stopped / SpeakerTest_Running**.

`ReadyNoSession` and `InSession` are parallel valid runtime contexts, not sequential prerequisites.

### Timing Notes
- API return `Success` means request accepted and local state may change immediately.
- For test volume/status, observe delegate callbacks:
  - `onMicSpeakerVolumeChanged:speakerVolume:`
  - `onAudioDeviceStatusChanged:status:`
  - `onTestMicStatusChanged:`
- **Thread:** These callbacks are **not** guaranteed to run on the main thread; dispatch to main thread before updating UI.

## APIs
### `ZMVideoSDKAudioDeviceTestHelper`

#### `- (ZMVideoSDKErrors)startMicTestRecording:(NSString *)deviceID`
- Purpose: Start mic recording test and optionally switch to the specified mic.
- Preconditions:
  - Helper non-nil.
  - `deviceID` can be `nil`; empty string is invalid.
  - Mic test status should be `CanTest`.
- Returns:
  - `Success`, `Invalid_Parameter`, `Wrong_Usage`, `Session_Audio_No_Microphone`, `SessionService_Invalid`.
- State:
  - `MicTest_CanTest -> MicTest_Recording` on success.
- Notes:
  - Invalid/unknown device ID returns parameter error.
  - Passing valid non-selected ID may select that device for test.

#### `- (ZMVideoSDKErrors)stopMicTestRecording`
- Purpose: Stop mic recording test.
- Preconditions: mic test must be active.
- Returns: `Success`, `Wrong_Usage`, `SessionService_Invalid`.
- State: `MicTest_Recording|MicTest_CanPlay -> MicTest_CanTest`.

#### `- (ZMVideoSDKErrors)playMicTestRecording`
- Purpose: Play recorded mic test clip.
- Preconditions: recording must exist.
- Returns: `Success`, `Wrong_Usage`, `SessionService_Invalid`.
- State: remains in test flow; status reflected via audio test / device delegate callbacks (not a `zmVideoSDKDelegateCallbacks` entry on select APIs).

#### `- (ZMVideoSDKErrors)startSpeakerTest:(nullable NSString *)deviceID`
- Purpose: Start speaker test and optionally select speaker device.
- Preconditions:
  - Helper non-nil.
  - `deviceID` can be `nil`; empty string is invalid.
- Returns:
  - `Success`, `Invalid_Parameter`, `Session_Audio_No_Speaker`, `SessionService_Invalid`.
- State: `SpeakerTest_Stopped -> SpeakerTest_Running`.

#### `- (ZMVideoSDKErrors)stopSpeakerTest`
- Purpose: Stop speaker test.
- Returns: `Success`, `SessionService_Invalid`.
- State: `SpeakerTest_Running -> SpeakerTest_Stopped`.

#### `- (ZMVideoSDKErrors)setTimerInterval:(unsigned int)timerInterval`
- Purpose: Set test callback interval for mic/speaker levels.
- Input rule:
  - Documented accepted range: 50..1000 ms.
  - Runtime behavior: out-of-range falls back to 200 ms and still returns success.
- Side effect:
  - Stops ongoing mic/speaker test and resets related timers/state.
- Returns: `Success`, `SessionService_Invalid`.

---

### `ZMVideoSDKAudioSettingHelper`

#### `- (ZMVideoSDKErrors)getSuppressBackgroundNoiseLevel:(ZMVideoSDKSuppressBackgroundNoiseLevel*)level`
- Returns current suppression level.
- Returns: `Success`, `SessionService_Invalid` (or equivalent helper unavailable error).

#### `- (ZMVideoSDKErrors)setSuppressBackgroundNoiseLevel:(ZMVideoSDKSuppressBackgroundNoiseLevel)level`
- Sets suppression level.
- Returns: `Success`, `SessionService_Invalid`, `Wrong_Usage`, `Load_Module_Error`.

#### `- (ZMVideoSDKErrors)enableMicOriginalInput:(BOOL)bEnable`
- Enables/disables original sound mode.
- Important constraints:
  - Feature may be unsupported in some contexts.
  - If no usable mic context, returns usage-related error.
- Returns:
  - `Success`, `Dont_Support_Feature`, `Wrong_Usage`, `SessionService_Invalid`.

#### `- (ZMVideoSDKErrors)isMicOriginalInputEnable:(BOOL*)bEnable`
- Reads original sound enable status.
- Returns: `Success`, helper unavailable errors.

#### `- (ZMVideoSDKErrors)enableHighFidelityMusicMode:(BOOL)bEnable`
- Valid only when original sound mode is enabled.
- Returns: `Success`, `Wrong_Usage`, helper unavailable errors.

#### `- (ZMVideoSDKErrors)isHighFidelityMusicModeEnable:(BOOL*)bEnable`
- Reads high fidelity music mode status.
- Returns: `Success`, helper unavailable errors.

#### `- (ZMVideoSDKErrors)enableEchoCancellation:(BOOL)bEnable`
- Valid only when original sound mode is enabled.
- Returns: `Success`, `Wrong_Usage`, helper unavailable errors.

#### `- (ZMVideoSDKErrors)isEchoCancellationEnable:(BOOL*)bEnable`
- Reads echo cancellation enable status.
- Returns: `Success`, helper unavailable errors.

#### `- (ZMVideoSDKErrors)enableStereoAudio:(BOOL)bEnable`
- Valid only when original sound mode is enabled.
- Returns: `Success`, `Wrong_Usage`, helper unavailable errors.

#### `- (ZMVideoSDKErrors)isStereoAudioEnable:(BOOL*)bEnable`
- Reads stereo enable status.
- Returns: `Success`, helper unavailable errors.

#### `- (ZMVideoSDKErrors)getEchoCancellationLevel:(ZMVideoSDKEchoCancellationLevel*)level`
- Returns echo cancellation level.
- Returns: `Success`, helper unavailable errors.

#### `- (ZMVideoSDKErrors)setEchoCancellationLevel:(ZMVideoSDKEchoCancellationLevel)level`
- Sets echo cancellation level.
- Returns: `Success`, `Invalid_Parameter` (if enum mapping fails), helper unavailable errors.

#### `- (ZMVideoSDKErrors)enableAutoAdjustMicVolume:(BOOL)bEnable`
- Enables/disables AGC (auto mic adjustment).
- Returns: `Success`, helper unavailable errors.

#### `- (ZMVideoSDKErrors)isAutoAdjustMicVolumeEnabled:(BOOL*)bEnable`
- Reads AGC status.
- Returns: `Success`, helper unavailable errors.

## Callbacks
### `- (void)onMicSpeakerVolumeChanged:(unsigned int)micVolume speakerVolume:(unsigned int)speakerVolume`
- Fired while testing (and in specific in-session audio-level update paths).
- `micVolume` and `speakerVolume` are immediate sampled levels.
- **Thread:** Not guaranteed main thread; dispatch to main for UI.

### `- (void)onAudioDeviceStatusChanged:(ZMVideoSDKAudioDeviceType)type status:(ZMVideoSDKAudioDeviceStatus)status`
- Fired when mic/speaker availability or status changes.
- Typical statuses: no device, list updated, no input, echo-disconnect, talk-while-muted.
- **Thread:** Not guaranteed main thread; dispatch to main for UI.

### `- (void)onTestMicStatusChanged:(ZMVideoSDKMicTestStatus)status`
- Mic test state updates (`CanTest`, `Recording`, `CanPlay`).
- **Thread:** Not guaranteed main thread; dispatch to main for UI.

### Lifecycle-related callbacks impacting usage
- `- (void)onSessionJoin`
- `- (void)onSessionLeave:(ZMVideoSDKSessionLeaveReason)reason`
- `- (void)onUserHostChanged:(ZMVideoSDKUserHelper*)userHelper user:(ZMVideoSDKUser*)user`

## Error Handling
### General Strategy
- Always check non-`Success` return value.
- For this module, do not auto-retry by default.
- If helper is unavailable, reacquire helper and re-check SDK/session state.

### Typical Non-Success Meanings
- `SessionService_Invalid`: helper/service unavailable.
- `Wrong_Usage`: API called in invalid runtime state (for example, test flow order mismatch).
- `Invalid_Parameter`: invalid device ID or invalid pointer/parameter usage.
- `Dont_Support_Feature`: feature unsupported by context/capability.
- `Load_Module_Error`: lower-level module/context unavailable.
- `Session_Audio_No_Microphone` / `Session_Audio_No_Speaker`: no usable device.

## Rules
### Forbidden Sequences
- Call `stopMicTestRecording` before successful `startMicTestRecording`.
- Call `playMicTestRecording` without a completed record flow.
- Enable `stereo/high-fidelity/echo-cancellation` when original sound is not enabled.

### Required Sequences
- Recommended mic test flow:
  1. `setTimerInterval` (optional)
  2. `startMicTestRecording`
  3. Wait for test progress / status
  4. `stopMicTestRecording`
  5. `playMicTestRecording` (optional)

## Examples
### Example 1: Safe helper acquisition and precondition check
```objective-c
ZMVideoSDKAudioSettingHelper *setting = [[ZMVideoSDK sharedVideoSDK] getAudioSettingHelper];
if (!setting) {
    return;
}
```

### Example 2: Original sound + stereo flow
```objective-c
ZMVideoSDKErrors err = [setting enableMicOriginalInput:YES];
if (err == ZMVideoSDKErrors_Success) {
    err = [setting enableStereoAudio:YES];
}
```

### Example 3: Mic test flow
```objective-c
ZMVideoSDKAudioDeviceTestHelper *test = [[ZMVideoSDK sharedVideoSDK] getAudioDeviceTestHelper];
if (!test) return;

[test setTimerInterval:200];
if ([test startMicTestRecording:nil] == ZMVideoSDKErrors_Success) {
    // wait for callbacks...
    [test stopMicTestRecording];
    [test playMicTestRecording];
}
```

### Example 4: Handle non-retryable errors
```objective-c
ZMVideoSDKErrors err = [setting enableHighFidelityMusicMode:YES];
if (err != ZMVideoSDKErrors_Success) {
    // For this module, default policy is no automatic retry.
    // Update UI and ask user to adjust environment/state.
}
```

## Examples

Structured snippets: this module's **`*-API.json`** → `examples` and `codeSnippets`.
