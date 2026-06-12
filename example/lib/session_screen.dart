import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:zoom_video_sdk_flutter/zoom_video_sdk_flutter.dart';

import 'event_formatter.dart';
import 'event_log.dart';
import 'settings_drawer.dart';
import 'video_tile.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.sdk});

  final ZoomVideoSdk sdk;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  static const int _logCap = 200;

  StreamSubscription<ZoomEvent>? _eventsSub;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<String> _logEntries = [];

  ZoomSessionInfo? _sessionInfo;
  ZoomUser? _myself;
  List<ZoomUser> _users = [];

  /// User currently screen-sharing — derived from `UserShareStatusChangedEvent`.
  String? _sharingUserId;

  bool _showLog = false;

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
      case UserShareStatusChangedEvent(:final user, :final status):
        _applyUserUpdate(user);
        if (!mounted) return;
        setState(() {
          _sharingUserId = status == ZoomShareStatus.started
              ? user.userId
              : null;
        });
      case SessionJoinedEvent():
      case SessionNeedPasswordEvent():
      case SessionPasswordWrongEvent():
      case UserActiveAudioChangedEvent():
      case ChatMessageReceivedEvent():
      case ErrorEvent():
      case CommandReceivedEvent():
        break;
    }
  }

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
    // Detect a share already in progress at the moment we joined — the SDK
    // doesn't replay userShareStatusChanged for late joiners, so we have
    // to discover it from the user list.
    String? sharingNow;
    for (final u in users) {
      if (u.isSharing) {
        sharingNow = u.userId;
        break;
      }
    }
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
      _sharingUserId ??= sharingNow;
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
    final sharingUser = _sharingUserId == null
        ? null
        : _users.firstWhere(
            (u) => u.userId == _sharingUserId,
            orElse: () => const ZoomUser(userId: '', userName: ''),
          );
    final sharingUserValid =
        sharingUser != null && sharingUser.userId.isNotEmpty;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF1B1B1F),
      endDrawer: SettingsDrawer(
        sdk: widget.sdk,
        myself: _myself,
        actions: SessionActions(runAction: _runAction, runQuery: _runQuery),
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A30),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_sessionInfo?.sessionName ?? 'Session'),
        actions: [
          IconButton(
            tooltip: _showLog ? 'Hide log' : 'Show log',
            icon: Icon(_showLog ? Icons.notes : Icons.notes_outlined),
            onPressed: () => setState(() => _showLog = !_showLog),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: sharingUserValid
                  ? _ShareLayout(
                      sharingUser: sharingUser,
                      otherUsers: _users,
                      myselfId: _myself?.userId,
                      onUserTap: _showUserActions,
                    )
                  : _VideoGrid(
                      users: _users,
                      myselfId: _myself?.userId,
                      onUserTap: _showUserActions,
                    ),
            ),
          ),
          if (_showLog)
            Container(
              color: const Color(0xFF2A2A30),
              padding: const EdgeInsets.all(8),
              child: EventLogPanel(
                entries: _logEntries,
                onClear: () => setState(_logEntries.clear),
              ),
            ),
          _ControlBar(
            myself: _myself,
            onToggleAudio: _onToggleAudio,
            onToggleVideo: _onToggleVideo,
            onToggleShare: _onToggleShare,
            onOpenChat: _onOpenChat,
            onOpenParticipants: _onOpenParticipants,
            onLeave: _onLeavePressed,
            isSharing: _sharingUserId == _myself?.userId,
          ),
        ],
      ),
    );
  }

  // ---- Control bar actions ----

  Future<void> _onToggleAudio() async {
    final me = _myself;
    if (me == null) return;
    final audio = me.audioStatus;
    final audioStarted = audio != null && audio.audioType != ZoomAudioType.none;
    if (!audioStarted) {
      await _runAction('startAudio', widget.sdk.audioHelper.startAudio);
      return;
    }
    if (audio.isMuted) {
      await _runAction(
        'unmuteAudio',
        () => widget.sdk.audioHelper.unmuteAudio(me.userId),
      );
    } else {
      await _runAction(
        'muteAudio',
        () => widget.sdk.audioHelper.muteAudio(me.userId),
      );
    }
  }

  Future<void> _onToggleVideo() async {
    final videoOn = _myself?.videoStatus?.isOn ?? false;
    if (videoOn) {
      await _runAction('stopVideo', widget.sdk.videoHelper.stopVideo);
    } else {
      await _runAction('startVideo', widget.sdk.videoHelper.startVideo);
    }
  }

  Future<void> _onToggleShare() async {
    if (_sharingUserId == _myself?.userId) {
      await _runAction('stopShare', widget.sdk.shareHelper.stopShare);
      return;
    }
    await _pickShareSource();
  }

  Future<void> _pickShareSource() async {
    final sources = await _runQuery(
      'getShareSourceList',
      widget.sdk.shareHelper.getShareSourceList,
    );
    if (sources == null || !mounted) return;
    const option = ZoomShareOption();
    final screens = sources
        .where((s) => s.type == ZoomShareSourceType.screen)
        .toList();
    final windows = sources
        .where((s) => s.type == ZoomShareSourceType.window)
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => ListView(
          controller: controller,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Pick a source to share',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (screens.isNotEmpty) ...[
              const _SectionLabel('Monitors'),
              ...screens.map(
                (s) => ListTile(
                  leading: const Icon(Icons.desktop_windows),
                  title: Text(s.name),
                  subtitle: Text(
                    s.sourceId,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _runAction(
                      'startShareScreen',
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
              const _SectionLabel('Windows'),
              ...windows.map(
                (s) => ListTile(
                  leading: const Icon(Icons.window),
                  title: Text(s.name),
                  subtitle: Text(
                    s.sourceId,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _runAction(
                      'startShareView',
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
    );
  }

  Future<void> _onOpenChat() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ChatSheet(
        sdk: widget.sdk,
        users: _users,
        myselfId: _myself?.userId,
        onAction: _runAction,
        onQuery: _runQuery,
      ),
    );
  }

  Future<void> _onOpenParticipants() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ParticipantsSheet(
        users: _users,
        myselfId: _myself?.userId,
        onTap: (u) {
          Navigator.of(ctx).pop();
          _showUserActions(u);
        },
        onRefresh: () {
          Navigator.of(ctx).pop();
          _refreshUsers();
        },
      ),
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
}

// ---------------------------------------------------------------------------
// Layouts
// ---------------------------------------------------------------------------

class _VideoGrid extends StatelessWidget {
  const _VideoGrid({
    required this.users,
    required this.myselfId,
    required this.onUserTap,
  });

  final List<ZoomUser> users;
  final String? myselfId;
  final void Function(ZoomUser) onUserTap;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(
        child: Text(
          'No participants yet',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = users.length;
        final cols = switch (count) {
          1 => 1,
          2 => 2,
          <= 4 => 2,
          _ => 3,
        };
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 16 / 9,
          ),
          itemCount: count,
          itemBuilder: (_, i) {
            final u = users[i];
            return VideoTile(
              user: u,
              isSelf: u.userId == myselfId,
              onTap: () => onUserTap(u),
            );
          },
        );
      },
    );
  }
}

class _ShareLayout extends StatelessWidget {
  const _ShareLayout({
    required this.sharingUser,
    required this.otherUsers,
    required this.myselfId,
    required this.onUserTap,
  });

  final ZoomUser sharingUser;
  // All session participants — includes the sharing user so their camera
  // tile remains visible in the strip alongside the big share view.
  final List<ZoomUser> otherUsers;
  final String? myselfId;
  final void Function(ZoomUser) onUserTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: VideoTile(
            user: sharingUser,
            isSelf: sharingUser.userId == myselfId,
            kind: ZoomVideoKind.share,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: otherUsers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final u = otherUsers[i];
              return AspectRatio(
                aspectRatio: 16 / 9,
                child: VideoTile(
                  user: u,
                  isSelf: u.userId == myselfId,
                  onTap: () => onUserTap(u),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom control bar
// ---------------------------------------------------------------------------

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.myself,
    required this.onToggleAudio,
    required this.onToggleVideo,
    required this.onToggleShare,
    required this.onOpenChat,
    required this.onOpenParticipants,
    required this.onLeave,
    required this.isSharing,
  });

  final ZoomUser? myself;
  final VoidCallback onToggleAudio;
  final VoidCallback onToggleVideo;
  final VoidCallback onToggleShare;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenParticipants;
  final VoidCallback onLeave;
  final bool isSharing;

  @override
  Widget build(BuildContext context) {
    final audio = myself?.audioStatus;
    final audioStarted = audio != null && audio.audioType != ZoomAudioType.none;
    final isMuted = !audioStarted || audio.isMuted;
    final videoOn = myself?.videoStatus?.isOn ?? false;

    return Container(
      color: const Color(0xFF2A2A30),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: isMuted ? Icons.mic_off : Icons.mic,
            label: audioStarted ? (isMuted ? 'Unmute' : 'Mute') : 'Start audio',
            color: audioStarted && !isMuted ? Colors.white : Colors.redAccent,
            onPressed: onToggleAudio,
          ),
          _ControlButton(
            icon: videoOn ? Icons.videocam : Icons.videocam_off,
            label: videoOn ? 'Stop video' : 'Start video',
            color: videoOn ? Colors.white : Colors.redAccent,
            onPressed: onToggleVideo,
          ),
          _ControlButton(
            icon: isSharing ? Icons.stop_screen_share : Icons.screen_share,
            label: isSharing ? 'Stop share' : 'Share',
            color: isSharing ? Colors.blueAccent : Colors.white,
            onPressed: onToggleShare,
          ),
          _ControlButton(
            icon: Icons.chat_bubble_outline,
            label: 'Chat',
            color: Colors.white,
            onPressed: onOpenChat,
          ),
          _ControlButton(
            icon: Icons.people_outline,
            label: 'People',
            color: Colors.white,
            onPressed: onOpenParticipants,
          ),
          _ControlButton(
            icon: Icons.call_end,
            label: 'Leave',
            color: Colors.redAccent,
            onPressed: onLeave,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat sheet
// ---------------------------------------------------------------------------

class _ChatSheet extends StatefulWidget {
  const _ChatSheet({
    required this.sdk,
    required this.users,
    required this.myselfId,
    required this.onAction,
    required this.onQuery,
  });

  final ZoomVideoSdk sdk;
  final List<ZoomUser> users;
  final String? myselfId;
  final Future<void> Function(String, Future<void> Function()) onAction;
  final Future<T?> Function<T>(String, Future<T> Function()) onQuery;

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _ctrl = TextEditingController();
  String? _receiverId;
  final List<ZoomChatMessage> _messages = [];
  StreamSubscription<ChatMessageReceivedEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.sdk.onChatMessageReceived.listen((e) {
      if (!mounted) return;
      setState(() => _messages.insert(0, e.message));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipients = widget.users
        .where((u) => u.userId != widget.myselfId)
        .toList();
    final selected =
        (_receiverId != null && recipients.any((u) => u.userId == _receiverId))
        ? _receiverId
        : null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Chat',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          '${m.senderUser.userName}${m.isChatToAll ? "" : " → ${m.receiverUser?.userName ?? ""}"}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(m.content),
                      );
                    },
                  ),
          ),
          const Divider(),
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              labelText: 'Message',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  hint: const Text('Everyone'),
                  value: selected,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Everyone'),
                    ),
                    ...recipients.map(
                      (u) => DropdownMenuItem<String?>(
                        value: u.userId,
                        child: Text(u.userName),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _receiverId = v),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _onSend, child: const Text('Send')),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _onSend() {
    final msg = _ctrl.text.trim();
    if (msg.isEmpty) return;
    final receiver = _receiverId;
    widget
        .onAction(
          receiver == null ? 'sendChatToAll' : 'sendChatToUser',
          () => receiver == null
              ? widget.sdk.chatHelper.sendChatToAll(msg)
              : widget.sdk.chatHelper.sendChatToUser(receiver, msg),
        )
        .then((_) {
          if (mounted) _ctrl.clear();
        });
  }
}

// ---------------------------------------------------------------------------
// Participants sheet
// ---------------------------------------------------------------------------

class _ParticipantsSheet extends StatelessWidget {
  const _ParticipantsSheet({
    required this.users,
    required this.myselfId,
    required this.onTap,
    required this.onRefresh,
  });

  final List<ZoomUser> users;
  final String? myselfId;
  final void Function(ZoomUser) onTap;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Participants (${users.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: onRefresh,
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: users.length,
              itemBuilder: (_, i) {
                final u = users[i];
                final audio = u.audioStatus;
                final audioConnected =
                    audio != null && audio.audioType != ZoomAudioType.none;
                final video = u.videoStatus;
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(u.userName.characters.firstOrNull ?? '?'),
                  ),
                  title: Text(
                    u.userId == myselfId ? '${u.userName} (You)' : u.userName,
                  ),
                  subtitle: Wrap(
                    spacing: 6,
                    children: [
                      if (u.isHost)
                        const _ParticipantChip(
                          label: 'HOST',
                          color: Colors.blue,
                        ),
                      if (u.isManager)
                        const _ParticipantChip(
                          label: 'MGR',
                          color: Colors.green,
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        audioConnected
                            ? (audio.isMuted ? Icons.mic_off : Icons.mic)
                            : Icons.mic_off_outlined,
                        size: 18,
                        color: audio?.isTalking == true ? Colors.green : null,
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        video?.isOn == true
                            ? Icons.videocam
                            : Icons.videocam_off,
                        size: 18,
                      ),
                    ],
                  ),
                  onTap: () => onTap(u),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantChip extends StatelessWidget {
  const _ParticipantChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User actions sheet (mute/name/private chat/etc.)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }
}

enum _LeaveChoice { cancel, leave, endForAll }
