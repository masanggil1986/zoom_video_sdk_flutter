import FlutterMacOS
import ZMVideoSDK

/// EventChannel의 FlutterStreamHandler + ZMVideoSDKDelegate 구현.
///
/// 네이티브 Zoom SDK 이벤트를 Flutter EventChannel로 전달한다.
/// 모든 이벤트는 `DispatchQueue.main`에서 전송하여 스레드 안전성을 보장한다.
class ZoomEventStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

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
}

// MARK: - ZMVideoSDKDelegate

extension ZoomEventStreamHandler: ZMVideoSDKDelegate {

    func onSessionJoin() {
        sendEvent(type: "sessionJoined")
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
}
