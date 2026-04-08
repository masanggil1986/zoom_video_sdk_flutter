# ZMVideoSDKVideoSettingHelper API Documentation

## Module Information
- **Module:** Video Setting Helper
- **Platform:** macOS
- **Language:** Objective-C
- **Version:** 2.5.5
- **Header:** `ZMVideoSDKVideoSettingHelper.h`

## JSON callback fields (`ZMVideoSDKVideoSettingHelper-API.json`)

Prefer zmVideoSDKDelegateCallbacks where APIs drive ZMVideoSDKDelegate; this helper is mostly synchronous queries/setters.

Column semantics: see the paired `*-API.json` (`async`, `zmVideoSDKDelegateCallbacks`, `callbackFieldDoc`, and per-API notes).

## Overview
Video enhancement settings exposed on the SDK setting path: **temporal denoising** (inter-frame noise reduction) and **face beauty** (enable/disable plus strength 0–100). Access via `[[ZMVideoSDK sharedVideoSDK] getVideoSettingHelper]`. Behavior depends on the underlying video-setting service being available (initialized SDK and active session context as required by the platform stack).

## Lifecycle

### Prerequisites
1. `[[ZMVideoSDK sharedVideoSDK] initialize:]` completed successfully.
2. Obtain helper: `[[ZMVideoSDK sharedVideoSDK] getVideoSettingHelper]` (may be nil if the SDK is not ready).
3. When the internal setting helper is unavailable, mutating APIs return **`ZMVideoSDKErrors_SessionService_Invalid`**; query APIs return **NO** or **0**.

### Session and teardown
- After **`onSessionLeave`**, treat video-setting state as undefined until rejoin; avoid assuming denoise/beauty flags persist across sessions.
- **`onUserHostChanged`**: These APIs are local video appearance settings, not host-gated in the public header; re-query after major session transitions if UI must stay in sync.

## State machine (logical)
| Concern | States | Notes |
|---------|--------|--------|
| Temporal denoise | Off / On | Toggled by `enableTemporalDeNoise:`; read with `isTemporalDeNoiseEnabled`. |
| Face beauty | Off / On (+ strength) | Enable with `enableFaceBeautyEffect:`; strength via `setFaceBeautyStrengthValue:` (header: **enable beauty before relying on strength**). |

State updates are effectively **synchronous** from the caller’s perspective after a successful return; actual video pipeline application may lag slightly.

## APIs

### Temporal denoising
| Method | Returns | Description |
|--------|---------|-------------|
| `-enableTemporalDeNoise:(BOOL)enable` | `ZMVideoSDKErrors` | Turn temporal denoise on/off. |
| `-isTemporalDeNoiseEnabled` | `BOOL` | **YES**/**NO** if query succeeds; **NO** if helper unavailable or query error. |

### Face beauty
| Method | Returns | Description |
|--------|---------|-------------|
| `-enableFaceBeautyEffect:(BOOL)enable` | `ZMVideoSDKErrors` | Enable/disable. If already in the requested state, returns **Success** without re-invoking bridge. |
| `-isFaceBeautyEffectEnabled` | `BOOL` | **YES**/**NO** on success; **NO** on failure or nil helper. |
| `-setFaceBeautyStrengthValue:(unsigned int)strengthValue` | `ZMVideoSDKErrors` | Strength **0–100** per header. Implementation may **clamp values above 100 to 100**. |
| `-getFaceBeautyStrengthValue` | `unsigned int` | Current strength on success; **0** if helper nil or query fails. |

## Callbacks
None on this helper. Camera list changes are surfaced at the SDK delegate level (`ZMVideoSDKDelegate`); see **ZMVideoSDKDelegate-API**.

## Error handling
| Code / outcome | Meaning | Retry |
|----------------|---------|--------|
| `ZMVideoSDKErrors_SessionService_Invalid` | Underlying video setting helper not available (mac wrapper). | After SDK init / session ready. |
| Non-Success from bridge (mapped to `ZMVideoSDKErrors_*`) | Feature unsupported, wrong state, or bridge failure. | Re-check capability; backoff if rate-limited. |
| Query returns NO / 0 | Unavailable helper or failed internal query. | Do not treat as definitive “disabled” without a prior successful enable path. |

## Rules
1. **Face beauty:** Header requires beauty **enabled** before meaningfully adjusting strength; call `enableFaceBeautyEffect:YES` before `setFaceBeautyStrengthValue:`.
2. **Strength range:** Use **0–100**; values **> 100** may be clamped by the stack.
3. **Idempotency:** `enableFaceBeautyEffect:` returns Success when the desired state already matches.

## Examples
Structured snippets: **`ZMVideoSDKVideoSettingHelper-API.json`** → `examples`, `codeSnippets`.

```objc
ZMVideoSDKVideoSettingHelper *h = [[ZMVideoSDK sharedVideoSDK] getVideoSettingHelper];
if (!h) { /* wait for SDK ready */ return; }
[h enableTemporalDeNoise:YES];
[h enableFaceBeautyEffect:YES];
[h setFaceBeautyStrengthValue:50];
```
