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

## macOS SDK Setup

macOS는 Zoom Video SDK 바이너리가 저장소에 포함되어 있지 않습니다.  
이 플러그인은 **Zoom Video SDK for macOS 2.5.5** 기준으로 개발되었습니다.

[https://developers.zoom.us/docs/video-sdk/](https://developers.zoom.us/docs/video-sdk/) 에서 macOS 2.5.5 버전을 다운로드한 후 아래 명령어를 실행합니다.

```bash
unzip zoom-video-sdk-macos-2.5.5.zip -d zoom_sdk_macos
cp -R zoom_sdk_macos/* /path/to/zoom_video_sdk_flutter/macos/Frameworks/
```

> Zoom Video SDK 바이너리는 Zoom의 라이선스 약관이 적용됩니다.  
> 다운로드 전 [Zoom Developer Agreement](https://developers.zoom.us/docs/api/rest/developer-agreement/)를 확인하세요.

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
