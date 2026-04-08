/**
 * @file zoom_video_sdk_annotation_helper_interface.h
 * @brief Annotation helper.
 */

#ifndef _ZOOM_VIDEO_SDK_ANNOTATION_HELPER_INTERFACE_H_
#define _ZOOM_VIDEO_SDK_ANNOTATION_HELPER_INTERFACE_H_
#include "zoom_video_sdk_def.h"

BEGIN_ZOOM_VIDEO_SDK_NAMESPACE

/**
 * @brief Enumeration of annotation tool types.
 */
enum ZoomVideoSDKAnnotationToolType
{
	/** No tool selected. */
	ZoomVideoSDKAnnotationToolType_None,
	/** Pen tool. */
	ZoomVideoSDKAnnotationToolType_Pen,
	ZoomVideoSDKAnnotationToolType_HighLighter,
	ZoomVideoSDKAnnotationToolType_AutoLine,
	ZoomVideoSDKAnnotationToolType_AutoRectangle,
	ZoomVideoSDKAnnotationToolType_AutoEllipse,
	ZoomVideoSDKAnnotationToolType_AutoArrow,
	ZoomVideoSDKAnnotationToolType_AutoRectangleFill,
	ZoomVideoSDKAnnotationToolType_AutoEllipseFill,
	ZoomVideoSDKAnnotationToolType_SpotLight,
	ZoomVideoSDKAnnotationToolType_Arrow,
	ZoomVideoSDKAnnotationToolType_ERASER,
	ZoomVideoSDKAnnotationToolType_Textbox,
	ZoomVideoSDKAnnotationToolType_Picker,
	ZoomVideoSDKAnnotationToolType_AutoRectangleSemiFill,
	ZoomVideoSDKAnnotationToolType_AutoEllipseSemiFill,
	ZoomVideoSDKAnnotationToolType_AutoDoubleArrow,
	ZoomVideoSDKAnnotationToolType_AutoDiamond,
	ZoomVideoSDKAnnotationToolType_AutoStampArrow,
	ZoomVideoSDKAnnotationToolType_AutoStampCheck,
	ZoomVideoSDKAnnotationToolType_AutoStampX,
	ZoomVideoSDKAnnotationToolType_AutoStampStar,
	ZoomVideoSDKAnnotationToolType_AutoStampHeart,
	ZoomVideoSDKAnnotationToolType_AutoStampQm,
	ZoomVideoSDKAnnotationToolType_VanishingPen,
	ZoomVideoSDKAnnotationToolType_VanishingArrow,
	ZoomVideoSDKAnnotationToolType_VanishingDoubleArrow,
	ZoomVideoSDKAnnotationToolType_VanishingDiamond,
	ZoomVideoSDKAnnotationToolType_VanishingEllipse,
	ZoomVideoSDKAnnotationToolType_VanishingRectangle,
};

/**
 * @brief Enumeration of annotation clear types.
 */
enum ZoomVideoSDKAnnotationClearType
{
	/** Clear all annotations. */
	ZoomVideoSDKAnnotationClearType_All,
	/** Clear only the others' annotations. */
	ZoomVideoSDKAnnotationClearType_Others,
	/** Clear only your own annotations. */
	ZoomVideoSDKAnnotationClearType_My,
	
};

/**
 * @class IZoomVideoSDKAnnotationHelper
 * @brief Annotation helper interface.
 */
class IZoomVideoSDKAnnotationHelper
{
public:
	virtual ~IZoomVideoSDKAnnotationHelper() {};
	
	/**
	 * @brief Determines Whether the current user can do annotation on the share.
	 * @return true if the user can do annotation. Otherwise, false.
	 */
	virtual bool canDoAnnotation() = 0;
	
	/**
	 * @brief Determines whether annotation was disabled or not by the share owner.
	 * @return true disable, false not disable.
	 * @deprecated Use \link canDoAnnotation \endlink instead.
	 */
	virtual bool isSenderDisableAnnotation() = 0;
	
	/**
	 * @brief Starts annotation.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.  
	 */
	virtual ZoomVideoSDKErrors startAnnotation() = 0;
	
	/**
	 * @brief Stops annotation.	
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.  
	 */
	virtual ZoomVideoSDKErrors stopAnnotation() = 0;
	
	/**
	 * @brief Sets the annotation tool type.
	 * @param toolType The specified tool type.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.  
	 * @note The tool type ZoomVideoSDKAnnotationToolType_Picker and ZoomVideoSDKAnnotationToolType_SpotLight are not support for viewer.
	 */
	virtual ZoomVideoSDKErrors setToolType(ZoomVideoSDKAnnotationToolType toolType) = 0;
	
	/**
	 * @brief Gets the annotation tool type.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.  
	 */
	virtual ZoomVideoSDKErrors getToolType(ZoomVideoSDKAnnotationToolType& toolType) = 0;
	
	/**
	 * @brief Sets the annotation tool color.
	 * @param color The specified color.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.  
	 */
	virtual ZoomVideoSDKErrors setToolColor(unsigned long color) = 0;
	
	/**
	 * @brief Gets the annotation tool color.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.  
	 */
	virtual ZoomVideoSDKErrors getToolColor(unsigned long& color) = 0;
	
	/**
	 * @brief Sets the annotation tool width.
	 * @param lineWidth The specified tool width.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.  
	 */
	virtual ZoomVideoSDKErrors setToolWidth(long lineWidth) = 0;
	
	/**
	 * @brief Gets the annotation tool width.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.  
	 */
	virtual ZoomVideoSDKErrors getToolWidth(long& lineWidth) = 0;
	
	/**
	 * @brief ClearS the annotation content.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.
	 * @note Host and manager can clear all and clear self; Share owner can clear all, clear othersand clear self; Attendee can only clear self.
	 */
	virtual ZoomVideoSDKErrors clear(ZoomVideoSDKAnnotationClearType clearType) = 0;
	
	/**
	 * @brief Undo one annotation content step.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.  
	 */
	virtual ZoomVideoSDKErrors undo() = 0;
	
	/**
	 * @brief Redo one annotation content step.
	 * @return If the function succeeds, the return value is ZoomVideoSDKErrors_Success. Otherwise, this function returns an error.  
	 */
	virtual ZoomVideoSDKErrors redo() = 0;
	

};
END_ZOOM_VIDEO_SDK_NAMESPACE
#endif