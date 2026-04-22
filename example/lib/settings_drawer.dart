import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:zoom_video_sdk_flutter/zoom_video_sdk_flutter.dart';

/// Right-side drawer that groups all advanced session controls in one place.
///
/// The host [SessionScreen] is responsible for state — this drawer is
/// a stateless wrapper that dispatches through a [SessionActions] bag so
/// side effects remain easy to centralize (logging, error toasts, etc.).
class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({
    super.key,
    required this.sdk,
    required this.myself,
    required this.actions,
  });

  final ZoomVideoSdk sdk;
  final ZoomUser? myself;
  final SessionActions actions;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const _Header(),
            _AudioSection(sdk: sdk, myself: myself, actions: actions),
            _VideoSection(sdk: sdk, actions: actions),
            _ShareSection(sdk: sdk, actions: actions),
            _RecordingSection(sdk: sdk, actions: actions),
            _VirtualBackgroundSection(sdk: sdk, actions: actions),
          ],
        ),
      ),
    );
  }
}

/// Functional dependencies shared between the drawer and the host screen.
class SessionActions {
  SessionActions({required this.runAction, required this.runQuery});

  /// Run an action that has a side-effect, with uniform error/log handling.
  final Future<void> Function(String label, Future<void> Function() action)
  runAction;

  /// Run a query that returns a value, with uniform error/log handling.
  final Future<T?> Function<T>(String label, Future<T> Function() query)
  runQuery;
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: const Text(
        'Session settings',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Audio
// ---------------------------------------------------------------------------

class _AudioSection extends StatefulWidget {
  const _AudioSection({
    required this.sdk,
    required this.myself,
    required this.actions,
  });

  final ZoomVideoSdk sdk;
  final ZoomUser? myself;
  final SessionActions actions;

  @override
  State<_AudioSection> createState() => _AudioSectionState();
}

class _AudioSectionState extends State<_AudioSection> {
  bool _micOriginal = false;
  ZoomNoiseSuppression _noiseLevel = ZoomNoiseSuppression.auto_;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text('Audio'),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Mic original input'),
                value: _micOriginal,
                onChanged: (v) async {
                  setState(() => _micOriginal = v);
                  await widget.actions.runAction(
                    'enableMicOriginalInput',
                    () => widget.sdk.audioHelper.enableMicOriginalInput(v),
                  );
                },
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Expanded(child: Text('Noise suppression')),
                  DropdownButton<ZoomNoiseSuppression>(
                    value: _noiseLevel,
                    items: ZoomNoiseSuppression.values
                        .map(
                          (l) =>
                              DropdownMenuItem(value: l, child: Text(l.name)),
                        )
                        .toList(),
                    onChanged: (level) async {
                      if (level == null) return;
                      setState(() => _noiseLevel = level);
                      await widget.actions.runAction(
                        'setNoiseSuppression',
                        () => widget.sdk.audioHelper.setNoiseSuppression(level),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _showAudioDevices(context),
                child: const Text('List audio devices'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAudioDevices(BuildContext context) async {
    final devices = await widget.actions.runQuery(
      'getAudioDeviceList',
      widget.sdk.audioHelper.getAudioDeviceList,
    );
    if (devices == null || !context.mounted) return;
    await _pickFromList(
      context,
      title: 'Audio devices',
      items: devices,
      labelOf: (d) => d.deviceName,
      subtitleOf: (d) => d.deviceId,
      onPick: (d) => widget.actions.runAction(
        'selectAudioDevice',
        () => widget.sdk.audioHelper.selectAudioDevice(d.deviceId),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Video
// ---------------------------------------------------------------------------

class _VideoSection extends StatefulWidget {
  const _VideoSection({required this.sdk, required this.actions});

  final ZoomVideoSdk sdk;
  final SessionActions actions;

  @override
  State<_VideoSection> createState() => _VideoSectionState();
}

class _VideoSectionState extends State<_VideoSection> {
  ZoomVideoPreferenceMode _mode = ZoomVideoPreferenceMode.balance;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text('Video'),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Quality preference')),
                  DropdownButton<ZoomVideoPreferenceMode>(
                    value: _mode,
                    items: ZoomVideoPreferenceMode.values
                        .map(
                          (m) =>
                              DropdownMenuItem(value: m, child: Text(m.name)),
                        )
                        .toList(),
                    onChanged: (mode) async {
                      if (mode == null) return;
                      setState(() => _mode = mode);
                      await widget.actions.runAction(
                        'setVideoQualityPreference',
                        () => widget.sdk.videoHelper.setVideoQualityPreference(
                          mode,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _showCameras(context),
                child: const Text('Select camera'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showCameras(BuildContext context) async {
    final cameras = await widget.actions.runQuery(
      'getCameraList',
      widget.sdk.videoHelper.getCameraList,
    );
    if (cameras == null || !context.mounted) return;
    await _pickFromList(
      context,
      title: 'Cameras',
      items: cameras,
      labelOf: (c) => c.deviceName,
      subtitleOf: (c) => c.deviceId,
      onPick: (c) => widget.actions.runAction(
        'selectCamera',
        () => widget.sdk.videoHelper.selectCamera(c.deviceId),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Share
// ---------------------------------------------------------------------------

class _ShareSection extends StatefulWidget {
  const _ShareSection({required this.sdk, required this.actions});

  final ZoomVideoSdk sdk;
  final SessionActions actions;

  @override
  State<_ShareSection> createState() => _ShareSectionState();
}

class _ShareSectionState extends State<_ShareSection> {
  bool _withDeviceAudio = false;
  bool _optimizeForVideo = false;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text('Share'),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Include device audio'),
                value: _withDeviceAudio,
                onChanged: (v) => setState(() => _withDeviceAudio = v),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Optimize for video'),
                subtitle: const Text(
                  'Used on share start; also callable mid-share below.',
                  style: TextStyle(fontSize: 11),
                ),
                value: _optimizeForVideo,
                onChanged: (v) => setState(() => _optimizeForVideo = v),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  final next = !_optimizeForVideo;
                  await widget.actions.runAction(
                    'enableOptimizeForSharedVideo($next)',
                    () => widget.sdk.shareHelper.enableOptimizeForSharedVideo(
                      next,
                    ),
                  );
                  if (mounted) setState(() => _optimizeForVideo = next);
                },
                child: Text(
                  _optimizeForVideo
                      ? 'Disable video optimization (runtime)'
                      : 'Enable video optimization (runtime)',
                ),
              ),
              const SizedBox(height: 4),
              OutlinedButton(
                onPressed: () => widget.actions.runAction(
                  'enableShareDeviceAudio',
                  () => widget.sdk.shareHelper.enableShareDeviceAudio(true),
                ),
                child: const Text('Enable share device audio (desktop)'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Recording
// ---------------------------------------------------------------------------

class _RecordingSection extends StatelessWidget {
  const _RecordingSection({required this.sdk, required this.actions});

  final ZoomVideoSdk sdk;
  final SessionActions actions;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text('Recording'),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton(
                onPressed: () =>
                    actions.runAction('canStartRecording', () async {
                      await sdk.recordingHelper.canStartRecording();
                    }),
                child: const Text('Can start?'),
              ),
              ElevatedButton(
                onPressed: () => actions.runAction(
                  'startCloudRecording',
                  sdk.recordingHelper.startCloudRecording,
                ),
                child: const Text('Start'),
              ),
              ElevatedButton(
                onPressed: () => actions.runAction(
                  'stopCloudRecording',
                  sdk.recordingHelper.stopCloudRecording,
                ),
                child: const Text('Stop'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Virtual background
// ---------------------------------------------------------------------------

class _VirtualBackgroundSection extends StatefulWidget {
  const _VirtualBackgroundSection({required this.sdk, required this.actions});

  final ZoomVideoSdk sdk;
  final SessionActions actions;

  @override
  State<_VirtualBackgroundSection> createState() =>
      _VirtualBackgroundSectionState();
}

class _VirtualBackgroundSectionState extends State<_VirtualBackgroundSection> {
  final _pathCtrl = TextEditingController();

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text('Virtual background'),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pathCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Image file path',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final path = _pathCtrl.text.trim();
                      if (path.isEmpty) return;
                      widget.actions.runAction(
                        'addVirtualBackgroundItem',
                        () => widget.sdk.virtualBackgroundHelper.addItem(path),
                      );
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _showItems(context),
                child: const Text('Choose from list'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showItems(BuildContext context) async {
    final items = await widget.actions.runQuery(
      'getVirtualBackgroundItemList',
      widget.sdk.virtualBackgroundHelper.getItemList,
    );
    if (items == null || !context.mounted) return;
    await _pickFromList(
      context,
      title: 'Virtual backgrounds',
      items: items,
      labelOf: (i) => i.imageName,
      subtitleOf: (i) => i.imagePath,
      onPick: (i) => widget.actions.runAction(
        'setVirtualBackgroundItem',
        () => widget.sdk.virtualBackgroundHelper.setItem(i.imageName),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic pick-from-list dialog
// ---------------------------------------------------------------------------

Future<void> _pickFromList<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required String Function(T) labelOf,
  required String Function(T) subtitleOf,
  required Future<void> Function(T) onPick,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: items.isEmpty
          ? const Text('(none)')
          : SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: items
                    .map(
                      (item) => ListTile(
                        title: Text(labelOf(item)),
                        subtitle: Text(
                          subtitleOf(item),
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          try {
                            await onPick(item);
                          } on PlatformException {
                            // Swallowed here — runAction already logs.
                          }
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
