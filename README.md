# zoom_video_sdk_flutter

Zoom Video SDK의 Flutter 플러그인. Android, iOS, macOS, Windows를 지원합니다.

## Features

- Session 생성/참가/퇴장
- Audio 제어 (음소거, 노이즈 억제, 디바이스 선택)
- Video 제어 (카메라 전환, 디바이스 선택)
- Screen sharing (화면/윈도우 공유)
- In-session chat (전체/개인 메시지)
- Cloud recording
- Virtual background
- Host controls (호스트 이전, 매니저 지정, 참가자 제거)
- Sealed class 기반 이벤트 스트림

## Platform Support

| Feature | Android | iOS | Windows | macOS |
|---------|---------|-----|---------|-------|
| Session | ✅ | ✅ | ✅ | ✅ |
| Audio | ✅ | ✅ | ✅ | ✅ |
| Audio device selection | ⚠️ | ⚠️ | ✅ | ✅ |
| Video | ✅ | ✅ | ✅ | ✅ |
| Camera list | ❌ | ❌ | ✅ | ✅ |
| Screen share | ✅ | ✅ | ✅ | ✅ |
| Window share | ❌ | ❌ | ✅ | ✅ |
| Chat | ✅ | ✅ | ✅ | ✅ |
| Cloud recording | ✅ | ✅ | ✅ | ✅ |
| Virtual background | ✅ | ✅ | ✅ | ✅ |
| Host controls | ✅ | ✅ | ✅ | ✅ |

> ⚠️ = 부분 지원. 자세한 내용은 [DART_API_DESIGN.md](docs/DART_API_DESIGN.md) 참고.

## Requirements

- Flutter >= 3.3.0
- Dart SDK >= 3.11.1
- Zoom Video SDK 계정 및 JWT 토큰

| Platform | Minimum version |
|----------|----------------|
| Android  | API 21+        |
| iOS      | 16.0+          |
| macOS    | 13.0+          |
| Windows  | 10+            |

## Native SDK Setup

Zoom Video SDK 바이너리는 Zoom의 라이선스 약관이 적용되므로 저장소에 포함되어 있지 않습니다.
각 데스크톱 플랫폼별로 Zoom Developer 포털에서 해당 버전을 다운로드한 뒤 아래 경로에 배치해야 합니다.

> Zoom Video SDK 바이너리는 Zoom의 라이선스 약관이 적용됩니다.
> 다운로드 전 [Zoom Developer Agreement](https://developers.zoom.us/docs/api/rest/developer-agreement/)를 확인하세요.

### macOS

- 테스트/검증된 버전: **Zoom Video SDK for macOS 2.5.5**
- 다운로드: [https://developers.zoom.us/docs/video-sdk/](https://developers.zoom.us/docs/video-sdk/)
- 배치 위치: `macos/Frameworks/`

```bash
unzip zoom-video-sdk-macos-2.5.5.zip -d zoom_sdk_macos
cp -R zoom_sdk_macos/* /path/to/zoom_video_sdk_flutter/macos/Frameworks/
```

최종 구조:

```
macos/Frameworks/
├── ZoomVideoSDK.framework/
└── ...
```

### Windows

- 테스트/검증된 버전: **Zoom Video SDK for Windows 2.5.7** (x64)
- 다운로드: [https://developers.zoom.us/docs/video-sdk/](https://developers.zoom.us/docs/video-sdk/)
- 배치 위치: `windows/zoom_sdk/`

다운로드한 zip의 `Sample-Libs/x64/` 아래 세 개 디렉터리(`bin`, `include`, `lib`)를 `windows/zoom_sdk/`로 그대로 복사합니다.

```powershell
# zip 해제 후 (경로는 환경에 맞게)
Expand-Archive zoom-video-sdk-windows-2.5.7.zip -DestinationPath zoom_sdk_windows

$src = "zoom_sdk_windows\Sample-Libs\x64"
$dst = "C:\path\to\zoom_video_sdk_flutter\windows\zoom_sdk"
Copy-Item -Recurse "$src\bin"     "$dst\bin"
Copy-Item -Recurse "$src\include" "$dst\include"
Copy-Item -Recurse "$src\lib"     "$dst\lib"
```

최종 구조:

```
windows/zoom_sdk/
├── bin/        # DLL + EXE + ini — 런타임에 앱 바이너리 옆에 복사됨
├── include/    # SDK C++ 헤더 — 컴파일 시 include
└── lib/        # videosdk.lib — 링커 입력
```

> **주의:** `bin/` 안의 `*.exe`(특히 `zCSVCptHost.exe`)와 `crashrpt_lang.ini` 는 반드시 함께 복사해야 합니다. 화면 공유 시 SDK가 해당 프로세스를 런타임에 실행하며, 누락 시 `startShareScreen` / `startShareView` 가 `ZoomVideoSDKErrors_Internal_Error (2)` 로 실패합니다. `windows/CMakeLists.txt` 는 `bin/*.dll`, `bin/*.exe`, `bin/*.ini` 전체를 `zoom_video_sdk_flutter_bundled_libraries` 로 번들링하므로 Flutter Windows 빌드 시 자동으로 실행 파일 옆에 복사됩니다.

### Android / iOS

네이티브 SDK는 Gradle / CocoaPods 가 자동 해결합니다. 별도 수동 배치가 필요하지 않습니다.

## Installation

```yaml
dependencies:
  zoom_video_sdk_flutter:
    git:
      url: https://github.com/<your-org>/zoom_video_sdk_flutter.git
```

## Quick Start

```dart
import 'package:zoom_video_sdk_flutter/zoom_video_sdk_flutter.dart';

final sdk = ZoomVideoSdk();

await sdk.init(const ZoomInitConfig(domain: 'zoom.us'));

sdk.onSessionJoin.listen((_) { /* session joined */ });
sdk.onUserJoined.listen((e) { /* e.users */ });

await sdk.joinSession(const ZoomJoinSessionConfig(
  sessionName: 'my-session',
  userName: 'Alice',
  token: '<server-generated-jwt>',
));

await sdk.audioHelper.startAudio();
await sdk.videoHelper.startVideo();

await sdk.leaveSession();
sdk.dispose();
```

## License

See [LICENSE](LICENSE).
