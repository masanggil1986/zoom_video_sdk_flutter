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
  final _shareWindowCtrl = TextEditingController();
  final _vbPathCtrl = TextEditingController();
  final _vbRemoveCtrl = TextEditingController();

  String? _chatReceiverId;
  ZoomNoiseSuppression _noiseLevel = ZoomNoiseSuppression.auto_;
  bool _micOriginalInput = false;
  bool _shareDeviceAudio = false;

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
    _shareWindowCtrl.dispose();
    _vbPathCtrl.dispose();
    _vbRemoveCtrl.dispose();
    super.dispose();
  }

  // ---- Event handling ----

  void _onEvent(ZoomEvent e) {
    if (!mounted) return;
    setState(() {
      _logEntries.insert(0, formatEvent(e));
      if (_logEntries.length > _logCap) _logEntries.removeLast();
    });
    switch (e) {
      case SessionLeftEvent():
        if (mounted) Navigator.of(context).maybePop();
      case UserJoinedEvent():
      case UserLeftEvent():
      case UserVideoStatusChangedEvent():
      case UserAudioStatusChangedEvent():
      case UserHostChangedEvent():
      case UserManagerChangedEvent():
      case UserNameChangedEvent():
        _refreshUsers();
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
    setState(() => _users = users);
  }

  // ---- Action wrappers ----

  Future<void> _runAction(String label, Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      _showSnack('$label: ok');
    } on PlatformException catch (e) {
      if (!mounted) return;
      _showSnack(
        '$label: ${e.code}${e.message != null ? ": ${e.message}" : ""}',
      );
    } on UnimplementedError catch (e) {
      if (!mounted) return;
      _showSnack('$label: ${e.message ?? "not supported on this platform"}');
    }
  }

  Future<T?> _runQuery<T>(String label, Future<T> Function() query) async {
    try {
      return await query();
    } on PlatformException catch (e) {
      if (!mounted) return null;
      _showSnack(
        '$label: ${e.code}${e.message != null ? ": ${e.message}" : ""}',
      );
    } on UnimplementedError catch (e) {
      if (!mounted) return null;
      _showSnack('$label: ${e.message ?? "not supported on this platform"}');
    }
    return null;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
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
            audio == null
                ? Icons.mic_off_outlined
                : (audio.isMuted ? Icons.mic_off : Icons.mic),
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
    return Card(
      child: ExpansionTile(
        title: const Text('Audio'),
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
                    ElevatedButton(
                      onPressed: () => _runAction(
                        'startAudio',
                        widget.sdk.audioHelper.startAudio,
                      ),
                      child: const Text('Start audio'),
                    ),
                    ElevatedButton(
                      onPressed: () => _runAction(
                        'stopAudio',
                        widget.sdk.audioHelper.stopAudio,
                      ),
                      child: const Text('Stop audio'),
                    ),
                    ElevatedButton(
                      onPressed: myId == null
                          ? null
                          : () => _runAction(
                              'muteAudio(self)',
                              () => widget.sdk.audioHelper.muteAudio(myId),
                            ),
                      child: const Text('Mute self'),
                    ),
                    ElevatedButton(
                      onPressed: myId == null
                          ? null
                          : () => _runAction(
                              'unmuteAudio(self)',
                              () => widget.sdk.audioHelper.unmuteAudio(myId),
                            ),
                      child: const Text('Unmute self'),
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
    return Card(
      child: ExpansionTile(
        title: const Text('Video'),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ElevatedButton(
                  onPressed: () => _runAction(
                    'startVideo',
                    widget.sdk.videoHelper.startVideo,
                  ),
                  child: const Text('Start video'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      _runAction('stopVideo', widget.sdk.videoHelper.stopVideo),
                  child: const Text('Stop video'),
                ),
                ElevatedButton(
                  onPressed: () => _runAction(
                    'switchCamera',
                    widget.sdk.videoHelper.switchCamera,
                  ),
                  child: const Text('Switch camera'),
                ),
                OutlinedButton(
                  onPressed: _onListCameras,
                  child: const Text('List cameras (desktop)'),
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
                    ElevatedButton(
                      onPressed: () => _runAction(
                        'startShareScreen',
                        widget.sdk.shareHelper.startShareScreen,
                      ),
                      child: const Text('Start share screen'),
                    ),
                    ElevatedButton(
                      onPressed: () => _runAction(
                        'stopShare',
                        widget.sdk.shareHelper.stopShare,
                      ),
                      child: const Text('Stop share'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _shareWindowCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Window ID (desktop)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final id = _shareWindowCtrl.text.trim();
                        if (id.isEmpty) {
                          _showSnack('Enter a window ID first');
                          return;
                        }
                        _runAction(
                          'startShareView',
                          () => widget.sdk.shareHelper.startShareView(id),
                        );
                      },
                      child: const Text('Start share view'),
                    ),
                  ],
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
                          _showSnack('isChatDisabled: $v');
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
                          _showSnack('isPrivateChatDisabled: $v');
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
      _showSnack('Enter a message');
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
      _showSnack('Pick a recipient and enter a message');
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
                      _showSnack('canStartRecording: $v');
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
                        if (v != null && mounted) _showSnack('isSupported: $v');
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
                        _showSnack('selected: ${item?.imageName ?? "(none)"}');
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
                          _showSnack('Enter a file path');
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
                          _showSnack('Enter an image name');
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
