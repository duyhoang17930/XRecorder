import 'package:xrecorder/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/studio_widgets.dart';
import 'audio_tracks_editor.dart';
import 'layers_editor.dart';
import 'subtitles.dart';
import 'timeline_effects.dart';

Future<Map<String, Object>?> editProjectEffects(
  BuildContext context,
  Map<String, Object> current, {
  required int durationMs,
}) => showDialog<Map<String, Object>>(
  context: context,
  builder: (_) => _EffectsDialog(current: current, durationMs: durationMs),
);

class _EffectsDialog extends StatefulWidget {
  const _EffectsDialog({required this.current, required this.durationMs});
  final Map<String, Object> current;
  final int durationMs;
  @override
  State<_EffectsDialog> createState() => _EffectsDialogState();
}

class _EffectsDialogState extends State<_EffectsDialog> {
  String? musicError;
  String? validationError;
  int get durationMs =>
      (widget.durationMs *
              ((widget.current['speed'] as num?)?.toDouble() ?? 1) /
              (values['speed'] as num))
          .floor();
  void select(String key, Object next) {
    if (key == 'speed') {
      final old = (values['speed'] as num).toDouble(),
          speed = (next as num).toDouble();
      final ratio = old / speed;
      final newDuration = (durationMs * ratio).floor();
      if (values['subtitles'] != null) {
        values['subtitles'] = SubtitleTrack.decode(
          values['subtitles'],
          durationMs,
        ).retime(old, speed, newDuration).toJson();
      }
      for (final name in ['layers', 'audioTracks']) {
        final entries = values[name] as List?;
        if (entries == null) continue;
        values[name] = entries.map((v) {
          final row = Map<String, Object>.from(v as Map);
          for (final field
              in name == 'layers' ? ['startMs', 'endMs'] : ['offsetMs']) {
            row[field] = (((row[field] as num?) ?? 0) * ratio).round();
          }
          return row;
        }).toList();
      }
      for (final field in ['fadeInMs', 'fadeOutMs']) {
        values[field] = ((values[field] as num) * ratio).round();
      }
    }
    setState(() => values[key] = next);
  }

  void apply() {
    try {
      if ((values['fadeInMs'] as num) + (values['fadeOutMs'] as num) >
          durationMs) {
        throw const FormatException(
          'Original audio fades must fit the video duration.',
        );
      }
      for (final row in values['audioTracks'] as List? ?? []) {
        AudioTrack.fromJson(row as Map).validate(durationMs);
      }
      for (final row in values['layers'] as List? ?? []) {
        validateLayer(Map<String, Object>.from(row as Map), durationMs);
      }
      Navigator.pop(context, {...values, 'text': text.text});
    } on FormatException catch (e) {
      setState(() => validationError = e.message.toString());
    }
  }

  late final values = <String, Object>{
    'speed': 1.0,
    'volume': 1.0,
    'pitch': 1.0,
    'height': 0,
    'fps': 30,
    'filter': 'none',
    'aspect': 0.0,
    'musicVolume': .5,
    'format': 'mp4',
    'bitrate': 0,
    'gifFps': 10,
    'gifEdge': 320,
    'gifRepeats': 0,
    'fadeInMs': 0,
    'fadeOutMs': 0,
    'voice': 'none',
    'noiseReduction': false,
    'subtitleColor': 'white',
    'subtitleSize': 'normal',
    'subtitleBackground': 'dark',
    'subtitlePosition': 'bottom',
    ...widget.current,
  };
  late final text = TextEditingController(
    text: widget.current['text'] as String? ?? '',
  );
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Widget choice(String key, String label, List<Object> options) =>
      DropdownButtonFormField<Object>(
        icon: const Icon(AppIcons.chevronDown),
        isExpanded: true,
        initialValue: values[key],
        decoration: InputDecoration(labelText: label),
        items: {...options, values[key]!}
            .toList()
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(
                  v == 0 && (key == 'height' || key == 'aspect')
                      ? context.l10n.originalDimensions
                      : context.effectValue(v),
                ),
              ),
            )
            .toList(),
        onChanged: (v) => select(key, v!),
      );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.videoAudioEffects),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            choice('speed', context.l10n.playbackSpeedAudioPitchAlsoChanges, [
              .5,
              1.0,
              1.5,
              2.0,
            ]),
            choice('volume', context.l10n.originalAudioGain0Mutes, [
              0.0,
              .5,
              1.0,
              1.5,
              2.0,
            ]),
            choice('pitch', context.l10n.audioPitchAppliesToAllClipAudio, [
              .75,
              1.0,
              1.25,
            ]),
            choice('voice', context.l10n.originalAudioVoiceEffect, [
              'none',
              'deep',
              'bright',
              'robot',
            ]),
            SwitchListTile(
              title: Text(context.l10n.reduceBackgroundNoise),
              subtitle: Text(context.l10n.offlineSpeechNoiseReduction),
              value: values['noiseReduction'] == true,
              onChanged: (v) => setState(() => values['noiseReduction'] = v),
            ),
            choice(
              'fadeInMs',
              context.l10n.originalAudioFadeInMilliseconds,
              [0, 100, 250, 500, 1000].where((v) => v <= durationMs).toList(),
            ),
            choice(
              'fadeOutMs',
              context.l10n.originalAudioFadeOutMilliseconds,
              [0, 100, 250, 500, 1000].where((v) => v <= durationMs).toList(),
            ),
            TextButton(
              onPressed: () async {
                final tracks = await editAudioTracks(
                  context,
                  ((values['audioTracks'] as List?) ?? [])
                      .map((v) => Map<String, Object>.from(v as Map))
                      .toList(),
                  durationMs,
                );
                if (mounted && tracks != null) {
                  setState(() => values['audioTracks'] = tracks);
                }
              },
              child: Text(
                context.l10n.audioTrackCount(
                  context.displayValue(
                    (values['audioTracks'] as List?)?.length ?? 0,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final layers = await editLayers(
                  context,
                  ((values['layers'] as List?) ?? [])
                      .map((v) => Map<String, Object>.from(v as Map))
                      .toList(),
                  durationMs,
                );
                if (mounted && layers != null) {
                  setState(() => values['layers'] = layers);
                }
              },
              child: Text(
                context.l10n.layerCount(
                  context.displayValue(
                    (values['layers'] as List?)?.length ?? 0,
                  ),
                ),
              ),
            ),
            choice('height', context.l10n.outputHeightCompression, [
              0,
              480,
              720,
              1080,
            ]),
            choice('fps', context.l10n.targetOutputFpsVariable, [24, 30, 60]),
            choice('bitrate', context.l10n.targetVideoBitrateBitsS0Automatic, [
              0,
              1000000,
              2000000,
              4000000,
              8000000,
            ]),
            choice('filter', context.l10n.colorFilter, [
              'none',
              'grayscale',
              'invert',
            ]),
            choice('subtitleColor', context.l10n.subtitleColor, [
              'white',
              'yellow',
            ]),
            choice('subtitleSize', context.l10n.subtitleTextSize, [
              'small',
              'normal',
              'large',
            ]),
            choice('subtitleBackground', context.l10n.subtitleBackground, [
              'dark',
              'none',
            ]),
            choice('subtitlePosition', context.l10n.subtitlePosition, [
              'bottom',
              'top',
            ]),
            choice('format', context.l10n.exportFormat, ['mp4', 'gif']),
            if (values['format'] == 'gif') ...[
              choice('gifFps', context.l10n.gifFramesPerSecond, [5, 10, 20]),
              choice('gifEdge', context.l10n.gifLongestEdgePixels, [
                160,
                320,
                480,
              ]),
              choice('gifRepeats', context.l10n.gifRepeatCount0Forever, [
                0,
                1,
                2,
                5,
                10,
                20,
              ]),
            ],
            Text(context.l10n.gifUsesTheTrimmedTimelineHasNoa3b084),
            choice('aspect', context.l10n.blackBackgroundAspectRatio, [
              0.0,
              1.0,
              16 / 9,
              9 / 16,
            ]),
            TextButton(
              onPressed: () async {
                try {
                  final uri = await const MethodChannel('com.xrecorder/media')
                      .invokeMethod<String>('selectAudio');
                  if (uri != null && mounted) {
                    setState(() {
                      values['music'] = uri;
                      musicError = null;
                    });
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      musicError = UserMessages.failure(
                        e,
                        operation: UserOperation.openMedia,
                      ).text;
                    });
                  }
                }
              },
              child: Text(
                values['music'] == null
                    ? context.l10n.addBackgroundMusic
                    : context.l10n.replaceBackgroundMusic,
              ),
            ),
            if (musicError != null)
              Text(
                context.message(musicError!),
                style: AppTypography.body.copyWith(
                  color: context.studioColors.warning,
                ),
              ),
            if (values['music'] != null) ...[
              Text(context.l10n.musicLoopsToTheVideoDuration),
              choice('musicVolume', context.l10n.musicGain, [
                0.0,
                .25,
                .5,
                .75,
                1.0,
              ]),
              TextButton(
                onPressed: () => setState(() => values.remove('music')),
                child: Text(context.l10n.removeMusic),
              ),
            ],
            TextField(
              controller: text,
              maxLength: 120,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.l10n.centeredTextThroughoutVideo,
              ),
            ),
            Text(context.l10n.smallerDimensionsCanReduceFileSizeThe),
            if (validationError != null)
              Text(
                context.message(validationError!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      TextButton(onPressed: apply, child: Text(context.l10n.applyToProject)),
    ],
  );
}
