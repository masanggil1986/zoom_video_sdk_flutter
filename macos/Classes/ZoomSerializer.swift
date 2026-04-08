import Foundation
import ZMVideoSDK

/// 네이티브 Zoom SDK 객체를 Flutter MethodChannel 호환 Dictionary로 변환
enum ZoomSerializer {

    // MARK: - User

    static func serializeUser(_ user: ZMVideoSDKUser) -> [String: Any] {
        var dict: [String: Any] = [
            "userId": user.getID() ?? "",
            "userName": user.getName() ?? "",
            "isHost": user.isHost(),
            "isManager": user.isManager(),
        ]

        if let audio = user.getAudioStatus() {
            dict["audioStatus"] = [
                "isMuted": audio.isMuted,
                "isTalking": audio.isTalking,
                "audioType": serializeAudioType(audio.audioType),
            ]
        }

        if let videoStatus = user.getVideoPipe()?.getVideoStatus() {
            dict["videoStatus"] = [
                "isOn": videoStatus.isOn,
                "hasSource": videoStatus.isHasVideoDevice,
            ]
        }

        return dict
    }

    static func serializeUserList(_ users: [ZMVideoSDKUser]?) -> [[String: Any]] {
        return (users ?? []).map { serializeUser($0) }
    }

    // MARK: - Session

    static func serializeSessionInfo(_ session: ZMVideoSDKSession) -> [String: Any] {
        var dict: [String: Any] = [
            "sessionName": session.getName() ?? "",
            "sessionId": session.getID() ?? "",
        ]
        let password = session.getPassword() ?? ""
        if !password.isEmpty {
            dict["sessionPassword"] = password
        }
        if let host = session.getHost(), let hostId = host.getID(), !hostId.isEmpty {
            dict["host"] = serializeUser(host)
        }
        return dict
    }

    // MARK: - Chat Message

    static func serializeChatMessage(_ msg: ZMVideoSDKChatMessage) -> [String: Any] {
        var dict: [String: Any] = [
            "content": msg.content ?? "",
            "isChatToAll": msg.isChatToAll,
            "isSelfSend": msg.isSelfSend,
            "timestamp": Int64(msg.timeStamp),
        ]
        let sender = msg.sendUser
        if let senderId = sender.getID(), !senderId.isEmpty {
            dict["senderUser"] = serializeUser(sender)
        }
        let receiver = msg.receiverUser
        if let receiverId = receiver.getID(), !receiverId.isEmpty {
            dict["receiverUser"] = serializeUser(receiver)
        }
        return dict
    }

    // MARK: - Devices

    static func serializeSpeakerDevice(_ device: ZMVideoSDKSpeakerDevice) -> [String: Any] {
        return [
            "deviceId": device.deviceId ?? "",
            "deviceName": device.deviceName ?? "",
        ]
    }

    static func serializeMicDevice(_ device: ZMVideoSDKMicDevice) -> [String: Any] {
        return [
            "deviceId": device.deviceId ?? "",
            "deviceName": device.deviceName ?? "",
        ]
    }

    static func serializeCameraDevice(_ device: ZMVideoSDKCameraDevice) -> [String: Any] {
        return [
            "deviceId": device.deviceID ?? "",
            "deviceName": device.deviceName ?? "",
        ]
    }

    // MARK: - Virtual Background
    // ZMVideoSDKVirtualBackgroundItem은 SDK 바이너리에서 심볼이 export되지 않아
    // 직접 타입 참조 불가. Plugin에서 performSelector + KVC로 직접 처리.

    // MARK: - Enums

    static func serializeAudioType(_ type: ZMVideoSDKAudioType) -> String {
        if type == ZMVideoSDKAudioType_VOIP { return "voip" }
        if type == ZMVideoSDKAudioType_TELEPHONY { return "telephony" }
        return "none"
    }

    static func serializeShareStatus(_ status: ZMVideoSDKShareStatus) -> String {
        if status == ZMVideoSDKShareStatus_Start || status == ZMVideoSDKShareStatus_Resume { return "started" }
        if status == ZMVideoSDKShareStatus_Pause { return "paused" }
        return "stopped"
    }

    static func serializeErrorCode(_ error: ZMVideoSDKErrors) -> String {
        if error == ZMVideoSDKErrors_Success { return "success" }
        if error == ZMVideoSDKErrors_Wrong_Usage || error == ZMVideoSDKErrors_Invalid_Parameter { return "invalidParameter" }
        if error == ZMVideoSDKErrors_Auth_Error { return "authenticationFailed" }
        if error == ZMVideoSDKErrors_Session_No_Rights { return "permissionDenied" }
        if error == ZMVideoSDKErrors_Session_Reconnecting { return "networkError" }
        return "unknown"
    }
}
