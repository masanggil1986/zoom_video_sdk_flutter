#ifndef ZOOM_VIDEO_SDK_FLUTTER_ZOOM_VIDEO_TEXTURE_RENDERER_H_
#define ZOOM_VIDEO_SDK_FLUTTER_ZOOM_VIDEO_TEXTURE_RENDERER_H_

#include <flutter/texture_registrar.h>

#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

#include "zoom_video_sdk_def.h"
#include "zoom_video_sdk_interface.h"
#include "helpers/zoom_video_sdk_user_helper_interface.h"

namespace zoom_video_sdk_flutter {

// Consumes YUV I420 raw frames from a Zoom SDK video or share pipe, converts
// to BGRA8888, and feeds a Flutter PixelBuffer texture. One instance per
// active ZoomVideoView on the Dart side.
class ZoomVideoTextureRenderer
    : public ZOOM_VIDEO_SDK_NAMESPACE::IZoomVideoSDKRawDataPipeDelegate {
 public:
  enum class Kind { Video, Share };

  ZoomVideoTextureRenderer(flutter::TextureRegistrar* registrar,
                           std::string userId, Kind kind);
  ~ZoomVideoTextureRenderer() override;

  ZoomVideoTextureRenderer(const ZoomVideoTextureRenderer&) = delete;
  ZoomVideoTextureRenderer& operator=(const ZoomVideoTextureRenderer&) = delete;

  // Register with the texture registrar; returns the Flutter texture id.
  int64_t Register();

  // Find the target pipe (video or share) for the user and subscribe.
  // No-op if already subscribed or disposed.
  bool TrySubscribe(ZOOM_VIDEO_SDK_NAMESPACE::IZoomVideoSDK* sdk);

  // Drop the cached share pipe pointer *without* calling unSubscribe.
  // Called when the SDK tells us the pipe is gone (share stopped) — the
  // pointer would otherwise dangle through the next Dispose.
  void ForgetPipe();

  // Unsubscribe (if the pipe is still live per SDK state) and unregister
  // the texture. Blocks until Flutter confirms the texture is no longer
  // in use, so it is safe for the caller to destroy this renderer next.
  void Dispose(ZOOM_VIDEO_SDK_NAMESPACE::IZoomVideoSDK* sdk);

  const std::string& user_id() const { return userId_; }
  Kind kind() const { return kind_; }
  int64_t texture_id() const { return textureId_; }

  // IZoomVideoSDKRawDataPipeDelegate
  void onRawDataFrameReceived(YUVRawDataI420* data) override;
  void onRawDataStatusChanged(
      ZOOM_VIDEO_SDK_NAMESPACE::RawDataStatus status) override;
  void onShareCursorDataReceived(
      ZOOM_VIDEO_SDK_NAMESPACE::ZoomVideoSDKShareCursorData info) override;

 private:
  const FlutterDesktopPixelBuffer* CopyBuffer(size_t width, size_t height);

  flutter::TextureRegistrar* registrar_ = nullptr;
  const std::string userId_;
  const Kind kind_;

  std::unique_ptr<flutter::TextureVariant> texture_;
  int64_t textureId_ = -1;

  std::mutex mutex_;
  std::vector<uint8_t> bgraBuffer_;
  FlutterDesktopPixelBuffer pixelBuffer_{};
  size_t frameWidth_ = 0;
  size_t frameHeight_ = 0;
  bool hasFrame_ = false;

  ZOOM_VIDEO_SDK_NAMESPACE::IZoomVideoSDKRawDataPipe* subscribedPipe_ = nullptr;
  bool disposed_ = false;
};

// Owns all active texture renderers by textureId.
class ZoomVideoTextureManager {
 public:
  explicit ZoomVideoTextureManager(flutter::TextureRegistrar* registrar)
      : registrar_(registrar) {}

  int64_t Create(ZOOM_VIDEO_SDK_NAMESPACE::IZoomVideoSDK* sdk,
                 const std::string& userId,
                 ZoomVideoTextureRenderer::Kind kind);

  void Dispose(ZOOM_VIDEO_SDK_NAMESPACE::IZoomVideoSDK* sdk, int64_t textureId);

  // Invalidate stale share-pipe pointers whose owning share just ended, so
  // a subsequent Dispose doesn't use-after-free. Does NOT call back into
  // the SDK — safe to invoke from an SDK event-thread callback.
  void OnSessionStateChanged(ZOOM_VIDEO_SDK_NAMESPACE::IZoomVideoSDK* sdk);

  void DisposeAll(ZOOM_VIDEO_SDK_NAMESPACE::IZoomVideoSDK* sdk);

 private:
  flutter::TextureRegistrar* registrar_;
  std::mutex mutex_;
  std::unordered_map<int64_t, std::unique_ptr<ZoomVideoTextureRenderer>>
      renderers_;
};

}  // namespace zoom_video_sdk_flutter

#endif  // ZOOM_VIDEO_SDK_FLUTTER_ZOOM_VIDEO_TEXTURE_RENDERER_H_
