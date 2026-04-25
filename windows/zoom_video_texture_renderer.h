#ifndef ZOOM_VIDEO_SDK_FLUTTER_ZOOM_VIDEO_TEXTURE_RENDERER_H_
#define ZOOM_VIDEO_SDK_FLUTTER_ZOOM_VIDEO_TEXTURE_RENDERER_H_

#include <flutter/texture_registrar.h>

#include <atomic>
#include <condition_variable>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
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

  // True if currently holding a subscription to the SDK pipe.
  bool IsSubscribed() const { return subscribedPipe_ != nullptr; }

  // Unsubscribe the cached pipe and drop the pointer. Safe to call from
  // an SDK status-changed callback — the pipe is still live at that
  // point. Required to release the SDK's reference to our delegate
  // before the pipe is destroyed; otherwise the SDK may invoke a
  // callback on freed memory after Dispose.
  void Unsubscribe();

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
  explicit ZoomVideoTextureManager(flutter::TextureRegistrar* registrar);
  ~ZoomVideoTextureManager();

  int64_t Create(ZOOM_VIDEO_SDK_NAMESPACE::IZoomVideoSDK* sdk,
                 const std::string& userId,
                 ZoomVideoTextureRenderer::Kind kind);

  void Dispose(ZOOM_VIDEO_SDK_NAMESPACE::IZoomVideoSDK* sdk, int64_t textureId);

  // Reconcile renderer subscriptions with current SDK state:
  //   - Subscribe any renderer whose pipe is now reachable but isn't yet
  //     subscribed (handles late-joining users / late-started video).
  //   - Unsubscribe any share renderer whose user no longer has an
  //     active share, while the pipe is still live.
  // Invoked from the SDK event thread on user/video/share state changes.
  void OnSessionStateChanged(ZOOM_VIDEO_SDK_NAMESPACE::IZoomVideoSDK* sdk);

  void DisposeAll(ZOOM_VIDEO_SDK_NAMESPACE::IZoomVideoSDK* sdk);

 private:
  // Run by retry_thread_: while there are unsubscribed renderers, wake
  // every retry_interval_ms_ and call TrySubscribe on each. Sleeps idle
  // when all renderers are subscribed. The SDK occasionally fails to
  // attach a video pipe at the precise moment of the user-state event
  // (e.g. for a host whose video was already on when we joined), and
  // emits no follow-up callback to retry on. This loop fills that gap.
  void RetryLoop();
  void NotifyUnsubscribed();

  flutter::TextureRegistrar* registrar_;
  ZOOM_VIDEO_SDK_NAMESPACE::IZoomVideoSDK* sdk_for_retry_ = nullptr;
  std::mutex mutex_;
  std::unordered_map<int64_t, std::unique_ptr<ZoomVideoTextureRenderer>>
      renderers_;

  std::thread retry_thread_;
  std::mutex retry_mutex_;
  std::condition_variable retry_cv_;
  std::atomic<bool> retry_stop_{false};
  static constexpr int retry_interval_ms_ = 500;
};

}  // namespace zoom_video_sdk_flutter

#endif  // ZOOM_VIDEO_SDK_FLUTTER_ZOOM_VIDEO_TEXTURE_RENDERER_H_
