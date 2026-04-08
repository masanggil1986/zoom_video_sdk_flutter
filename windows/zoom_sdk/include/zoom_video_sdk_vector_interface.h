/**
 * @file zoom_video_sdk_vector_interface.h
 * @brief Vector container interface.
 */

#ifndef _ZOOM_VIDEO_SDK_VECTOR_INTERFACE_H_
#define _ZOOM_VIDEO_SDK_VECTOR_INTERFACE_H_
#include "zoom_video_sdk_def.h"

BEGIN_ZOOM_VIDEO_SDK_NAMESPACE
/**
 * @class IVideoSDKVector
 * @brief SDK-defined vector interface for managing collections of items.
 */
template<class T>
class IVideoSDKVector
{
public:
	virtual ~IVideoSDKVector(){};
	
	/**
	 * @brief Gets the total number of items in the vector.
	 * @return The count of items in the vector.
	 */
	virtual int GetCount() = 0;
	
	/**
	 * @brief Gets the item at the specified index.
	 * @param index The zero-based index of the item to retrieve.
	 * @return The item at the specified index.
	 */
	virtual T   GetItem(int index) = 0;
};
END_ZOOM_VIDEO_SDK_NAMESPACE
#endif