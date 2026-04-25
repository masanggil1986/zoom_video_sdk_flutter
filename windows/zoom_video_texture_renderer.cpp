#include "zoom_video_texture_renderer.h"

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <future>

#include "zoom_serializer.h"
#include "zoom_sdk_raw_data_def.h"
#include "zoom_video_sdk_session_info_interface.h"
#include "helpers/zoom_video_sdk_share_helper_interface.h"

namespace zoom_video_sdk_flutter {

namespace {

inline uint8_t ClampToByte(int v) {
  if (v < 0) return 0;
  if (v > 255) return 255;
  return static_cast<uint8_t>(v);
}

// I420 (limited-range BT.601) → RGBA8888 conversion. Flutter's
// FlutterDesktopPixelBuffer expects tightly packed RGBA order on Windows.
void ConvertI420ToRgba(const uint8_t* y, const uint8_t* u, const uint8_t* v,
                       int yStride, int uStride, int vStride, int width,
                       int height, uint8_t* dst, int dstStride) {
  for (int j = 0; j < height; ++j) {
    const uint8_t* yRow = y + j * yStride;
    const uint8_t* uRow = u + (j / 2) * uStride;
    const uint8_t* vRow = v + (j / 2) * vStride;
    uint8_t* out = dst + j * dstStride;
    for (int i = 0; i < width; ++i) {
      int Y = yRow[i] - 16;
      int U = uRow[i / 2] - 128;
      int V = vRow[i / 2] - 128;
      if (Y < 0) Y = 0;

      int c = 298 * Y;
      int r = (c + 409 * V + 128) >> 8;
      int g = (c - 100 * U - 208 * V + 128) >> 8;
      int b = (c + 516 * U + 128) >> 8;

      out[0] = ClampToByte(r);
      out[1] = ClampToByte(g);
      out[2] = ClampToByte(b);
      out[3] = 0xFF;
      out += 4;
    }
  }
}

IZoomVideoSDKUser* FindUser(IZoomVideoSDK* sdk, const std::string& userId) {
  if (!sdk) return nullptr;
  auto* session = sdk->getSessionInfo();
  if (!session) return nullptr;
  std::wstring wideId = Utf8ToWide(userId);

  if (auto* myself = session->getMyself()) {
    auto* mid = myself->getUserID();
    if (mid && wideId == mid) return myself;
  }
  auto* remotes = session->getRemoteUsers();
  if (remotes) {
    for (int i = 0; i < remotes->GetCount(); ++i) {
      auto* u = remotes->GetItem(i);
      if (!u) continue;
      auto* uid = u->getUserID();
      if (uid && wideId == uid) return u;
    }
  }
  return nullptr;
}

// True iff the user has a share action whose pipe is still live — i.e.
// safe to call unSubscribe on. Critically, we must check the action's
// status, not just its presence in the list: when onUserShareStatusChanged
// fires for Stop, the action is still in the list (with status=Stop) but
// its pipe is being torn down. Treating that as "active" causes us to
// skip the in-callback unSubscribe, leaving the SDK with a dangling
// delegate that crashes on later teardown.
bool UserHasActiveShare(IZoomVideoSDKUser* user) {
  if (!user) return false;
  auto* list = user->getShareActionList();
  if (!list || list->GetCount() == 0) return false;
  auto* action = list->GetItem(0);
  if (!action) return false;
  auto status = action->getShareStatus();
  return status == ZoomVideoSDKShareStatus_Start ||
         status == ZoomVideoSDKShareStatus_Resume ||
         status == ZoomVideoSDKShareStatus_Pause;
}

}  // namespace

// MARK: - ZoomVideoTextureRenderer

ZoomVideoTextureRenderer::ZoomVideoTextureRenderer(
    flutter::TextureRegistrar* registrar, std::string userId, Kind kind)
    : registrar_(registrar), userId_(std::move(userId)), kind_(kind) {}

ZoomVideoTextureRenderer::~ZoomVideoTextureRenderer() {
  // Defensive: Dispose(sdk) should have already run. If it didn't, we at
  // least avoid leaking the texture registration — but we cannot safely
  // call unSubscribe here without an SDK pointer, so we skip it. The SDK
  // tears down subscriptions on cleanup().
  if (registrar_ && textureId_ >= 0) {
    registrar_->UnregisterTexture(textureId_, nullptr);
    textureId_ = -1;
  }
}

int64_t ZoomVideoTextureRenderer::Register() {
  texture_ = std::make_unique<flutter::TextureVariant>(
      flutter::PixelBufferTexture([this](size_t w, size_t h) {
        return CopyBuffer(w, h);
      }));
  textureId_ = registrar_->RegisterTexture(texture_.get());
  return textureId_;
}

bool ZoomVideoTextureRenderer::TrySubscribe(IZoomVideoSDK* sdk) {
  if (disposed_ || subscribedPipe_) return subscribedPipe_ != nullptr;

  auto* user = FindUser(sdk, userId_);
  if (!user) return false;

  IZoomVideoSDKRawDataPipe* pipe = nullptr;
  if (kind_ == Kind::Video) {
    pipe = user->GetVideoPipe();
  } else {
    // Do not subscribe to our own outgoing share on Windows — the SDK
    // crashes when the local share ends while a subscriber is still
    // attached to that pipe. Remote shares are fine.
    if (auto* session = sdk->getSessionInfo()) {
      if (auto* myself = session->getMyself()) {
        auto* mid = myself->getUserID();
        if (mid && Utf8ToWide(userId_) == mid) return false;
      }
    }
    auto* list = user->getShareActionList();
    if (list && list->GetCount() > 0) {
      auto* action = list->GetItem(0);
      if (action) pipe = action->getSharePipe();
    }
  }
  if (!pipe) return false;

  // Walk down resolutions until subscribe succeeds. Zoom's raw-data
  // subscriber budget is roughly: 1×1080p OR 2×720p OR many×360p, plus
  // ≤2 share streams. With 4+ video tiles in a grid, a uniform 720p
  // subscribe leaves the 3rd/4th tile black with a HasSubscribeTwo720P /
  // HasSubscribeExceededLimit failure. 360p is plenty for tile-sized
  // rendering and lifts the per-session cap, while still letting the
  // first one or two tiles try 720p first for sharpness.
  static constexpr ZoomVideoSDKResolution kFallback[] = {
      ZoomVideoSDKResolution_720P,
      ZoomVideoSDKResolution_360P,
      ZoomVideoSDKResolution_180P,
  };
  for (auto res : kFallback) {
    auto err = pipe->subscribe(res, this);
    if (err == ZoomVideoSDKErrors_Success) {
      subscribedPipe_ = pipe;
      return true;
    }
  }
  return false;
}

void ZoomVideoTextureRenderer::Unsubscribe() {
  if (!subscribedPipe_) return;
  subscribedPipe_->unSubscribe(this);
  subscribedPipe_ = nullptr;
}

void ZoomVideoTextureRenderer::Dispose(IZoomVideoSDK* sdk) {
  if (disposed_) return;
  disposed_ = true;

  // Only call unSubscribe when we can verify the pipe is still live in the
  // SDK. For share, the pipe is destroyed when the share action ends; for
  // video, the pipe lives as long as the user is in the session. If the
  // share already ended, OnSessionStateChanged should have unsubscribed
  // synchronously while the pipe was still live.
  if (subscribedPipe_) {
    bool pipeStillLive = true;
    if (kind_ == Kind::Share) {
      auto* user = FindUser(sdk, userId_);
      pipeStillLive = UserHasActiveShare(user);
    } else {
      pipeStillLive = FindUser(sdk, userId_) != nullptr;
    }
    if (pipeStillLive) subscribedPipe_->unSubscribe(this);
    subscribedPipe_ = nullptr;
  }

  // Block until Flutter confirms it has finished using the texture —
  // otherwise a CopyBuffer callback on this renderer could fire after we
  // return, and the caller is about to destroy us.
  if (registrar_ && textureId_ >= 0) {
    std::promise<void> done;
    std::future<void> waiter = done.get_future();
    registrar_->UnregisterTexture(
        textureId_, [&done]() { done.set_value(); });
    textureId_ = -1;
    waiter.wait();
  }
}

void ZoomVideoTextureRenderer::onRawDataFrameReceived(YUVRawDataI420* data) {
  if (disposed_ || !data) return;
  unsigned int w = data->GetStreamWidth();
  unsigned int h = data->GetStreamHeight();
  if (w == 0 || h == 0) return;

  const uint8_t* yBuf = reinterpret_cast<const uint8_t*>(data->GetYBuffer());
  const uint8_t* uBuf = reinterpret_cast<const uint8_t*>(data->GetUBuffer());
  const uint8_t* vBuf = reinterpret_cast<const uint8_t*>(data->GetVBuffer());
  if (!yBuf || !uBuf || !vBuf) return;

  const int width = static_cast<int>(w);
  const int height = static_cast<int>(h);
  const int dstStride = width * 4;

  {
    std::lock_guard<std::mutex> lk(mutex_);
    bgraBuffer_.resize(static_cast<size_t>(dstStride) * height);
    // Zoom's YUVRawDataI420 is tightly packed — Y stride = width,
    // U/V stride = width/2.
    ConvertI420ToRgba(yBuf, uBuf, vBuf, width, width / 2, width / 2, width,
                      height, bgraBuffer_.data(), dstStride);
    frameWidth_ = static_cast<size_t>(width);
    frameHeight_ = static_cast<size_t>(height);
    hasFrame_ = true;
  }

  if (registrar_ && textureId_ >= 0) {
    registrar_->MarkTextureFrameAvailable(textureId_);
  }
}

void ZoomVideoTextureRenderer::onRawDataStatusChanged(RawDataStatus /*status*/) {
  // Zoom will stop delivering frames on its own; nothing to do here.
}

void ZoomVideoTextureRenderer::onShareCursorDataReceived(
    ZoomVideoSDKShareCursorData /*info*/) {}

const FlutterDesktopPixelBuffer* ZoomVideoTextureRenderer::CopyBuffer(
    size_t /*width*/, size_t /*height*/) {
  std::lock_guard<std::mutex> lk(mutex_);
  if (!hasFrame_ || bgraBuffer_.empty()) return nullptr;
  pixelBuffer_.buffer = bgraBuffer_.data();
  pixelBuffer_.width = frameWidth_;
  pixelBuffer_.height = frameHeight_;
  pixelBuffer_.release_context = nullptr;
  pixelBuffer_.release_callback = [](void*) {};
  return &pixelBuffer_;
}

// MARK: - ZoomVideoTextureManager

ZoomVideoTextureManager::ZoomVideoTextureManager(
    flutter::TextureRegistrar* registrar)
    : registrar_(registrar) {
  retry_thread_ = std::thread(&ZoomVideoTextureManager::RetryLoop, this);
}

ZoomVideoTextureManager::~ZoomVideoTextureManager() {
  {
    std::lock_guard<std::mutex> lk(retry_mutex_);
    retry_stop_ = true;
  }
  retry_cv_.notify_all();
  if (retry_thread_.joinable()) retry_thread_.join();
}

int64_t ZoomVideoTextureManager::Create(IZoomVideoSDK* sdk,
                                         const std::string& userId,
                                         ZoomVideoTextureRenderer::Kind kind) {
  auto renderer =
      std::make_unique<ZoomVideoTextureRenderer>(registrar_, userId, kind);
  int64_t id = renderer->Register();
  bool subscribed = renderer->TrySubscribe(sdk);

  {
    std::lock_guard<std::mutex> lk(mutex_);
    sdk_for_retry_ = sdk;
    renderers_.emplace(id, std::move(renderer));
  }
  if (!subscribed) NotifyUnsubscribed();
  return id;
}

void ZoomVideoTextureManager::Dispose(IZoomVideoSDK* sdk, int64_t textureId) {
  std::unique_ptr<ZoomVideoTextureRenderer> renderer;
  {
    std::lock_guard<std::mutex> lk(mutex_);
    auto it = renderers_.find(textureId);
    if (it == renderers_.end()) return;
    renderer = std::move(it->second);
    renderers_.erase(it);
  }
  renderer->Dispose(sdk);
}

void ZoomVideoTextureManager::NotifyUnsubscribed() {
  retry_cv_.notify_all();
}

void ZoomVideoTextureManager::RetryLoop() {
  using namespace std::chrono;
  std::unique_lock<std::mutex> wait_lk(retry_mutex_);
  while (!retry_stop_) {
    // Idle until either someone notifies us (a renderer was just created
    // unsubscribed) or the retry interval elapses while there's work to do.
    retry_cv_.wait_for(wait_lk, milliseconds(retry_interval_ms_),
                       [this] { return retry_stop_.load(); });
    if (retry_stop_) break;

    IZoomVideoSDK* sdk = nullptr;
    bool any_unsubscribed = false;
    {
      std::lock_guard<std::mutex> lk(mutex_);
      sdk = sdk_for_retry_;
      if (sdk) {
        for (auto& [_, renderer] : renderers_) {
          if (renderer->IsSubscribed()) continue;
          // Skip share renderers whose user has no active share — those
          // remain unsubscribed by design (e.g. self-share, or share
          // ended) and should not be polled forever.
          if (renderer->kind() == ZoomVideoTextureRenderer::Kind::Share) {
            auto* user = FindUser(sdk, renderer->user_id());
            if (!UserHasActiveShare(user)) continue;
          }
          renderer->TrySubscribe(sdk);
          if (!renderer->IsSubscribed()) any_unsubscribed = true;
        }
      }
    }
    // If everything is subscribed, fall back to a long sleep until the
    // next Create-or-event nudge wakes us.
    if (!any_unsubscribed) {
      retry_cv_.wait(wait_lk, [this] {
        if (retry_stop_) return true;
        std::lock_guard<std::mutex> lk(mutex_);
        for (auto& [_, renderer] : renderers_) {
          if (!renderer->IsSubscribed()) return true;
        }
        return false;
      });
    }
  }
}

void ZoomVideoTextureManager::OnSessionStateChanged(IZoomVideoSDK* sdk) {
  // Invoked from the Zoom SDK event thread. We must release the SDK's
  // delegate reference *before* the pipe is torn down (share end) — doing
  // so after teardown leaves the SDK with a dangling delegate pointer and
  // crashes when it later tries to call us. The status-changed callback
  // is the last point at which the pipe is guaranteed live.
  //
  // We also retry subscriptions here for renderers that couldn't attach
  // when the view was first created — e.g. a user who hadn't started
  // their video yet, or who joined after our widget mounted.
  if (!sdk) return;
  bool any_unsubscribed = false;
  {
    std::lock_guard<std::mutex> lk(mutex_);
    sdk_for_retry_ = sdk;
    for (auto& [_, renderer] : renderers_) {
      if (renderer->kind() == ZoomVideoTextureRenderer::Kind::Share) {
        auto* user = FindUser(sdk, renderer->user_id());
        if (!UserHasActiveShare(user)) {
          renderer->Unsubscribe();
          continue;
        }
      }
      if (!renderer->IsSubscribed()) {
        renderer->TrySubscribe(sdk);
        if (!renderer->IsSubscribed()) any_unsubscribed = true;
      }
    }
  }
  if (any_unsubscribed) NotifyUnsubscribed();
}

void ZoomVideoTextureManager::DisposeAll(IZoomVideoSDK* sdk) {
  std::unordered_map<int64_t, std::unique_ptr<ZoomVideoTextureRenderer>> moved;
  {
    std::lock_guard<std::mutex> lk(mutex_);
    moved = std::move(renderers_);
    renderers_.clear();
  }
  for (auto& [_, renderer] : moved) renderer->Dispose(sdk);
}

}  // namespace zoom_video_sdk_flutter
