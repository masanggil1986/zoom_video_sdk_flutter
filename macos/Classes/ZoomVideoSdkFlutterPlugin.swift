import Cocoa
import FlutterMacOS
import ZMVideoSDK

public class ZoomVideoSdkFlutterPlugin: NSObject, FlutterPlugin {
    private var eventStreamHandler: ZoomEventStreamHandler?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "zoom_video_sdk_flutter",
            binaryMessenger: registrar.messenger
        )
        let instance = ZoomVideoSdkFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        let eventChannel = FlutterEventChannel(
            name: "zoom_video_sdk_flutter/events",
            binaryMessenger: registrar.messenger
        )
        instance.eventStreamHandler = ZoomEventStreamHandler()
        eventChannel.setStreamHandler(instance.eventStreamHandler)
    }

    // MARK: - Dispatch

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]

        switch call.method {
        // SDK 라이프사이클
        case "init":
            handleInit(args: args, result: result)
        case "joinSession":
            handleJoinSession(args: args, result: result)
        case "leaveSession":
            handleLeaveSession(args: args, result: result)
        case "getSessionInfo":
            handleGetSessionInfo(result: result)
        case "getMyself":
            handleGetMyself(result: result)
        case "getAllUsers":
            handleGetAllUsers(result: result)
        case "getRemoteUsers":
            handleGetRemoteUsers(result: result)

        // Audio
        case "audio.startAudio":
            handleAudioStartAudio(result: result)
        case "audio.stopAudio":
            handleAudioStopAudio(result: result)
        case "audio.muteAudio":
            handleAudioMuteAudio(args: args, result: result)
        case "audio.unmuteAudio":
            handleAudioUnmuteAudio(args: args, result: result)
        case "audio.enableMicOriginalInput":
            handleAudioEnableMicOriginalInput(args: args, result: result)
        case "audio.setNoiseSuppression":
            handleAudioSetNoiseSuppression(args: args, result: result)
        case "audio.getAudioDeviceList":
            handleAudioGetDeviceList(result: result)
        case "audio.selectAudioDevice":
            handleAudioSelectDevice(args: args, result: result)

        // Video
        case "video.startVideo":
            handleVideoStartVideo(result: result)
        case "video.stopVideo":
            handleVideoStopVideo(result: result)
        case "video.switchCamera":
            handleVideoSwitchCamera(result: result)
        case "video.getCameraList":
            handleVideoGetCameraList(result: result)

        // Share
        case "share.startShareScreen":
            handleShareStartScreen(result: result)
        case "share.startShareView":
            handleShareStartView(args: args, result: result)
        case "share.stopShare":
            handleShareStop(result: result)
        case "share.enableShareDeviceAudio":
            handleShareEnableDeviceAudio(args: args, result: result)

        // Chat
        case "chat.sendChatToAll":
            handleChatSendToAll(args: args, result: result)
        case "chat.sendChatToUser":
            handleChatSendToUser(args: args, result: result)
        case "chat.isChatDisabled":
            handleChatIsDisabled(result: result)
        case "chat.isPrivateChatDisabled":
            handleChatIsPrivateDisabled(result: result)

        // Recording
        case "recording.canStartRecording":
            handleRecordingCanStart(result: result)
        case "recording.startCloudRecording":
            handleRecordingStart(result: result)
        case "recording.stopCloudRecording":
            handleRecordingStop(result: result)

        // Virtual Background
        case "virtualBackground.isSupported":
            handleVBIsSupported(result: result)
        case "virtualBackground.addItem":
            handleVBAddItem(args: args, result: result)
        case "virtualBackground.getItemList":
            handleVBGetItemList(result: result)
        case "virtualBackground.setItem":
            handleVBSetItem(args: args, result: result)
        case "virtualBackground.removeItem":
            handleVBRemoveItem(args: args, result: result)
        case "virtualBackground.getSelectedItem":
            handleVBGetSelectedItem(result: result)

        // User Management
        case "user.makeHost":
            handleUserMakeHost(args: args, result: result)
        case "user.makeManager":
            handleUserMakeManager(args: args, result: result)
        case "user.revokeManager":
            handleUserRevokeManager(args: args, result: result)
        case "user.removeUser":
            handleUserRemove(args: args, result: result)
        case "user.changeName":
            handleUserChangeName(args: args, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Helpers

    private var sdk: ZMVideoSDK? { ZMVideoSDK.shared() }

    private func findUser(byId userId: String) -> ZMVideoSDKUser? {
        guard let session = sdk?.getSessionInfo() else { return nil }
        if let myself = session.getMySelf(), (myself.getID() ?? "") == userId {
            return myself
        }
        if let remoteUsers = session.getRemoteUsers() {
            return remoteUsers.first { ($0.getID() ?? "") == userId }
        }
        return nil
    }

    private func flutterError(_ code: String, _ message: String) -> FlutterError {
        FlutterError(code: code, message: message, details: nil)
    }
}

// MARK: - SDK Lifecycle Handlers

private extension ZoomVideoSdkFlutterPlugin {

    func handleInit(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let args = args else {
            result(flutterError("INVALID_ARGS", "Arguments required"))
            return
        }

        let initParams = ZMVideoSDKInitParams()
        initParams.domain = args["domain"] as? String ?? "zoom.us"
        initParams.enableLog = args["enableLog"] as? Bool ?? true

        let sdkResult = sdk?.initialize(initParams)

        if sdkResult == ZMVideoSDKErrors_Success {
            if let handler = eventStreamHandler {
                sdk?.addListener(handler)
            }
            result(nil)
        } else {
            result(flutterError("INIT_FAILED", "SDK init failed: \(String(describing: sdkResult))"))
        }
    }

    func handleJoinSession(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let args = args else {
            result(flutterError("INVALID_ARGS", "Arguments required"))
            return
        }

        let ctx = ZMVideoSDKSessionContext()
        ctx.sessionName = args["sessionName"] as? String ?? ""
        ctx.userName = args["userName"] as? String ?? ""
        ctx.token = args["token"] as? String ?? ""
        ctx.sessionPassword = args["sessionPassword"] as? String

        if let audioOpts = args["audioOptions"] as? [String: Any] {
            let audio = ZMVideoSDKAudioOption()
            audio.connect = audioOpts["connect"] as? Bool ?? true
            audio.mute = audioOpts["mute"] as? Bool ?? false
            ctx.audioOption = audio
        }

        if let videoOpts = args["videoOptions"] as? [String: Any] {
            let video = ZMVideoSDKVideoOption()
            video.localVideoOn = videoOpts["localVideoOn"] as? Bool ?? false
            ctx.videoOption = video
        }

        if let timeout = args["sessionIdleTimeoutMins"] as? Int {
            ctx.sessionIdleTimeoutMins = UInt32(timeout)
        }

        let session = sdk?.joinSession(ctx)
        if session != nil {
            result(nil)
        } else {
            result(flutterError("JOIN_FAILED", "Failed to join session"))
        }
    }

    func handleLeaveSession(args: [String: Any]?, result: @escaping FlutterResult) {
        let endSession = args?["endSession"] as? Bool ?? false
        sdk?.leaveSession(endSession)
        result(nil)
    }

    func handleGetSessionInfo(result: @escaping FlutterResult) {
        guard let session = sdk?.getSessionInfo() else {
            result(flutterError("NO_SESSION", "No active session"))
            return
        }
        result(ZoomSerializer.serializeSessionInfo(session))
    }

    func handleGetMyself(result: @escaping FlutterResult) {
        guard let myself = sdk?.getSessionInfo()?.getMySelf() else {
            result(flutterError("NO_SESSION", "No active session or user"))
            return
        }
        result(ZoomSerializer.serializeUser(myself))
    }

    func handleGetAllUsers(result: @escaping FlutterResult) {
        guard let session = sdk?.getSessionInfo() else {
            result(flutterError("NO_SESSION", "No active session"))
            return
        }
        var users: [[String: Any]] = []
        if let myself = session.getMySelf() {
            users.append(ZoomSerializer.serializeUser(myself))
        }
        if let remoteUsers = session.getRemoteUsers() {
            users.append(contentsOf: remoteUsers.map { ZoomSerializer.serializeUser($0) })
        }
        result(users)
    }

    func handleGetRemoteUsers(result: @escaping FlutterResult) {
        guard let session = sdk?.getSessionInfo() else {
            result(flutterError("NO_SESSION", "No active session"))
            return
        }
        let remoteUsers = session.getRemoteUsers() ?? []
        result(remoteUsers.map { ZoomSerializer.serializeUser($0) })
    }
}

// MARK: - Audio Handlers

private extension ZoomVideoSdkFlutterPlugin {

    func handleAudioStartAudio(result: @escaping FlutterResult) {
        let err = sdk?.getAudioHelper().startAudio()
        if err == ZMVideoSDKErrors_Success {
            result(nil)
        } else {
            result(flutterError("AUDIO_ERROR", "startAudio failed: \(String(describing: err))"))
        }
    }

    func handleAudioStopAudio(result: @escaping FlutterResult) {
        let err = sdk?.getAudioHelper().stopAudio()
        if err == ZMVideoSDKErrors_Success {
            result(nil)
        } else {
            result(flutterError("AUDIO_ERROR", "stopAudio failed: \(String(describing: err))"))
        }
    }

    func handleAudioMuteAudio(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let userId = args?["userId"] as? String,
              let user = findUser(byId: userId) else {
            result(flutterError("INVALID_ARGS", "User not found"))
            return
        }
        let err = sdk?.getAudioHelper().muteAudio(user)
        if err == ZMVideoSDKErrors_Success {
            result(nil)
        } else {
            result(flutterError("AUDIO_ERROR", "muteAudio failed: \(String(describing: err))"))
        }
    }

    func handleAudioUnmuteAudio(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let userId = args?["userId"] as? String,
              let user = findUser(byId: userId) else {
            result(flutterError("INVALID_ARGS", "User not found"))
            return
        }
        let err = sdk?.getAudioHelper().unMuteAudio(user)
        if err == ZMVideoSDKErrors_Success {
            result(nil)
        } else {
            result(flutterError("AUDIO_ERROR", "unmuteAudio failed: \(String(describing: err))"))
        }
    }

    func handleAudioEnableMicOriginalInput(args: [String: Any]?, result: @escaping FlutterResult) {
        let enable = args?["enable"] as? Bool ?? false
        let err = sdk?.getAudioSettingHelper().enableMicOriginalInput(enable)
        if err == ZMVideoSDKErrors_Success {
            result(nil)
        } else {
            result(flutterError("AUDIO_ERROR", "enableMicOriginalInput failed: \(String(describing: err))"))
        }
    }

    func handleAudioSetNoiseSuppression(args: [String: Any]?, result: @escaping FlutterResult) {
        let levelStr = args?["level"] as? String ?? "auto_"
        let level: ZMVideoSDKSuppressBackgroundNoiseLevel
        switch levelStr {
        case "low": level = ZMVideoSDKSuppressBackgroundNoiseLevel_Low
        case "medium": level = ZMVideoSDKSuppressBackgroundNoiseLevel_Medium
        case "high": level = ZMVideoSDKSuppressBackgroundNoiseLevel_High
        default: level = ZMVideoSDKSuppressBackgroundNoiseLevel_Auto
        }
        let err = sdk?.getAudioSettingHelper().setSuppressBackgroundNoiseLevel(level)
        if err == ZMVideoSDKErrors_Success {
            result(nil)
        } else {
            result(flutterError("AUDIO_ERROR", "setNoiseSuppression failed: \(String(describing: err))"))
        }
    }

    func handleAudioGetDeviceList(result: @escaping FlutterResult) {
        guard let helper = sdk?.getAudioHelper() else {
            result([])
            return
        }
        let micList = helper.getMicList() ?? []
        let speakerList = helper.getSpeakerList() ?? []
        var all: [[String: Any]] = []
        all.append(contentsOf: micList.map { ZoomSerializer.serializeMicDevice($0) })
        all.append(contentsOf: speakerList.map { ZoomSerializer.serializeSpeakerDevice($0) })
        result(all)
    }

    func handleAudioSelectDevice(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let deviceId = args?["deviceId"] as? String else {
            result(flutterError("INVALID_ARGS", "deviceId required"))
            return
        }
        guard let helper = sdk?.getAudioHelper() else {
            result(flutterError("AUDIO_ERROR", "Audio helper not available"))
            return
        }
        // mic 목록에서 찾기
        if let micList = helper.getMicList(),
           let device = micList.first(where: { ($0.deviceId ?? "") == deviceId }) {
            let err = helper.selectMic(device.deviceId ?? "", deviceName: device.deviceName ?? "")
            if err == ZMVideoSDKErrors_Success {
                result(nil)
                return
            }
        }
        // speaker 목록에서 찾기
        if let speakerList = helper.getSpeakerList(),
           let device = speakerList.first(where: { ($0.deviceId ?? "") == deviceId }) {
            let err = helper.selectSpeaker(device.deviceId ?? "", deviceName: device.deviceName ?? "")
            if err == ZMVideoSDKErrors_Success {
                result(nil)
                return
            }
        }
        result(flutterError("AUDIO_ERROR", "Device not found: \(deviceId)"))
    }
}

// MARK: - Video Handlers

private extension ZoomVideoSdkFlutterPlugin {

    func handleVideoStartVideo(result: @escaping FlutterResult) {
        let err = sdk?.getVideoHelper().startVideo()
        if err == ZMVideoSDKErrors_Success {
            result(nil)
        } else {
            result(flutterError("VIDEO_ERROR", "startVideo failed: \(String(describing: err))"))
        }
    }

    func handleVideoStopVideo(result: @escaping FlutterResult) {
        let err = sdk?.getVideoHelper().stopVideo()
        if err == ZMVideoSDKErrors_Success {
            result(nil)
        } else {
            result(flutterError("VIDEO_ERROR", "stopVideo failed: \(String(describing: err))"))
        }
    }

    func handleVideoSwitchCamera(result: @escaping FlutterResult) {
        let success = sdk?.getVideoHelper().switchCamera() ?? false
        if success {
            result(nil)
        } else {
            result(flutterError("VIDEO_ERROR", "switchCamera failed"))
        }
    }

    func handleVideoGetCameraList(result: @escaping FlutterResult) {
        let cameras = sdk?.getVideoHelper().getCameraList() ?? []
        result(cameras.map { ZoomSerializer.serializeCameraDevice($0) })
    }
}

// MARK: - Share Handlers

private extension ZoomVideoSdkFlutterPlugin {

    func handleShareStartScreen(result: @escaping FlutterResult) {
        let mainDisplayId = CGMainDisplayID()
        let option = ZMVideoSDKShareOption()
        let err = sdk?.getShareHelper().startShareScreen(mainDisplayId, shareOption: option)
        if err == ZMVideoSDKErrors_Success {
            result(nil)
        } else {
            result(flutterError("SHARE_ERROR", "startShareScreen failed: \(String(describing: err))"))
        }
    }

    func handleShareStartView(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let windowIdStr = args?["windowId"] as? String,
              let windowId = UInt32(windowIdStr) else {
            result(flutterError("INVALID_ARGS", "windowId required"))
            return
        }
        let option = ZMVideoSDKShareOption()
        let err = sdk?.getShareHelper().startShareView(CGWindowID(windowId), shareOption: option)
        if err == ZMVideoSDKErrors_Success {
            result(nil)
        } else {
            result(flutterError("SHARE_ERROR", "startShareView failed: \(String(describing: err))"))
        }
    }

    func handleShareStop(result: @escaping FlutterResult) {
        let err = sdk?.getShareHelper().stopShare()
        if err == ZMVideoSDKErrors_Success {
            result(nil)
        } else {
            result(flutterError("SHARE_ERROR", "stopShare failed: \(String(describing: err))"))
        }
    }

    func handleShareEnableDeviceAudio(args: [String: Any]?, result: @escaping FlutterResult) {
        let enable = args?["enable"] as? Bool ?? false
        let err = sdk?.getShareHelper().enableShareDeviceAudio(enable)
        if err == ZMVideoSDKErrors_Success {
            result(nil)
        } else {
            result(flutterError("SHARE_ERROR", "enableShareDeviceAudio failed: \(String(describing: err))"))
        }
    }
}

// MARK: - Chat Handlers

private extension ZoomVideoSdkFlutterPlugin {

    func handleChatSendToAll(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let message = args?["message"] as? String else {
            result(flutterError("INVALID_ARGS", "message required"))
            return
        }
        let err = sdk?.getChatHelper().sendChat(toAll: message)
        if err == ZMVideoSDKErrors_Success {
            result(nil)
        } else {
            result(flutterError("CHAT_ERROR", "sendChatToAll failed: \(String(describing: err))"))
        }
    }

    func handleChatSendToUser(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let userId = args?["userId"] as? String,
              let message = args?["message"] as? String,
              let user = findUser(byId: userId) else {
            result(flutterError("INVALID_ARGS", "userId and message required"))
            return
        }
        let err = sdk?.getChatHelper().sendChat(to: user, content: message)
        if err == ZMVideoSDKErrors_Success {
            result(nil)
        } else {
            result(flutterError("CHAT_ERROR", "sendChatToUser failed: \(String(describing: err))"))
        }
    }

    func handleChatIsDisabled(result: @escaping FlutterResult) {
        let disabled = sdk?.getChatHelper().isChatDisabled() ?? false
        result(disabled)
    }

    func handleChatIsPrivateDisabled(result: @escaping FlutterResult) {
        let disabled = sdk?.getChatHelper().isPrivateChatDisabled() ?? false
        result(disabled)
    }
}

// MARK: - Recording Handlers

private extension ZoomVideoSdkFlutterPlugin {

    func handleRecordingCanStart(result: @escaping FlutterResult) {
        let canStart = sdk?.getRecordingHelper().canStartRecording() == ZMVideoSDKErrors_Success
        result(canStart)
    }

    func handleRecordingStart(result: @escaping FlutterResult) {
        let err = sdk?.getRecordingHelper().startCloudRecording()
        if err == ZMVideoSDKErrors_Success {
            result(nil)
        } else {
            result(flutterError("RECORDING_ERROR", "startCloudRecording failed: \(String(describing: err))"))
        }
    }

    func handleRecordingStop(result: @escaping FlutterResult) {
        let err = sdk?.getRecordingHelper().stopCloudRecording()
        if err == ZMVideoSDKErrors_Success {
            result(nil)
        } else {
            result(flutterError("RECORDING_ERROR", "stopCloudRecording failed: \(String(describing: err))"))
        }
    }
}

// MARK: - Virtual Background Handlers
// ZMVideoSDKVirtualBackgroundItem 심볼이 SDK 바이너리에 export되지 않아
// 직접 타입 참조 시 링커 에러 발생. performSelector로 우회하여 구현.

private extension ZoomVideoSdkFlutterPlugin {

    func handleVBIsSupported(result: @escaping FlutterResult) {
        let hasHelper = sdk?.getVideoHelper() != nil
        result(hasHelper)
    }

    func handleVBAddItem(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let filePath = args?["filePath"] as? String else {
            result(flutterError("INVALID_ARGS", "filePath required"))
            return
        }
        guard let helper = sdk?.getVideoHelper() else {
            result(flutterError("VB_ERROR", "Video helper not available"))
            return
        }
        let sel = NSSelectorFromString("addVirtualBackgroundItem:imageItem:")
        if helper.responds(to: sel) {
            helper.perform(sel, with: filePath, with: nil)
            result(nil)
        } else {
            result(flutterError("VB_ERROR", "addItem not supported"))
        }
    }

    func handleVBGetItemList(result: @escaping FlutterResult) {
        guard let helper = sdk?.getVideoHelper() else { result([]); return }
        let sel = NSSelectorFromString("getVirtualBackgroundItemList")
        guard helper.responds(to: sel),
              let items = helper.perform(sel)?.takeUnretainedValue() as? NSArray else {
            result([])
            return
        }
        var list: [[String: Any]] = []
        for item in items {
            if let obj = item as? NSObject {
                let name = obj.value(forKey: "imageName") as? String ?? ""
                let path = obj.value(forKey: "imageFilePath") as? String ?? ""
                list.append(["imageName": name, "imagePath": path])
            }
        }
        result(list)
    }

    func handleVBSetItem(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let imageName = args?["imageName"] as? String else {
            result(flutterError("INVALID_ARGS", "imageName required"))
            return
        }
        guard let helper = sdk?.getVideoHelper() else {
            result(flutterError("VB_ERROR", "Video helper not available"))
            return
        }
        let listSel = NSSelectorFromString("getVirtualBackgroundItemList")
        guard helper.responds(to: listSel),
              let items = helper.perform(listSel)?.takeUnretainedValue() as? NSArray else {
            result(flutterError("VB_ERROR", "Item not found"))
            return
        }
        var targetItem: NSObject?
        for item in items {
            if let obj = item as? NSObject, (obj.value(forKey: "imageName") as? String) == imageName {
                targetItem = obj
                break
            }
        }
        guard let item = targetItem else {
            result(flutterError("VB_ERROR", "Item not found: \(imageName)"))
            return
        }
        let setSel = NSSelectorFromString("setVirtualBackgroundItem:")
        if helper.responds(to: setSel) {
            helper.perform(setSel, with: item)
            result(nil)
        } else {
            result(flutterError("VB_ERROR", "setItem not supported"))
        }
    }

    func handleVBRemoveItem(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let imageName = args?["imageName"] as? String else {
            result(flutterError("INVALID_ARGS", "imageName required"))
            return
        }
        guard let helper = sdk?.getVideoHelper() else {
            result(flutterError("VB_ERROR", "Video helper not available"))
            return
        }
        let listSel = NSSelectorFromString("getVirtualBackgroundItemList")
        guard helper.responds(to: listSel),
              let items = helper.perform(listSel)?.takeUnretainedValue() as? NSArray else {
            result(flutterError("VB_ERROR", "Item not found"))
            return
        }
        var targetItem: NSObject?
        for item in items {
            if let obj = item as? NSObject, (obj.value(forKey: "imageName") as? String) == imageName {
                targetItem = obj
                break
            }
        }
        guard let item = targetItem else {
            result(flutterError("VB_ERROR", "Item not found: \(imageName)"))
            return
        }
        let removeSel = NSSelectorFromString("removeVirtualBackgroundItem:")
        if helper.responds(to: removeSel) {
            helper.perform(removeSel, with: item)
            result(nil)
        } else {
            result(flutterError("VB_ERROR", "removeItem not supported"))
        }
    }

    func handleVBGetSelectedItem(result: @escaping FlutterResult) {
        guard let helper = sdk?.getVideoHelper() else { result(nil); return }
        let sel = NSSelectorFromString("getSelectedVirtualBackgroundItem")
        guard helper.responds(to: sel),
              let obj = helper.perform(sel)?.takeUnretainedValue() as? NSObject else {
            result(nil)
            return
        }
        let name = obj.value(forKey: "imageName") as? String ?? ""
        let path = obj.value(forKey: "imageFilePath") as? String ?? ""
        result(["imageName": name, "imagePath": path])
    }
}

// MARK: - User Management Handlers

private extension ZoomVideoSdkFlutterPlugin {

    func handleUserMakeHost(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let userId = args?["userId"] as? String,
              let user = findUser(byId: userId) else {
            result(flutterError("INVALID_ARGS", "User not found"))
            return
        }
        let success = sdk?.getUserHelper().makeHost(user) ?? false
        if success {
            result(nil)
        } else {
            result(flutterError("USER_ERROR", "makeHost failed"))
        }
    }

    func handleUserMakeManager(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let userId = args?["userId"] as? String,
              let user = findUser(byId: userId) else {
            result(flutterError("INVALID_ARGS", "User not found"))
            return
        }
        let success = sdk?.getUserHelper().makeManager(user) ?? false
        if success {
            result(nil)
        } else {
            result(flutterError("USER_ERROR", "makeManager failed"))
        }
    }

    func handleUserRevokeManager(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let userId = args?["userId"] as? String,
              let user = findUser(byId: userId) else {
            result(flutterError("INVALID_ARGS", "User not found"))
            return
        }
        let err = sdk?.getUserHelper().revokeManager(user)
        if err == ZMVideoSDKErrors_Success {
            result(nil)
        } else {
            result(flutterError("USER_ERROR", "revokeManager failed: \(String(describing: err))"))
        }
    }

    func handleUserRemove(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let userId = args?["userId"] as? String,
              let user = findUser(byId: userId) else {
            result(flutterError("INVALID_ARGS", "User not found"))
            return
        }
        let success = sdk?.getUserHelper().remove(user) ?? false
        if success {
            result(nil)
        } else {
            result(flutterError("USER_ERROR", "removeUser failed"))
        }
    }

    func handleUserChangeName(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let name = args?["name"] as? String,
              let userId = args?["userId"] as? String,
              let user = findUser(byId: userId) else {
            result(flutterError("INVALID_ARGS", "name and userId required"))
            return
        }
        let success = sdk?.getUserHelper().changeName(name, user: user) ?? false
        if success {
            result(nil)
        } else {
            result(flutterError("USER_ERROR", "changeName failed"))
        }
    }
}
