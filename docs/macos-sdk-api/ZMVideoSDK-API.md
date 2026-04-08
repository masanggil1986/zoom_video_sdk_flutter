# ZMVideoSDK API Documentation

## Module Information
- Module: Zoom Video SDK
- Platform: macOS
- Language: Objective-C
- Version: 2.5.5
- Header File: `ZMVideoSDK.h`

## JSON callback fields (`ZMVideoSDK-API.json`)

zmVideoSDKDelegateCallbacks / zmVideoSDKDelegateCallbacksMayFollow: ZMVideoSDKDelegate (ZMVideoSDKDelegate.h). joinSession paths vary; list includes common outcomes. List each delegate selector once under zmVideoSDKDelegateCallbacks or zmVideoSDKDelegateCallbacksMayFollow.

Column semantics: see the paired `*-API.json` (`async`, `zmVideoSDKDelegateCallbacks`, `callbackFieldDoc`, and per-API notes).

## Overview
`ZMVideoSDK` is the main entry object of the macOS Video SDK wrapper. It provides:
- SDK lifecycle control (`initialize`, `cleanUp`)
- Session lifecycle control (`joinSession`, `leaveSession`)
- Listener registration and callback delivery
- Session query and diagnostics (`isInSession`, `getSessionInfo`, `getSDKVersion`, `exportLog`)
- **While joining:** after `joinSession:` returns a session, `getSessionInfo` and `getMySelf` may provide the local user before `onSessionJoin`
- Helper object access for audio/video/share/chat/recording/subsession and other features

Synchronous APIs (`initialize:`, `cleanUp`, `addListener:`, `removeListener:`, queries) **do not** invoke `ZMVideoSDKDelegate` to signal the result of that call. For **`joinSession:`** / **`leaveSession:`**, Success (or non-nil session) means request accepted only; delegate outcomes are documented per API in **`ZMVideoSDK-API.json`** and summarized under **JSON callback fields** above.

## Lifecycle
### Prerequisites
1. Create/get singleton: `+ (ZMVideoSDK*)sharedVideoSDK`.
2. Build `ZMVideoSDKInitParams`.
3. `domain` must be non-empty and must include schema (`https://` or `http://`).
4. Call `- (ZMVideoSDKErrors)initialize:(ZMVideoSDKInitParams*)params`.

### Entry / Exit
- Module entry: `initialize` returns `ZMVideoSDKErrors_Success`.
- Session entry event: `onSessionJoin`.
- Session exit event: `onSessionLeave:(ZMVideoSDKSessionLeaveReason)reason`.
- Module exit: `cleanUp` returns `ZMVideoSDKErrors_Success`.

### Role Requirements
- Most APIs are role-agnostic.
- `getSubSessionHelper` is role-restricted:
  - Host/cohost: can get helper when capability is available.
  - Non-host/cohost: cannot get helper (returns `nil`).
- After `onUserHostChanged`, role restrictions apply immediately.

### Implicit Side Effects (Confirmed)
- `onSessionLeave`:
  - All in-flight asynchronous operations are treated as terminated by leave.
  - Caller must not rely on pending success callbacks from pre-leave requests.
  - New session-scoped operations should wait until rejoin.
- `onUserHostChanged`:
  - If current user is no longer host/cohost, `getSubSessionHelper` becomes unavailable.

## State Machine
1. **SDKNotInitialized**: SDK not initialized.
2. **SDKInitialized_NoSession**: initialized, not in session.
3. **SessionJoining**: join request accepted, waiting for session callbacks.
4. **InSession**: session active.
5. **SessionLeaving**: leave request accepted, waiting for leave callback.
6. **CleanedUp**: SDK cleaned.

### Transition Notes
- `initialize: Success` -> `SDKInitialized_NoSession`.
- `joinSession` returns non-nil -> `SessionJoining` (final success via `onSessionJoin`).
- `onSessionJoin` -> `InSession`.
- `leaveSession` returns `Success` -> `SessionLeaving`.
- `onSessionLeave` -> `SDKInitialized_NoSession`.
- `cleanUp: Success` (out of session only) -> `CleanedUp`.

## Data Types
### `ZMVideoSDKInitParams`
- `domain` (`NSString*`, required)
- `logFilePrefix` (`NSString*`, optional)
- `enableLog` (`BOOL`)
- `audioRawDataMemoryMode`, `videoRawDataMemoryMode`, `shareRawDataMemoryMode`
- `extendParams` (`ZMVideoSDKExtendParams*`, optional)

### `ZMVideoSDKExtendParams`
- `speakerTestFilePath` (mp3 only, <= 1MB)
- `wrapperType`
- `preferVideoResolution`
- `disableKeychainAccess`

### `ZMVideoSDKSessionContext`
- `sessionName`, `sessionPassword`, `userName`, `token`
- `videoOption`, `audioOption`
- `preProcessor`, `externalVideoSource`, `virtualAudioMic`, `virtualAudioSpeaker`
- `sessionIdleTimeoutMins` (default 40, < 0 means keep alive indefinitely)
- `autoLoadMutliStream` (default YES)

## APIs
### Core Lifecycle APIs
#### `+ (ZMVideoSDK*)sharedVideoSDK`
- Returns singleton instance.

#### `- (ZMVideoSDKErrors)initialize:(ZMVideoSDKInitParams*)params`
- Preconditions:
  - `params` non-nil
  - `params.domain` non-empty and includes `https://` or `http://`
  - SDK not already initialized
- Success means SDK runtime initialized and helper access becomes valid.
- Typical errors: `Invalid_Parameter`, `Wrong_Usage`, `Internal_Error`.

#### `- (ZMVideoSDKErrors)cleanUp`
- Preconditions:
  - SDK initialized
  - Not in session
  - Must not call inside SDK callback
- Typical errors: `Cannot_Call_Cleanup_In_Session`, `Wrong_Usage`.

### Listener APIs
#### `- (void)addListener:(id<ZMVideoSDKDelegate>)listener`
#### `- (void)removeListener:(id<ZMVideoSDKDelegate>)listener`
- Register/unregister callback sink.
- `listener == nil` is ignored.

### Session APIs
#### `- (ZMVideoSDKSession* _Nullable)joinSession:(ZMVideoSDKSessionContext*)params`
- Preconditions: `params` non-nil and required join fields valid.
- Return non-nil means join request accepted, not final join success.
- **JSON:** `zmVideoSDKDelegateCallbacks`: `onSessionJoin`. **May follow:** `onSessionNeedPassword:`, `onSessionPasswordWrong:`, `onError:detail:`, `onCommandChannelConnectResult:`, `onUserJoin:userList:`, `onUserLeave:userList:`.

#### `- (ZMVideoSDKErrors)leaveSession:(BOOL)end`
- Sends leave/end request.
- `end=YES` ends session for host; otherwise leave self.
- **JSON:** `zmVideoSDKDelegateCallbacks`: `onSessionLeave:`. **May follow:** `onError:detail:`.

#### `- (ZMVideoSDKSession* _Nullable)getSessionInfo`
- Returns the session for the **current join** while you are joining or in session; **`nil`** if the SDK is **not initialized** or there is **no active session**.
- For a given join, this is the **same session object** as the value returned by **`joinSession:`** until you leave.
- You may use **`[session getMySelf]`** on that object **before `onSessionJoin`** when the SDK provides the local user. Remote list, statistics, and file transfer should follow **`onSessionJoin`** / in-session readiness.

#### `- (BOOL)isInSession`
- Returns current session flag.

### Diagnostics APIs
#### `- (NSString* _Nullable)getSDKVersion`
#### `- (NSString* _Nullable)exportLog`
#### `- (ZMVideoSDKErrors)cleanAllExportedLogs`

### Helper Getter APIs
`ZMVideoSDK` exposes helper getters. These typically return helper objects after initialization:
- `getAudioHelper`, `getVideoHelper`, `getUserHelper`, `getShareHelper`
- `getLiveStreamHelper`, `getChatHelper`, `getRecordingHelper`
- `getCmdChannel`, `getPhoneHelper`
- `getAudioSettingHelper`, `getAudioDeviceTestHelper`
- `getNetworkConnectionHelper`, `getVideoSettingHelper`, `getShareSettingHelper`
- `getCRCHelper`, `getLiveTranscriptionHelper`, `getIncomingLiveStreamHelper`
- `getBroadcastStreamingController`, `getBroadcastStreamingViewer`
- `getRealTimeMediaStreamsHelper`
- `getSubSessionHelper` (role/capability restricted)

## Callbacks
### Session Boundary Callbacks
- `- (void)onSessionJoin`
- `- (void)onSessionLeave:(ZMVideoSDKSessionLeaveReason)reason`
- `- (void)onSessionNeedPassword:(ZMVideoSDKPasswordHandler* _Nonnull)handle`
- `- (void)onSessionPasswordWrong:(ZMVideoSDKPasswordHandler* _Nonnull)handle`

### Password Flow Callback Notes
- `onSessionNeedPassword`: triggered when join flow requires password input.
- `onSessionPasswordWrong`: triggered when provided password is invalid.
- Use `ZMVideoSDKPasswordHandler` to submit a new password in callback handling flow.

### Error Callback
- `- (void)onError:(ZMVideoSDKErrors)ErrorType detail:(int)details`
- May follow **`joinSession:`** / **`leaveSession:`** on failure paths (see JSON `zmVideoSDKDelegateCallbacksMayFollow`).

### Command channel
- `- (void)onCommandChannelConnectResult:(BOOL)isSuccess` — may follow a successful join path.

### Participant roster (after join)
- `- (void)onUserJoin:(ZMVideoSDKUserHelper*)userHelper userList:(NSArray<ZMVideoSDKUser*>*)userArray`
- `- (void)onUserLeave:(ZMVideoSDKUserHelper*)userHelper userList:(NSArray<ZMVideoSDKUser*>*)userArray`

### Role Change Callback
- `- (void)onUserHostChanged:(ZMVideoSDKUserHelper* _Nonnull)userHelper user:(ZMVideoSDKUser* _Nullable)user`
- After this callback, role-restricted APIs (notably `getSubSessionHelper`) must be re-evaluated immediately.

### Callback Threading
- Confirmed policy for this module: callbacks are treated as main-thread callbacks.

### Parameter Lifetime Notes
- For callbacks whose header explicitly says object is destroyed after callback (for example proxy/SSL related handlers), object lifetime is callback-scoped and should not be retained.
- For other callback parameters without temporary-lifetime note, follow normal object usage semantics.

## Error Handling
### General Policy
- Always check returned `ZMVideoSDKErrors`.
- Default policy: no automatic retry.
- If operation fails, fix state/role/parameter first, then trigger again by user action.

### Typical Error Semantics
- `ZMVideoSDKErrors_Invalid_Parameter`: required input missing/invalid.
- `ZMVideoSDKErrors_Wrong_Usage`: invalid call timing/state.
- `ZMVideoSDKErrors_Cannot_Call_Cleanup_In_Session`: cleanup attempted in session.
- `ZMVideoSDKErrors_NO_PERMISSION` / role-related failures: user lacks required role/capability.
- `ZMVideoSDKErrors_SessionService_Invalid`: session/helper service unavailable.
- `ZMVideoSDKErrors_Internal_Error`: internal runtime unavailable.

## Rules
### Forbidden Sequences
- `cleanUp` while in session.
- Calling session-scoped actions after `onSessionLeave` without rejoin.
- Assuming `joinSession` return non-nil equals already joined.
- Assuming role-restricted helper remains usable after host-role changes.

### Required Sequences
1. `sharedVideoSDK` -> `initialize`.
2. `addListener` (recommended before join).
3. `joinSession` -> wait for `onSessionJoin`.
4. Run in-session features.
5. `leaveSession` -> wait for `onSessionLeave`.
6. `cleanUp` when no longer in session.

## Examples
### Example 1: Initialize SDK safely
```objective-c
ZMVideoSDK *sdk = [ZMVideoSDK sharedVideoSDK];
ZMVideoSDKInitParams *params = [[ZMVideoSDKInitParams alloc] init];
params.domain = @"https://zoom.us";
params.enableLog = YES;

ZMVideoSDKErrors err = [sdk initialize:params];
if (err != ZMVideoSDKErrors_Success) {
    return;
}
```

### Example 2: Join flow (request vs delegate outcome)
```objective-c
ZMVideoSDKSessionContext *ctx = [[ZMVideoSDKSessionContext alloc] init];
ctx.sessionName = @"demo_session";
ctx.userName = @"tester";
ctx.token = token;

ZMVideoSDKSession *session = [[ZMVideoSDK sharedVideoSDK] joinSession:ctx];
if (!session) {
    return;
}
// Wait for onSessionJoin to confirm actual joined state.
```

### Example 2b: Local user while joining (`getSessionInfo` + `getMySelf`)
```objective-c
ZMVideoSDK *sdk = [ZMVideoSDK sharedVideoSDK];
ZMVideoSDKSession *s = [sdk getSessionInfo];  // same session as joinSession: return
ZMVideoSDKUser *me = [s getMySelf];
// Optional early self info when me is non-nil
```

### Example 3: Re-check subsession capability after host change
```objective-c
- (void)onUserHostChanged:(ZMVideoSDKUserHelper *)userHelper user:(ZMVideoSDKUser *)user {
    ZMVideoSDKSubSessionHelper *helper = [[ZMVideoSDK sharedVideoSDK] getSubSessionHelper];
    if (!helper) {
        // Non-host/cohost or capability unavailable.
    }
}
```

### Example 4: Leave terminates in-flight assumptions
```objective-c
- (void)onSessionLeave:(ZMVideoSDKSessionLeaveReason)reason {
    // Treat all in-flight async requests as terminated by leave.
    // Do not rely on pending success callbacks from pre-leave requests.
}
```

Structured snippets: this module's **`*-API.json`** → `examples` and `codeSnippets`.
