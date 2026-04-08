# ZMVideoSDKPasswordHandler API Documentation

## Module Information
- Module: Password Handler
- Platform: macOS
- Language: Objective-C
- Version: 2.5.5
- Header File: `ZMVideoSDKPasswordHandler.h`

## JSON callback fields (`ZMVideoSDKPasswordHandler-API.json`)

Session password prompts are satisfied via handler methods during the delegate callback scope that provides this object.

Column semantics: see the paired `*-API.json` (`async`, `zmVideoSDKDelegateCallbacks`, `callbackFieldDoc`, and per-API notes).

## Overview
`ZMVideoSDKPasswordHandler` is provided to the app when the session requires a password (during join). The handler is delivered only via `ZMVideoSDKDelegate` callbacks `onSessionNeedPassword:` (session requires a password to join) and `onSessionPasswordWrong:` (the provided password was wrong or invalid). The handler object is **valid only during the callback**; the manager releases it immediately after dispatching to delegates. The app must call either `inputSessionPassword:` or `leaveSessionIgnorePassword` during the callback and must not retain the handler for use after the callback returns.

## Lifecycle
### Prerequisites
- The handler is not obtained by the app directly. It is created by the SDK and passed as the parameter of `onSessionNeedPassword:` or `onSessionPasswordWrong:`.
- These callbacks occur during the join flow (session requires password, or user submitted a wrong password).

### Entry / Exit
- **Entry:** App receives the handler when `onSessionNeedPassword:` or `onSessionPasswordWrong:` is invoked.
- **Exit:** The handler is released by the SDK when the delegate callback returns. After the callback returns, the handler must not be used or retained.

### Implicit side effects
- **During callback:** The app must call either `inputSessionPassword:(NSString*)password` or `leaveSessionIgnorePassword` once. Calling both on the same handler is not specified; prefer calling exactly one.
- **After callback returns:** The handler is invalid; do not retain or use it asynchronously.

## APIs

### ZMVideoSDKPasswordHandler

| Method | Description | Returns / Notes |
|--------|-------------|-----------------|
| `inputSessionPassword:(NSString*)password` | Submit the session password. | `ZMVideoSDKErrors_Success` or error. `password` must be non-nil and non-empty; otherwise returns `ZMVideoSDKErrors_Invalid_Parameter`. If the underlying handler is invalid (e.g. already released), returns `ZMVideoSDKErrors_Internal_Error`. |
| `leaveSessionIgnorePassword` | Cancel password input and leave the session (do not join). | `ZMVideoSDKErrors_Success` or error. If the underlying handler is invalid, returns `ZMVideoSDKErrors_Internal_Error`. |

**Preconditions:** Call only during `onSessionNeedPassword:` or `onSessionPasswordWrong:`; do not retain the handler. For `inputSessionPassword:`, pass a non-nil, non-empty password string.

## Callbacks (ZMVideoSDKDelegate)

| Callback | When | Parameter lifetime |
|----------|------|---------------------|
| `onSessionNeedPassword:(ZMVideoSDKPasswordHandler*)handle` | Session requires a password to join. | Handler is valid only during the callback. Call `inputSessionPassword:` or `leaveSessionIgnorePassword` before returning; do not retain the handler. |
| `onSessionPasswordWrong:(ZMVideoSDKPasswordHandler*)handle` | The provided session password was wrong or invalid. | Same as above. |

**Thread:** Both callbacks are invoked on the main thread.

## Error Handling
- **ZMVideoSDKErrors_Invalid_Parameter:** `inputSessionPassword:` was called with nil or empty `password`. Do not retry with the same empty value; prompt the user for a non-empty password.
- **ZMVideoSDKErrors_Internal_Error:** The underlying handler is null (e.g. handler already invalidated). Do not retry; the handler is no longer valid.
- Other errors may be returned from the C++ layer and mapped via `ZMVideoSDKErrors`; see `ZMVideoSDKDef.h`.

## Rules
- Call either `inputSessionPassword:` or `leaveSessionIgnorePassword` when the handler is provided; do not retain the handler beyond the callback.
- Do not pass nil or empty string to `inputSessionPassword:`.
- Both callbacks are on the main thread; UI updates may be done directly in the callback.

## Examples

### Handle session need password
```objc
- (void)onSessionNeedPassword:(ZMVideoSDKPasswordHandler *)handle {
    if (!handle) return;
    // Show UI to collect password; then call one of the two methods before this method returns.
    // Option 1: submit password
    [handle inputSessionPassword:userEnteredPassword];
    // Option 2: cancel and leave
    // [handle leaveSessionIgnorePassword];
    // Do not retain handle.
}
```

### Handle wrong password
```objc
- (void)onSessionPasswordWrong:(ZMVideoSDKPasswordHandler *)handle {
    if (!handle) return;
    // Show "wrong password" UI; let user retry or leave.
    [handle inputSessionPassword:newPassword];  // retry with new password
    // Or: [handle leaveSessionIgnorePassword];  // leave without joining
}
```

## Examples

Structured snippets: this module's **`*-API.json`** → `examples` and `codeSnippets`.
