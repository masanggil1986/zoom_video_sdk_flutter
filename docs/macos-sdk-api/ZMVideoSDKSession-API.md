# ZMVideoSDKSession API Documentation

## Module Information
- **Module:** Zoom Video SDK Session (includes nested file-transfer and statistic types)
- **Platform:** macOS
- **Language:** Objective-C
- **Version:** 2.5.5
- **Header file:** `ZMVideoSDKSession.h`
- **Related:** `ZMVideoSDKFileTransferStatus`, `ZMVideoSDKSessionType` in `ZMVideoSDKDef.h`. File transfer progress is reported via `ZMVideoSDKDelegate` — **`onSendFile:status:`** and **`onReceiveFile:status:`** (both on the **main thread**).

## JSON callback fields (`ZMVideoSDKSession-API.json`)

zmVideoSDKDelegateCallbacks: ZMVideoSDKDelegate (ZMVideoSDKDelegate.h). Async outcomes are listed here only.

Column semantics: see the paired `*-API.json` (`async`, `zmVideoSDKDelegateCallbacks`, `callbackFieldDoc`, and per-API notes).

## Overview
`ZMVideoSDKSession` exposes **session metadata** (number, name, password, host, remote users, self user, session type), **session-level audio/video/share statistics**, and **in-session file transfer** (broadcast to all participants when enabled). Sending uses `transferFile:`; the SDK surfaces an outbound handle via `onSendFile:`. Receiving uses `ZMVideoSDKReceiveFile` from `onReceiveFile:` plus `startReceive:` with a **full download path** (directory + filename + extension).

**Before `onSessionJoin`:** After `joinSession:` returns a session, you can call **`[[ZMVideoSDK sharedVideoSDK] getSessionInfo]`** and **`[session getMySelf]`** to read the local user when the SDK exposes it—useful for pre-join UI. **`getSessionInfo`** is `nil` if the SDK is not initialized or there is no active session. Remote users, statistics, and file transfer should still be treated as authoritative only after **`onSessionJoin`** / confirmed in-session state.

**Local user (`getMySelf`) before full join / after leave:** Some **view-based** operations tied to the local user’s **`ZMVideoSDKVideoCanvas`** can still be meaningful when **`[session getMySelf]`** is non-nil and a container view is already subscribed and rendering—for example **`takeSnapshot:`** captures whatever is currently drawn in that **`NSView`** (not a separate “session RPC”). The same pattern can apply in a **short window after `onSessionLeave`** if the view still holds the last frame before teardown. Do **not** treat this as “session APIs still valid after leave”; **`ZMVideoSDKSession`** and roster/file APIs remain invalid after leave per lifecycle rules. See **[ZMVideoSDKVideoCanvas-API](./ZMVideoSDKVideoCanvas-API.md)** for **`takeSnapshot:`** threading and failure (`nil`) behavior.

**File send:** **`[session transferFile:]`** sends to **everyone** in the session. To send to **one** participant, use **`ZMVideoSDKUserHelper`** **`transferFile:`** (see UserHelper documentation). For session-wide sends, **`ZMVideoSDKSendFile.receiver`** is often **`nil`**.

## Lifecycle
### Prerequisites
1. SDK initialized; session handle from `joinSession:` (non-`nil` return) or from **`getSessionInfo`** while joining or in session.
2. **Fully in-session** behavior (remote users, stats, file transfer, etc.): confirm with `onSessionJoin` / `isInSession` per `ZMVideoSDK` docs.
3. Session reference is valid only while the user remains in that session context until `onSessionLeave`.

### Implicit side effects
- **onSessionLeave:** Session object and any `ZMVideoSDKSendFile` / `ZMVideoSDKReceiveFile` instances must be treated as invalid; in-flight transfers are undefined.
- **onUserHostChanged:** `getSessionID` is **host-only**; after host change, non-hosts may receive `nil` from `getSessionID`.

## Session information APIs (`ZMVideoSDKSession`)

| Method | Description |
|--------|-------------|
| `getSessionNumber` | Current session number; `0` on failure. |
| `getSessionName` | Session name or `nil`. |
| `getSessionPassword` | Session password or `nil`. |
| `getSessionPhonePasscode` | Phone passcode or `nil`. |
| `getSessionID` | Session ID or `nil`. **Host only.** |
| `getSessionHostName` | Host display name or `nil`. |
| `getSessionHost` | Host `ZMVideoSDKUser` or `nil`. |
| `getRemoteUsers` | Remote participants or `nil`. |
| `getMySelf` | Local **`ZMVideoSDKUser`** or `nil`. May be available on the session from `getSessionInfo` / `joinSession:` before `onSessionJoin` when the SDK provides it. |
| `getSessionType` | `ZMVideoSDKSessionType` (`MainSession`, `SubSession`). |

## Statistics APIs
| Method | Returns |
|--------|---------|
| `getSessionAudioStatisticInfo` | `ZMVideoSDKSessionAudioStatisticInfo` (send/recv frequency, latency, jitter, packet loss) or `nil`. |
| `getSessionVideoStatisticInfo` | `ZMVideoSDKSessionASVStatisticInfo` for video (resolution, FPS, latency, jitter, packet loss) or `nil`. |
| `getSessionShareStatisticInfo` | Same shape for screen share statistics or `nil`. |

## File transfer APIs (`ZMVideoSDKSession`)
| Method | Description |
|--------|-------------|
| `isFileTransferEnabled` | Whether file transfer is allowed in this session. |
| `transferFile:` | Sends the file to **all** participants. For a **single** recipient, use **`ZMVideoSDKUserHelper`** **`transferFile:`**. `filePath` = local path. Returns `ZMVideoSDKErrors`. **JSON:** `zmVideoSDKDelegateCallbacks`: **`onSendFile:status:`**; progress in `sendFile.status` while callbacks fire. |
| `getTransferFileTypeWhiteList` | Comma-separated allowed extensions; executable types are forbidden by default; `nil` on failure. |
| `getMaxTransferFileSize` | Maximum transfer size in bytes. |

## `ZMVideoSDKSendFile` (outbound)
| Property / method | Description |
|-------------------|-------------|
| `timeStamp`, `isSendToAll`, `fileSize`, `fileName`, `status`, `receiver` | Transfer metadata and `ZMVideoSDKFileStatus`. For session **send-to-all**, **`receiver`** is commonly **`nil`**. |
| `cancelSend` | Cancel send; returns `ZMVideoSDKErrors`. **JSON:** `zmVideoSDKDelegateCallbacks`: **`onSendFile:status:`**. |

## `ZMVideoSDKReceiveFile` (inbound)
| Property / method | Description |
|-------------------|-------------|
| `timeStamp`, `isSendToAll`, `fileSize`, `fileName`, `status`, `sender` | Same pattern as send side. |
| `startReceive:` | **Full path** including file name and extension. **JSON:** `zmVideoSDKDelegateCallbacks`: **`onReceiveFile:status:`**. |
| `cancelReceive` | Cancel inbound transfer. **JSON:** `zmVideoSDKDelegateCallbacks`: **`onReceiveFile:status:`**. |

## `ZMVideoSDKFileTransferStatus`
- **None**, **ReadyToTransfer**, **Transfering**, **TransferFailed**, **TransferDone** — surfaced on `sendFile.status.transStatus` / delegate `status` parameter.

## Callbacks (`ZMVideoSDKDelegate`)
**`onSendFile:status:`** and **`onReceiveFile:status:`** are invoked on the **main thread**; safe to update **AppKit** UI directly from these callbacks.
- **`onSendFile:status:`** — Outbound transfer state changes; use `sendFile` and `status` to track progress (`sendFile.status.transProgress`: ratio, completeSize, bitPreSecond).
- **`onReceiveFile:status:`** — Inbound transfer; call `startReceive:` when appropriate (e.g. after **ReadyToTransfer** per your product flow).

## Error handling
- `transferFile:`, `startReceive:`, `cancelSend`, `cancelReceive` return `ZMVideoSDKErrors`. Common causes: disabled feature, invalid path, size/type policy violation, wrong session state.
- After errors, re-check `isFileTransferEnabled`, whitelist, and `getMaxTransferFileSize` before retry.

## Rules
- Pass a **complete** `downloadPath` for `startReceive:` (directory + filename + extension).
- Do **not** retain or use `ZMVideoSDKSendFile` / `ZMVideoSDKReceiveFile` after session leave.
- `getSessionID` is for **host** only; others get `nil`.

## Examples

### Local user before `onSessionJoin`
```objc
ZMVideoSDKSession *s = [[ZMVideoSDK sharedVideoSDK] getSessionInfo];
ZMVideoSDKUser *me = [s getMySelf];
// Optional early self info when joining
```

### Session info
```objc
unsigned long long num = [session getSessionNumber];
NSString *name = [session getSessionName];
ZMVideoSDKUser *host = [session getSessionHost];
```

### Send file to all
```objc
if (![session isFileTransferEnabled]) return;
ZMVideoSDKErrors err = [session transferFile:@"/path/to/file.pdf"];
// Track progress in onSendFile:status:
```

### Receive file
```objc
- (void)onReceiveFile:(ZMVideoSDKReceiveFile *)receiveFile status:(ZMVideoSDKFileTransferStatus)status {
    NSString *path = [@"/tmp/Downloads" stringByAppendingPathComponent:receiveFile.fileName];
    [receiveFile startReceive:path];
}
```

Structured snippets: this module's **`*-API.json`** → `examples` and `codeSnippets`.
