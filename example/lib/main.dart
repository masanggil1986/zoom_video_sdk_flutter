import 'package:flutter/material.dart';
import 'package:zoom_video_sdk_flutter/zoom_video_sdk_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ZoomVideoSdk _sdk;

  @override
  void initState() {
    super.initState();
    _sdk = ZoomVideoSdk();
  }

  @override
  void dispose() {
    _sdk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Zoom Video SDK Example')),
        body: const Center(child: Text('SDK initialized')),
      ),
    );
  }
}
