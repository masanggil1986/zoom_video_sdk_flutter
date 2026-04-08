#include "zoom_event_stream_handler.h"
#include "zoom_serializer.h"

namespace zoom_video_sdk_flutter {

ZoomEventStreamHandler::ZoomEventStreamHandler() {}
ZoomEventStreamHandler::~ZoomEventStreamHandler() {}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
ZoomEventStreamHandler::OnListenInternal(
    const flutter::EncodableValue* arguments,
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
  std::lock_guard<std::mutex> lock(sink_mutex_);
  event_sink_ = std::move(events);
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
ZoomEventStreamHandler::OnCancelInternal(
    const flutter::EncodableValue* arguments) {
  std::lock_guard<std::mutex> lock(sink_mutex_);
  event_sink_ = nullptr;
  return nullptr;
}

void ZoomEventStreamHandler::SendEvent(const std::string& type,
                                       const flutter::EncodableMap& data) {
  std::lock_guard<std::mutex> lock(sink_mutex_);
  if (!event_sink_) return;

  flutter::EncodableMap event;
  event[flutter::EncodableValue("eventType")] = flutter::EncodableValue(type);
  event[flutter::EncodableValue("data")] = flutter::EncodableValue(data);
  event_sink_->Success(flutter::EncodableValue(event));
}

// ---- IZoomVideoSDKDelegate: Flutter에 전달하는 핵심 이벤트 ----

void ZoomEventStreamHandler::onSessionJoin() {
  SendEvent("sessionJoined");
}

void ZoomEventStreamHandler::onSessionLeave() {
  SendEvent("sessionLeft");
}

void ZoomEventStreamHandler::onSessionLeave(ZoomVideoSDKSessionLeaveReason) {
  SendEvent("sessionLeft");
}

void ZoomEventStreamHandler::onError(ZoomVideoSDKErrors errorCode,
                                     int detailErrorCode) {
  flutter::EncodableMap data;
  data[flutter::EncodableValue("errorCode")] =
      flutter::EncodableValue(SerializeErrorCode(errorCode));
  data[flutter::EncodableValue("message")] =
      flutter::EncodableValue("error:" + std::to_string(errorCode) +
                              " detail:" + std::to_string(detailErrorCode));
  SendEvent("error", data);
}

void ZoomEventStreamHandler::onUserJoin(
    IZoomVideoSDKUserHelper*, IVideoSDKVector<IZoomVideoSDKUser*>* userList) {
  flutter::EncodableMap data;
  data[flutter::EncodableValue("users")] =
      flutter::EncodableValue(SerializeUserList(userList));
  SendEvent("userJoined", data);
}

void ZoomEventStreamHandler::onUserLeave(
    IZoomVideoSDKUserHelper*, IVideoSDKVector<IZoomVideoSDKUser*>* userList) {
  flutter::EncodableMap data;
  data[flutter::EncodableValue("users")] =
      flutter::EncodableValue(SerializeUserList(userList));
  SendEvent("userLeft", data);
}

void ZoomEventStreamHandler::onUserVideoStatusChanged(
    IZoomVideoSDKVideoHelper*,
    IVideoSDKVector<IZoomVideoSDKUser*>* userList) {
  if (!userList || userList->GetCount() == 0) return;
  flutter::EncodableMap data;
  data[flutter::EncodableValue("user")] =
      flutter::EncodableValue(SerializeUser(userList->GetItem(0)));
  SendEvent("userVideoStatusChanged", data);
}

void ZoomEventStreamHandler::onUserAudioStatusChanged(
    IZoomVideoSDKAudioHelper*,
    IVideoSDKVector<IZoomVideoSDKUser*>* userList) {
  if (!userList || userList->GetCount() == 0) return;
  flutter::EncodableMap data;
  data[flutter::EncodableValue("user")] =
      flutter::EncodableValue(SerializeUser(userList->GetItem(0)));
  SendEvent("userAudioStatusChanged", data);
}

void ZoomEventStreamHandler::onUserShareStatusChanged(
    IZoomVideoSDKShareHelper*, IZoomVideoSDKUser* pUser,
    IZoomVideoSDKShareAction* pShareAction) {
  if (!pUser) return;
  auto status = pShareAction ? pShareAction->getShareStatus()
                             : ZoomVideoSDKShareStatus_None;
  flutter::EncodableMap data;
  data[flutter::EncodableValue("user")] =
      flutter::EncodableValue(SerializeUser(pUser));
  data[flutter::EncodableValue("status")] =
      flutter::EncodableValue(SerializeShareStatus(status));
  SendEvent("userShareStatusChanged", data);
}

void ZoomEventStreamHandler::onChatNewMessageNotify(
    IZoomVideoSDKChatHelper*, IZoomVideoSDKChatMessage* messageItem) {
  if (!messageItem) return;
  flutter::EncodableMap data;
  data[flutter::EncodableValue("message")] =
      flutter::EncodableValue(SerializeChatMessage(messageItem));
  SendEvent("chatMessageReceived", data);
}

void ZoomEventStreamHandler::onUserHostChanged(IZoomVideoSDKUserHelper*,
                                               IZoomVideoSDKUser* pUser) {
  if (!pUser) return;
  flutter::EncodableMap data;
  data[flutter::EncodableValue("newHost")] =
      flutter::EncodableValue(SerializeUser(pUser));
  SendEvent("userHostChanged", data);
}

void ZoomEventStreamHandler::onUserActiveAudioChanged(
    IZoomVideoSDKAudioHelper*,
    IVideoSDKVector<IZoomVideoSDKUser*>* list) {
  flutter::EncodableMap data;
  data[flutter::EncodableValue("activeUsers")] =
      flutter::EncodableValue(SerializeUserList(list));
  SendEvent("userActiveAudioChanged", data);
}

void ZoomEventStreamHandler::onUserManagerChanged(IZoomVideoSDKUser* pUser) {
  if (!pUser) return;
  flutter::EncodableMap data;
  data[flutter::EncodableValue("user")] =
      flutter::EncodableValue(SerializeUser(pUser));
  data[flutter::EncodableValue("isManager")] =
      flutter::EncodableValue(pUser->isManager());
  SendEvent("userManagerChanged", data);
}

void ZoomEventStreamHandler::onUserNameChanged(IZoomVideoSDKUser* pUser) {
  if (!pUser) return;
  flutter::EncodableMap data;
  data[flutter::EncodableValue("user")] =
      flutter::EncodableValue(SerializeUser(pUser));
  SendEvent("userNameChanged", data);
}

void ZoomEventStreamHandler::onSessionNeedPassword(
    IZoomVideoSDKPasswordHandler*) {
  SendEvent("sessionNeedPassword");
}

void ZoomEventStreamHandler::onSessionPasswordWrong(
    IZoomVideoSDKPasswordHandler*) {
  SendEvent("sessionPasswordWrong");
}

// ---- 아래는 Flutter에 직접 전달하지 않는 콜백 (빈 구현) ----

void ZoomEventStreamHandler::onShareContentChanged(
    IZoomVideoSDKShareHelper*, IZoomVideoSDKUser*, IZoomVideoSDKShareAction*) {}
void ZoomEventStreamHandler::onFailedToStartShare(
    IZoomVideoSDKShareHelper*, IZoomVideoSDKUser*) {}
void ZoomEventStreamHandler::onShareSettingChanged(ZoomVideoSDKShareSetting) {}
void ZoomEventStreamHandler::onUserRecordingConsent(IZoomVideoSDKUser*) {}
void ZoomEventStreamHandler::onLiveStreamStatusChanged(
    IZoomVideoSDKLiveStreamHelper*, ZoomVideoSDKLiveStreamStatus) {}
void ZoomEventStreamHandler::onMixedAudioRawDataReceived(AudioRawData*) {}
void ZoomEventStreamHandler::onOneWayAudioRawDataReceived(AudioRawData*,
                                                          IZoomVideoSDKUser*) {}
void ZoomEventStreamHandler::onSharedAudioRawDataReceived(AudioRawData*) {}
void ZoomEventStreamHandler::onCameraControlRequestResult(IZoomVideoSDKUser*,
                                                          bool) {}
void ZoomEventStreamHandler::onCameraControlRequestReceived(
    IZoomVideoSDKUser*, ZoomVideoSDKCameraControlRequestType,
    IZoomVideoSDKCameraControlRequestHandler*) {}
void ZoomEventStreamHandler::onRemoteControlStatus(
    IZoomVideoSDKUser*, IZoomVideoSDKShareAction*,
    ZoomVideoSDKRemoteControlStatus) {}
void ZoomEventStreamHandler::onRemoteControlRequestReceived(
    IZoomVideoSDKUser*, IZoomVideoSDKShareAction*,
    IZoomVideoSDKRemoteControlRequestHandler*) {}
void ZoomEventStreamHandler::onRemoteControlServiceInstallResult(bool) {}
void ZoomEventStreamHandler::onCommandReceived(IZoomVideoSDKUser*,
                                               const zchar_t*) {}
void ZoomEventStreamHandler::onCommandChannelConnectResult(bool) {}
void ZoomEventStreamHandler::onInviteByPhoneStatus(PhoneStatus,
                                                   PhoneFailedReason) {}
void ZoomEventStreamHandler::onCalloutJoinSuccess(IZoomVideoSDKUser*,
                                                  const zchar_t*) {}
void ZoomEventStreamHandler::onCloudRecordingStatus(
    RecordingStatus, IZoomVideoSDKRecordingConsentHandler*) {}
void ZoomEventStreamHandler::onHostAskUnmute() {}
void ZoomEventStreamHandler::onMultiCameraStreamStatusChanged(
    ZoomVideoSDKMultiCameraStreamStatus, IZoomVideoSDKUser*,
    IZoomVideoSDKRawDataPipe*) {}
void ZoomEventStreamHandler::onMicSpeakerVolumeChanged(unsigned int,
                                                       unsigned int) {}
void ZoomEventStreamHandler::onAudioLevelChanged(unsigned int, bool,
                                                 IZoomVideoSDKUser*) {}
void ZoomEventStreamHandler::onAudioDeviceStatusChanged(
    ZoomVideoSDKAudioDeviceType, ZoomVideoSDKAudioDeviceStatus) {}
void ZoomEventStreamHandler::onTestMicStatusChanged(
    ZoomVideoSDK_TESTMIC_STATUS) {}
void ZoomEventStreamHandler::onSelectedAudioDeviceChanged() {}
void ZoomEventStreamHandler::onCameraListChanged() {}
void ZoomEventStreamHandler::onLiveTranscriptionStatus(
    ZoomVideoSDKLiveTranscriptionStatus) {}
void ZoomEventStreamHandler::onOriginalLanguageMsgReceived(
    ILiveTranscriptionMessageInfo*) {}
void ZoomEventStreamHandler::onLiveTranscriptionMsgInfoReceived(
    ILiveTranscriptionMessageInfo*) {}
void ZoomEventStreamHandler::onLiveTranscriptionMsgError(
    ILiveTranscriptionLanguage*, ILiveTranscriptionLanguage*) {}
void ZoomEventStreamHandler::onSpokenLanguageChanged(
    ILiveTranscriptionLanguage*) {}
void ZoomEventStreamHandler::onChatMsgDeleteNotification(
    IZoomVideoSDKChatHelper*, const zchar_t*,
    ZoomVideoSDKChatMessageDeleteType) {}
void ZoomEventStreamHandler::onChatPrivilegeChanged(
    IZoomVideoSDKChatHelper*, ZoomVideoSDKChatPrivilegeType) {}
void ZoomEventStreamHandler::onSendFileStatus(IZoomVideoSDKSendFile*,
                                              const FileTransferStatus&) {}
void ZoomEventStreamHandler::onReceiveFileStatus(IZoomVideoSDKReceiveFile*,
                                                 const FileTransferStatus&) {}
void ZoomEventStreamHandler::onProxyDetectComplete() {}
void ZoomEventStreamHandler::onProxySettingNotification(
    IZoomVideoSDKProxySettingHandler*) {}
void ZoomEventStreamHandler::onSSLCertVerifiedFailNotification(
    IZoomVideoSDKSSLCertificateInfo*) {}
void ZoomEventStreamHandler::onUserVideoNetworkStatusChanged(
    ZoomVideoSDKNetworkStatus, IZoomVideoSDKUser*) {}
void ZoomEventStreamHandler::onShareNetworkStatusChanged(
    ZoomVideoSDKNetworkStatus, bool) {}
void ZoomEventStreamHandler::onUserNetworkStatusChanged(
    ZoomVideoSDKDataType, ZoomVideoSDKNetworkStatus, IZoomVideoSDKUser*) {}
void ZoomEventStreamHandler::onUserOverallNetworkStatusChanged(
    ZoomVideoSDKNetworkStatus, IZoomVideoSDKUser*) {}
void ZoomEventStreamHandler::onCallCRCDeviceStatusChanged(
    ZoomVideoSDKCRCCallStatus) {}
void ZoomEventStreamHandler::onVideoCanvasSubscribeFail(
    ZoomVideoSDKSubscribeFailReason, IZoomVideoSDKUser*, void*) {}
void ZoomEventStreamHandler::onShareCanvasSubscribeFail(
    IZoomVideoSDKUser*, void*, IZoomVideoSDKShareAction*) {}
void ZoomEventStreamHandler::onAnnotationHelperCleanUp(
    IZoomVideoSDKAnnotationHelper*) {}
void ZoomEventStreamHandler::onAnnotationPrivilegeChange(
    IZoomVideoSDKUser*, IZoomVideoSDKShareAction*) {}
void ZoomEventStreamHandler::onAnnotationHelperActived(void*) {}
void ZoomEventStreamHandler::onAnnotationToolTypeChanged(
    IZoomVideoSDKAnnotationHelper*, void*, ZoomVideoSDKAnnotationToolType) {}
void ZoomEventStreamHandler::onVideoAlphaChannelStatusChanged(bool) {}
void ZoomEventStreamHandler::onSpotlightVideoChanged(
    IZoomVideoSDKVideoHelper*, IVideoSDKVector<IZoomVideoSDKUser*>*) {}
void ZoomEventStreamHandler::onBindIncomingLiveStreamResponse(
    bool, const zchar_t*) {}
void ZoomEventStreamHandler::onUnbindIncomingLiveStreamResponse(
    bool, const zchar_t*) {}
void ZoomEventStreamHandler::onIncomingLiveStreamStatusResponse(
    bool, IVideoSDKVector<IncomingLiveStreamStatus>*) {}
void ZoomEventStreamHandler::onStartIncomingLiveStreamResponse(
    bool, const zchar_t*) {}
void ZoomEventStreamHandler::onStopIncomingLiveStreamResponse(
    bool, const zchar_t*) {}
void ZoomEventStreamHandler::onShareContentSizeChanged(
    IZoomVideoSDKShareHelper*, IZoomVideoSDKUser*, IZoomVideoSDKShareAction*) {}
void ZoomEventStreamHandler::onUnsharingWindowsChanged(
    IVideoSDKVector<void*>*, IZoomVideoSDKShareHelper*, IZoomVideoSDKUser*,
    IZoomVideoSDKShareAction*) {}
void ZoomEventStreamHandler::onSharingActiveMonitorChanged(
    IVideoSDKVector<void*>*, IZoomVideoSDKShareHelper*, IZoomVideoSDKUser*,
    IZoomVideoSDKShareAction*) {}
void ZoomEventStreamHandler::onSubSessionStatusChanged(
    ZoomVideoSDKSubSessionStatus, IVideoSDKVector<ISubSessionKit*>*) {}
void ZoomEventStreamHandler::onSubSessionManagerHandle(
    IZoomVideoSDKSubSessionManager*) {}
void ZoomEventStreamHandler::onSubSessionParticipantHandle(
    IZoomVideoSDKSubSessionParticipant*) {}
void ZoomEventStreamHandler::onSubSessionUsersUpdate(ISubSessionKit*) {}
void ZoomEventStreamHandler::onBroadcastMessageFromMainSession(
    const zchar_t*, const zchar_t*) {}
void ZoomEventStreamHandler::onSubSessionUserHelpRequest(
    ISubSessionUserHelpRequestHandler*) {}
void ZoomEventStreamHandler::onSubSessionUserHelpRequestResult(
    ZoomVideoSDKUserHelpRequestResult) {}
void ZoomEventStreamHandler::onStartBroadcastResponse(bool,
                                                      const zchar_t*) {}
void ZoomEventStreamHandler::onStopBroadcastResponse(bool) {}
void ZoomEventStreamHandler::onGetBroadcastControlStatus(
    bool, ZoomVideoSDKBroadcastControlStatus) {}
void ZoomEventStreamHandler::onStreamingJoinStatusChanged(
    ZoomVideoSDKStreamingJoinStatus) {}
void ZoomEventStreamHandler::onWhiteboardExported(ZoomVideoSDKExportFormat,
                                                  unsigned char*, long) {}
void ZoomEventStreamHandler::onUserWhiteboardShareStatusChanged(
    IZoomVideoSDKUser*, IZoomVideoSDKWhiteboardHelper*) {}
void ZoomEventStreamHandler::onRealTimeMediaStreamsStatus(
    RealTimeMediaStreamsStatus) {}
void ZoomEventStreamHandler::onRealTimeMediaStreamsFail(
    RealTimeMediaStreamsFailReason) {}
void ZoomEventStreamHandler::onCanvasSnapshotTaken(IZoomVideoSDKUser*,
                                                   bool) {}
void ZoomEventStreamHandler::onCanvasSnapshotIncompatible(
    IZoomVideoSDKUser*) {}
void ZoomEventStreamHandler::onQOSStatisticsReceived(
    const ZoomVideoSDKQOSStatistics&, IZoomVideoSDKUser*) {}

}  // namespace zoom_video_sdk_flutter
