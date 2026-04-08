/**
 * @file zoom_video_sdk_api.h
 * @brief Zoom Video SDK API entry points.
 */

#ifndef _ZOOM_VIDEO_SDK_API_H_
#define _ZOOM_VIDEO_SDK_API_H_
#include "zoom_video_sdk_def.h"

BEGIN_ZOOM_VIDEO_SDK_NAMESPACE
extern "C"
{
	class IZoomVideoSDK;
	/**
	 * @brief Creates the Zoom Video SDK object instance.
	 * @return If the function succeeds, the return value is a pointer to the Zoom Video SDK object. Otherwise, this function fails and returns nullptr.
	 */
	ZOOM_VIDEO_SDK_EXPORT IZoomVideoSDK* CreateZoomVideoSDKObj();
	
	/**
	 * @brief Destroys the Zoom Video SDK object instance.
	 */
	ZOOM_VIDEO_SDK_EXPORT void DestroyZoomVideoSDKObj();
}
END_ZOOM_VIDEO_SDK_NAMESPACE
#endif