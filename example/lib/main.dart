import 'package:flutter/material.dart';
import 'package:zoom_video_sdk_flutter/zoom_video_sdk_flutter.dart';

import 'join_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ZoomVideoSdk _sdk = ZoomVideoSdk();
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _sdk.init(const ZoomInitConfig());
  }

  @override
  void dispose() {
    _sdk.dispose();
    super.dispose();
  }

  // Re-run init after a failure; captured once so FutureBuilder doesn't
  // restart the future on every rebuild.
  void _retry() {
    setState(() {
      _initFuture = _sdk.init(const ZoomInitConfig());
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zoom Video SDK Example',
      home: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Initializing Zoom Video SDK...'),
                  ],
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Init failed: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          return JoinScreen(sdk: _sdk);
        },
      ),
    );
  }
}
