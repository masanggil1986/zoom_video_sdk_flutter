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

### Platform-specific

| Platform | Minimum version |
|----------|----------------|
| Android  | API 21+        |
| iOS      | 16.0+          |
| macOS    | 13.0+          |
| Windows  | 10+            |

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

// 초기화
await sdk.init(const ZoomInitConfig(domain: 'zoom.us'));

// 이벤트 구독
sdk.onSessionJoin.listen((_) => print('Session joined'));
sdk.onUserJoined.listen((e) => print('Users joined: ${e.users}'));

// 세션 참가
await sdk.joinSession(const ZoomJoinSessionConfig(
  sessionName: 'my-session',
  userName: 'Alice',
  token: '<server-generated-jwt>',
));

// 오디오/비디오 시작
await sdk.audioHelper.startAudio();
await sdk.videoHelper.startVideo();

// 세션 퇴장
await sdk.leaveSession();
sdk.dispose();
```

## Project Structure

```
lib/
  zoom_video_sdk_flutter.dart   # Dart API (enums, models, ZoomVideoSdk)
android/                        # Android platform implementation
ios/                            # iOS platform implementation
macos/                          # macOS platform implementation
windows/                        # Windows platform implementation
docs/
  DART_API_DESIGN.md            # API 설계 문서 및 플랫폼 지원 상세
  ZOOM_SDK_REFERENCE.md         # 네이티브 SDK 레퍼런스
example/                        # Example app
```

## Documentation

- [Dart API Design](docs/DART_API_DESIGN.md) - 전체 API 명세 및 플랫폼별 지원 현황
- [Zoom Video SDK Reference](docs/ZOOM_SDK_REFERENCE.md) - 네이티브 SDK 레퍼런스

## License

See [LICENSE](LICENSE).
