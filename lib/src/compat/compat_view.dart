import 'package:flutter/widgets.dart' hide View;
import 'package:flutter_zoom_videosdk/flutter_zoom_view.dart' as mobile_view;

import '../../zoom_video_sdk_flutter.dart' show ZoomVideoKind, ZoomVideoView;
import 'compat_sdk.dart' show isZoomDesktop;

/// flutter_zoom_videosdk 의 zoom_view.View 와 동일 시그니처.
/// 데스크톱은 creationParams 중 userId/sharing 만 의미 있다(나머지는 모바일 전용).
class View extends StatelessWidget {
  const View({super.key, required this.creationParams});

  final Map<String, dynamic> creationParams;

  @override
  Widget build(BuildContext context) {
    if (!isZoomDesktop) {
      return mobile_view.View(creationParams: creationParams);
    }
    return ZoomVideoView(
      userId: creationParams['userId'] as String? ?? '',
      kind: creationParams['sharing'] == true
          ? ZoomVideoKind.share
          : ZoomVideoKind.video,
    );
  }
}
