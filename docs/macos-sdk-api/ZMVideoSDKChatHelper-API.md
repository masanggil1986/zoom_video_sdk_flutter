# ZMVideoSDKChatHelper API Documentation

## Module Information
- Module: Chat Helper
- Platform: macOS
- Language: Objective-C
- Version: 2.5.5
- Header File: `ZMVideoSDKChatHelper.h`

## JSON callback fields (`ZMVideoSDKChatHelper-API.json`)

zmVideoSDKDelegateCallbacks: ZMVideoSDKDelegate (ZMVideoSDKDelegate.h). Async outcomes listed here only.

Column semantics: see the paired `*-API.json` (`async`, `zmVideoSDKDelegateCallbacks`, `callbackFieldDoc`, and per-API notes).

## Overview
`ZMVideoSDKChatHelper` provides in-session meeting chat capabilities:
- Query chat availability
- Send messages to a user or all participants
- Delete messages on server (UI data is not automatically removed)
- Manage attendee chat privilege (host/manager capability)

For send APIs, `ZMVideoSDKErrors_Success` means request accepted only. The sender is guaranteed to receive `onChatNewMessageNotify:chatMessage:` for self-sent messages, and send success should be confirmed by this callback. Per-API callback columns: see **JSON callback fields** above.

## Lifecycle
### Prerequisites
1. SDK is initialized.
2. User has joined session.
3. APIs are considered available after session-join-success callback.
4. Internal chat helper must be valid.

### Availability Boundaries
- After `onSessionLeave`, in-flight chat operations are treated as invalid and no callback is guaranteed.
- Role changes are delivered via `onUserHostChanged`; for privilege changes, treat state as effective after `onChatPrivilegeChanged`.

## State Machine
This module does not expose a dedicated enum state machine, but behavior is state-gated:
- **Not Ready**: before session join success.
- **Ready**: after session join success callback.
- **Invalid**: after session leave.

Timing rules:
- `changeChatPrivilege` returning `Success` means request accepted; use `onChatPrivilegeChanged` as the effective-state signal.
- `sendChatToUser` / `sendChatToAll`: immediate return means request accepted; sender-side success is callback-driven and guaranteed by `onChatNewMessageNotify`.
- `deleteChatMessage`: immediate return means request accepted; deletion effect is callback-driven by `onChatMsgDeleteNotification`.

## APIs
### `- (BOOL)isChatDisabled`
- Returns `YES` if chat is disabled.
- Returns `NO` if helper is unavailable.

### `- (BOOL)isPrivateChatDisabled`
- Returns `YES` if private chat is disabled.
- Returns `NO` if helper is unavailable.

### `- (ZMVideoSDKErrors)sendChatToUser:(ZMVideoSDKUser*)user content:(NSString *)msgContent`
- Sends chat message to one user.
- `ZMVideoSDKErrors_Success` means request accepted; sender will receive `onChatNewMessageNotify` for this self-sent message, and this callback is the success signal.
- Preconditions:
  - `user` is not nil.
  - `msgContent` is non-empty.
  - user is valid in current session mapping.
- Typical errors:
  - `ZMVideoSDKErrors_Invalid_Parameter`
  - `ZMVideoSDKErrors_Internal_Error`
  - mapped bridge errors such as `Wrong_Usage`, `Session_No_Rights`, `Dont_Support_Feature`, `Call_Too_Frequently`

### `- (ZMVideoSDKErrors)sendChatToAll:(NSString *)msgContent`
- Sends chat message to all participants.
- `ZMVideoSDKErrors_Success` means request accepted; sender will receive `onChatNewMessageNotify` for this self-sent message, and this callback is the success signal.
- Preconditions:
  - `msgContent` is non-empty.
- Typical errors:
  - `ZMVideoSDKErrors_Invalid_Parameter`
  - `ZMVideoSDKErrors_SessionService_Invalid`
  - mapped bridge errors such as `Wrong_Usage`, `Session_No_Rights`, `Dont_Support_Feature`, `Call_Too_Frequently`

### `- (BOOL)canChatMessageBeDeleted:(NSString *)msgID`
- Returns whether a message can be deleted.
- `NO` when `msgID` is invalid or helper unavailable.

### `- (ZMVideoSDKErrors)deleteChatMessage:(NSString *)msgID`
- Deletes a message on Zoom server.
- Note: this does **not** remove local UI message item automatically.
- Preconditions:
  - `msgID` is non-empty.
- Typical errors:
  - `ZMVideoSDKErrors_Invalid_Parameter`
  - `ZMVideoSDKErrors_SessionService_Invalid`
  - mapped bridge errors such as `No_Rights` / `Wrong_Usage`

### `- (ZMVideoSDKErrors)changeChatPrivilege:(ZMVideoSDKChatPrivilegeType)privilege`
- Sets attendee chat privilege.
- Only host/manager-equivalent role can apply privilege changes.
- Effective privilege should be treated as updated when `onChatPrivilegeChanged` fires.
- Typical errors:
  - `ZMVideoSDKErrors_Invalid_Parameter`
  - `ZMVideoSDKErrors_SessionService_Invalid`
  - mapped bridge errors such as `Session_No_Rights`, `Call_Too_Frequently`, `Dont_Support_Feature`

### `- (ZMVideoSDKChatPrivilegeType)getChatPrivilege`
- Gets current attendee chat privilege.
- Returns `ZMVideoSDKChatPrivilegeType_Unknown` if helper unavailable.

## Callbacks
### `- (void)onChatNewMessageNotify:(ZMVideoSDKChatHelper*)chatHelper chatMessage:(ZMVideoSDKChatMessage*)chatMessage`
- New chat message event.
- Thread: main thread.
- Lifetime: `chatMessage` is valid only during callback scope.
- For self-send flow, sender is guaranteed to receive this callback; it is the success signal for `sendChatToUser` / `sendChatToAll`.

### `- (void)onChatMsgDeleteNotification:(ZMVideoSDKChatHelper*)chatHelper messageID:(NSString*)msgID deleteBy:(ZMVideoSDKChatMessageDeleteType)type`
- Message delete notification event.
- Thread: main thread.

### `- (void)onChatPrivilegeChanged:(ZMVideoSDKChatHelper*)chatHelper chatPrivilegeType:(ZMVideoSDKChatPrivilegeType)privilege`
- Privilege update event.
- Thread: main thread.
- Use this callback as the effective transition point for chat privilege.

## Error Handling
- Validate all inputs before calling APIs.
- Do not treat immediate `Success` from send APIs as final send success; wait for `onChatNewMessageNotify`.
- `Call_Too_Frequently`: avoid immediate retry.
- `Invalid_Parameter`: fix inputs before retry.
- `SessionService_Invalid` / `Internal_Error`: recover lifecycle/service state first.
- Message content may be truncated by backend-side logic in some paths; callers should not assume full-length delivery.

## Examples
### Send to user safely
```objective-c
ZMVideoSDKChatHelper *chat = [[ZMVideoSDK sharedVideoSDK] getChatHelper];
if (!chat || !user || content.length == 0) return;
ZMVideoSDKErrors err = [chat sendChatToUser:user content:content];
if (err == ZMVideoSDKErrors_Call_Too_Frequently) {
    // avoid immediate retry
    return;
}
if (err != ZMVideoSDKErrors_Success) return;
// wait for onChatNewMessageNotify to confirm self-send success
```

### Change chat privilege with callback-driven state
```objective-c
ZMVideoSDKErrors err = [chat changeChatPrivilege:ZMVideoSDKChatPrivilegeType_Publicly];
if (err != ZMVideoSDKErrors_Success) return;
// wait for onChatPrivilegeChanged callback before treating privilege as effective
```

## Examples

Structured snippets: this module's **`*-API.json`** → `examples` and `codeSnippets`.
