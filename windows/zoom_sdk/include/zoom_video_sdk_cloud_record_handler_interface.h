/**
 * @file zoom_video_sdk_cloud_record_handler_interface.h
 * @brief Cloud recording consent handler interface.
 */

#ifndef _ZOOM_VIDEO_SDK_CLOUD_RECORD_HANDLER_INTERFACE_H_
#define _ZOOM_VIDEO_SDK_CLOUD_RECORD_HANDLER_INTERFACE_H_
#include "zoom_video_sdk_def.h"

BEGIN_ZOOM_VIDEO_SDK_NAMESPACE

/**
 * @brief Enumeration of cloud recording consent types.
 */
enum ConsentType
{
	/** Invalid type. */
	ConsentType_Invalid,         
	/** In this case, 'accept' means agree to be recorded to gallery and speaker mode, 'decline' means leave session. */
	ConsentType_Traditional,     
	/** In this case, 'accept' means agree to be recorded to a separate file, 'decline' means stay in session and can't be recorded. */
	ConsentType_Individual,      
	
};
/**
 * @class IZoomVideoSDKRecordingConsentHandler
 * @brief Handler interface for cloud recording consent requests.
 */
class IZoomVideoSDKRecordingConsentHandler
{
public:
	virtual ~IZoomVideoSDKRecordingConsentHandler(){}
	
	/**
	 * @brief Accepts the recording consent request.
	 * @return true if the consent was accepted successfully. Otherwise, false.
	 */
	virtual bool accept() = 0;
	
	/**
	 * @brief Declines the recording consent request.
	 * @return true if the consent was declined successfully. Otherwise, false.
	 */
	virtual bool decline() = 0;
	
	/**
	 * @brief Gets the type of recording consent being requested.
	 * @return The consent type. See \link ConsentType \endlink.
	 */
	virtual ConsentType getConsentType() = 0;
};
END_ZOOM_VIDEO_SDK_NAMESPACE
#endif