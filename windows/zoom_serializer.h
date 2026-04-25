#ifndef ZOOM_SERIALIZER_H_
#define ZOOM_SERIALIZER_H_

#include <flutter/encodable_value.h>
#include <string>
#include <windows.h>

#include "zoom_video_sdk_api.h"
#include "zoom_video_sdk_interface.h"
#include "zoom_video_sdk_session_info_interface.h"
#include "zoom_video_sdk_chat_message_interface.h"
#include "helpers/zoom_video_sdk_user_helper_interface.h"
#include "helpers/zoom_video_sdk_audio_helper_interface.h"
#include "helpers/zoom_video_sdk_video_helper_interface.h"

USING_ZOOM_VIDEO_SDK_NAMESPACE

namespace zoom_video_sdk_flutter {

// wchar_t(Windows zchar_t) → UTF-8 std::string
inline std::string WideToUtf8(const wchar_t* wide) {
    if (!wide || wide[0] == L'\0') return "";
    int len = WideCharToMultiByte(CP_UTF8, 0, wide, -1, nullptr, 0, nullptr, nullptr);
    if (len <= 0) return "";
    std::string result(len - 1, '\0');
    WideCharToMultiByte(CP_UTF8, 0, wide, -1, &result[0], len, nullptr, nullptr);
    return result;
}

// UTF-8 std::string → wchar_t std::wstring
inline std::wstring Utf8ToWide(const std::string& utf8) {
    if (utf8.empty()) return L"";
    int len = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
    if (len <= 0) return L"";
    std::wstring result(len - 1, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, &result[0], len);
    return result;
}

// --- Enum serializers ---

inline std::string SerializeAudioType(ZoomVideoSDKAudioType type) {
    if (type == ZoomVideoSDKAudioType_VOIP) return "voip";
    if (type == ZoomVideoSDKAudioType_TELEPHONY) return "telephony";
    return "none";
}

inline std::string SerializeShareStatus(ZoomVideoSDKShareStatus status) {
    if (status == ZoomVideoSDKShareStatus_Start || status == ZoomVideoSDKShareStatus_Resume)
        return "started";
    if (status == ZoomVideoSDKShareStatus_Pause) return "paused";
    return "stopped";
}

inline std::string SerializeErrorCode(ZoomVideoSDKErrors error) {
    if (error == ZoomVideoSDKErrors_Success) return "success";
    if (error == ZoomVideoSDKErrors_Wrong_Usage || error == ZoomVideoSDKErrors_Invalid_Parameter)
        return "invalidParameter";
    if (error == ZoomVideoSDKErrors_Auth_Error) return "authenticationFailed";
    if (error == ZoomVideoSDKErrors_Session_No_Rights) return "permissionDenied";
    if (error == ZoomVideoSDKErrors_Session_Reconnecting) return "networkError";
    return "unknown";
}

// --- Object serializers ---

inline flutter::EncodableMap SerializeUser(IZoomVideoSDKUser* user) {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("userId")] =
        flutter::EncodableValue(WideToUtf8(user->getUserID()));
    map[flutter::EncodableValue("userName")] =
        flutter::EncodableValue(WideToUtf8(user->getUserName()));
    map[flutter::EncodableValue("isHost")] =
        flutter::EncodableValue(user->isHost());
    map[flutter::EncodableValue("isManager")] =
        flutter::EncodableValue(user->isManager());

    // Audio status
    auto audioStatus = user->getAudioStatus();
    flutter::EncodableMap audioMap;
    audioMap[flutter::EncodableValue("isMuted")] =
        flutter::EncodableValue(audioStatus.isMuted);
    audioMap[flutter::EncodableValue("isTalking")] =
        flutter::EncodableValue(audioStatus.isTalking);
    audioMap[flutter::EncodableValue("audioType")] =
        flutter::EncodableValue(SerializeAudioType(audioStatus.audioType));
    map[flutter::EncodableValue("audioStatus")] =
        flutter::EncodableValue(audioMap);

    // Video status
    auto* videoPipe = user->GetVideoPipe();
    if (videoPipe) {
        auto videoStatus = videoPipe->getVideoStatus();
        flutter::EncodableMap videoMap;
        videoMap[flutter::EncodableValue("isOn")] =
            flutter::EncodableValue(videoStatus.isOn);
        videoMap[flutter::EncodableValue("hasSource")] =
            flutter::EncodableValue(videoStatus.isHasVideoDevice);
        map[flutter::EncodableValue("videoStatus")] =
            flutter::EncodableValue(videoMap);
    }

    // Share status — true iff the user has at least one active share action.
    // Lets late joiners detect an in-progress share that fired its
    // userShareStatusChanged event before they joined.
    auto* shareList = user->getShareActionList();
    bool isSharing = shareList && shareList->GetCount() > 0;
    map[flutter::EncodableValue("isSharing")] =
        flutter::EncodableValue(isSharing);

    return map;
}

inline flutter::EncodableList SerializeUserList(
    IVideoSDKVector<IZoomVideoSDKUser*>* userList) {
    flutter::EncodableList list;
    if (!userList) return list;
    for (int i = 0; i < userList->GetCount(); i++) {
        list.push_back(flutter::EncodableValue(SerializeUser(userList->GetItem(i))));
    }
    return list;
}

inline flutter::EncodableMap SerializeSessionInfo(IZoomVideoSDKSession* session) {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("sessionName")] =
        flutter::EncodableValue(WideToUtf8(session->getSessionName()));
    map[flutter::EncodableValue("sessionId")] =
        flutter::EncodableValue(WideToUtf8(session->getSessionID()));

    auto* password = session->getSessionPassword();
    std::string pw = WideToUtf8(password);
    if (!pw.empty()) {
        map[flutter::EncodableValue("sessionPassword")] =
            flutter::EncodableValue(pw);
    }

    auto* host = session->getSessionHost();
    if (host) {
        std::string hostId = WideToUtf8(host->getUserID());
        if (!hostId.empty()) {
            map[flutter::EncodableValue("host")] =
                flutter::EncodableValue(SerializeUser(host));
        }
    }

    return map;
}

inline flutter::EncodableMap SerializeChatMessage(IZoomVideoSDKChatMessage* msg) {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("content")] =
        flutter::EncodableValue(WideToUtf8(msg->getContent()));
    map[flutter::EncodableValue("isChatToAll")] =
        flutter::EncodableValue(msg->isChatToAll());
    map[flutter::EncodableValue("isSelfSend")] =
        flutter::EncodableValue(msg->isSelfSend());
    map[flutter::EncodableValue("timestamp")] =
        flutter::EncodableValue(static_cast<int64_t>(msg->getTimeStamp()));

    auto* sender = msg->getSendUser();
    if (sender) {
        std::string senderId = WideToUtf8(sender->getUserID());
        if (!senderId.empty()) {
            map[flutter::EncodableValue("senderUser")] =
                flutter::EncodableValue(SerializeUser(sender));
        }
    }

    auto* receiver = msg->getReceiveUser();
    if (receiver) {
        std::string receiverId = WideToUtf8(receiver->getUserID());
        if (!receiverId.empty()) {
            map[flutter::EncodableValue("receiverUser")] =
                flutter::EncodableValue(SerializeUser(receiver));
        }
    }

    return map;
}

inline flutter::EncodableMap SerializeSpeakerDevice(IZoomVideoSDKSpeakerDevice* device) {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("deviceId")] =
        flutter::EncodableValue(WideToUtf8(device->getDeviceId()));
    map[flutter::EncodableValue("deviceName")] =
        flutter::EncodableValue(WideToUtf8(device->getDeviceName()));
    return map;
}

inline flutter::EncodableMap SerializeMicDevice(IZoomVideoSDKMicDevice* device) {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("deviceId")] =
        flutter::EncodableValue(WideToUtf8(device->getDeviceId()));
    map[flutter::EncodableValue("deviceName")] =
        flutter::EncodableValue(WideToUtf8(device->getDeviceName()));
    return map;
}

inline flutter::EncodableMap SerializeCameraDevice(IZoomVideoSDKCameraDevice* device) {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("deviceId")] =
        flutter::EncodableValue(WideToUtf8(device->getDeviceId()));
    map[flutter::EncodableValue("deviceName")] =
        flutter::EncodableValue(WideToUtf8(device->getDeviceName()));
    return map;
}

inline flutter::EncodableMap SerializeVirtualBackgroundItem(IVirtualBackgroundItem* item) {
    flutter::EncodableMap map;
    map[flutter::EncodableValue("imageName")] =
        flutter::EncodableValue(WideToUtf8(item->getImageName()));
    map[flutter::EncodableValue("imagePath")] =
        flutter::EncodableValue(WideToUtf8(item->getImageFilePath()));
    return map;
}

}  // namespace zoom_video_sdk_flutter

#endif  // ZOOM_SERIALIZER_H_
