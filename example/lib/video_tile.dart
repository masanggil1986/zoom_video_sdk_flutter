import 'package:flutter/material.dart';
import 'package:zoom_video_sdk_flutter/zoom_video_sdk_flutter.dart';

/// A single tile in the video grid — renders a user's camera (or share)
/// canvas when available, a letter avatar otherwise, with a bottom-left
/// label showing name + mic status.
class VideoTile extends StatelessWidget {
  const VideoTile({
    super.key,
    required this.user,
    this.isSelf = false,
    this.kind = ZoomVideoKind.video,
    this.onTap,
  });

  final ZoomUser user;
  final bool isSelf;
  final ZoomVideoKind kind;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final audio = user.audioStatus;
    final audioConnected =
        audio != null && audio.audioType != ZoomAudioType.none;
    final isMuted = audio?.isMuted ?? true;
    final isTalking = audio?.isTalking ?? false;
    final videoOn = user.videoStatus?.isOn ?? false;
    final showVideo = kind == ZoomVideoKind.share || videoOn;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: const Color(0xFF202124),
          foregroundDecoration: isTalking
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green, width: 2),
                )
              : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (showVideo)
                ZoomVideoView(userId: user.userId, kind: kind)
              else
                Center(child: _Avatar(name: user.userName)),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: _Label(
                  text: isSelf ? '${user.userName} (You)' : user.userName,
                  isHost: user.isHost,
                  isManager: user.isManager,
                  micIcon: !audioConnected
                      ? Icons.headset_off
                      : isMuted
                      ? Icons.mic_off
                      : Icons.mic,
                  micColor: !audioConnected
                      ? Colors.white54
                      : isMuted
                      ? Colors.redAccent
                      : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.characters.firstOrNull?.toUpperCase() ?? '?';
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xFF3C4043),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({
    required this.text,
    required this.micIcon,
    required this.micColor,
    required this.isHost,
    required this.isManager,
  });

  final String text;
  final IconData micIcon;
  final Color micColor;
  final bool isHost;
  final bool isManager;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(micIcon, size: 14, color: micColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          if (isHost) ...[const SizedBox(width: 6), const _Badge(text: 'HOST')],
          if (isManager) ...[
            const SizedBox(width: 4),
            const _Badge(text: 'MGR'),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
