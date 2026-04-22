import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:zoom_video_sdk_flutter/zoom_video_sdk_flutter.dart';

import 'event_formatter.dart';
import 'event_log.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.sdk});

  final ZoomVideoSdk sdk;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  static const int _logCap = 200;

  StreamSubscription<ZoomEvent>? _eventsSub;
  final List<String> _logEntries = [];

  ZoomSessionInfo? _sessionInfo;
  ZoomUser? _myself;
  List<ZoomUser> _users = [];

  final _chatMessageCtrl = TextEditingController();
  final _vbPathCtrl = TextEditingController();
  final _vbRemoveCtrl = TextEditingController();

  String? _chatReceiverId;
  ZoomNoiseSuppression _noiseLevel = ZoomNoiseSuppression.auto_;
  bool _micOriginalInput = false;
  bool _shareDeviceAudio = false;
  bool _shareWithDeviceAudio = false;
  bool _shareOptimizeForVideo = false;
  ZoomVideoPreferenceMode _videoPreferenceMode =
      ZoomVideoPreferenceMode.balance;

  @override
  void initState() {
    super.initState();
    _eventsSub = widget.sdk.events.listen(_onEvent);
    Future.microtask(() async {
      await _refreshSession();
      await _refreshUsers();
    });
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _chatMessageCtrl.dispose();
    _vbPathCtrl.dispose();
    _vbRemoveCtrl.dispose();
    super.dispose();
  }

  // ---- Event handling ----

  void _log(String entry) {
    if (!mounted) return;
    setState(() {
      _logEntries.insert(0, entry);
      if (_logEntries.length > _logCap) _logEntries.removeLast();
    });
  }

  void _onEvent(ZoomEvent e) {
    _log(formatEvent(e));
    switch (e) {
      case SessionLeftEvent():
        if (mounted) Navigator.of(context).maybePop();
      case UserJoinedEvent():
      case UserLeftEvent():
        _refreshUsers();
      case UserVideoStatusChangedEvent(:final user):
      case UserAudioStatusChangedEvent(:final user):
      case UserNameChangedEvent(:final user):
        _applyUserUpdate(user);
      case UserHostChangedEvent(:final newHost):
        _applyUserUpdate(newHost);
        _refreshUsers();
      case UserManagerChangedEvent(:final user):
        _applyUserUpdate(user);
      case SessionJoinedEvent():
      case SessionNeedPasswordEvent():
      case SessionPasswordWrongEvent():
      case UserActiveAudioChangedEvent():
      case UserShareStatusChangedEvent():
      case ChatMessageReceivedEvent():
      case ErrorEvent():
        break;
    }
  }

  /// Replace the matching user in [_users] (and [_myself] if it's self) with
  /// the version carried by the event — avoids relying on a re-fetch that may
  /// return stale data.
  void _applyUserUpdate(ZoomUser updated) {
    if (!mounted) return;
    setState(() {
      final idx = _users.indexWhere((u) => u.userId == updated.userId);
      if (idx >= 0) {
        _users = [
          ..._users.sublist(0, idx),
          updated,
          ..._users.sublist(idx + 1),
        ];
      } else {
        _users = [..._users, updated];
      }
      if (_myself?.userId == updated.userId) _myself = updated;
    });
  }

  // ---- Fetches ----

  Future<void> _refreshSession() async {
    final info = await _runQuery('getSessionInfo', widget.sdk.getSessionInfo);
    final me = await _runQuery('getMyself', widget.sdk.getMyself);
    if (!mounted) return;
    setState(() {
      if (info != null) _sessionInfo = info;
      if (me != null) _myself = me;
    });
  }

  Future<void> _refreshUsers() async {
    final users = await _runQuery('getAllUsers', widget.sdk.getAllUsers);
    if (!mounted || users == null) return;
    final myId = _myself?.userId;
    setState(() {
      _users = users;
      if (myId != null) {
        for (final u in users) {
          if (u.userId == myId) {
            _myself = u;
            break;
          }
        }
      }
    });
  }

  // ---- Action wrappers ----

  Future<void> _runAction(String label, Future<void> Function() action) async {
    try {
      await action();
      _log('→ $label: ok');
    } on PlatformException catch (e) {
      _log('✗ $label: ${e.code}${e.message != null ? ": ${e.message}" : ""}');
    } on UnimplementedError catch (e) {
      _log('✗ $label: ${e.message ?? "not supported on this platform"}');
    }
  }

  Future<T?> _runQuery<T>(String label, Future<T> Function() query) async {
    try {
      return await query();
    } on PlatformException catch (e) {
      _log('✗ $label: ${e.code}${e.message != null ? ": ${e.message}" : ""}');
    } on UnimplementedError catch (e) {
      _log('✗ $label: ${e.message ?? "not supported on this platform"}');
    }
    return null;
  }

  // ---- Leave ----

  Future<void> _onLeavePressed() async {
    final choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave session'),
        content: const Text('What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_LeaveChoice.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_LeaveChoice.leave),
            child: const Text('Leave'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_LeaveChoice.endForAll),
            child: const Text('End for all (host)'),
          ),
        ],
      ),
    );
    if (choice == null || choice == _LeaveChoice.cancel) return;
    await _runAction(
      'leaveSession',
      () =>
          widget.sdk.leaveSession(endSession: choice == _LeaveChoice.endForAll),
    );
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_sessionInfo?.sessionName ?? 'Session'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Leave',
            onPressed: _onLeavePressed,
          ),
        ],
      ),
      body: Column(
        children: [
          _sessionInfoBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  _participantsSection(),
                  _audioSection(),
                  _videoSection(),
                  _shareSection(),
                  _chatSection(),
                  _recordingSection(),
                  _virtualBackgroundSection(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: EventLogPanel(
              entries: _logEntries,
              onClear: () => setState(_logEntries.clear),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Section: Session info ----

  Widget _sessionInfoBanner() {
    final info = _sessionInfo;
    final me = _myself;
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    info == null
                        ? 'Session: (loading)'
                        : 'Session: ${info.sessionName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh session info',
                  onPressed: () async {
                    await _refreshSession();
                    await _refreshUsers();
                  },
                ),
              ],
            ),
            if (info != null) Text('ID: ${info.sessionId}'),
            if (me != null)
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Me: ${me.userName} (${me.userId})'),
                  if (me.isHost) _badge('HOST', Colors.blue),
                  if (me.isManager) _badge('MANAGER', Colors.green),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }

  // ---- Section: Participants ----

  Widget _participantsSection() {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text('Participants (${_users.length})'),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refreshUsers,
        ),
        children: _users.map(_participantTile).toList(),
      ),
    );
  }

  Widget _participantTile(ZoomUser user) {
    final audio = user.audioStatus;
    final audioConnected =
        audio != null && audio.audioType != ZoomAudioType.none;
    final video = user.videoStatus;
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        child: Text(user.userName.characters.firstOrNull ?? '?'),
      ),
      title: Text(user.userName),
      subtitle: Text(user.userId, style: const TextStyle(fontSize: 11)),
      trailing: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (user.isHost) _badge('H', Colors.blue),
          if (user.isManager) _badge('M', Colors.green),
          Icon(
            audioConnected
                ? (audio.isMuted ? Icons.mic_off : Icons.mic)
                : Icons.mic_off_outlined,
            size: 18,
            color: audio?.isTalking == true ? Colors.green : null,
          ),
          Icon(
            video?.isOn == true ? Icons.videocam : Icons.videocam_off,
            size: 18,
          ),
        ],
      ),
      onLongPress: () => _showUserActions(user),
    );
  }

  // ---- Per-user bottom sheet ----

  Future<void> _showUserActions(ZoomUser user) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _UserActionsSheet(
        user: user,
        isSelf: user.userId == _myself?.userId,
        onAction: (action, [arg]) async {
          Navigator.of(ctx).pop();
          await _handleUserAction(user, action, arg);
        },
      ),
    );
  }

  Future<void> _handleUserAction(
    ZoomUser user,
    _UserAction action, [
    String? arg,
  ]) async {
    switch (action) {
      case _UserAction.makeHost:
        await _runAction(
          'makeHost',
          () => widget.sdk.userHelper.makeHost(user.userId),
        );
      case _UserAction.makeManager:
        await _runAction(
          'makeManager',
          () => widget.sdk.userHelper.makeManager(user.userId),
        );
      case _UserAction.revokeManager:
        await _runAction(
          'revokeManager',
          () => widget.sdk.userHelper.revokeManager(user.userId),
        );
      case _UserAction.removeUser:
        await _runAction(
          'removeUser',
          () => widget.sdk.userHelper.removeUser(user.userId),
        );
      case _UserAction.mute:
        await _runAction(
          'muteAudio',
          () => widget.sdk.audioHelper.muteAudio(user.userId),
        );
      case _UserAction.unmute:
        await _runAction(
          'unmuteAudio',
          () => widget.sdk.audioHelper.unmuteAudio(user.userId),
        );
      case _UserAction.changeName:
        final newName = arg ?? '';
        if (newName.trim().isEmpty) return;
        await _runAction(
          'changeName',
          () => widget.sdk.userHelper.changeName(newName.trim(), user.userId),
        );
      case _UserAction.sendPrivateChat:
        final msg = arg ?? '';
        if (msg.trim().isEmpty) return;
        await _runAction(
          'sendChatToUser',
          () => widget.sdk.chatHelper.sendChatToUser(user.userId, msg.trim()),
        );
    }
  }

  // ---- Section: Audio ----

  Widget _audioSection() {
    final myId = _myself?.userId;
    final audio = _myself?.audioStatus;
    // Zoom SDK may return AudioStatus with audioType=none after stopAudio;
    // treat that as "not started" so Start audio re-enables.
    final audioStarted = audio != null && audio.audioType != ZoomAudioType.none;
    final isMuted = audio?.isMuted ?? true;
    return Card(
      child: ExpansionTile(
        title: Row(
          children: [
            const Text('Audio'),
            const SizedBox(width: 8),
            Icon(
              audioStarted
                  ? (isMuted ? Icons.mic_off : Icons.mic)
                  : Icons.headset_off,
              size: 16,
              color: audioStarted && !isMuted ? Colors.green : null,
            ),
          ],
        ),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.headset),
                      label: const Text('Start audio'),
                      onPressed: audioStarted
                          ? null
                          : () => _runAction(
                              'startAudio',
                              widget.sdk.audioHelper.startAudio,
                            ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.headset_off),
                      label: const Text('Stop audio'),
                      onPressed: !audioStarted
                          ? null
                          : () => _runAction(
                              'stopAudio',
                              widget.sdk.audioHelper.stopAudio,
                            ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.mic_off),
                      label: const Text('Mute'),
                      onPressed: (myId == null || !audioStarted || isMuted)
                          ? null
                          : () => _runAction(
                              'muteAudio(self)',
                              () => widget.sdk.audioHelper.muteAudio(myId),
                            ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.mic),
                      label: const Text('Unmute'),
                      onPressed: (myId == null || !audioStarted || !isMuted)
                          ? null
                          : () => _runAction(
                              'unmuteAudio(self)',
                              () => widget.sdk.audioHelper.unmuteAudio(myId),
                            ),
                    ),
                  ],
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('Mic original input'),
                  value: _micOriginalInput,
                  onChanged: (v) async {
                    setState(() => _micOriginalInput = v);
                    await _runAction(
                      'enableMicOriginalInput',
                      () => widget.sdk.audioHelper.enableMicOriginalInput(v),
                    );
                  },
                ),
                Row(
                  children: [
                    const Text('Noise suppression: '),
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
                        await _runAction(
                          'setNoiseSuppression',
                          () =>
                              widget.sdk.audioHelper.setNoiseSuppression(level),
                        );
                      },
                    ),
                  ],
                ),
                OutlinedButton(
                  onPressed: _onListAudioDevices,
                  child: const Text('List audio devices'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onListAudioDevices() async {
    final devices = await _runQuery(
      'getAudioDeviceList',
      widget.sdk.audioHelper.getAudioDeviceList,
    );
    if (devices == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Audio devices'),
        content: devices.isEmpty
            ? const Text('(none)')
            : SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: devices
                      .map(
                        (d) => ListTile(
                          title: Text(d.deviceName),
                          subtitle: Text(
                            d.deviceId,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () async {
                            Navigator.of(ctx).pop();
                            await _runAction(
                              'selectAudioDevice',
                              () => widget.sdk.audioHelper.selectAudioDevice(
                                d.deviceId,
                              ),
                            );
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

  // ---- Section: Video ----

  Widget _videoSection() {
    final videoOn = _myself?.videoStatus?.isOn ?? false;
    return Card(
      child: ExpansionTile(
        title: Row(
          children: [
            const Text('Video'),
            const SizedBox(width: 8),
            Icon(
              videoOn ? Icons.videocam : Icons.videocam_off,
              size: 16,
              color: videoOn ? Colors.green : null,
            ),
          ],
        ),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.videocam),
                      label: const Text('Start video'),
                      onPressed: videoOn
                          ? null
                          : () => _runAction(
                              'startVideo',
                              widget.sdk.videoHelper.startVideo,
                            ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.videocam_off),
                      label: const Text('Stop video'),
                      onPressed: !videoOn
                          ? null
                          : () => _runAction(
                              'stopVideo',
                              widget.sdk.videoHelper.stopVideo,
                            ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cameraswitch),
                      label: const Text('Select camera'),
                      onPressed: _onListCameras,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Quality preference: '),
                    DropdownButton<ZoomVideoPreferenceMode>(
                      value: _videoPreferenceMode,
                      items: ZoomVideoPreferenceMode.values
                          .map(
                            (m) =>
                                DropdownMenuItem(value: m, child: Text(m.name)),
                          )
                          .toList(),
                      onChanged: (mode) async {
                        if (mode == null) return;
                        setState(() => _videoPreferenceMode = mode);
                        await _runAction(
                          'setVideoQualityPreference',
                          () => widget.sdk.videoHelper
                              .setVideoQualityPreference(mode),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onListCameras() async {
    final cameras = await _runQuery(
      'getCameraList',
      widget.sdk.videoHelper.getCameraList,
    );
    if (cameras == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cameras'),
        content: cameras.isEmpty
            ? const Text('(none)')
            : SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: cameras
                      .map(
                        (c) => ListTile(
                          title: Text(c.deviceName),
                          subtitle: Text(
                            c.deviceId,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () async {
                            Navigator.of(ctx).pop();
                            await _runAction(
                              'selectCamera',
                              () => widget.sdk.videoHelper.selectCamera(
                                c.deviceId,
                              ),
                            );
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

  // ---- Section: Share ----

  Widget _shareSection() {
    return Card(
      child: ExpansionTile(
        title: const Text('Share'),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.screen_share),
                      label: const Text('Pick source & share'),
                      onPressed: _onPickShareSource,
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.stop_screen_share),
                      label: const Text('Stop share'),
                      onPressed: () => _runAction(
                        'stopShare',
                        widget.sdk.shareHelper.stopShare,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Include device audio in share'),
                  value: _shareWithDeviceAudio,
                  onChanged: (v) =>
                      setState(() => _shareWithDeviceAudio = v ?? false),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Optimize for video (smoother motion, lower detail)',
                  ),
                  subtitle: const Text(
                    'Applies on share start. Use the button below to toggle mid-share.',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: _shareOptimizeForVideo,
                  onChanged: (v) {
                    final next = v ?? false;
                    setState(() => _shareOptimizeForVideo = next);
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.tune),
                    label: Text(
                      _shareOptimizeForVideo
                          ? 'Disable video optimization (runtime)'
                          : 'Enable video optimization (runtime)',
                    ),
                    onPressed: () async {
                      final next = !_shareOptimizeForVideo;
                      await _runAction(
                        'enableOptimizeForSharedVideo($next)',
                        () => widget.sdk.shareHelper
                            .enableOptimizeForSharedVideo(next),
                      );
                      if (mounted) {
                        setState(() => _shareOptimizeForVideo = next);
                      }
                    },
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text('Share device audio (desktop)'),
                  value: _shareDeviceAudio,
                  onChanged: (v) async {
                    setState(() => _shareDeviceAudio = v);
                    await _runAction(
                      'enableShareDeviceAudio',
                      () => widget.sdk.shareHelper.enableShareDeviceAudio(v),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onPickShareSource() async {
    final sources = await _runQuery(
      'getShareSourceList',
      widget.sdk.shareHelper.getShareSourceList,
    );
    if (sources == null || !mounted) return;
    final option = ZoomShareOption(
      withDeviceAudio: _shareWithDeviceAudio,
      optimizeForSharedVideo: _shareOptimizeForVideo,
    );
    final screens = sources
        .where((s) => s.type == ZoomShareSourceType.screen)
        .toList();
    final windows = sources
        .where((s) => s.type == ZoomShareSourceType.window)
        .toList();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pick a source to share'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (screens.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Monitors',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...screens.map(
                  (s) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.desktop_windows),
                    title: Text(s.name),
                    subtitle: Text(
                      s.sourceId,
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _runAction(
                        'startShareScreen(${s.sourceId})',
                        () => widget.sdk.shareHelper.startShareScreen(
                          monitorId: s.sourceId,
                          option: option,
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (windows.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Windows',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...windows.map(
                  (s) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.window),
                    title: Text(s.name),
                    subtitle: Text(
                      s.sourceId,
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _runAction(
                        'startShareView(${s.sourceId})',
                        () => widget.sdk.shareHelper.startShareView(
                          s.sourceId,
                          option: option,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
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

  // ---- Section: Chat ----

  Widget _chatSection() {
    final recipients = _users
        .where((u) => u.userId != _myself?.userId)
        .toList();
    // Dropdown이 존재하지 않는 userId를 선택 중이면 값으로 취급하지 않는다.
    // setState는 하지 않는다 — build 중 상태 변경 금지.
    final selectedReceiver =
        (_chatReceiverId != null &&
            recipients.any((u) => u.userId == _chatReceiverId))
        ? _chatReceiverId
        : null;
    return Card(
      child: ExpansionTile(
        title: const Text('Chat'),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _chatMessageCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _onSendChatToAll,
                      child: const Text('Send to all'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('Recipient'),
                        value: selectedReceiver,
                        items: recipients
                            .map(
                              (u) => DropdownMenuItem(
                                value: u.userId,
                                child: Text(u.userName),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _chatReceiverId = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _onSendPrivateChat,
                      child: const Text('Send private'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final v = await _runQuery(
                          'isChatDisabled',
                          widget.sdk.chatHelper.isChatDisabled,
                        );
                        if (v != null && mounted) {
                          _log('isChatDisabled: $v');
                        }
                      },
                      child: const Text('Chat disabled?'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final v = await _runQuery(
                          'isPrivateChatDisabled',
                          widget.sdk.chatHelper.isPrivateChatDisabled,
                        );
                        if (v != null && mounted) {
                          _log('isPrivateChatDisabled: $v');
                        }
                      },
                      child: const Text('Private chat disabled?'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onSendChatToAll() {
    final msg = _chatMessageCtrl.text.trim();
    if (msg.isEmpty) {
      _log('Enter a message');
      return;
    }
    _runAction(
      'sendChatToAll',
      () => widget.sdk.chatHelper.sendChatToAll(msg),
    ).then((_) {
      if (mounted) _chatMessageCtrl.clear();
    });
  }

  void _onSendPrivateChat() {
    final msg = _chatMessageCtrl.text.trim();
    final receiver = _chatReceiverId;
    if (msg.isEmpty || receiver == null) {
      _log('Pick a recipient and enter a message');
      return;
    }
    _runAction(
      'sendChatToUser',
      () => widget.sdk.chatHelper.sendChatToUser(receiver, msg),
    ).then((_) {
      if (mounted) _chatMessageCtrl.clear();
    });
  }

  // ---- Section: Recording ----

  Widget _recordingSection() {
    return Card(
      child: ExpansionTile(
        title: const Text('Recording'),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    final v = await _runQuery(
                      'canStartRecording',
                      widget.sdk.recordingHelper.canStartRecording,
                    );
                    if (v != null && mounted) {
                      _log('canStartRecording: $v');
                    }
                  },
                  child: const Text('Can start? (desktop)'),
                ),
                ElevatedButton(
                  onPressed: () => _runAction(
                    'startCloudRecording',
                    widget.sdk.recordingHelper.startCloudRecording,
                  ),
                  child: const Text('Start cloud recording'),
                ),
                ElevatedButton(
                  onPressed: () => _runAction(
                    'stopCloudRecording',
                    widget.sdk.recordingHelper.stopCloudRecording,
                  ),
                  child: const Text('Stop cloud recording'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Section: Virtual Background ----

  Widget _virtualBackgroundSection() {
    return Card(
      child: ExpansionTile(
        title: const Text('Virtual background'),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final v = await _runQuery(
                          'isSupported',
                          widget.sdk.virtualBackgroundHelper.isSupported,
                        );
                        if (v != null && mounted) _log('isSupported: $v');
                      },
                      child: const Text('Supported?'),
                    ),
                    OutlinedButton(
                      onPressed: _onListVirtualBackgrounds,
                      child: const Text('List items'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final item = await _runQuery(
                          'getSelectedItem',
                          widget.sdk.virtualBackgroundHelper.getSelectedItem,
                        );
                        if (!mounted) return;
                        _log('selected: ${item?.imageName ?? "(none)"}');
                      },
                      child: const Text('Get selected'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _vbPathCtrl,
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
                        final path = _vbPathCtrl.text.trim();
                        if (path.isEmpty) {
                          _log('Enter a file path');
                          return;
                        }
                        _runAction(
                          'addItem',
                          () =>
                              widget.sdk.virtualBackgroundHelper.addItem(path),
                        );
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _vbRemoveCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Image name to remove',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final name = _vbRemoveCtrl.text.trim();
                        if (name.isEmpty) {
                          _log('Enter an image name');
                          return;
                        }
                        _runAction(
                          'removeItem',
                          () => widget.sdk.virtualBackgroundHelper.removeItem(
                            name,
                          ),
                        );
                      },
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onListVirtualBackgrounds() async {
    final items = await _runQuery(
      'getItemList',
      widget.sdk.virtualBackgroundHelper.getItemList,
    );
    if (items == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Virtual backgrounds'),
        content: items.isEmpty
            ? const Text('(none)')
            : SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: items
                      .map(
                        (item) => ListTile(
                          title: Text(item.imageName),
                          subtitle: Text(
                            item.imagePath,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () async {
                            Navigator.of(ctx).pop();
                            await _runAction(
                              'setItem',
                              () => widget.sdk.virtualBackgroundHelper.setItem(
                                item.imageName,
                              ),
                            );
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
}

// ---- Private types ----

enum _LeaveChoice { cancel, leave, endForAll }

enum _UserAction {
  makeHost,
  makeManager,
  revokeManager,
  removeUser,
  mute,
  unmute,
  changeName,
  sendPrivateChat,
}

class _UserActionsSheet extends StatefulWidget {
  const _UserActionsSheet({
    required this.user,
    required this.isSelf,
    required this.onAction,
  });

  final ZoomUser user;
  final bool isSelf;
  final void Function(_UserAction action, [String? arg]) onAction;

  @override
  State<_UserActionsSheet> createState() => _UserActionsSheetState();
}

class _UserActionsSheetState extends State<_UserActionsSheet> {
  final _nameCtrl = TextEditingController();
  final _chatCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _chatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${user.userName} (${user.userId})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(
                  onPressed: () => widget.onAction(_UserAction.makeHost),
                  child: const Text('Make host'),
                ),
                OutlinedButton(
                  onPressed: () => widget.onAction(_UserAction.makeManager),
                  child: const Text('Make manager'),
                ),
                OutlinedButton(
                  onPressed: () => widget.onAction(_UserAction.revokeManager),
                  child: const Text('Revoke manager'),
                ),
                OutlinedButton(
                  onPressed: () => widget.onAction(_UserAction.removeUser),
                  child: const Text('Remove'),
                ),
                OutlinedButton(
                  onPressed: () => widget.onAction(_UserAction.mute),
                  child: const Text('Mute'),
                ),
                OutlinedButton(
                  onPressed: () => widget.onAction(_UserAction.unmute),
                  child: const Text('Unmute'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'New name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () =>
                      widget.onAction(_UserAction.changeName, _nameCtrl.text),
                  child: const Text('Change name'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!widget.isSelf)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Private message',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => widget.onAction(
                      _UserAction.sendPrivateChat,
                      _chatCtrl.text,
                    ),
                    child: const Text('Send'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
