/// flutter_zoom_videosdk(모바일 공식 플러그인) 호환 facade.
///
/// tuit 앱들이 모바일(공식 패키지)과 데스크톱(이 플러그인의 메서드채널)을
/// 동일한 인터페이스로 쓰기 위한 층. 클래스/메서드/반환 문자열을
/// flutter_zoom_videosdk 2.5 와 동일하게 맞춘다 — 앱이 쓰는 부분집합만(YAGNI).
library;

export 'package:flutter_zoom_videosdk/native/zoom_videosdk.dart'
    show VideoAspect;

export 'src/compat/compat_event_listener.dart';
export 'src/compat/compat_models.dart';
export 'src/compat/compat_sdk.dart';
export 'src/compat/compat_view.dart';
