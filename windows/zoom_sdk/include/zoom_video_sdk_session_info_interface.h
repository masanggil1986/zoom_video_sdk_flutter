/**
 * @file zoom_video_sdk_session_info_interface.h
 * @brief Zoom video sdk session info interface.
 */

#ifndef _ZOOM_VIDEO_SDK_SESSION_INFO_INTERFACE_H_
#define _ZOOM_VIDEO_SDK_SESSION_INFO_INTERFACE_H_
#include "zoom_video_sdk_def.h"
#include "zoom_video_sdk_vector_interface.h"
#include <string.h>
BEGIN_ZOOM_VIDEO_SDK_NAMESPACE
class IZoomVideoSDKUser;

/**
 * @brief Session audio statistic information.
 */
typedef struct _SessionAudioStatisticInfo
{
	/** The frequency in kilohertz (KHz). */
	int   frequency; 
	/** The audio latency in milliseconds (delay in network data transfer). */
	int   latency;   
	/** The audio jitter in milliseconds (change in latency). */
	int   Jitter;    
	/** The percentage of average audio packet loss. */
	float packetLossAvg; 
	/** The percentage of maximum audio packet loss. */
	float packetLossMax; 

	_SessionAudioStatisticInfo()
	{
		reset();
	}

	void reset() 
	{
		memset(this, 0, sizeof(_SessionAudioStatisticInfo));  
	}
}ZoomVideoSDKSessionAudioStatisticInfo;

/**
 * @brief Session video/share statistic information.
 */
typedef struct _SessionASVStatisticInfo
{
	/** The frame width in pixels. */
	int	  frame_width;	
	/** The frame height in pixels. */
	int   frame_height;	
	/** The frame rate in FPS (Frames Per Second). */
	int   fps;     
	/** The video latency in milliseconds (delay in network data transfer). */
	int   latency; 
	/** The video jitter in milliseconds (change in latency). */
	int   Jitter;  
	/** The percentage of average video packet loss. */
	float packetLossAvg; 
	/** The percentage of maximum video packet loss. */
	float packetLossMax; 

	_SessionASVStatisticInfo()
	{
		reset();
	}

	void reset() 
	{
		frame_width = 0;
		frame_height = 0;
		fps = 0;
		latency = 0;
		Jitter = 0;
		packetLossAvg = 0.0;
		packetLossMax = 0.0;
	}
}ZoomVideoSDKSessionASVStatisticInfo;
/**
 * @class IZoomVideoSDKSession
 * @brief Session information interface.
 */
class IZoomVideoSDKSession
{
public:
	/**
	 * @brief Get the current session number.
	 * @return If the function succeeds, the return value is the current meeting number. Otherwise, this function fails and returns ZERO(0).
	 */
	virtual uint64_t getSessionNumber() = 0;
	
	/**
	 * @brief Get the session name.
	 * @return If the function succeeds, the return value is the session name. Otherwise, this function fails and returns nullptr.
	 */
	virtual const zchar_t* getSessionName() = 0;
	
	/**
	 * @brief Get the session's password.
	 * @return If the function succeeds, the return value is the session password. Otherwise, this function fails and returns nullptr.
	 */
	virtual const zchar_t* getSessionPassword() = 0;
	
	/**
	 * @brief Get the session phone passcode.
	 * @return If the function succeeds, the return value is the session phone passcode. Otherwise, this function fails and returns nullptr.
	 */
	virtual const zchar_t* getSessionPhonePasscode() = 0;
	
	/**
	 * @brief Get the session ID.
	 * @return If the function succeeds, the return value is the session ID. Otherwise, this function fails and returns nullptr.
	 * @note This interface is only valid for the host.
	 */
	virtual const zchar_t* getSessionID() = 0;
	
	/**
	 * @brief Get the host's name.
	 * @return If the function succeeds, the return value is the session host name. Otherwise, this function fails and returns nullptr.
	 */
	virtual const zchar_t* getSessionHostName() = 0;
	
	/**
	 * @brief Get the session's host user object.
	 * @return If the function succeeds, the return value is the session host user object. Otherwise, this function fails and returns nullptr.
	 */
	virtual IZoomVideoSDKUser* getSessionHost() = 0;
	
	/**
	 * @brief Get a list of the session's remote users.
	 * @return If the function succeeds, the return value is the remote users list. Otherwise, this function fails and returns nullptr.
	 */
	virtual IVideoSDKVector<IZoomVideoSDKUser*>* getRemoteUsers() = 0;
	
	/**
	 * @brief Get the session's user object for myself.
	 * @return If the function succeeds, the return value is the myself object. Otherwise, this function fails and returns nullptr.
	 */
	virtual IZoomVideoSDKUser* getMyself() = 0;
	
	/**
	 * @brief Determines if a user object is valid.
	 * @param pUser The user object pointer.
	 * @return true if the user object is valid. Otherwise, false.
	 */
	virtual bool IsValidUser(IZoomVideoSDKUser* pUser) = 0;
	
	/**
	 * @brief Get session's audio statistic information.
	 * @param [out] send_info Audio send information refer.
	 * @param [out] recv_info Audio receive information refer.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error. 
	 */
	virtual ZoomVideoSDKErrors getSessionAudioStatisticInfo(ZoomVideoSDKSessionAudioStatisticInfo& send_info, ZoomVideoSDKSessionAudioStatisticInfo& recv_info) = 0;
	
	/**
	 * @brief Get session's video statistic information.
	 * @param [out] send_info Video send information refer.
	 * @param [out] recv_info Video receive information refer.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error. 
	 */
	virtual ZoomVideoSDKErrors getSessionVideoStatisticInfo(ZoomVideoSDKSessionASVStatisticInfo& send_info, ZoomVideoSDKSessionASVStatisticInfo& recv_info) = 0;
	
	/**
	 * @brief Get session's share statistic information.
	 * @param [out] send_info Share send information refer.
	 * @param [out] recv_info Share receive information refer.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error. 
	 */
	virtual ZoomVideoSDKErrors getSessionShareStatisticInfo(ZoomVideoSDKSessionASVStatisticInfo& send_info, ZoomVideoSDKSessionASVStatisticInfo& recv_info) = 0;
	
	/**
	 * @brief Determines whether file transfer is enabled.
	 * @return true if file transfer is enabled. Otherwise, false.
	 */
	virtual bool isFileTransferEnable() = 0;
	
	/**
	 * @brief Send file to all users in current session.
	 * @param filePath The local path of the file.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.
	 */
	virtual ZoomVideoSDKErrors transferFile(const zchar_t* filePath) = 0;
	
	/**
	 * @brief Get the list of allowed file types in transfer.
	 * @return The value of allowed file types in transfer, comma-separated if there are multiple values.Exe files are by default forbidden from being transferred.
	 */
	virtual const zchar_t* getTransferFileTypeWhiteList() = 0;
	
	/**
	 * @brief Gets the maximum size for file transfer.
	 * @return The maximum number of bytes for file transfer.
	 */
	virtual uint64_t getMaxTransferFileSize() = 0;
	
	/**
	 * @brief Get the session type of this session.
	 * @return The session type.
	 */
	virtual ZoomVideoSDKSessionType getSessionType() = 0;
};
END_ZOOM_VIDEO_SDK_NAMESPACE
#endif