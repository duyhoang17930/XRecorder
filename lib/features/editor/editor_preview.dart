import 'package:xrecorder/l10n/localization.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/widgets/studio_widgets.dart';

import 'package:flutter/services.dart';

import '../../core/domain/models.dart';
import '../media/media_repository.dart';

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
  double aspectRatio = 16 / 9;
  Duration? _lastPosition;
  int _seekRevision = 0;
  bool _foreground = true;
  String? _loadedDocument;
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
    final document = widget.project.toJson();
    final identity = jsonEncode([document['clips'], document['effects']]);
    // Platform-view creation already starts a load. Re-sending that same
    // composition while Media3 prepares tears down its active decoder graph.
    if (_loadedDocument == identity && error == null) {
      if (position != null) await command('seek', position.inMilliseconds);
      return;
    }
    _loadedDocument = identity;
    final revision = ++generation;
    unawaited(_readAspectRatio(widget.project, revision));
    final target = (position ?? _lastPosition ?? Duration.zero).inMilliseconds
        .clamp(0, widget.project.duration.inMilliseconds);
    try {
      await channel!.invokeMethod<void>('load', document);
      if (!mounted || revision != generation) return;
      if (target > 0) await channel!.invokeMethod<void>('seek', target);
      if (!mounted || revision != generation) return;
      _lastPosition = Duration(milliseconds: target);
      setState(() => error = null);
    } catch (e) {
      if (mounted && revision == generation) {
        _loadedDocument = null;
        setState(() => error = e.toString());
      }
    }
  }

  Future<void> _readAspectRatio(EditProject project, int revision) async {
    try {
      var ratio = (project.effects['aspect'] as num?)?.toDouble() ?? 0;
      if (ratio <= 0) {
        final clip = project.clips.first;
        // The catalog normalizes EXIF and video rotation on its worker thread.
        // CompositionPlayer 1.11's default graph reports an unknown videoSize.
        final metadata = await AndroidMediaRepository.channel
            .invokeMapMethod<String, dynamic>('find', {'id': clip.mediaId});
        final width = (metadata?['width'] as num?)?.toDouble() ?? 0;
        final height = (metadata?['height'] as num?)?.toDouble() ?? 0;
        if (width <= 0 || height <= 0) return;
        ratio =
            width *
            (clip.cropRight - clip.cropLeft) /
            (height * (clip.cropBottom - clip.cropTop));
        if (clip.rotation % 180 != 0) ratio = 1 / ratio;
      }
      if (mounted &&
          revision == generation &&
          ratio.isFinite &&
          ratio > 0 &&
          ratio != aspectRatio) {
        setState(() => aspectRatio = ratio);
      }
    } on PlatformException {
      // Native playback reports inaccessible sources; keep the last layout.
    } on MissingPluginException {
      // Non-Android hosts do not have catalog metadata.
    }
  }

  Future<void> command(String method, [Object? value]) async {
    Duration? requested;
    if (method == 'seek' && value is num && channel != null) {
      final milliseconds = value.toInt();
      requested = Duration(milliseconds: milliseconds < 0 ? 0 : milliseconds);
      _lastPosition = requested;
      _seekRevision++;
    }
    final seekRevision = _seekRevision;
    try {
      await channel?.invokeMethod<void>(method, value);
      if (requested == null) {
        await poll();
      } else if (mounted && seekRevision == _seekRevision) {
        // CompositionPlayer may report the old position immediately after a
        // seek. Preserve the latest user request if an effect reload follows;
        // the scheduled poll will read the player again on its next frame.
        widget.onPosition(requested);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> poll() async {
    if (polling || channel == null || !_foreground || !mounted) return;
    polling = true;
    final revision = generation;
    final seekRevision = _seekRevision;
    try {
      final state = await channel!.invokeMapMethod<Object?, Object?>('state');
      if (mounted && revision == generation && state != null) {
        final position = Duration(
          milliseconds: (state['positionMs'] as num).toInt(),
        );
        if (seekRevision == _seekRevision && position != _lastPosition) {
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
      if (mounted && revision == generation) {
        setState(() => error = e.toString());
      }
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
      ColoredBox(
        color: Colors.black,
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .4,
            ),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              // Media3's SurfaceView needs composition in the Android hierarchy.
              // Its video surface can be attached after platform-view creation;
              // do not rely on texture-mode detection before that attachment.
              child: PlatformViewLink(
                viewType: 'com.xrecorder/editor_preview',
                surfaceFactory: (context, controller) => AndroidViewSurface(
                  controller: controller as AndroidViewController,
                  hitTestBehavior: PlatformViewHitTestBehavior.opaque,
                  gestureRecognizers: const {},
                ),
                onCreatePlatformView: (params) {
                  return PlatformViewsService.initExpensiveAndroidView(
                      id: params.id,
                      viewType: 'com.xrecorder/editor_preview',
                      layoutDirection: TextDirection.ltr,
                    )
                    ..addOnPlatformViewCreatedListener(
                      params.onPlatformViewCreated,
                    )
                    ..addOnPlatformViewCreatedListener((id) {
                      _loadedDocument = null;
                      channel = MethodChannel(
                        'com.xrecorder/editor_preview/$id',
                      );
                      load();
                      timer?.cancel();
                      timer = Timer.periodic(
                        const Duration(milliseconds: 250),
                        (_) => poll(),
                      );
                    })
                    ..create();
                },
              ),
            ),
          ),
        ),
      ),
      if (error != null)
        Text(
          context.message(
            UserMessages.failure(error, operation: UserOperation.preview).text,
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      TextButton.icon(
        onPressed: () => command(playing ? 'pause' : 'play'),
        icon: Icon(playing ? AppIcons.pause : AppIcons.play),
        label: Text(
          playing ? context.l10n.pausePreview : context.l10n.playPreview,
        ),
      ),
    ],
  );
}
