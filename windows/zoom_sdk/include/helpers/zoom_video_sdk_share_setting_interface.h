/**
 * @file zoom_video_sdk_share_setting_interface.h
 * @brief Share setting helper interface.
 */

#ifndef _ZOOM_VIDEO_SDK_SHARE_SETTING_INTERFACE_H_
#define _ZOOM_VIDEO_SDK_SHARE_SETTING_INTERFACE_H_
#include "zoom_video_sdk_def.h"

BEGIN_ZOOM_VIDEO_SDK_NAMESPACE

/**
 * @brief Enumeration of screen capture modes for screen sharing.
 */
enum ZoomVideoSDKScreenCaptureMode
{
	/** Screen capture mode is automatically.
        Choosing Auto mode will automatically try to select the best screen sharing method. */
    ZoomVideoSDKScreenCaptureMode_Auto,
	/** Screen capture mode is legacy operating systems. */
    ZoomVideoSDKScreenCaptureMode_Legacy,
	/** Screen capture mode is capture with window filtering. */
    ZoomVideoSDKScreenCaptureMode_Filtering,
	/** Screen capture mode is advanced share with window filtering. */
    ZoomVideoSDKScreenCaptureMode_ADA_Filtering,
	/** Screen capture mode is advanced share without window filtering. */
    ZoomVideoSDKScreenCaptureMode_ADA_Without_Filtering,
	/** Screen capture mode is secure share with window filtering. */
    ZoomVideoSDKScreenCaptureMode_Secure_Filtering,
};

/**
 * @class IZoomVideoSDKShareSettingHelper
 * @brief Helper interface for configuring screen sharing settings.
 */
class IZoomVideoSDKShareSettingHelper
{
public:
	/**
     * @brief Set screen capture mode.
     * @param captureMode The mode to be set.
     * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.  
	 */
    virtual ZoomVideoSDKErrors setScreenCaptureMode(ZoomVideoSDKScreenCaptureMode captureMode) = 0;
	
	/**
     * @brief Get the screen capture mode.
     * @param [out] captureMode The screen capture mode.
     * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.  
	 */
    virtual ZoomVideoSDKErrors getScreenCaptureMode(ZoomVideoSDKScreenCaptureMode& captureMode) = 0;
	
	/**
     * @brief Set the visibility of the green border when sharing the screen.
     * @param bEnable true indicates to display the green border. Otherwise, false.
     * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.  
	 */
    virtual ZoomVideoSDKErrors enableGreenBorder(bool bEnable) = 0;
	
	/**
     * @brief Determines if the green border is enabled when user shares the screen.
     * @return true if the green border is enabled. Otherwise, false.
	 */
    virtual bool isGreenBorderEnabled() = 0;
    
    /**
     * @brief Limits the screen sharing sending resolution to Full HD (1920x1080).
     * @param bLimit true to limit the sending resolution to Full HD (1920x1080), false to send the screen share at its original resolution.
     * @return If the function succeeds, it returns ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.
     */
    virtual ZoomVideoSDKErrors limitShareSendingResolutionToFullHD(bool bLimit) = 0;

#if defined(WIN32)
	/**
     * @brief Enable/disable remote control of all applications that require admin privileges such as Task Manager.
     * @param bEnable true to enable the remote control, false to disable.
     * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.  
	 */
    virtual ZoomVideoSDKErrors enableAdminRemoteControl(bool bEnable) = 0;
	
    /**
     * @brief Determines if remote control of all applications is enabled, including those that require admin privileges.
     * @return true if remote control is enabled. Otherwise, false.
	 */
    virtual bool isRemoteControlAllApplicationsEnabled() = 0;
#endif
};
END_ZOOM_VIDEO_SDK_NAMESPACE
#endif
