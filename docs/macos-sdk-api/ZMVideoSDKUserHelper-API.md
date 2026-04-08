# ZMVideoSDKUserHelper API Documentation

## Module Information
| Field | Value |
|-------|--------|
| Module | User Helper (same header: `ZMVideoSDKUser`, `ZMVideoSDKRawDataPipe`, QOS types, remote camera types) |
| Platform | macOS |
| Language | Objective-C |
| Version | 2.5.5 |
| Header | `ZMVideoSDKUserHelper.h` |

## JSON callback fields (`ZMVideoSDKUserHelper-API.json`)

- **`zmVideoSDKDelegateCallbacks`**: primary `ZMVideoSDKDelegate` follow-ups after async **Success** (empty array `[]` when none).
- **`zmVideoSDKDelegateCallbacksMayFollow`**: optional or order-dependent delegate methods (e.g. camera approve/decline affecting the requester).
- **`callbackSemantics`**: short explanation when the delegate list is empty or split across protocols.
- **`otherProtocolCallbacks`**: listener-owned protocols (e.g. **`ZMVideoSDKRawDataPipeDelegate`**). Raw pipe subscribe/unsubscribe uses these; **`zmVideoSDKDelegateCallbacks`** is `[]` there.

Column semantics: see the paired `*-API.json` (`async`, `zmVideoSDKDelegateCallbacks`, `callbackFieldDoc`, and per-API notes).

## Overview
- **`ZMVideoSDKUserHelper`** — Session control: rename users, assign host/manager, revoke manager, remove user, reclaim host. Obtained via `[[ZMVideoSDK sharedVideoSDK] getUserHelper]`.
- **`ZMVideoSDKUser`** — Per-participant APIs: identity, audio/video/share stats, **`getVideoCanvas`** (see **[ZMVideoSDKVideoCanvas-API](./ZMVideoSDKVideoCanvas-API.md)**), raw pipes, single-user file transfer, local playback volume, network level, remote camera helper (remote users only), etc. For **local self** (`getMySelf`), canvas **`takeSnapshot:`** can be usable **before `onSessionJoin`** or **briefly after leave** when the subscribed view still has rendered content—see **Session** and **VideoCanvas** docs; session-level APIs still follow join/leave rules.
- **`ZMVideoSDKRawDataPipe`** — Subscribe/unsubscribe raw YUV (video or share) per pipe; resolution must be in the supported enum range (see **Raw data subscribe** below).
- User **enumeration** is on **`ZMVideoSDKSession`**: `getRemoteUsers`, `getMySelf` from `getSessionInfo` — not on `UserHelper`.

Host/manager/remove rules below match the shared Video SDK user-helper logic used by the macOS wrapper.

## Lifecycle
### Prerequisites
1. SDK initialized; in session for user objects and host operations.
2. **`ZMVideoSDKUser` validity**: Valid while the user is in the session. After leave, do not use the reference. On conference leave, user objects and pipes are torn down in the SDK.
3. **Raw data**: Call `unSubscribe:` with the same listener before releasing the listener or leaving the session.

### Entry / exit
- **Entry:** Session joined; user list from session; `getUserHelper` non-nil when SDK ready.
- **Exit:** `onSessionLeave` — drop all user references; unsubscribe raw listeners first.

## State machine (conceptual)
| State | Notes |
|-------|--------|
| User valid | User in roster; safe for getters and pipes. |
| User left | Do not call APIs on that `ZMVideoSDKUser`. |
| Raw subscribed | After `subscribe:listener:` succeeds; frames via delegate; must `unSubscribe:` before listener teardown. |

---

## ZMVideoSDKUserHelper APIs

### `changeName:user:` → `BOOL`
| Condition | Result |
|-----------|--------|
| `name` nil/empty (macOS wrapper) | `NO` |
| `user` nil / user not tracked by SDK | `NO` |
| Target is **incoming live stream user** | `NO` |
| **Rename self** (same user as caller or internal id 0 path) | Uses rename-self path (no host/co-host required for self). |
| **Rename another user** | Caller must be **host or co-host**. **Not allowed** if target is **host**, or if target is **co-host and caller is co-host** (co-host cannot rename another co-host or host). |
| Not in session / no conference | `NO` |

### `makeHost:` → `BOOL`
- **Host only** (caller must be host, not merely co-host).
- Target must not be self; not incoming live stream user.
- `NO` if nil user, not in session, or not host.

### `makeManager:` → `BOOL`
- **Host only**; target not self; not incoming live stream user.

### `revokeManager:` → `ZMVideoSDKErrors`
| Code (typical) | When |
|----------------|------|
| `Invalid_Parameter` | nil user, user not in map (macOS), or invalid internal user id |
| `SessionService_Invalid` | Helper/manager unavailable (macOS wrapper) |
| `Uninitialize` | No active conference instance |
| `Wrong_Usage` | Revoking self; or target is **host**; or target is **not** a manager |
| `Session_No_Rights` | Caller is not host |
| After revoke | Mapped from meeting-bridge last error (may include other SDK errors) |

### `removeUser:` → `BOOL`
- Caller **host or co-host**.
- **Co-host cannot** remove **host** or **another co-host**.
- Cannot remove **self**; cannot remove **incoming live stream user**.

### `reclaimHost` → `BOOL`
- Delegates to session reclaim-host action; `NO` if conference unavailable or action fails.

---

## ZMVideoSDKUser — selected behavior (from implementation)

### `getRemoteCameraControlHelper`
- Returns **non-nil only for remote users** (not for the local user). For self, use flow appropriate to being the controlled party.

### `transferFile:`
- `Invalid_Parameter` if path nil.
- `Internal_Error` if chat helper unavailable.
- `Dont_Support_Feature` if file transfer disabled for the session.
- Otherwise maps chat bridge result when sending to that user’s id (outcome via **`onSendFile:status:`**; JSON `zmVideoSDKDelegateCallbacks` on that API).

### Volume APIs (`setUserPlaybackVolume:…`, etc.)
- Local playback only; does not change how others hear the user. Range **0…10** per header.

### Identity
- Prefer **`getUserKey`** over deprecated **`getCustomIdentity`** (same underlying value in implementation).

### Full `ZMVideoSDKUser` surface (header)
`getUserID`, `getUserKey` / deprecated `getCustomIdentity`, `getUserName`, `getUserReference`, `getAudioStatus`, `isHost`, `isManager`, `getVideoStatisticInfo`, `getShareStatisticInfo`, `getVideoPipe`, `getVideoCanvas`, `getShareActionList`, `getRemoteCameraControlHelper`, `getMultiCameraStreamList`, deprecated volume trio, `setUserPlaybackVolume:isSharingAudio:`, `getUserPlaybackVolume:isSharingAudio:`, `canSetUserPlaybackVolume:`, `getAudioLevel`, `hasIndividualRecordingConsent`, `transferFile:`, `isVideoSpotLighted`, `isIncomingLiveStreamUser`, `isInSubSession`, `getWhiteboardStatus`, `getNetworkLevel:`, `getOverallNetworkLevel`.

---

## ZMVideoSDKRawDataPipe

### `subscribe:listener:`
- **`Invalid_Parameter`**: nil listener, or **resolution outside supported range** (implementation accepts from **90P through 1080P** inclusive; out-of-range fails).
- **`Internal_Error`**: raw-data manager not available (e.g. build/feature path).
- Success starts subscription; frames arrive asynchronously on **`ZMVideoSDKRawDataPipeDelegate`** (not guaranteed main thread; see raw-data delegate doc).

### `unSubscribe:`
- **`Invalid_Parameter`** if nil listener.
- **`ZMVideoSDKErrors_Success`** means the unsubscribe request was accepted; **frame and share-cursor callbacks stop asynchronously** — do not release the listener until you no longer rely on in-flight callbacks. **`onRawDataStatusChanged:`** may still fire to reflect updated pipe status.

### Queries
- `getVideoStatus`, `getShareStatus`, `getShareCapturePauseReason`, `getShareType`, `getVideoStatisticInfo`, `getVideoDeviceName`, `getRawdataType` — synchronous snapshots; share pipe reflects share state held on the pipe.

---

## Types (`typeDefinitions` in JSON)

Machine-readable property/method lists: **`ZMVideoSDKUserHelper-API.json`** → `typeDefinitions`. Below is a human summary aligned with **`ZMVideoSDKUserHelper.h`**.

### Status & QOS
- **ZMVideoSDKVideoStatus** — `isHasVideoDevice`, `isOn`.
- **ZMVideoSDKAudioStatus** — `audioType`, `isMuted`, `isTalking`.
- **ZMVideoSDKQOSStatistics** — `direction`, `timestamp`, `codecName`, `rtt`, `jitter`, `width`, `height`, `fps`, `bps`, `bytesTransferred`, `packetsLost`, `packetsTransferred`, `networkLevel`, `statisticsType`, `avg_loss`, `max_loss`, `bandwidth`. **`codecName` valid only during `onQOSStatisticsReceived:user:`** (see header).
- **ZMVideoSDKQOSSendStatistics** *(extends QOSStatistics)* — `frameWidthInput`, `frameHeightInput`, `frameRateInput`, `bytesSent`, `packetsSent`, `totalPacketSendDelay`, `totalEncodeTime`, `framesEncoded`.
- **ZMVideoSDKQOSRecvStatistics** *(extends QOSStatistics)* — `bytesReceived`, `packetsReceived`, `estimatedPlayoutTimestamp`, `totalDecodeTime`, `framesDecoded`, `jitterBufferDelay`, `jitterBufferEmittedCount`.
- **ZMVideoSDKVideoStatisticInfo** / **ZMVideoSDKShareStatisticInfo** — inherit QOS base fields; deprecated: **`bpf`** (use **`bps`**), **`videoNetworkStatus`** / **`shareNetworkStatus`** (use **`networkLevel`**).

### Raw video / share data
- **ZMVideoSDKYUVRawDataI420** — `yBuffer`, `uBuffer`, `vBuffer`, `buffer`, `alphaBuffer`, `bufferLen`, `alphaBufferLen`, `isLimitedI420`, `streamWidth`, `streamHeight`, `rotation`, `resourceID`, `timeStamp`; **`canAddRef`**, **`addRef`**, **`releaseRef`** for lifetime beyond callback.
- **ZMVideoSDKShareCursorData** — `sourceID`, `x`, `y`.
- **ZMVideoSDKRawDataPipeDelegate** *(protocol, `@optional`)* — `onRawDataFrameReceived:`, `onRawDataStatusChanged:`, `onShareCursorDataReceived:`.
- **ZMVideoSDKRawDataPipe** — `subscribe:listener:`, `unSubscribe:`, `getRawdataType`, `getVideoStatus`, `getVideoDeviceName`, `getShareStatus`, `getShareCapturePauseReason`, `getShareType`, `getVideoStatisticInfo`.

### User, helper, remote camera
- **ZMVideoSDKUser** — full method surface is listed under **Full `ZMVideoSDKUser` surface** above and in JSON `apis` keys `ZMVideoSDKUser.*`.
- **ZMVideoSDKUserHelper** — `changeName:user:`, `makeHost:`, `makeManager:`, `revokeManager:`, `removeUser:`, `reclaimHost`.
- **ZMVideoSDKRemoteCameraControlHelper** — `requestControlRemoteCamera`, `giveUpControlRemoteCamera`, `turnLeft:`, `turnRight:`, `turnUp:`, `turnDown:`, `zoomIn:`, `zoomOut:` (range `10…100` per header).
- **ZMVideoSDKCameraControlRequestHandler** — `approve`, `decline` (use inside `onCameraControlRequestReceived:…` flow).

---

## Callbacks (ZMVideoSDKDelegate — relevant)
- Roster / roles: `onUserJoin`, `onUserLeave`, `onUserNameChanged`, `onUserManagerChanged`, `onUserHostChanged`.
- A/V: `onUserVideoStatusChanged:userList:`, `onUserAudioStatusChanged:userList:`.
- QOS: `onQOSStatisticsReceived:user:` (temporary codec-related fields).
- File: `onSendFile:status:` for per-user `transferFile:`.
- Remote camera: `onCameraControlRequestReceived:…`, `onCameraControlRequestResult:…`.

Raw pipe: `onRawDataFrameReceived:`, `onRawDataStatusChanged:`, `onShareCursorDataReceived:` — see **`ZMVideoSDKRawDataPipeDelegate-API.md`**.

---

## Error handling & retry
- Host APIs returning `NO`: fix role, target user, and session state before retry.
- **`revokeManager:`**: handle `Invalid_Parameter`, `Wrong_Usage`, `Session_No_Rights`; on success still observe manager list via delegate.
- **`subscribe:`**: fix resolution and listener; backoff if rate-limited (generic SDK pattern).
- Do not retry in a tight loop on permission failures.

## Rules (required / forbidden)
1. Unsubscribe raw listeners before listener release or session leave.
2. Do not retain QOS codec strings or raw buffers beyond callback without `addRef`.
3. After host/co-host changes, re-check eligibility for host APIs.
4. Do not use `ZMVideoSDKUser` after the user has left.

## Examples
**Session users**
```objc
ZMVideoSDKSession *session = [[ZMVideoSDK sharedVideoSDK] getSessionInfo];
NSArray<ZMVideoSDKUser *> *others = [session getRemoteUsers];
ZMVideoSDKUser *me = [session getMySelf];
```

**Raw subscribe (valid resolution)**
```objc
ZMVideoSDKRawDataPipe *pipe = [remoteUser getVideoPipe];
if (!pipe) return;
ZMVideoSDKErrors e = [pipe subscribe:ZMVideoSDKResolution_720P listener:self];
if (e != ZMVideoSDKErrors_Success) { /* handle */ }
```

**Revoke manager (host)**
```objc
ZMVideoSDKUserHelper *h = [[ZMVideoSDK sharedVideoSDK] getUserHelper];
ZMVideoSDKErrors err = [h revokeManager:managerUser];
```

## Related
- `ZMVideoSDKSession-API.md`, `ZMVideoSDKRawDataPipeDelegate-API.md`, `ZMVideoSDKDelegate-API.md`.
