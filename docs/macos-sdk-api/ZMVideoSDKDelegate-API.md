# ZMVideoSDKDelegate API Documentation

## Module Information
- Module: Zoom Video SDK Delegate
- Platform: macOS
- Language: Objective-C
- Version: 2.5.5
- Header File: `ZMVideoSDKDelegate.h`

## JSON callback fields (`ZMVideoSDKDelegate-API.json`)

This module lists ZMVideoSDKDelegate selectors; per-feature *-API.json files reference them via zmVideoSDKDelegateCallbacks / MayFollow.

Column semantics: see the paired `*-API.json` (`async`, `zmVideoSDKDelegateCallbacks`, `callbackFieldDoc`, and per-API notes).

## Overview
`ZMVideoSDKDelegate` is the central callback protocol for session lifecycle, user/media status, chat/command, recording, annotation, networking, subsession, broadcast, and real-time media stream events.

This document covers all callbacks defined in `ZMVideoSDKDelegate.h`.

## Lifecycle
### Prerequisites
1. SDK initialized.
2. Delegate object registered to SDK.
3. Session joined for in-session callbacks.

### Availability Boundary
- Callback availability starts after delegate registration and session lifecycle progression.
- After `onSessionLeave`, in-flight delegate delivery for prior requests is not guaranteed.

### Confirmed Session-Leave Side Effect
- Core cleanup and callback dispatch are asynchronous in multiple paths.
- App should stop waiting for pending feature callbacks after `onSessionLeave`.

### Confirmed Host-Transfer Side Effect
- `onUserHostChanged` is a role-change notification.
- It does not itself enforce auto-cancel of unrelated in-progress operations.
- Permission-sensitive behavior is re-evaluated when subsequent helper APIs are called.

## Threading and Parameter Lifetime
### Threading Model
- Not all callbacks have a strict global main-thread guarantee from code paths.
- Many events are posted to main thread, but there are also direct-dispatch paths.
- For UI safety, dispatch to main thread inside delegate handlers when updating UI.
- `onSharedAudioRawDataReceived:` is **not** guaranteed on the main thread (shared-audio raw path may run off main).

### Parameter Lifetime Rules
- Header-explicit temporary objects are callback-scoped:
  - `onProxySettingNotification` handler
  - `onSSLCertVerifiedFailNotification` info
  - `onQOSStatisticsReceived` codec-related internals
- `onChatNewMessageNotify` `chatMessage` is callback-scoped in ObjC wrapper dispatch path.
- Other user/helper objects are generally session objects; still avoid long-term assumptions beyond session validity.

## State Machine
`ZMVideoSDKDelegate` itself is event-driven and does not define an independent API state machine.  
State transitions are represented by callback sequences from feature modules.

## Callback Catalog (All)
### Session / Error
- `onSessionJoin`
- `onSessionLeave` (deprecated)
- `onSessionLeave:`
- `onError:detail:`
- `onSessionNeedPassword:`
- `onSessionPasswordWrong:`

### User / Role / Presence
- `onUserJoin:userList:`
- `onUserLeave:userList:`
- `onUserHostChanged:user:`
- `onUserManagerChanged:`
- `onUserNameChanged:`
- `onUserActiveAudioChanged:userList:`

### Audio / Device / Raw Audio
- `onUserAudioStatusChanged:userList:`
- `onMixedAudioRawDataReceived:`
- `onOneWayAudioRawDataReceived:user:`
- `onSharedAudioRawDataReceived:`
- `onAudioLevelChanged:audioSharing:user:`
- `onMicSpeakerVolumeChanged:speakerVolume:`
- `onAudioDeviceStatusChanged:status:`
- `onTestMicStatusChanged:`
- `onSelectedAudioDeviceChanged`
- `onHostAskUnmute`

### Video / Canvas / Snapshot
- `onUserVideoStatusChanged:userList:`
- `onCameraListChanged`
- **`onVideoCanvasSubscribeFail:user:view:`** — May fire **after** `[canvas subscribeWithView:aspectMode:resolution:]` returns **Success** (late subscribe failure). Related: **[ZMVideoSDKVideoCanvas-API](./ZMVideoSDKVideoCanvas-API.md)**.
- **`onShareCanvasSubscribeFail:view:shareAction:`** — Share-canvas subscribe failure; same doc for **`ZMVideoSDKVideoCanvas`** share path.
- `onVideoAlphaChannelStatusChanged:`
- `onSpotlightVideoChanged:userList:`
- `onCanvasSnapshotTaken:isShare:`
- `onCanvasSnapshotIncompatible:`

### Share / Remote Control / Annotation / Whiteboard
- `onUserShareStatusChanged:user:shareAction:`
- `onShareContentSizeChanged:user:shareAction:`
- `onShareContentChanged:user:shareAction:`
- `onUnsharingWindowsChanged:shareHelper:user:shareAction:`
- `onSharingActiveMonitorChanged:shareHelper:user:shareAction:`
- `onFailedToStartShare:user:`
- `onShareSettingChanged:`
- `onShareCanvasSubscribeFail:view:shareAction:`
- `onRemoteControlStatus:user:shareAction:`
- `onRemoteControlRequestReceived:shareAction:handler:`
- `onAnnotationHelperCleanUp:`
- `onAnnotationPrivilegeChange:shareAction:`
- `onAnnotationHelperActived:`
- `onAnnotationToolTypeChanged:view:toolType:`
- `onUserWhiteboardShareStatusChanged:whiteboardHelper:`
- `onWhiteboardExported:data:dataLength:`

### Chat / Command / CRC
- `onChatNewMessageNotify:chatMessage:`
- `onChatMsgDeleteNotification:messageID:deleteBy:`
- `onChatPrivilegeChanged:chatPrivilegeType:`
- `onCommandChannelConnectResult:`
- `onCommandReceived:senderUser:`
- `onCallCRCDeviceStatusChanged:`

### Recording / Phone
- `onCloudRecordingStatus:recordingConsentHandler:`
- `onUserRecordingConsent:`
- `onInviteByPhoneStatus:reason:`
- `onCalloutJoinSuccess:phoneNumber:`
- `onCameraControlRequestResult:approved:`
- `onCameraControlRequestReceived:cameraControlRequestType:requestHandler:`

### Transcription / Language
- `onLiveTranscriptionStatus:`
- `onLiveTranscriptionMsgInfoReceived:`
- `onOriginalLanguageMsgReceived:`
- `onLiveTranscriptionMsgError:transcriptLanguage:`
- `onSpokenLanguageChanged:`

### Network / QoS / Proxy / SSL
- `onProxyDetectComplete`
- `onProxySettingNotification:`
- `onSSLCertVerifiedFailNotification:`
- `onUserVideoNetworkStatusChanged:user:` (deprecated)
- `onShareNetworkStatusChanged:isSendingShare:` (deprecated)
- `onUserNetworkStatusChanged:level:user:`
- `onUserOverallNetworkStatusChanged:user:`
- `onQOSStatisticsReceived:user:`

### File Transfer
- `onSendFile:status:`
- `onReceiveFile:status:`

### Incoming Live Stream / Broadcast
- `onBindIncomingLiveStreamResponse:streamKeyID:`
- `onUnbindIncomingLiveStreamResponse:streamKeyID:`
- `onIncomingLiveStreamStatusResponse:streamsStatusList:`
- `onStartIncomingLiveStreamResponse:streamKeyID:`
- `onStopIncomingLiveStreamResponse:streamKeyID:`
- `onStartBroadcastResponse:channelID:`
- `onStopBroadcastResponse:`
- `onGetBroadcastControlStatus:broadcastControlStatus:`
- `onStreamingJoinStatusChanged:`

### Subsession
- `onSubSessionStatusChanged:subSessionKit:`
- `onSubSessionManagerHandle:`
- `onSubSessionParticipantHandle:`
- `onSubSessionUsersUpdate:`
- `onBroadcastMessageFromMainSession:userName:`
- `onSubSessionUserHelpRequest:`
- `onSubSessionUserHelpRequestResult:`

### Real-Time Media Streams
- `onRealTimeMediaStreamsStatusChanged:`
- `onRealTimeMediaStreamsFail:`

## Error Handling Guidance
- `onError:detail:` is generic error surface; map handling by `ZMVideoSDKErrors`.
- For `Call_Too_Frequently`: avoid immediate retry.
- For `Session_No_Rights`: re-check host/cohost/manager role after role-change callbacks.
- For `Invalid_Parameter`: fix input and retry.

## Rules
- Do not assume callback order across independent feature domains.
- Do not assume callback always on main thread.
- After `onSessionLeave`, invalidate waiting states for pending feature callbacks.
- Handle deprecated callbacks only for backward compatibility; prefer the new replacements.

## Examples
### Example 1: Main-thread safe UI update
```objective-c
- (void)onUserJoin:(ZMVideoSDKUserHelper *)userHelper userList:(NSArray<ZMVideoSDKUser *> *)userArray {
    dispatch_async(dispatch_get_main_queue(), ^{
        // update UI safely
    });
}
```

### Example 2: Session-leave boundary guard
```objective-c
- (void)onSessionLeave:(ZMVideoSDKSessionLeaveReason)reason {
    self.isSessionActive = NO;
    // clear pending waits/timeouts for in-flight operations
}
```

### Example 3: Temporary callback object usage
```objective-c
- (void)onProxySettingNotification:(ZMVideoSDKProxySettingHandler *)handler {
    // configure immediately in callback scope
    [handler setProxyUsername:@"user"];
}
```

## Examples

Structured snippets: this module's **`*-API.json`** → `examples` and `codeSnippets`.
