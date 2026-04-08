/**
 * @file zoom_video_sdk_video_setting_interface.h
 * @brief Video setting helper interface.
 */

#ifndef _ZOOM_VIDEO_SDK_VIDEO_SETTING_INTERFACE_H_
#define _ZOOM_VIDEO_SDK_VIDEO_SETTING_INTERFACE_H_
#include "zoom_video_sdk_def.h"
#include "zoom_video_sdk_vector_interface.h"

BEGIN_ZOOM_VIDEO_SDK_NAMESPACE

/**
 * @class IZoomVideoSDKVideoSettingHelper
 * @brief Helper interface for configuring video settings.
 */
class IZoomVideoSDKVideoSettingHelper
{
public:	
	/**
	 * @brief Call this method to enable or disable the temporal de-noise of video.
	 * @param bEnable true to enable the temporal de-noise of video or false to disable it.
	 * @return If the function succeeds, it returns ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.
	 */
	virtual ZoomVideoSDKErrors enableTemporalDeNoise(bool bEnable) = 0;
	
	/**
	 * @brief Determines whether the temporal de-noise of video is enabled.
	 * @param [out] bEnable true if the temporal de-noise of video is enabled, otherwise false.
	 * @return If the function succeeds, it returns ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.
	 */

	virtual ZoomVideoSDKErrors isTemporalDeNoiseEnabled(bool& bEnable) = 0;

	/**
	 * @brief Enables or disables the face beauty effect for the video stream.
	 * @param bEnable true to enable the face beauty effect, false to disable it.
	 * @return If the function succeeds, it returns ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.
	 */
	virtual ZoomVideoSDKErrors enableFaceBeautyEffect(bool bEnable) = 0;

	/**
	 * @brief Determines whether the face beauty effect is currently enabled.
	 * @param [out] bEnable true if the face beauty effect is enabled, false otherwise.
	 * @return If the function succeeds, it returns ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.
	 */
	virtual ZoomVideoSDKErrors isFaceBeautyEffectEnabled(bool& bEnable) = 0;

	/**
	 * @brief Sets the intensity level of the face beauty effect (the strength value).
	 * @param strengthValue The desired face beauty strength value (0-100).
	 * @return If the function succeeds, it returns ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.
	 * @note The face beauty effect must be enabled before adjusting its strength.
	 */
	virtual ZoomVideoSDKErrors setFaceBeautyStrengthValue(unsigned int strengthValue) = 0;

	/**
	 * @brief Gets the current intensity level of the face beauty effect (the strength value).
	 * @param [out] strengthValue The current face beauty strength value (0-100).
	 * @return If the function succeeds, it returns ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.
	 * @note A higher value indicates a stronger beauty effect.
	 */
	virtual ZoomVideoSDKErrors getFaceBeautyStrengthValue(unsigned int& strengthValue) = 0;
};
END_ZOOM_VIDEO_SDK_NAMESPACE
#endif