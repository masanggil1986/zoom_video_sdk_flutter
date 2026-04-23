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

// True iff the user currently has a live share action — i.e. the share
// pipe we may have cached is still safe to call unSubscribe on.
bool UserHasActiveShare(IZoomVideoSDKUser* user) {
  if (!user) return false;
  auto* list = user->getShareActionList();
  return list && list->GetCount() > 0 && list->GetItem(0) != nullptr;
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

  auto err = pipe->subscribe(ZoomVideoSDKResolution_720P, this);
  if (err == ZoomVideoSDKErrors_Success) {
    subscribedPipe_ = pipe;
    return true;
  }
  return false;
}

void ZoomVideoTextureRenderer::ForgetPipe() { subscribedPipe_ = nullptr; }

void ZoomVideoTextureRenderer::Dispose(IZoomVideoSDK* sdk) {
  if (disposed_) return;
  disposed_ = true;

  // Only call unSubscribe when we can verify the pipe is still live in the
  // SDK. For share, the pipe is destroyed when the share action ends; for
  // video, the pipe lives as long as the user is in the session.
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

int64_t ZoomVideoTextureManager::Create(IZoomVideoSDK* sdk,
                                         const std::string& userId,
                                         ZoomVideoTextureRenderer::Kind kind) {
  auto renderer =
      std::make_unique<ZoomVideoTextureRenderer>(registrar_, userId, kind);
  int64_t id = renderer->Register();
  renderer->TrySubscribe(sdk);

  std::lock_guard<std::mutex> lk(mutex_);
  renderers_.emplace(id, std::move(renderer));
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

void ZoomVideoTextureManager::OnSessionStateChanged(IZoomVideoSDK* sdk) {
  // Invoked from the Zoom SDK event thread. Do NOT call back into the SDK
  // here (e.g. pipe->subscribe) — reentrancy from inside a status-changed
  // callback has crashed the SDK on Windows. We only drop cached share
  // pipe pointers that the SDK is about to destroy.
  std::lock_guard<std::mutex> lk(mutex_);
  for (auto& [_, renderer] : renderers_) {
    if (renderer->kind() != ZoomVideoTextureRenderer::Kind::Share) continue;
    auto* user = FindUser(sdk, renderer->user_id());
    if (!UserHasActiveShare(user)) renderer->ForgetPipe();
  }
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
