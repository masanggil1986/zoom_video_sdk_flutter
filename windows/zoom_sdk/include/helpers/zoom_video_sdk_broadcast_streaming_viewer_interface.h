/**
* @file zoom_video_sdk_broadcast_streaming_viewer_interface.h
* @brief broadcast streaming viewer
*
*/

#ifndef _ZOOM_VIDEO_SDK_BROADCAST_STREAMING_VIEWER_INTERFACE_H_
#define _ZOOM_VIDEO_SDK_BROADCAST_STREAMING_VIEWER_INTERFACE_H_
#include "zoom_video_sdk_def.h"
#include "zoom_video_sdk_vector_interface.h"
#include "zoom_sdk_raw_data_def.h"
#include "zoom_video_sdk_user_helper_interface.h"

BEGIN_ZOOM_VIDEO_SDK_NAMESPACE

/**
 * @brief Streaming join status enumeration.
 */
enum ZoomVideoSDKStreamingJoinStatus
{
	/** Initialized status. */
	ZoomVideoSDKStreamingJoinStatus_None,

	/** Connecting to streaming. */
	ZoomVideoSDKStreamingJoinStatus_Connecting,

	/** Joined streaming. */
	ZoomVideoSDKStreamingJoinStatus_Joined,

	/** Disconnecting from streaming. */
	ZoomVideoSDKStreamingJoinStatus_Disconnecting,

	/** Reconnecting to streaming. */
	ZoomVideoSDKStreamingJoinStatus_Reconnecting,

	/** Join failed. */
	ZoomVideoSDKStreamingJoinStatus_Failed,

	/** Left streaming. */
	ZoomVideoSDKStreamingJoinStatus_Left
};

/**
 * @brief Streaming join context.
 */
struct ZoomVideoSDKSteamingJoinContext
{
	/** JWT token. */
	const zchar_t* token;

	/** Broadcast channel ID. */
	const zchar_t* channelID;
};

/**
 * @class IZoomVideoSDKBroadcastStreamingVideoCallback
 * @brief Video callback interface for receiving broadcast streaming video data.
 */
class IZoomVideoSDKBroadcastStreamingVideoCallback
{
public:
	virtual ~IZoomVideoSDKBroadcastStreamingVideoCallback() {}

	/**
	 * @brief Called when subscribed video data is received.
	 * @param pRawDataObj The video data object.
	 */
	virtual void onVideoFrameReceived(YUVRawDataI420* pRawDataObj) = 0;
};

/**
 * @class IZoomVideoSDKBroadcastStreamingAudioCallback
 * @brief Audio callback interface for receiving broadcast streaming audio data.
 */
class IZoomVideoSDKBroadcastStreamingAudioCallback
{
public:
	virtual ~IZoomVideoSDKBroadcastStreamingAudioCallback() {}

	/**
	* @brief Called when subscribed audio data is received.
	* @param pRawDataObj The audio data object.
	*/
	virtual void onAudioRawDataReceived(AudioRawData* pAudioRawDataObj) = 0;
};

/**
 * @class IZoomVideoSDKBroadcastStreamingViewer
 * @brief Broadcast streaming viewer interface for viewing broadcast streams.
 */
class IZoomVideoSDKBroadcastStreamingViewer
{
public:
	virtual ~IZoomVideoSDKBroadcastStreamingViewer() {}

	/**
	 * @brief Joins broadcast streaming asynchronously. Result is notified via the callback 'onStreamingJoinStatusChanged'.
	 * @param joinContext The join context containing token and channel ID.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.
	 */
	virtual ZoomVideoSDKErrors joinStreaming(ZoomVideoSDKSteamingJoinContext& joinContext) = 0;

	/**
	 * @brief Leaves broadcast streaming asynchronously. Result is notified via the callback 'onStreamingJoinStatusChanged'.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.
	 */
	virtual ZoomVideoSDKErrors leaveStreaming() = 0;

	/**
	* @brief Gets the current streaming join status.
	* @return The join status. See \link ZoomVideoSDKStreamingJoinStatus \endlink.
	*/
	virtual ZoomVideoSDKStreamingJoinStatus getStreamingJoinStatus() = 0;

	/**
	* @brief Subscribes to streaming video.
	* @param resolution The desired video resolution. Supported: ZoomVideoSDKResolution_180P, ZoomVideoSDKResolution_360P, ZoomVideoSDKResolution_720P, ZoomVideoSDKResolution_1080P. See \link ZoomVideoSDKResolution \endlink.
	* @param pCallback the raw video data callback object, see \link IZoomVideoSDKBroadcastStreamingVideoCallback \endlink.
	* @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.
	*/
	virtual ZoomVideoSDKErrors subscribeVideo(ZoomVideoSDKResolution resolution, IZoomVideoSDKBroadcastStreamingVideoCallback* pCallback) = 0;

	/**
	* @brief Unsubscribe from streaming video raw data.
	* @param pCallback The video raw data callback object, see \link IZoomVideoSDKBroadcastStreamingVideoCallback \endlink.
	* @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.
	*/
	virtual ZoomVideoSDKErrors unSubscribeVideo(IZoomVideoSDKBroadcastStreamingVideoCallback* pCallback) = 0;

	/**
	* @brief Subscribes to streaming audio.
	* @param pCallback The raw audio data callback object. See \link IZoomVideoSDKBroadcastStreamingAudioCallback \endlink.
	* @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.
	*/
	virtual ZoomVideoSDKErrors subscribeAudio(IZoomVideoSDKBroadcastStreamingAudioCallback* pCallback) = 0;

	/**
	* @brief Unsubscribe from streaming audio raw data.
	* @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.
	*/
	virtual ZoomVideoSDKErrors unSubscribeAudio() = 0;
};

END_ZOOM_VIDEO_SDK_NAMESPACE
#endif