# ZMVideoSDKAudioHelper API Documentation

## Module Information
- Module: Audio Helper
- Platform: macOS
- Language: Objective-C
- Version: 2.5.5
- Header File: `ZMVideoSDKAudioHelper.h`

## JSON callback fields (`ZMVideoSDKAudioHelper-API.json`)

zmVideoSDKDelegateCallbacks / zmVideoSDKDelegateCallbacksMayFollow: ZMVideoSDKDelegate (ZMVideoSDKDelegate.h). Raw subscribe uses delegate audio raw callbacks only.

Column semantics: see the paired `*-API.json` (`async`, `zmVideoSDKDelegateCallbacks`, `callbackFieldDoc`, and per-API notes).

## Overview
`ZMVideoSDKAudioHelper` provides in-session audio control, audio device selection, and raw audio subscription for the macOS Objective-C Video SDK wrapper.

This module includes:
- VOIP join/leave (`startAudio`, `stopAudio`)
- User mute/unmute controls (`muteAudio`, `unMuteAudio`, `muteAllAudio`, `unmuteAllAudio`, `allowAudioUnmutedBySelf`)
- Device APIs (`getSpeakerList`, `getMicList`, `selectSpeaker`, `selectMic`)
- Raw audio subscription (`subscribe`, `unSubscribe`)

## Lifecycle
### Prerequisites
1. SDK is initialized.
2. Audio helper is acquired from `[[ZMVideoSDK sharedVideoSDK] getAudioHelper]`.
3. Session-related audio control APIs require in-session state.
4. Device APIs can be used even when not in session.

### Entry / Exit
- Helper availability entry: `getAudioHelper` returns non-nil helper object.
- Session audio entry: `startAudio` success.
- Session audio exit: `stopAudio` success.
- Session leave side effect: session audio control becomes invalid until rejoin.
- Raw audio subscription exit: `unSubscribe`, or automatic stop when session disconnects/leaves.

### Role / Permission Notes
- `muteAudio` / `unMuteAudio`:
  - Current user can mute/unmute self.
  - Muting/unmuting other users requires host/cohost.
- `muteAllAudio`, `unmuteAllAudio`, `allowAudioUnmutedBySelf`:
  - Host/cohost required.
- Permission should be re-evaluated after `onUserHostChanged`.

### Implicit Side Effects (Confirmed)
- On `onSessionLeave`, audio control APIs are treated as unavailable until rejoin.
- On session leave/disconnect, raw audio receive channels are stopped by runtime cleanup.
- Additional final audio-status callbacks are not guaranteed after leave.

## State Machine
This module uses simplified runtime states:

1. **HelperReady**: helper object exists.
2. **AudioNotJoined**: in session but VOIP audio not joined (or already stopped).
3. **AudioJoined**: VOIP audio joined.
4. **RawAudioSubscribed**: raw audio receiving channel active.
5. **HelperInvalidForSession**: out of session; session audio control invalid.

### Transition Notes
- `startAudio: Success` -> target state `AudioJoined` (final UI state should follow callbacks).
- `stopAudio: Success` -> target state `AudioNotJoined`.
- `subscribe: Success` -> `RawAudioSubscribed`.
- `unSubscribe: Success` -> exits `RawAudioSubscribed`.
- `onSessionLeave` -> `HelperInvalidForSession` + raw audio channel stop.

## APIs
### `- (ZMVideoSDKErrors)startAudio`
- Purpose: join VOIP audio.
- Preconditions:
  - In-session.
  - Session supports VOIP audio.
- Typical errors:
  - `Wrong_Usage`, `Dont_Support_Feature`, `Call_Too_Frequently`, `Internal_Error`.
- Retry guidance: do not auto-retry; fix state and retry with user action.

### `- (ZMVideoSDKErrors)stopAudio`
- Purpose: leave VOIP audio.
- Preconditions:
  - In-session.
- Typical errors:
  - `Wrong_Usage`, `Dont_Support_Feature`, `Call_Too_Frequently`, `Internal_Error`.

### `- (ZMVideoSDKErrors)muteAudio:(ZMVideoSDKUser*)user`
- Purpose: mute target user audio.
- Preconditions:
  - `user` non-nil and valid session user object.
  - If target is not self, caller must be host/cohost.
- Typical errors:
  - `Invalid_Parameter`, `Wrong_Usage`, `Session_No_Rights`, `SessionService_Invalid`.

### `- (ZMVideoSDKErrors)unMuteAudio:(ZMVideoSDKUser*)user`
- Purpose: unmute target user audio.
- Preconditions and permission rules are same as `muteAudio`.
- If target is self, current user receives `onUserAudioStatusChanged`.
- If caller is host/cohost and target is another participant, target side receives `onHostAskUnmute`.
- Typical errors:
  - `Invalid_Parameter`, `Wrong_Usage`, `Session_No_Rights`, `SessionService_Invalid`.

### `- (ZMVideoSDKErrors)allowAudioUnmutedBySelf:(BOOL)allowUnmute`
- Purpose: host/cohost toggles whether participants can unmute themselves.
- Preconditions:
  - In-session.
  - Host/cohost role.
- Typical errors:
  - `Wrong_Usage`, `Session_No_Rights`, `Internal_Error`.

### `- (ZMVideoSDKErrors)muteAllAudio:(BOOL)allowUnmute`
- Purpose: host/cohost mutes all users (except self behavior is runtime-defined).
- Preconditions:
  - In-session.
  - Host/cohost role.
- Typical errors:
  - `Wrong_Usage`, `Session_No_Rights`, `Call_Too_Frequently`, `Internal_Error`.

### `- (ZMVideoSDKErrors)unmuteAllAudio`
- Purpose: host/cohost sends ask-unmute to other participants (not self).
- Preconditions:
  - In-session.
  - Host/cohost role.
- Typical errors:
  - `Wrong_Usage`, `Session_No_Rights`, `Call_Too_Frequently`, `Internal_Error`.

### `- (NSArray<ZMVideoSDKSpeakerDevice *>*)getSpeakerList`
### `- (NSArray<ZMVideoSDKMicDevice *>*)getMicList`
- Purpose: query available speaker/mic devices.
- Can be used outside meeting session.
- Returns `nil` when underlying device service is unavailable.

### `- (ZMVideoSDKErrors)selectSpeaker:(NSString *)deviceId deviceName:(NSString *)name`
### `- (ZMVideoSDKErrors)selectMic:(NSString *)deviceId deviceName:(NSString *)name`
- Purpose: select default speaker/mic device.
- Preconditions:
  - `deviceId` and `name` are non-empty.
- Can be used outside meeting session.
- No callback is emitted for these APIs.
- `ZMVideoSDKErrors_Success` means device selection call succeeded.
- Typical errors:
  - `Invalid_Parameter`, `SessionService_Invalid`, `Internal_Error`.

### `- (ZMVideoSDKErrors)subscribe`
### `- (ZMVideoSDKErrors)unSubscribe`
- Purpose: subscribe/unsubscribe mixed + one-way + shared audio raw data.
- Preconditions:
  - Raw-data subsystem initialized by SDK runtime.
- Typical errors:
  - `Uninitialize`, `Internal_Error`.
- Leave/disconnect behavior:
  - runtime may stop channels automatically on session leave/disconnect.
- `onSharedAudioRawDataReceived` requires share-audio source:
  - it is received only when someone starts share and shares audio at the same time.

### `ZMVideoSDKAudioRawData` (payload class)
Defined in **`ZMVideoSDKAudioHelper.h`**. Instances are passed into raw-audio delegate callbacks.

**Readonly properties**
| Property | Type | Meaning |
|----------|------|---------|
| `buffer` | `char*` (nullable) | PCM sample buffer pointer |
| `bufferLen` | `unsigned int` | Length of `buffer` in bytes |
| `sampleRate` | `unsigned int` | Sample rate (Hz) |
| `channelNum` | `unsigned int` | Channel count |
| `timeStamp` | `long long` | Timestamp (milliseconds) |

**Methods**
- `- (BOOL)canAddRef` — whether reference counting is supported for this payload.
- `- (BOOL)addRef` — retain buffer beyond the callback; required before async use.
- `- (int)releaseRef` — release after `addRef`; returns remaining reference count (0 when released).

## Callbacks
Audio-related callbacks are delivered via `ZMVideoSDKDelegate`.

### Status / Permission Related
- `onUserAudioStatusChanged:userList:`
- `onUserActiveAudioChanged:userList:`
- `onHostAskUnmute`
- `onUserHostChanged:user:`

`onHostAskUnmute` note:
- Triggered for the target participant when host/cohost calls `unMuteAudio` (for others) or `unmuteAllAudio`.
- `unmuteAllAudio` does not unmute host/cohost self.
- After receiving this callback, user can decide whether to unmute self audio.

### Raw Audio Related
- `onMixedAudioRawDataReceived:`
- `onOneWayAudioRawDataReceived:user:`
- `onSharedAudioRawDataReceived:`

`onSharedAudioRawDataReceived` note:
- Triggered only when share starts with audio sharing enabled.
- **Not guaranteed on the main thread** (unlike `onMixedAudioRawDataReceived:` / `onOneWayAudioRawDataReceived:user:`); use `dispatch_async` to main before UI work.

### Device / Level Related
- `onAudioLevelChanged:audioSharing:user:`
- `onMicSpeakerVolumeChanged:speakerVolume:`
- `onAudioDeviceStatusChanged:status:`
- `onSelectedAudioDeviceChanged`

`onSelectedAudioDeviceChanged` note:
- Triggered only during audio device test flow.
- Not used to signal success of `selectSpeaker` / `selectMic` (those are synchronous; see JSON notes on those APIs).

### Threading
- `onSharedAudioRawDataReceived:` is **not** guaranteed on the main thread; dispatch to main before UI.
- `onMicSpeakerVolumeChanged:speakerVolume:` and `onAudioDeviceStatusChanged:status:` are **not** guaranteed to run on the main thread; dispatch to main thread before updating UI.

### Parameter Lifetime
- For `ZMVideoSDKAudioRawData` callback payload (see **properties and methods** above):
  - If `buffer` / `bufferLen` are used asynchronously beyond callback scope, call `canAddRef` / `addRef` first.
  - Call `releaseRef` when done.
  - Without `addRef`, treat `buffer` and object lifetime as callback-scoped.

## Error Handling
### General policy
- Always check `ZMVideoSDKErrors` return value.
- Default policy: no automatic retry.
- For non-success:
  - Re-check session state.
  - Re-check role/permission.
  - Re-check target user validity or device parameters.

### Typical non-success meanings
- `Invalid_Parameter`: invalid input (`nil` user, empty device id/name, etc.).
- `Wrong_Usage`: API called in invalid state (not in session, invalid user/audio state).
- `Session_No_Rights`: role does not allow operation.
- `SessionService_Invalid`: session/helper service unavailable.
- `Dont_Support_Feature`: current meeting/context does not support target audio capability.
- `Call_Too_Frequently`: operation is rate-limited by runtime command protection.
- `Internal_Error`: runtime/service internal failure.
- `Uninitialize`: raw data channel not initialized for subscribe APIs.

## Rules
### Forbidden sequences
- Calling session-scoped audio control APIs after session leave.
- Unmuting/muting other users as non-host/cohost.
- Calling `selectSpeaker/selectMic` with empty device id or name.
- Asynchronously using `ZMVideoSDKAudioRawData` without `addRef`.

### Required sequences
1. Acquire helper from SDK singleton.
2. For audio control APIs: ensure in-session first.
3. Validate role for host/cohost-only APIs.
4. For raw audio async processing: `addRef` in callback, `releaseRef` after done.

## Examples
### Example 1: Start audio and handle errors
```objective-c
ZMVideoSDKAudioHelper *audio = [[ZMVideoSDK sharedVideoSDK] getAudioHelper];
ZMVideoSDKErrors err = [audio startAudio];
if (err != ZMVideoSDKErrors_Success) {
    // no auto-retry by default
    return;
}
```

### Example 2: Host mutes all with self-unmute policy
```objective-c
ZMVideoSDKAudioHelper *audio = [[ZMVideoSDK sharedVideoSDK] getAudioHelper];
ZMVideoSDKErrors err = [audio muteAllAudio:YES];
if (err == ZMVideoSDKErrors_Session_No_Rights) {
    // role not enough
}
```

### Example 3: Device selection outside session
```objective-c
ZMVideoSDKAudioHelper *audio = [[ZMVideoSDK sharedVideoSDK] getAudioHelper];
NSArray<ZMVideoSDKMicDevice *> *mics = [audio getMicList];
ZMVideoSDKMicDevice *target = mics.firstObject;
if (target) {
    [audio selectMic:target.deviceId deviceName:target.deviceName];
}
```

### Example 4: Safe async raw-audio handling
```objective-c
- (void)onMixedAudioRawDataReceived:(ZMVideoSDKAudioRawData *)data {
    if (![data canAddRef] || ![data addRef]) return;
    dispatch_async(self.audioQueue, ^{
        // consume data.buffer with data.bufferLen
        [data releaseRef];
    });
}
```

Structured snippets: this module's **`*-API.json`** → `examples` and `codeSnippets`.
