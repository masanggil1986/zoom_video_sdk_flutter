import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:zoom_video_sdk_flutter/zoom_video_sdk_flutter.dart';

import 'session_screen.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.sdk});

  final ZoomVideoSdk sdk;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _formKey = GlobalKey<FormState>();

  final _sessionNameCtrl = TextEditingController();
  final _userNameCtrl = TextEditingController(text: 'FlutterTester');
  final _tokenCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _idleTimeoutCtrl = TextEditingController(text: '40');

  bool _audioConnect = true;
  bool _audioMute = false;
  bool _videoOn = false;
  bool _isJoining = false;

  @override
  void dispose() {
    _sessionNameCtrl.dispose();
    _userNameCtrl.dispose();
    _tokenCtrl.dispose();
    _passwordCtrl.dispose();
    _idleTimeoutCtrl.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? _idleTimeoutValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      return 'Must be a positive integer';
    }
    return null;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onJoinPressed() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _isJoining = true);

    // Listen before joinSession so we don't miss events that fire synchronously
    // during the native join flow.
    final joinFuture = widget.sdk.onSessionJoin.first;
    final errorFuture = widget.sdk.onError.first;

    try {
      final idleText = _idleTimeoutCtrl.text.trim();
      final idleMins = idleText.isEmpty ? null : int.tryParse(idleText);
      final password = _passwordCtrl.text.trim();

      await widget.sdk.joinSession(
        ZoomJoinSessionConfig(
          sessionName: _sessionNameCtrl.text.trim(),
          userName: _userNameCtrl.text.trim(),
          token: _tokenCtrl.text.trim(),
          sessionPassword: password.isEmpty ? null : password,
          audioOptions: ZoomAudioOptions(
            connect: _audioConnect,
            mute: _audioMute,
          ),
          videoOptions: ZoomVideoOptions(localVideoOn: _videoOn),
          sessionIdleTimeoutMins: idleMins,
        ),
      );

      final result = await Future.any([
        joinFuture.then((e) => _JoinResult.success()),
        errorFuture.then(
          (e) => _JoinResult.error(
            '${e.errorCode.name}${e.message != null ? ": ${e.message}" : ""}',
          ),
        ),
      ]);

      if (!mounted) return;
      if (result.isSuccess) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SessionScreen(sdk: widget.sdk)),
        );
      } else {
        _showSnack(result.errorMessage ?? 'Join failed');
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      _showSnack('${e.code}${e.message != null ? ": ${e.message}" : ""}');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zoom Video SDK Example')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade200,
            child: const Text('Domain: https://zoom.us · Logs: enabled'),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _sessionNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Session name',
                        border: OutlineInputBorder(),
                      ),
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _userNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'User name',
                        border: OutlineInputBorder(),
                      ),
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tokenCtrl,
                      maxLines: 5,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Token (JWT)',
                        helperText: 'Generate via Zoom Video SDK JWT tool',
                        border: OutlineInputBorder(),
                      ),
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Session password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _idleTimeoutCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Session idle timeout (mins)',
                        border: OutlineInputBorder(),
                      ),
                      validator: _idleTimeoutValidator,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Audio: connect on join'),
                      value: _audioConnect,
                      onChanged: (v) => setState(() => _audioConnect = v),
                    ),
                    SwitchListTile(
                      title: const Text('Audio: start muted'),
                      value: _audioMute,
                      onChanged: (v) => setState(() => _audioMute = v),
                    ),
                    SwitchListTile(
                      title: const Text('Video: camera on at join'),
                      value: _videoOn,
                      onChanged: (v) => setState(() => _videoOn = v),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isJoining ? null : _onJoinPressed,
                        child: _isJoining
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Join'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinResult {
  _JoinResult._(this.isSuccess, this.errorMessage);

  factory _JoinResult.success() => _JoinResult._(true, null);
  factory _JoinResult.error(String msg) => _JoinResult._(false, msg);

  final bool isSuccess;
  final String? errorMessage;
}
