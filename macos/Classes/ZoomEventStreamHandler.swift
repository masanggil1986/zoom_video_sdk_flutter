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

    /// 주어진 사용자 목록 중 현재 share가 Start/Resume 상태인 사용자에 대해
    /// `userShareStatusChanged` 이벤트를 발화한다.
    /// Zoom SDK는 이미 진행 중인 공유에 대해 late-joiner에게 해당 콜백을
    /// 재발화하지 않으므로 직접 보정한다.
    ///
    /// 구현 주의: `ZMVideoSDKShareAction` 클래스 심볼은 SDK 바이너리에서
    /// export되지 않아 Swift 코드에서 직접 타입 참조하면 링커 에러가 발생한다.
    /// (ZoomVideoPlatformView의 resolveShareCanvas와 동일한 패턴으로 회피.)
    /// → `NSObject`로 다루고 KVC로 shareStatus를 읽는다.
    fileprivate func emitActiveShareStatus(for users: [ZMVideoSDKUser]?) {
        guard let users else { return }
        let listSel = NSSelectorFromString("getShareActionList")
        let startStatus = UInt(ZMVideoSDKShareStatus_Start.rawValue)
        let resumeStatus = UInt(ZMVideoSDKShareStatus_Resume.rawValue)
        for user in users {
            guard user.responds(to: listSel),
                  let raw = user.perform(listSel)?.takeUnretainedValue() as? NSArray else {
                continue
            }
            let hasActive = raw.contains { obj in
                guard let action = obj as? NSObject,
                      let n = action.value(forKey: "shareStatus") as? NSNumber else {
                    return false
                }
                let s = n.uintValue
                return s == startStatus || s == resumeStatus
            }
            guard hasActive else { continue }
            sendEvent(type: "userShareStatusChanged", data: [
                "user": ZoomSerializer.serializeUser(user),
                "status": ZoomSerializer.serializeShareStatus(ZMVideoSDKShareStatus_Start),
            ])
        }
    }
}

// MARK: - ZMVideoSDKDelegate

extension ZoomEventStreamHandler: ZMVideoSDKDelegate {

    func onSessionJoin() {
        sendEvent(type: "sessionJoined")
        notifyUserStateChanged()
        // late-joiner 대응: 이미 진행 중이던 공유는 `onUserShareStatusChanged`가
        // 발화하지 않으므로 현재 세션의 remote 사용자 중 active share를 가진
        // 사용자에 대해 synthetic 이벤트를 발화한다.
        emitActiveShareStatus(for: ZMVideoSDK.shared().getSessionInfo()?.getRemoteUsers())
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
        // `onSessionJoin` 시점에 share action이 아직 hydrate 되지 않았을 수 있으므로
        // user join 시점에도 한 번 더 체크. Flutter 측에서 "started" 이벤트는 멱등하다.
        emitActiveShareStatus(for: userArray)
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

    /// 커맨드 채널 수신. tuit 칭찬/제어 등 세션 내 커스텀 메시지 fan-in.
    func onCommandReceived(_ commandContent: String?, senderUser user: ZMVideoSDKUser?) {
        sendEvent(type: "commandReceived", data: [
            "command": commandContent ?? "",
            "senderId": user?.getID() ?? "",
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
