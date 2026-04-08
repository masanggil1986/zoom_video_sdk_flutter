/**
 * @file zoom_video_sdk_recording_helper_interface.h
 * @brief Cloud recording helper interface.
 */

#ifndef _ZOOM_VIDEO_SDK_RECORDING_HELPER_INTERFACE_H_
#define _ZOOM_VIDEO_SDK_RECORDING_HELPER_INTERFACE_H_

#include "zoom_video_sdk_def.h"

BEGIN_ZOOM_VIDEO_SDK_NAMESPACE

/**
 * @class IZoomVideoSDKRecordingHelper
 * @brief Helper interface for managing cloud recording during a Zoom Video SDK session.
 */
class IZoomVideoSDKRecordingHelper
{
public:	
	/**
	 * @brief Checks if the current user meets the requirements to start cloud recording.
	 *  The following are the prerequisites to use the helper class:
	 * 		A cloud recording add-on plan
	 * 		Cloud recording feature enabled on the Web portal
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.
	 */
	virtual ZoomVideoSDKErrors canStartRecording() = 0;
	
	/**
	 * @brief Start cloud recording.
	 *  Since cloud recording involves asynchronous operations, 
	 *  a return value of ZoomVideoSDKErrors_Success does not guarantee that the recording will start. 
	 *  See \link ZoomVideoSDKDelegate  \endlink, see \link onCloudRecordingStatus \endlink ,
	 *  for information on how to confirm that recording has commenced.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.  
	 */
	virtual ZoomVideoSDKErrors startCloudRecording() = 0;
	
	/**
	 * @brief Stop cloud recording.
	 *  Since cloud recording involves asynchronous operations, 
	 *  a return value of ZoomVideoSDKErrors_Success does not guarantee that the recording will pause. 
	 *  See \link ZoomVideoSDKDelegate  \endlink , see \link onCloudRecordingStatus \endlink ,
	 *  for information on how to confirm that recording has paused.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.  
	 */
	virtual ZoomVideoSDKErrors stopCloudRecording() = 0;
	
	/**
	 * @brief Pause the ongoing cloud recording.
	 *  Since cloud recording involves asynchronous operations, 
	 *  a return value of ZoomVideoSDKErrors_Success does not guarantee that the recording will pause. 
	 *  See \link ZoomVideoSDKDelegate  \endlink , see \link onCloudRecordingStatus \endlink ,
	 *  for information on how to confirm that recording has paused.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.  
	 */
	virtual ZoomVideoSDKErrors pauseCloudRecording() = 0;
	
	/**
	 * @brief Resume the previously paused cloud recording.
	 *  Since cloud recording involves asynchronous operations, 
	 *  a return value of ZoomVideoSDKErrors_Success does not guarantee that the recording will resume. 
	 *  See \link ZoomVideoSDKDelegate  \endlink , see \link onCloudRecordingStatus \endlink ,
	 *  for information on how to confirm that recording has resumed.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.  
	 */
	virtual ZoomVideoSDKErrors resumeCloudRecording() = 0;
	
	/**
	 * @brief Get the current status of cloud recording.
	 * @param [out] record_status Cloud recording status.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.  
	 */
	virtual ZoomVideoSDKErrors getCloudRecordingStatus(RecordingStatus& record_status) = 0;
};

END_ZOOM_VIDEO_SDK_NAMESPACE
#endif // _ZOOM_VIDEO_SDK_RECORDING_HELPER_INTERFACE_H_