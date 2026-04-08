# ZMVideoSDKChatMessage API Documentation

## Module Information
- Module: Chat Message
- Platform: macOS
- Language: Objective-C
- Version: 2.5.5
- Header File: `ZMVideoSDKChatMessage.h`

## JSON callback fields (`ZMVideoSDKChatMessage-API.json`)

Message objects are short-lived in onChatNewMessageNotify; see ZMVideoSDKChatHelper-API.json for delegate-driven send/delete flows.

Column semantics: see the paired `*-API.json` (`async`, `zmVideoSDKDelegateCallbacks`, `callbackFieldDoc`, and per-API notes).

## Overview
`ZMVideoSDKChatMessage` is a read-only message model delivered by chat callbacks.
It provides a snapshot of one chat message:
- sender/receiver user references
- message content and message ID
- message timestamp
- flags for "chat to all" and "self send"

This model is callback-scoped: use it during the callback only.

## Lifecycle
### Prerequisites
1. SDK initialized.
2. Session joined.
3. Message object is created when `onChatNewMessageNotify` is fired.

### Availability Boundary
- `ZMVideoSDKChatMessage` is valid only during callback execution.
- After callback returns, app should not continue using the same object instance.

### Role and Permission
- Reading `ZMVideoSDKChatMessage` fields does not require host/manager role.
- Role differences affect send/privilege control in chat helper, not message model schema.

### Confirmed Session-Leave Side Effect
- After `onSessionLeave`, in-flight callback expectations should be dropped for message consumption.
- Existing `chatMessage` object should be considered invalid outside callback scope.

### Confirmed Host-Transfer Side Effect
- `onUserHostChanged` does not change `ZMVideoSDKChatMessage` schema.
- Already delivered message snapshots remain unchanged.

## State Machine
### Functional States
1. `NotAvailable`: before chat callback arrives.
2. `CallbackActive`: inside `onChatNewMessageNotify`.
3. `Expired`: after callback returns.

### Timing Rules
- State enters `CallbackActive` when callback starts.
- State becomes `Expired` immediately when callback returns.
- A new callback provides a new message snapshot object.

## APIs
### `@property (nonatomic, retain, readonly) ZMVideoSDKUser* sendUser`
- Purpose: message sender user object.
- Notes:
  - May be `nil` if sender cannot be resolved from current user map.

### `@property (nonatomic, retain, readonly) ZMVideoSDKUser* receiverUser`
- Purpose: message receiver user object.
- Notes:
  - May be `nil` if receiver cannot be resolved from current user map.
  - For chat-to-all message, receiver may be `nil`.

### `@property (nonatomic, copy, readonly) NSString* content`
- Purpose: message text content.
- Notes:
  - May be empty depending on upstream content.

### `@property (nonatomic, assign, readonly) time_t timeStamp`
- Purpose: message time in Unix epoch seconds.

### `@property (nonatomic, assign, readonly) BOOL isChatToAll`
- Purpose: whether message target is all participants.

### `@property (nonatomic, assign, readonly) BOOL isSelfSend`
- Purpose: whether current user is the sender.
- Notes:
  - For self-send flow, callback is guaranteed for sender.

### `@property (nonatomic, copy, readonly) NSString* messageID`
- Purpose: stable ID for message operations (for example deletion checks in chat helper).
- Notes:
  - May be empty if upstream does not provide message ID.

## Callbacks
### `- (void)onChatNewMessageNotify:(ZMVideoSDKChatHelper* _Nonnull)chatHelper chatMessage:(ZMVideoSDKChatMessage* _Nullable)chatMessage`
- Message callback for chat message delivery.
- Sender echo: if caller sends chat successfully, sender is guaranteed to receive this callback.

### Threading
- Confirmed policy for this module: callback is handled on the main thread.
- Message lifetime: `chatMessage` is valid only during callback.

## Error Handling
### General Policy
- `ZMVideoSDKChatMessage` itself has no error-return APIs.
- Handle nullable fields safely (`sendUser`, `receiverUser`, and nullable callback argument).

### Usage Guidance
- Do not retain/use `chatMessage` after callback returns.
- If data must be used later, copy required scalar/string values during callback.

## Rules
### Forbidden Sequences
- Access `chatMessage` fields after callback returned.
- Assume `sendUser` or `receiverUser` is always non-nil.

### Required Sequences
1. Wait for `onChatNewMessageNotify`.
2. Read needed fields inside callback.
3. Copy values if business logic needs post-callback usage.

## Examples
### Example 1: Safe callback consumption
```objective-c
- (void)onChatNewMessageNotify:(ZMVideoSDKChatHelper *)chatHelper
                   chatMessage:(ZMVideoSDKChatMessage *)chatMessage {
    if (!chatMessage) return;

    NSString *messageID = chatMessage.messageID ?: @"";
    NSString *content = chatMessage.content ?: @"";
    time_t ts = chatMessage.timeStamp; // Unix seconds
    BOOL selfSend = chatMessage.isSelfSend;
    BOOL toAll = chatMessage.isChatToAll;

    ZMVideoSDKUser *sender = chatMessage.sendUser;     // may be nil
    ZMVideoSDKUser *receiver = chatMessage.receiverUser; // may be nil

    // If needed beyond callback, copy values now.
    [self storeMessageID:messageID content:content timestamp:ts selfSend:selfSend toAll:toAll];
}
```

### Example 2: Sender-success confirmation
```objective-c
ZMVideoSDKErrors err = [chatHelper sendChatToUser:user content:text];
if (err != ZMVideoSDKErrors_Success) {
    return;
}
// Sending success is confirmed when onChatNewMessageNotify is received for self-send message.
```

## End-to-End Verified Flow
1. App joins session and registers delegate.
2. Caller sends message through chat helper and receives `ZMVideoSDKErrors_Success`.
3. SDK delivers `onChatNewMessageNotify` on main thread.
4. App reads `chatMessage` fields within callback scope.
5. App copies required values for post-callback usage instead of holding `chatMessage`.

## Examples

Structured snippets: this module's **`*-API.json`** → `examples` and `codeSnippets`.
