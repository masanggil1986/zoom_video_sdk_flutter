import FlutterMacOS
import ZMVideoSDK

/// EventChannel의 FlutterStreamHandler + ZMVideoSDKDelegate 구현.
///
/// 네이티브 Zoom SDK 이벤트를 Flutter EventChannel로 전달한다.
/// 모든 이벤트는 `DispatchQueue.main`에서 전송하여 스레드 안전성을 보장한다.
class ZoomEventStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    /// 세션 참여/사용자 join/비디오 또는 공유 상태 변경 시 호출되는 콜백.
    /// 플러그인이 ZoomVideoView 텍스처/캔버스 subscribe 재시도를 트리거하는 데 사용한다.
    /// 항상 메인 스레드에서 호출된다.
    var onUserStateChanged: (() -> Void)?

    // MARK: - FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    // MARK: - Event Helper

    private func sendEvent(type: String, data: [String: Any] = [:]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(["eventType": type, "data": data])
        }
    }

    fileprivate func notifyUserStateChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.onUserStateChanged?()
        }
    }
}

// MARK: - ZMVideoSDKDelegate

extension ZoomEventStreamHandler: ZMVideoSDKDelegate {

    func onSessionJoin() {
        sendEvent(type: "sessionJoined")
        notifyUserStateChanged()
    }

    func onSessionLeave(_ reason: ZMVideoSDKSessionLeaveReason) {
        sendEvent(type: "sessionLeft")
    }

    func onError(_ errorType: ZMVideoSDKErrors, detail details: Int32) {
        sendEvent(type: "error", data: [
            "errorCode": ZoomSerializer.serializeErrorCode(errorType),
            "message": "error:\(errorType) detail:\(details)",
        ])
    }

    func onUserJoin(_ helper: ZMVideoSDKUserHelper, userList userArray: [ZMVideoSDKUser]?) {
        sendEvent(type: "userJoined", data: [
            "users": ZoomSerializer.serializeUserList(userArray),
        ])
        notifyUserStateChanged()
    }

    func onUserLeave(_ helper: ZMVideoSDKUserHelper, userList userArray: [ZMVideoSDKUser]?) {
        sendEvent(type: "userLeft", data: [
            "users": ZoomSerializer.serializeUserList(userArray),
        ])
    }

    func onUserVideoStatusChanged(_ videoHelper: ZMVideoSDKVideoHelper, userList userArray: [ZMVideoSDKUser]?) {
        guard let user = userArray?.first else { return }
        sendEvent(type: "userVideoStatusChanged", data: [
            "user": ZoomSerializer.serializeUser(user),
        ])
        notifyUserStateChanged()
    }

    func onUserAudioStatusChanged(_ audioHelper: ZMVideoSDKAudioHelper, userList userArray: [ZMVideoSDKUser]?) {
        guard let user = userArray?.first else { return }
        sendEvent(type: "userAudioStatusChanged", data: [
            "user": ZoomSerializer.serializeUser(user),
        ])
    }

    func onUserActiveAudioChanged(_ audioHelper: ZMVideoSDKAudioHelper, userList userArray: [ZMVideoSDKUser]?) {
        sendEvent(type: "userActiveAudioChanged", data: [
            "activeUsers": ZoomSerializer.serializeUserList(userArray),
        ])
    }

    func onChatNewMessageNotify(_ chatHelper: ZMVideoSDKChatHelper, chatMessage: ZMVideoSDKChatMessage?) {
        guard let message = chatMessage else { return }
        sendEvent(type: "chatMessageReceived", data: [
            "message": ZoomSerializer.serializeChatMessage(message),
        ])
    }

    func onUserShareStatusChanged(_ shareHelper: ZMVideoSDKShareHelper, user: ZMVideoSDKUser?, shareAction: ZMVideoSDKShareAction?) {
        guard let user = user else { return }
        let status = shareAction?.shareStatus ?? ZMVideoSDKShareStatus_None
        sendEvent(type: "userShareStatusChanged", data: [
            "user": ZoomSerializer.serializeUser(user),
            "status": ZoomSerializer.serializeShareStatus(status),
        ])
        notifyUserStateChanged()
    }

    func onUserHostChanged(_ userHelper: ZMVideoSDKUserHelper, user: ZMVideoSDKUser?) {
        guard let user = user else { return }
        sendEvent(type: "userHostChanged", data: [
            "newHost": ZoomSerializer.serializeUser(user),
        ])
    }

    func onUserManagerChanged(_ user: ZMVideoSDKUser?) {
        guard let user = user else { return }
        sendEvent(type: "userManagerChanged", data: [
            "user": ZoomSerializer.serializeUser(user),
            "isManager": user.isManager(),
        ])
    }

    func onUserNameChanged(_ user: ZMVideoSDKUser?) {
        guard let user = user else { return }
        sendEvent(type: "userNameChanged", data: [
            "user": ZoomSerializer.serializeUser(user),
        ])
    }

    func onSessionNeedPassword(_ handle: ZMVideoSDKPasswordHandler) {
        sendEvent(type: "sessionNeedPassword")
    }

    func onSessionPasswordWrong(_ handle: ZMVideoSDKPasswordHandler) {
        sendEvent(type: "sessionPasswordWrong")
    }

    /// `subscribeWithView:`가 sync Success를 반환하더라도, SDK는 이 콜백으로
    /// 비동기 실패를 알려올 수 있다 (rate limit, 고해상도 스트림 개수 초과 등).
    /// 이 때 캔버스가 실제로는 구독되지 않았으므로, 실패한 view가 자체 상태를
    /// 리셋하고 backoff 후 재시도할 수 있도록 위임한다.
    func onVideoCanvasSubscribeFail(_ failReason: ZMVideoSDKSubscribeFailReason,
                                    user: ZMVideoSDKUser?,
                                    view: NSView?) {
        NSLog("[ZoomVideoView] onVideoCanvasSubscribeFail reason=\(failReason.rawValue) userId=\(user?.getID() ?? "nil") view=\(String(describing: view))")
        guard let renderView = view as? ZoomVideoRenderView else { return }
        DispatchQueue.main.async {
            renderView.handleSubscribeFailure(reason: failReason)
        }
    }

    /// Share canvas 비동기 구독 실패. 사유 파라미터는 제공되지 않지만,
    /// view를 리셋하고 재시도하면 되므로 generic `None`으로 전달.
    func onShareCanvasSubscribeFail(_ user: ZMVideoSDKUser?,
                                    view: NSView?,
                                    shareAction: ZMVideoSDKShareAction?) {
        guard let renderView = view as? ZoomVideoRenderView else { return }
        DispatchQueue.main.async {
            renderView.handleSubscribeFailure(reason: ZMVideoSDKSubscribeFailReason_None)
        }
    }
}
