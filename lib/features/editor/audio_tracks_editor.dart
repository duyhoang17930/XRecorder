import '../../l10n/editor_numbers.dart';

import 'package:xrecorder/l10n/localization.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/studio_widgets.dart';
import 'timeline_effects.dart';

Future<List<Map<String, Object>>?> editAudioTracks(
  BuildContext context,
  List<Map<String, Object>> tracks,
  int durationMs,
) => showStudioDialog(
  context: context,
  builder: (_) => _TracksEditor(tracks: tracks, durationMs: durationMs),
);

class _TracksEditor extends StatefulWidget {
  const _TracksEditor({required this.tracks, required this.durationMs});
  final List<Map<String, Object>> tracks;
  final int durationMs;
  @override
  State<_TracksEditor> createState() => _TracksEditorState();
}

class _TracksEditorState extends State<_TracksEditor> {
  late final tracks = widget.tracks
      .map((v) => Map<String, Object>.from(v))
      .toList();
  bool busy = false;
  String? error;
  Future<void> add() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final uri = await const MethodChannel('com.xrecorder/media')
          .invokeMethod<String>('selectAudio');
      if (uri == null) return;
      final info = (await const MethodChannel('com.xrecorder/editor')
          .invokeMapMethod<String, dynamic>('audioInfo', uri))!;
      final duration = (info['durationMs'] as num).toInt();
      if (!mounted) return;
      final track = await _edit(
        context,
        AudioTrack(
          uri: uri,
          sourceDurationMs: duration,
          outMs: math.min(duration, widget.durationMs),
        ),
        widget.durationMs,
      );
      if (mounted && track != null) setState(() => tracks.add(track.toJson()));
    } catch (e) {
      if (mounted) {
        setState(
          () => error = UserMessages.failure(
            e,
            operation: UserOperation.openMedia,
          ).text,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StudioDialog(
    title: Text(context.l10n.audioTracks),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.trimAndAlignUpTo8Tracks),
          for (var i = 0; i < tracks.length; i++)
            ListTile(
              title: Text(
                context.l10n.trackNumber(context.displayValue(i + 1)),
              ),
              subtitle: Text(
                context.l10n.audioSourceRange(
                  context.displayValue((tracks[i]['offsetMs'] as num) / 1000),
                  context.displayValue((tracks[i]['inMs'] as num) / 1000),
                  context.displayValue((tracks[i]['outMs'] as num) / 1000),
                ),
              ),
              onTap: busy
                  ? null
                  : () async {
                      final edited = await _edit(
                        context,
                        AudioTrack.fromJson(tracks[i]),
                        widget.durationMs,
                      );
                      if (mounted && edited != null) {
                        setState(() => tracks[i] = edited.toJson());
                      }
                    },
              trailing: IconButton(
                tooltip: context.l10n.removeAudioTrackNumber(
                  context.displayValue(i + 1),
                ),
                icon: const Icon(AppIcons.trash),
                onPressed: busy
                    ? null
                    : () => setState(() => tracks.removeAt(i)),
              ),
            ),
          if (error != null)
            Text(
              context.message(error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          TextButton(
            onPressed: busy || tracks.length >= 8 ? null : add,
            child: Text(
              busy ? context.l10n.openingAudio : context.l10n.addAudioFile,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context, tracks),
        child: Text(context.l10n.useTracks),
      ),
    ],
  );
}

Future<AudioTrack?> _edit(
  BuildContext context,
  AudioTrack track,
  int durationMs,
) => showStudioDialog(
  context: context,
  builder: (_) => _TrackDialog(track: track, durationMs: durationMs),
);

class _TrackDialog extends StatefulWidget {
  const _TrackDialog({required this.track, required this.durationMs});
  final AudioTrack track;
  final int durationMs;
  @override
  State<_TrackDialog> createState() => _TrackDialogState();
}

class _TrackDialogState extends State<_TrackDialog> {
  late final fields = <String, TextEditingController>{
    'Start in audio (seconds)': TextEditingController(
      text: '${widget.track.inMs / 1000}',
    ),
    'End in audio (seconds)': TextEditingController(
      text: '${widget.track.outMs / 1000}',
    ),
    'Start in video (seconds)': TextEditingController(
      text: '${widget.track.offsetMs / 1000}',
    ),
    'Fade in (seconds)': TextEditingController(
      text: '${widget.track.fadeInMs / 1000}',
    ),
    'Fade out (seconds)': TextEditingController(
      text: '${widget.track.fadeOutMs / 1000}',
    ),
  };
  late double volume = widget.track.volume;
  late String voice = widget.track.voice;
  late bool noise = widget.track.noiseReduction;
  String? error;
  @override
  void dispose() {
    for (final v in fields.values) {
      v.dispose();
    }
    super.dispose();
  }

  void save() {
    try {
      final times = fields.values.map((v) {
        final n = parseEditorDecimal(v.text);
        if (n == null || !n.isFinite) {
          throw const FormatException('Enter valid times in seconds.');
        }
        return (n * 1000).round();
      }).toList();
      final track = AudioTrack(
        uri: widget.track.uri,
        sourceDurationMs: widget.track.sourceDurationMs,
        inMs: times[0],
        outMs: times[1],
        offsetMs: times[2],
        fadeInMs: times[3],
        fadeOutMs: times[4],
        volume: volume,
        voice: voice,
        noiseReduction: noise,
      );
      track.validate(widget.durationMs);
      Navigator.pop(context, track);
    } on FormatException catch (e) {
      setState(() => error = e.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) => StudioDialog(
    title: Text(context.l10n.trimMixAudio),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.audioVideoLength(
              context.displayValue(widget.track.sourceDurationMs / 1000),
              context.displayValue(widget.durationMs / 1000),
            ),
          ),
          for (final entry in fields.entries)
            TextField(
              controller: entry.value,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: context.message(entry.key),
              ),
            ),
          Text(
            context.l10n.volumePercent(
              context.displayValue((volume * 100).round()),
            ),
          ),
          Semantics(
            label: context.l10n.audioTrackVolume,
            child: Slider(
              value: volume,
              min: 0,
              max: 2,
              divisions: 40,
              semanticFormatterCallback: context.spokenValue((strings, value) => strings.accessibilityValue40(value), multiplier: 100),
              onChanged: (v) => setState(() => volume = v),
            ),
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: voice,
            decoration: InputDecoration(labelText: context.l10n.voiceEffect),
            items: ['none', 'deep', 'bright', 'robot']
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(context.effectValue(v)),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => voice = v!),
          ),
          SwitchListTile(
            title: Text(context.l10n.reduceBackgroundNoise),
            subtitle: Text(context.l10n.offlineSpeechNoiseReduction),
            value: noise,
            onChanged: (v) => setState(() => noise = v),
          ),
          if (error != null)
            Text(
              context.message(error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      TextButton(onPressed: save, child: Text(context.l10n.useAudio)),
    ],
  );
}
