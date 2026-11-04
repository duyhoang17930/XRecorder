import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/domain/models.dart';

class EditorPreview extends StatefulWidget {
  const EditorPreview({
    super.key,
    required this.project,
    required this.onPosition,
  });
  final EditProject project;
  final ValueChanged<Duration> onPosition;
  @override
  State<EditorPreview> createState() => EditorPreviewState();
}

class EditorPreviewState extends State<EditorPreview>
    with WidgetsBindingObserver {
  MethodChannel? channel;
  Timer? timer;
  String? error;
  bool playing = false, polling = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(EditorPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (jsonEncode(oldWidget.project.toJson()['clips']) !=
        jsonEncode(widget.project.toJson()['clips'])) {
      load();
    }
  }

  Future<void> load() async {
    if (channel == null || widget.project.clips.isEmpty) return;
    try {
      await channel!.invokeMethod<void>('load', widget.project.toJson());
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> command(String method, [Object? value]) async {
    try {
      await channel?.invokeMethod<void>(method, value);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> poll() async {
    if (polling || channel == null) return;
    polling = true;
    try {
      final state = await channel!.invokeMapMethod<Object?, Object?>('state');
      if (mounted && state != null) {
        widget.onPosition(
          Duration(milliseconds: (state['positionMs'] as num).toInt()),
        );
        setState(() {
          playing = state['playing'] == true;
          error = state['error'] as String? ?? error;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      polling = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) command('pause');
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AspectRatio(
        aspectRatio: 16 / 9,
        child: AndroidView(
          viewType: 'com.xrecorder/editor_preview',
          onPlatformViewCreated: (id) {
            channel = MethodChannel('com.xrecorder/editor_preview/$id');
            load();
            timer = Timer.periodic(
              const Duration(milliseconds: 250),
              (_) => poll(),
            );
          },
        ),
      ),
      if (error != null)
        Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      TextButton.icon(
        onPressed: () => command(playing ? 'pause' : 'play'),
        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
        label: Text(playing ? 'Pause preview' : 'Play preview'),
      ),
    ],
  );
}
