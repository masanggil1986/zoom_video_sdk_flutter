import AVFoundation
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
        // 사용자 상태(join/video/share) 변경 시 ZoomVideoRenderView가
        // 늦게 들어온 user/canvas에 대해 subscribe를 재시도할 수 있도록 알림 전파.
        // 다중 사용자 환경에서 일부 타일이 검은 화면으로 남는 문제 방지.
        instance.eventStreamHandler?.onUserStateChanged = {
            NotificationCenter.default.post(
                name: ZoomVideoRenderView.userStateChangedNotification,
                object: nil
            )
        }
        eventChannel.setStreamHandler(instance.eventStreamHandler)

        let viewFactory = ZoomVideoPlatformViewFactory(messenger: registrar.messenger)
        registrar.register(viewFactory, withId: ZoomVideoPlatformViewFactory.viewTypeId)
    }

    // MARK: - Dispatch

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]

        switch call.method {
        // SDK 라이프사이클
        case "init":                              handleInit(args: args, result: result)
        case "cleanup":                           handleCleanup(result: result)
        case "joinSession":                       handleJoinSession(args: args, result: result)
        case "leaveSession":                      handleLeaveSession(args: args, result: result)
        case "getSessionInfo":                    handleGetSessionInfo(result: result)
        case "getMyself":                         handleGetMyself(result: result)
        case "getAllUsers":                       handleGetAllUsers(result: result)
        case "getRemoteUsers":                    handleGetRemoteUsers(result: result)

        // Command Channel
        case "cmd.sendCommand":                   handleSendCommand(args: args, result: result)

        // Audio
        case "audio.startAudio":                  handleAudioStartAudio(result: result)
        case "audio.stopAudio":                   handleAudioStopAudio(result: result)
        case "audio.muteAudio":                   handleAudioMuteAudio(args: args, result: result)
        case "audio.unmuteAudio":                 handleAudioUnmuteAudio(args: args, result: result)
        case "audio.enableMicOriginalInput":      handleAudioEnableMicOriginalInput(args: args, result: result)
        case "audio.setNoiseSuppression":         handleAudioSetNoiseSuppression(args: args, result: result)
        case "audio.getAudioDeviceList":          handleAudioGetDeviceList(result: result)
        case "audio.selectAudioDevice":           handleAudioSelectDevice(args: args, result: result)

        // Video
        case "video.startVideo":                  handleVideoStartVideo(result: result)
        case "video.stopVideo":                   handleVideoStopVideo(result: result)
        case "video.switchCamera":                handleVideoSwitchCamera(result: result)
        case "video.getCameraList":               handleVideoGetCameraList(result: result)
        case "video.selectCamera":                handleVideoSelectCamera(args: args, result: result)
        case "video.setVideoQualityPreference":   handleVideoSetQualityPreference(args: args, result: result)

        // Share
        case "share.startShareScreen":            handleShareStartScreen(args: args, result: result)
        case "share.startShareView":              handleShareStartView(args: args, result: result)
        case "share.stopShare":                   handleShareStop(result: result)
        case "share.enableShareDeviceAudio":      handleShareEnableDeviceAudio(args: args, result: result)
        case "share.getShareSourceList":          handleShareGetSourceList(result: result)
        case "share.enableOptimizeForSharedVideo": handleShareEnableOptimizeForVideo(args: args, result: result)

        // Chat
        case "chat.sendChatToAll":                handleChatSendToAll(args: args, result: result)
        case "chat.sendChatToUser":               handleChatSendToUser(args: args, result: result)
        case "chat.isChatDisabled":               handleChatIsDisabled(result: result)
        case "chat.isPrivateChatDisabled":        handleChatIsPrivateDisabled(result: result)

        // Recording
        case "recording.canStartRecording":       handleRecordingCanStart(result: result)
        case "recording.startCloudRecording":     handleRecordingStart(result: result)
        case "recording.stopCloudRecording":      handleRecordingStop(result: result)

        // Virtual Background
        case "virtualBackground.isSupported":     handleVBIsSupported(result: result)
        case "virtualBackground.addItem":         handleVBAddItem(args: args, result: result)
        case "virtualBackground.getItemList":     handleVBGetItemList(result: result)
        case "virtualBackground.setItem":         handleVBSetItem(args: args, result: result)
        case "virtualBackground.removeItem":      handleVBRemoveItem(args: args, result: result)
        case "virtualBackground.getSelectedItem": handleVBGetSelectedItem(result: result)

        // User Management
        case "user.makeHost":                     handleUserMakeHost(args: args, result: result)
        case "user.makeManager":                  handleUserMakeManager(args: args, result: result)
        case "user.revokeManager":                handleUserRevokeManager(args: args, result: result)
        case "user.removeUser":                   handleUserRemove(args: args, result: result)
        case "user.changeName":                   handleUserChangeName(args: args, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Helpers

    fileprivate var sdk: ZMVideoSDK? { ZMVideoSDK.shared() }

    fileprivate func findUser(byId userId: String) -> ZMVideoSDKUser? {
        guard let session = sdk?.getSessionInfo() else { return nil }
        if let myself = session.getMySelf(), (myself.getID() ?? "") == userId {
            return myself
        }
        return session.getRemoteUsers()?.first { ($0.getID() ?? "") == userId }
    }

    fileprivate func flutterError(_ code: String, _ message: String) -> FlutterError {
        FlutterError(code: code, message: message, details: nil)
    }

    /// SDK err 반환을 FlutterResult로 전달. Success면 nil, 아니면 FlutterError.
    fileprivate func reply(_ err: ZMVideoSDKErrors?, _ result: FlutterResult, _ code: String, _ op: String) {
        if err == ZMVideoSDKErrors_Success {
            result(nil)
        } else {
            result(flutterError(code, "\(op) failed: \(String(describing: err))"))
        }
    }

    /// Bool 반환(true=성공)을 FlutterResult로 전달.
    fileprivate func reply(_ success: Bool, _ result: FlutterResult, _ code: String, _ op: String) {
        if success {
            result(nil)
        } else {
            result(flutterError(code, "\(op) failed"))
        }
    }

    /// args["userId"]로 사용자 조회. 실패 시 FlutterError 응답하고 nil 반환.
    fileprivate func requireUser(_ args: [String: Any]?, _ result: FlutterResult) -> ZMVideoSDKUser? {
        guard let userId = args?["userId"] as? String,
              let user = findUser(byId: userId) else {
            result(flutterError("INVALID_ARGS", "User not found"))
            return nil
        }
        return user
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
        guard sdkResult == ZMVideoSDKErrors_Success else {
            result(flutterError("INIT_FAILED", "SDK init failed: \(String(describing: sdkResult))"))
            return
        }
        if let handler = eventStreamHandler {
            sdk?.addListener(handler)
        }
        // TCC 마이크 권한 프롬프트를 사전에 트리거. startAudio 시점에 macOS가
        // 권한 거부를 조용히 처리하여 무음 송출되는 문제 방지.
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        // 카메라 TCC도 동일하게 사전 요청 (startVideo 시점 조용한 실패 방지).
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        result(nil)
    }

    /// SDK 자원 해제. cleanUp 후 재초기화(init) 가능. 세션 중에는 호출 금지(헤더 주의).
    func handleCleanup(result: @escaping FlutterResult) {
        sdk?.cleanUp()
        result(nil)
    }

    func handleSendCommand(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let command = args?["command"] as? String else {
            result(flutterError("INVALID_ARGS", "command required"))
            return
        }
        guard let cmdChannel = sdk?.getCmdChannel() else {
            result(flutterError("NO_SESSION", "command channel unavailable"))
            return
        }
        var receiver: ZMVideoSDKUser?
        if let receiverId = args?["receiverUserId"] as? String {
            guard let found = findUser(byId: receiverId) else {
                result(flutterError("USER_NOT_FOUND", "receiver not in session"))
                return
            }
            receiver = found
        }
        // 헤더: - (ZMVideoSDKErrors)sendCommand:receiveUser: , receiver nil이면 전체 broadcast.
        // Swift ObjC 임포터가 receiveUser: 라벨을 receive: 로 축약.
        let sdkResult = cmdChannel.sendCommand(command, receive: receiver)
        guard sdkResult == ZMVideoSDKErrors_Success else {
            result(flutterError("SEND_COMMAND_FAILED",
                                "sendCommand failed: \(sdkResult.rawValue)"))
            return
        }
        result(nil)
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
            audio.autoAdjustSpeakerVolume = audioOpts["autoAdjustSpeakerVolume"] as? Bool ?? true
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

        if sdk?.joinSession(ctx) != nil {
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
        users.append(contentsOf: (session.getRemoteUsers() ?? []).map { ZoomSerializer.serializeUser($0) })
        result(users)
    }

    func handleGetRemoteUsers(result: @escaping FlutterResult) {
        guard let session = sdk?.getSessionInfo() else {
            result(flutterError("NO_SESSION", "No active session"))
            return
        }
        result((session.getRemoteUsers() ?? []).map { ZoomSerializer.serializeUser($0) })
    }
}

// MARK: - Audio Handlers

private extension ZoomVideoSdkFlutterPlugin {

    func handleAudioStartAudio(result: @escaping FlutterResult) {
        // TCC 권한이 거부/제한 상태면 SDK는 성공 반환해도 실제 마이크 데이터는
        // 전송되지 않음. 조용한 실패 대신 명확한 오류를 돌려준다.
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .denied || status == .restricted {
            result(flutterError(
                "MIC_PERMISSION_DENIED",
                "Microphone permission denied. Enable it in System Settings → Privacy & Security → Microphone."
            ))
            return
        }
        reply(sdk?.getAudioHelper().startAudio(), result, "AUDIO_ERROR", "startAudio")
    }

    func handleAudioStopAudio(result: @escaping FlutterResult) {
        reply(sdk?.getAudioHelper().stopAudio(), result, "AUDIO_ERROR", "stopAudio")
    }

    func handleAudioMuteAudio(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let user = requireUser(args, result) else { return }
        reply(sdk?.getAudioHelper().muteAudio(user), result, "AUDIO_ERROR", "muteAudio")
    }

    func handleAudioUnmuteAudio(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let user = requireUser(args, result) else { return }
        reply(sdk?.getAudioHelper().unMuteAudio(user), result, "AUDIO_ERROR", "unmuteAudio")
    }

    func handleAudioEnableMicOriginalInput(args: [String: Any]?, result: @escaping FlutterResult) {
        let enable = args?["enable"] as? Bool ?? false
        reply(sdk?.getAudioSettingHelper().enableMicOriginalInput(enable),
              result, "AUDIO_ERROR", "enableMicOriginalInput")
    }

    func handleAudioSetNoiseSuppression(args: [String: Any]?, result: @escaping FlutterResult) {
        let level: ZMVideoSDKSuppressBackgroundNoiseLevel
        switch args?["level"] as? String {
        case "low":    level = ZMVideoSDKSuppressBackgroundNoiseLevel_Low
        case "medium": level = ZMVideoSDKSuppressBackgroundNoiseLevel_Medium
        case "high":   level = ZMVideoSDKSuppressBackgroundNoiseLevel_High
        default:       level = ZMVideoSDKSuppressBackgroundNoiseLevel_Auto
        }
        reply(sdk?.getAudioSettingHelper().setSuppressBackgroundNoiseLevel(level),
              result, "AUDIO_ERROR", "setNoiseSuppression")
    }

    func handleAudioGetDeviceList(result: @escaping FlutterResult) {
        guard let helper = sdk?.getAudioHelper() else {
            result([])
            return
        }
        let mics = (helper.getMicList() ?? []).map { ZoomSerializer.serializeMicDevice($0) }
        let speakers = (helper.getSpeakerList() ?? []).map { ZoomSerializer.serializeSpeakerDevice($0) }
        result(mics + speakers)
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
        if let mic = helper.getMicList()?.first(where: { $0.deviceId == deviceId }),
           helper.selectMic(mic.deviceId, deviceName: mic.deviceName) == ZMVideoSDKErrors_Success {
            result(nil)
            return
        }
        if let speaker = helper.getSpeakerList()?.first(where: { $0.deviceId == deviceId }),
           helper.selectSpeaker(speaker.deviceId, deviceName: speaker.deviceName) == ZMVideoSDKErrors_Success {
            result(nil)
            return
        }
        result(flutterError("AUDIO_ERROR", "Device not found: \(deviceId)"))
    }
}

// MARK: - Video Handlers

private extension ZoomVideoSdkFlutterPlugin {

    func handleVideoStartVideo(result: @escaping FlutterResult) {
        reply(sdk?.getVideoHelper().startVideo(), result, "VIDEO_ERROR", "startVideo")
    }

    func handleVideoStopVideo(result: @escaping FlutterResult) {
        reply(sdk?.getVideoHelper().stopVideo(), result, "VIDEO_ERROR", "stopVideo")
    }

    func handleVideoSwitchCamera(result: @escaping FlutterResult) {
        reply(sdk?.getVideoHelper().switchCamera() ?? false, result, "VIDEO_ERROR", "switchCamera")
    }

    func handleVideoGetCameraList(result: @escaping FlutterResult) {
        let cameras = sdk?.getVideoHelper().getCameraList() ?? []
        result(cameras.map { ZoomSerializer.serializeCameraDevice($0) })
    }

    func handleVideoSelectCamera(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let deviceId = args?["deviceId"] as? String else {
            result(flutterError("INVALID_ARGS", "deviceId required"))
            return
        }
        reply(sdk?.getVideoHelper().selectCamera(deviceId) ?? false,
              result, "VIDEO_ERROR", "selectCamera")
    }

    func handleVideoSetQualityPreference(args: [String: Any]?, result: @escaping FlutterResult) {
        let mode: ZMVideoSDKVideoPreferenceMode
        switch args?["mode"] as? String {
        case "sharpness":  mode = ZMVideoSDKVideoPreferenceMode_Sharpness
        case "smoothness": mode = ZMVideoSDKVideoPreferenceMode_Smoothness
        case "custom":     mode = ZMVideoSDKVideoPreferenceMode_Custom
        default:           mode = ZMVideoSDKVideoPreferenceMode_Balance
        }
        let pref = ZMVideoSDKPreferenceSetting()
        pref.mode = mode
        pref.minimumFrameRate = UInt32(max(0, args?["minimumFrameRate"] as? Int ?? 0))
        pref.maximumFrameRate = UInt32(max(0, args?["maximumFrameRate"] as? Int ?? 0))
        reply(sdk?.getVideoHelper().setVideoQualityPreference(pref),
              result, "VIDEO_ERROR", "setVideoQualityPreference")
    }
}

// MARK: - Share Handlers

private extension ZoomVideoSdkFlutterPlugin {

    func handleShareStartScreen(args: [String: Any]?, result: @escaping FlutterResult) {
        let displayId: CGDirectDisplayID = {
            if let s = args?["monitorId"] as? String, let parsed = UInt32(s) { return parsed }
            return CGMainDisplayID()
        }()
        let option = buildShareOption(args?["option"] as? [String: Any])
        reply(sdk?.getShareHelper().startShareScreen(displayId, shareOption: option),
              result, "SHARE_ERROR", "startShareScreen")
    }

    func buildShareOption(_ map: [String: Any]?) -> ZMVideoSDKShareOption {
        let option = ZMVideoSDKShareOption()
        option.isWithDeviceAudio = (map?["withDeviceAudio"] as? Bool) ?? false
        option.isOptimizeForSharedVideo = (map?["optimizeForSharedVideo"] as? Bool) ?? false
        return option
    }

    func handleShareGetSourceList(result: @escaping FlutterResult) {
        var sources: [[String: Any]] = []

        // Monitors (NSScreen → CGDirectDisplayID)
        let screenKey = NSDeviceDescriptionKey("NSScreenNumber")
        for (idx, screen) in NSScreen.screens.enumerated() {
            guard let number = screen.deviceDescription[screenKey] as? NSNumber else { continue }
            let name = screen.localizedName.isEmpty ? "Display \(idx + 1)" : screen.localizedName
            sources.append([
                "sourceId": String(number.uint32Value),
                "name": name,
                "type": "screen",
            ])
        }

        // Windows (CGWindowListCopyWindowInfo, on-screen, excluding desktop)
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        for info in windowList {
            guard
                let windowNumber = info[kCGWindowNumber as String] as? NSNumber,
                (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0
            else { continue }
            let owner = info[kCGWindowOwnerName as String] as? String ?? ""
            let title = info[kCGWindowName as String] as? String ?? ""
            guard let label = windowLabel(owner: owner, title: title) else { continue }
            sources.append([
                "sourceId": String(windowNumber.uint32Value),
                "name": label,
                "type": "window",
            ])
        }

        result(sources)
    }

    private func windowLabel(owner: String, title: String) -> String? {
        switch (owner.isEmpty, title.isEmpty) {
        case (false, false): return "\(owner) — \(title)"
        case (false, true):  return owner
        case (true, false):  return title
        case (true, true):   return nil
        }
    }

    func handleShareStartView(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let windowIdStr = args?["windowId"] as? String,
              let windowId = UInt32(windowIdStr) else {
            result(flutterError("INVALID_ARGS", "windowId required"))
            return
        }
        let option = buildShareOption(args?["option"] as? [String: Any])
        reply(sdk?.getShareHelper().startShareView(CGWindowID(windowId), shareOption: option),
              result, "SHARE_ERROR", "startShareView")
    }

    func handleShareStop(result: @escaping FlutterResult) {
        reply(sdk?.getShareHelper().stopShare(), result, "SHARE_ERROR", "stopShare")
    }

    func handleShareEnableOptimizeForVideo(args: [String: Any]?, result: @escaping FlutterResult) {
        let enable = args?["enable"] as? Bool ?? false
        reply(sdk?.getShareHelper().enableOptimize(forSharedVideo: enable),
              result, "SHARE_ERROR", "enableOptimizeForSharedVideo")
    }

    func handleShareEnableDeviceAudio(args: [String: Any]?, result: @escaping FlutterResult) {
        let enable = args?["enable"] as? Bool ?? false
        reply(sdk?.getShareHelper().enableShareDeviceAudio(enable),
              result, "SHARE_ERROR", "enableShareDeviceAudio")
    }
}

// MARK: - Chat Handlers

private extension ZoomVideoSdkFlutterPlugin {

    func handleChatSendToAll(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let message = args?["message"] as? String else {
            result(flutterError("INVALID_ARGS", "message required"))
            return
        }
        reply(sdk?.getChatHelper().sendChat(toAll: message),
              result, "CHAT_ERROR", "sendChatToAll")
    }

    func handleChatSendToUser(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let message = args?["message"] as? String else {
            result(flutterError("INVALID_ARGS", "message required"))
            return
        }
        guard let user = requireUser(args, result) else { return }
        reply(sdk?.getChatHelper().sendChat(to: user, content: message),
              result, "CHAT_ERROR", "sendChatToUser")
    }

    func handleChatIsDisabled(result: @escaping FlutterResult) {
        result(sdk?.getChatHelper().isChatDisabled() ?? false)
    }

    func handleChatIsPrivateDisabled(result: @escaping FlutterResult) {
        result(sdk?.getChatHelper().isPrivateChatDisabled() ?? false)
    }
}

// MARK: - Recording Handlers

private extension ZoomVideoSdkFlutterPlugin {

    func handleRecordingCanStart(result: @escaping FlutterResult) {
        result(sdk?.getRecordingHelper().canStartRecording() == ZMVideoSDKErrors_Success)
    }

    func handleRecordingStart(result: @escaping FlutterResult) {
        reply(sdk?.getRecordingHelper().startCloudRecording(),
              result, "RECORDING_ERROR", "startCloudRecording")
    }

    func handleRecordingStop(result: @escaping FlutterResult) {
        reply(sdk?.getRecordingHelper().stopCloudRecording(),
              result, "RECORDING_ERROR", "stopCloudRecording")
    }
}

// MARK: - Virtual Background Handlers
// ZMVideoSDKVirtualBackgroundItem 심볼이 SDK 바이너리에 export되지 않아
// 직접 타입 참조 시 링커 에러 발생. performSelector + KVC로 우회.

private extension ZoomVideoSdkFlutterPlugin {

    enum VBSelector {
        static let addItem     = NSSelectorFromString("addVirtualBackgroundItem:imageItem:")
        static let getList     = NSSelectorFromString("getVirtualBackgroundItemList")
        static let setItem     = NSSelectorFromString("setVirtualBackgroundItem:")
        static let removeItem  = NSSelectorFromString("removeVirtualBackgroundItem:")
        static let getSelected = NSSelectorFromString("getSelectedVirtualBackgroundItem")
    }

    func handleVBIsSupported(result: @escaping FlutterResult) {
        result(sdk?.getVideoHelper() != nil)
    }

    func handleVBAddItem(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let filePath = args?["filePath"] as? String else {
            result(flutterError("INVALID_ARGS", "filePath required"))
            return
        }
        guard let helper = sdk?.getVideoHelper(), helper.responds(to: VBSelector.addItem) else {
            result(flutterError("VB_ERROR", "addItem not supported"))
            return
        }
        helper.perform(VBSelector.addItem, with: filePath, with: nil)
        // 네이티브 add는 동기 반환값이 불안정(KVC 경유) — 목록에서 방금 추가된
        // 항목(imageName == 파일명, 또는 imagePath == 입력 경로)을 찾아 돌려준다.
        let fileName = (filePath as NSString).lastPathComponent
        let added = vbItems().map(serializeVBItem).first {
            ($0["imageName"] as? String) == fileName
                || ($0["imagePath"] as? String) == filePath
        }
        result(added)
    }

    func handleVBGetItemList(result: @escaping FlutterResult) {
        result(vbItems().map(serializeVBItem))
    }

    func handleVBSetItem(args: [String: Any]?, result: @escaping FlutterResult) {
        performVBItemAction(args: args, selector: VBSelector.setItem,
                            opName: "setItem", result: result)
    }

    func handleVBRemoveItem(args: [String: Any]?, result: @escaping FlutterResult) {
        performVBItemAction(args: args, selector: VBSelector.removeItem,
                            opName: "removeItem", result: result)
    }

    func handleVBGetSelectedItem(result: @escaping FlutterResult) {
        guard let helper = sdk?.getVideoHelper(),
              helper.responds(to: VBSelector.getSelected),
              let obj = helper.perform(VBSelector.getSelected)?.takeUnretainedValue() as? NSObject else {
            result(nil)
            return
        }
        result(serializeVBItem(obj))
    }

    // MARK: VB helpers

    private func performVBItemAction(
        args: [String: Any]?,
        selector: Selector,
        opName: String,
        result: @escaping FlutterResult
    ) {
        guard let imageName = args?["imageName"] as? String else {
            result(flutterError("INVALID_ARGS", "imageName required"))
            return
        }
        guard let helper = sdk?.getVideoHelper() else {
            result(flutterError("VB_ERROR", "Video helper not available"))
            return
        }
        guard let item = findVBItem(named: imageName) else {
            result(flutterError("VB_ERROR", "Item not found: \(imageName)"))
            return
        }
        guard helper.responds(to: selector) else {
            result(flutterError("VB_ERROR", "\(opName) not supported"))
            return
        }
        helper.perform(selector, with: item)
        result(nil)
    }

    private func vbItems() -> [NSObject] {
        guard let helper = sdk?.getVideoHelper(),
              helper.responds(to: VBSelector.getList),
              let raw = helper.perform(VBSelector.getList)?.takeUnretainedValue() as? NSArray else {
            return []
        }
        return raw.compactMap { $0 as? NSObject }
    }

    private func findVBItem(named name: String) -> NSObject? {
        vbItems().first { ($0.value(forKey: "imageName") as? String) == name }
    }

    private func serializeVBItem(_ obj: NSObject) -> [String: Any] {
        var map: [String: Any] = [
            "imageName": obj.value(forKey: "imageName") as? String ?? "",
            "imagePath": obj.value(forKey: "imageFilePath") as? String ?? "",
        ]
        // ZMVideoSDKVirtualBackgroundDataType raw: 0=None, 1=Image, 2=Blur (헤더 ZMVideoSDKDef.h 확인).
        // enum 반환을 perform()으로 받으면 불안정하므로 KVC로 읽는다.
        var typeName = "image"
        if let raw = (obj.value(forKey: "type") as? NSNumber)?.intValue {
            let names = ["none", "image", "blur"]
            typeName = (0..<names.count).contains(raw) ? names[raw] : "image"
        }
        map["type"] = typeName
        return map
    }
}

// MARK: - User Management Handlers

private extension ZoomVideoSdkFlutterPlugin {

    func handleUserMakeHost(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let user = requireUser(args, result) else { return }
        reply(sdk?.getUserHelper().makeHost(user) ?? false, result, "USER_ERROR", "makeHost")
    }

    func handleUserMakeManager(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let user = requireUser(args, result) else { return }
        reply(sdk?.getUserHelper().makeManager(user) ?? false, result, "USER_ERROR", "makeManager")
    }

    func handleUserRevokeManager(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let user = requireUser(args, result) else { return }
        reply(sdk?.getUserHelper().revokeManager(user), result, "USER_ERROR", "revokeManager")
    }

    func handleUserRemove(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let user = requireUser(args, result) else { return }
        reply(sdk?.getUserHelper().remove(user) ?? false, result, "USER_ERROR", "removeUser")
    }

    func handleUserChangeName(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let name = args?["name"] as? String else {
            result(flutterError("INVALID_ARGS", "name required"))
            return
        }
        guard let user = requireUser(args, result) else { return }
        reply(sdk?.getUserHelper().changeName(name, user: user) ?? false,
              result, "USER_ERROR", "changeName")
    }
}
