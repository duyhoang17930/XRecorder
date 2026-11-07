import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/widgets/studio_widgets.dart';

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
  Duration? _lastPosition;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(EditorPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.project, widget.project)) return;
    if (jsonEncode(oldWidget.project.toJson()['clips']) !=
            jsonEncode(widget.project.toJson()['clips']) ||
        jsonEncode(oldWidget.project.effects) !=
            jsonEncode(widget.project.effects)) {
      load(
        position: Duration(
          microseconds:
              ((_lastPosition ?? Duration.zero).inMicroseconds *
                      oldWidget.project.speed /
                      widget.project.speed)
                  .round(),
        ),
      );
    }
  }

  Future<void> load({Duration? position}) async {
    if (channel == null || widget.project.clips.isEmpty) return;
    final revision = ++generation;
    final target = (position ?? _lastPosition ?? Duration.zero).inMilliseconds
        .clamp(0, widget.project.duration.inMilliseconds);
    try {
      await channel!.invokeMethod<void>('load', widget.project.toJson());
      if (!mounted || revision != generation) return;
      if (target > 0) await channel!.invokeMethod<void>('seek', target);
      if (!mounted || revision != generation) return;
      _lastPosition = Duration(milliseconds: target);
      setState(() => error = null);
    } catch (e) {
      if (mounted && revision == generation) {
        setState(() => error = e.toString());
      }
    }
  }

  Future<void> command(String method, [Object? value]) async {
    try {
      await channel?.invokeMethod<void>(method, value);
      await poll();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> poll() async {
    if (polling || channel == null || !_foreground || !mounted) return;
    polling = true;
    try {
      final state = await channel!.invokeMapMethod<Object?, Object?>('state');
      if (mounted && state != null) {
        final position = Duration(
          milliseconds: (state['positionMs'] as num).toInt(),
        );
        if (position != _lastPosition) {
          _lastPosition = position;
          widget.onPosition(position);
        }
        final nextPlaying = state['playing'] == true;
        final nextError = state['error'] as String? ?? error;
        if (playing != nextPlaying || error != nextError) {
          setState(() {
            playing = nextPlaying;
            error = nextError;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      polling = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      poll();
    } else {
      command('pause');
    }
  }

  @override
  void dispose() {
    generation++;
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
          UserMessages.failure(error, operation: UserOperation.preview).text,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      TextButton.icon(
        onPressed: () => command(playing ? 'pause' : 'play'),
        icon: Icon(playing ? AppIcons.pause : AppIcons.play),
        label: Text(playing ? 'Pause preview' : 'Play preview'),
      ),
    ],
  );
}
