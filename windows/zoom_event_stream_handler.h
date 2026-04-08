#ifndef ZOOM_EVENT_STREAM_HANDLER_H_
#define ZOOM_EVENT_STREAM_HANDLER_H_

#include <flutter/event_channel.h>
#include <flutter/encodable_value.h>
#include <functional>
#include <mutex>

#include "zoom_video_sdk_delegate_interface.h"

USING_ZOOM_VIDEO_SDK_NAMESPACE

namespace zoom_video_sdk_flutter {

/// EventChannel의 StreamHandler + IZoomVideoSDKDelegate 구현.
/// 네이티브 Zoom SDK 이벤트를 Flutter EventChannel로 전달한다.
class ZoomEventStreamHandler
    : public flutter::StreamHandler<flutter::EncodableValue>,
      public IZoomVideoSDKDelegate {
 public:
  ZoomEventStreamHandler();
  virtual ~ZoomEventStreamHandler();

 protected:
  // StreamHandler
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
      OnListenInternal(
          const flutter::EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
          override;

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
      OnCancelInternal(const flutter::EncodableValue* arguments) override;

 private:
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  std::mutex sink_mutex_;

  void SendEvent(const std::string& type,
                 const flutter::EncodableMap& data = {});

  // ---- IZoomVideoSDKDelegate ----
  void onSessionJoin() override;
  void onSessionLeave() override;
  void onSessionLeave(ZoomVideoSDKSessionLeaveReason eReason) override;
  void onError(ZoomVideoSDKErrors errorCode, int detailErrorCode) override;
  void onUserJoin(IZoomVideoSDKUserHelper* pUserHelper,
                  IVideoSDKVector<IZoomVideoSDKUser*>* userList) override;
  void onUserLeave(IZoomVideoSDKUserHelper* pUserHelper,
                   IVideoSDKVector<IZoomVideoSDKUser*>* userList) override;
  void onUserVideoStatusChanged(
      IZoomVideoSDKVideoHelper* pVideoHelper,
      IVideoSDKVector<IZoomVideoSDKUser*>* userList) override;
  void onUserAudioStatusChanged(
      IZoomVideoSDKAudioHelper* pAudioHelper,
      IVideoSDKVector<IZoomVideoSDKUser*>* userList) override;
  void onUserShareStatusChanged(
      IZoomVideoSDKShareHelper* pShareHelper,
      IZoomVideoSDKUser* pUser,
      IZoomVideoSDKShareAction* pShareAction) override;
  void onShareContentChanged(IZoomVideoSDKShareHelper* pShareHelper,
                             IZoomVideoSDKUser* pUser,
                             IZoomVideoSDKShareAction* pShareAction) override;
  void onFailedToStartShare(IZoomVideoSDKShareHelper* pShareHelper,
                            IZoomVideoSDKUser* pUser) override;
  void onShareSettingChanged(ZoomVideoSDKShareSetting setting) override;
  void onUserRecordingConsent(IZoomVideoSDKUser* pUser) override;
  void onLiveStreamStatusChanged(
      IZoomVideoSDKLiveStreamHelper* pLiveStreamHelper,
      ZoomVideoSDKLiveStreamStatus status) override;
  void onChatNewMessageNotify(IZoomVideoSDKChatHelper* pChatHelper,
                              IZoomVideoSDKChatMessage* messageItem) override;
  void onUserHostChanged(IZoomVideoSDKUserHelper* pUserHelper,
                         IZoomVideoSDKUser* pUser) override;
  void onUserActiveAudioChanged(
      IZoomVideoSDKAudioHelper* pAudioHelper,
      IVideoSDKVector<IZoomVideoSDKUser*>* list) override;
  void onSessionNeedPassword(IZoomVideoSDKPasswordHandler* handler) override;
  void onSessionPasswordWrong(IZoomVideoSDKPasswordHandler* handler) override;
  void onMixedAudioRawDataReceived(AudioRawData* data_) override;
  void onOneWayAudioRawDataReceived(AudioRawData* data_,
                                    IZoomVideoSDKUser* pUser) override;
  void onSharedAudioRawDataReceived(AudioRawData* data_) override;
  void onUserManagerChanged(IZoomVideoSDKUser* pUser) override;
  void onUserNameChanged(IZoomVideoSDKUser* pUser) override;
  void onCameraControlRequestResult(IZoomVideoSDKUser* pUser,
                                    bool isApproved) override;
  void onCameraControlRequestReceived(
      IZoomVideoSDKUser* pUser,
      ZoomVideoSDKCameraControlRequestType requestType,
      IZoomVideoSDKCameraControlRequestHandler*
          pCameraControlRequestHandler) override;
  void onRemoteControlStatus(IZoomVideoSDKUser* pUser,
                             IZoomVideoSDKShareAction* pShareAction,
                             ZoomVideoSDKRemoteControlStatus status) override;
  void onRemoteControlRequestReceived(
      IZoomVideoSDKUser* pUser,
      IZoomVideoSDKShareAction* pShareAction,
      IZoomVideoSDKRemoteControlRequestHandler*
          pRemoteControlRequestHandler) override;
  void onRemoteControlServiceInstallResult(bool bSuccess) override;
  void onCommandReceived(IZoomVideoSDKUser* sender,
                         const zchar_t* strCmd) override;
  void onCommandChannelConnectResult(bool isSuccess) override;
  void onInviteByPhoneStatus(PhoneStatus status,
                             PhoneFailedReason reason) override;
  void onCalloutJoinSuccess(IZoomVideoSDKUser* pUser,
                            const zchar_t* phoneNumber) override;
  void onCloudRecordingStatus(
      RecordingStatus status,
      IZoomVideoSDKRecordingConsentHandler* pHandler) override;
  void onHostAskUnmute() override;
  void onMultiCameraStreamStatusChanged(
      ZoomVideoSDKMultiCameraStreamStatus status,
      IZoomVideoSDKUser* pUser,
      IZoomVideoSDKRawDataPipe* pVideoPipe) override;
  void onMicSpeakerVolumeChanged(unsigned int micVolume,
                                 unsigned int speakerVolume) override;
  void onAudioLevelChanged(unsigned int level, bool bAudioSharing,
                           IZoomVideoSDKUser* pUser) override;
  void onAudioDeviceStatusChanged(
      ZoomVideoSDKAudioDeviceType type,
      ZoomVideoSDKAudioDeviceStatus status) override;
  void onTestMicStatusChanged(ZoomVideoSDK_TESTMIC_STATUS status) override;
  void onSelectedAudioDeviceChanged() override;
  void onCameraListChanged() override;
  void onLiveTranscriptionStatus(
      ZoomVideoSDKLiveTranscriptionStatus status) override;
  void onOriginalLanguageMsgReceived(
      ILiveTranscriptionMessageInfo* messageInfo) override;
  void onLiveTranscriptionMsgInfoReceived(
      ILiveTranscriptionMessageInfo* messageInfo) override;
  void onLiveTranscriptionMsgError(
      ILiveTranscriptionLanguage* spokenLanguage,
      ILiveTranscriptionLanguage* transcriptLanguage) override;
  void onSpokenLanguageChanged(
      ILiveTranscriptionLanguage* spokenLanguage) override;
  void onChatMsgDeleteNotification(IZoomVideoSDKChatHelper* pChatHelper,
                                   const zchar_t* msgID,
                                   ZoomVideoSDKChatMessageDeleteType deleteBy) override;
  void onChatPrivilegeChanged(IZoomVideoSDKChatHelper* pChatHelper,
                              ZoomVideoSDKChatPrivilegeType privilege) override;
  void onSendFileStatus(IZoomVideoSDKSendFile* file,
                        const FileTransferStatus& status) override;
  void onReceiveFileStatus(IZoomVideoSDKReceiveFile* file,
                           const FileTransferStatus& status) override;
  void onProxyDetectComplete() override;
  void onProxySettingNotification(
      IZoomVideoSDKProxySettingHandler* handler) override;
  void onSSLCertVerifiedFailNotification(
      IZoomVideoSDKSSLCertificateInfo* info) override;
  void onUserVideoNetworkStatusChanged(ZoomVideoSDKNetworkStatus status,
                                       IZoomVideoSDKUser* pUser) override;
  void onShareNetworkStatusChanged(ZoomVideoSDKNetworkStatus shareNetworkStatus,
                                   bool isSendingShare) override;
  void onUserNetworkStatusChanged(ZoomVideoSDKDataType type,
                                  ZoomVideoSDKNetworkStatus level,
                                  IZoomVideoSDKUser* pUser) override;
  void onUserOverallNetworkStatusChanged(ZoomVideoSDKNetworkStatus level,
                                         IZoomVideoSDKUser* pUser) override;
  void onCallCRCDeviceStatusChanged(ZoomVideoSDKCRCCallStatus status) override;
  void onVideoCanvasSubscribeFail(ZoomVideoSDKSubscribeFailReason fail_reason,
                                  IZoomVideoSDKUser* pUser,
                                  void* handle) override;
  void onShareCanvasSubscribeFail(IZoomVideoSDKUser* pUser, void* handle,
                                  IZoomVideoSDKShareAction* pShareAction) override;
  void onAnnotationHelperCleanUp(
      IZoomVideoSDKAnnotationHelper* helper) override;
  void onAnnotationPrivilegeChange(
      IZoomVideoSDKUser* pUser,
      IZoomVideoSDKShareAction* pShareAction) override;
  void onAnnotationHelperActived(void* handle) override;
  void onAnnotationToolTypeChanged(IZoomVideoSDKAnnotationHelper* helper,
                                   void* handle,
                                   ZoomVideoSDKAnnotationToolType toolType) override;
  void onVideoAlphaChannelStatusChanged(bool isAlphaModeOn) override;
  void onSpotlightVideoChanged(
      IZoomVideoSDKVideoHelper* pVideoHelper,
      IVideoSDKVector<IZoomVideoSDKUser*>* userList) override;
  void onBindIncomingLiveStreamResponse(bool bSuccess,
                                        const zchar_t* strStreamKeyID) override;
  void onUnbindIncomingLiveStreamResponse(
      bool bSuccess, const zchar_t* strStreamKeyID) override;
  void onIncomingLiveStreamStatusResponse(
      bool bSuccess,
      IVideoSDKVector<IncomingLiveStreamStatus>* pStreamsStatusList) override;
  void onStartIncomingLiveStreamResponse(
      bool bSuccess, const zchar_t* strStreamKeyID) override;
  void onStopIncomingLiveStreamResponse(
      bool bSuccess, const zchar_t* strStreamKeyID) override;
  void onShareContentSizeChanged(IZoomVideoSDKShareHelper* pShareHelper,
                                 IZoomVideoSDKUser* pUser,
                                 IZoomVideoSDKShareAction* pShareAction) override;
  void onUnsharingWindowsChanged(
      IVideoSDKVector<void*>* windowsList,
      IZoomVideoSDKShareHelper* pShareHelper,
      IZoomVideoSDKUser* pUser,
      IZoomVideoSDKShareAction* pShareAction) override;
  void onSharingActiveMonitorChanged(
      IVideoSDKVector<void*>* monitorIDs,
      IZoomVideoSDKShareHelper* pShareHelper,
      IZoomVideoSDKUser* pUser,
      IZoomVideoSDKShareAction* pShareAction) override;
  void onSubSessionStatusChanged(
      ZoomVideoSDKSubSessionStatus status,
      IVideoSDKVector<ISubSessionKit*>* pSubSessionKitList) override;
  void onSubSessionManagerHandle(
      IZoomVideoSDKSubSessionManager* pManager) override;
  void onSubSessionParticipantHandle(
      IZoomVideoSDKSubSessionParticipant* pParticipant) override;
  void onSubSessionUsersUpdate(ISubSessionKit* pSubSessionKit) override;
  void onBroadcastMessageFromMainSession(const zchar_t* sMessage,
                                          const zchar_t* sUserName) override;
  void onSubSessionUserHelpRequest(
      ISubSessionUserHelpRequestHandler* pHandler) override;
  void onSubSessionUserHelpRequestResult(
      ZoomVideoSDKUserHelpRequestResult eResult) override;
  void onStartBroadcastResponse(bool bSuccess,
                                const zchar_t* channelID) override;
  void onStopBroadcastResponse(bool bSuccess) override;
  void onGetBroadcastControlStatus(
      bool bSuccess, ZoomVideoSDKBroadcastControlStatus status) override;
  void onStreamingJoinStatusChanged(
      ZoomVideoSDKStreamingJoinStatus status) override;
  void onWhiteboardExported(ZoomVideoSDKExportFormat format,
                            unsigned char* data, long length) override;
  void onUserWhiteboardShareStatusChanged(
      IZoomVideoSDKUser* pUser,
      IZoomVideoSDKWhiteboardHelper* pWhiteboardHelper) override;
  void onRealTimeMediaStreamsStatus(RealTimeMediaStreamsStatus status) override;
  void onRealTimeMediaStreamsFail(
      RealTimeMediaStreamsFailReason failReason) override;
  void onCanvasSnapshotTaken(IZoomVideoSDKUser* pUser, bool isShare) override;
  void onCanvasSnapshotIncompatible(IZoomVideoSDKUser* pUser) override;
  void onQOSStatisticsReceived(const ZoomVideoSDKQOSStatistics& statistics,
                               IZoomVideoSDKUser* pUser) override;
};

}  // namespace zoom_video_sdk_flutter

#endif  // ZOOM_EVENT_STREAM_HANDLER_H_
