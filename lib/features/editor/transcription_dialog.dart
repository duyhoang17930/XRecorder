import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/domain/models.dart';
import '../../core/widgets/studio_widgets.dart';
import 'subtitles.dart';
import 'transcription_service.dart';

Future<SubtitleTrack?> generateSubtitles(
  BuildContext context,
  EditProject project,
) => showStudioDialog(
  context: context,
  builder: (_) => _TranscriptionDialog(project: project),
);

class _TranscriptionDialog extends StatefulWidget {
  const _TranscriptionDialog({required this.project});
  final EditProject project;
  @override
  State<_TranscriptionDialog> createState() => _TranscriptionDialogState();
}

class _TranscriptionDialogState extends State<_TranscriptionDialog> {
  static const service = AndroidTranscriptionService();
  List<Map<String, dynamic>> models = [];
  String model = 'tiny', language = 'vi';
  String? jobId, error;
  bool busy = false, polling = false;
  TranscriptionJob? job;
  Timer? timer;
  bool get active =>
      busy ||
      jobId != null &&
          (job == null ||
              [
                TranscriptionState.queued,
                TranscriptionState.running,
              ].contains(job!.state));
  @override
  void initState() {
    super.initState();
    refresh();
    restoreJob();
  }

  Future<void> restoreJob() async {
    try {
      final list = await AndroidTranscriptionService.channel
          .invokeListMethod<dynamic>('transcriptionJobs');
      final matching =
          (list ?? [])
              .map((v) => Map<String, dynamic>.from(v as Map))
              .where((v) => v['projectId'] == widget.project.id)
              .toList()
            ..sort(
              (a, b) => ((b['createdAt'] as num?) ?? 0).compareTo(
                (a['createdAt'] as num?) ?? 0,
              ),
            );
      if (!mounted || matching.isEmpty || jobId != null) return;
      setState(() => jobId = matching.first['id'] as String);
      await poll();
      if (active) {
        timer = Timer.periodic(
          const Duration(milliseconds: 500),
          (_) => poll(),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = UserMessages.failure(
            e,
            operation: UserOperation.editClip,
          ).text,
        );
      }
    }
  }

  Future<void> refresh() async {
    try {
      final values = await AndroidTranscriptionService.channel
          .invokeListMethod<dynamic>('transcriptionModels');
      if (mounted) {
        setState(
          () => models = values!
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = UserMessages.failure(
            e,
            operation: UserOperation.openMedia,
          ).text,
        );
      }
    }
  }

  Future<void> removeModel() async {
    if (active) return;
    setState(() => busy = true);
    try {
      await AndroidTranscriptionService.channel.invokeMethod<void>(
        'transcriptionDeleteModel',
        model,
      );
      await refresh();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = UserMessages.failure(
            e,
            operation: UserOperation.editClip,
          ).text,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> run(bool download, {bool import = false}) async {
    if (active) return;
    setState(() {
      busy = true;
      error = null;
      job = null;
    });
    try {
      String? id;
      if (download) {
        String? uri;
        if (import) {
          uri = await const MethodChannel('com.xrecorder/media')
              .invokeMethod<String>('selectModel');
          if (uri == null) return;
        }
        id = await AndroidTranscriptionService.channel.invokeMethod<String>(
          import ? 'transcriptionImportModel' : 'transcriptionDownloadModel',
          {'model': model, if (import) 'uri': uri!},
        );
      } else {
        id = await service.start(
          TranscriptionRequest(
            audioUri: Uri.parse(widget.project.clips.first.mediaId),
            durationMs: widget.project.duration.inMilliseconds,
            language: language,
            operationId: 'speech_${DateTime.now().microsecondsSinceEpoch}',

            model: model,
            project: widget.project,
          ),
        );
      }
      if (!mounted) {
        if (id != null) await service.cancel(id);
        return;
      }
      setState(() => jobId = id);
      timer?.cancel();
      timer = Timer.periodic(const Duration(milliseconds: 500), (_) => poll());
      await poll();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = UserMessages.failure(
            e,
            operation: UserOperation.editClip,
          ).text,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> poll() async {
    if (polling || jobId == null) return;
    polling = true;
    try {
      final next = await service.poll(
        jobId!,
        widget.project.duration.inMilliseconds,
      );
      if (!mounted) return;
      setState(() => job = next);
      if (![
        TranscriptionState.queued,
        TranscriptionState.running,
      ].contains(next.state)) {
        timer?.cancel();
        await refresh();
        if (next.state == TranscriptionState.failed && mounted) {
          setState(
            () => error =
                next.error ??
                'Speech operation failed. Retry or choose a smaller model.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = UserMessages.failure(
            e,
            operation: UserOperation.editClip,
          ).text,
        );
      }
    } finally {
      polling = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    if (active && jobId != null) unawaited(service.cancel(jobId!));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final installed = models.any(
      (v) => v['id'] == model && v['installed'] == true,
    );
    return PopScope(
      canPop: !active,
      child: StudioDialog(
        title: const Text('Offline automatic subtitles'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Audio stays on this device. The first use requires a multilingual model. Tiny is smaller and faster; base may recognize speech better. Recognize up to 10 minutes at a time. Results need review.',
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                itemHeight: null,
                initialValue: model,
                decoration: const InputDecoration(labelText: 'Speech model'),
                items: const [
                  DropdownMenuItem(
                    value: 'tiny',
                    child: Text('tiny multilingual · 74 MiB'),
                  ),
                  DropdownMenuItem(
                    value: 'base',
                    child: Text('base multilingual · 141 MiB'),
                  ),
                  DropdownMenuItem(
                    value: 'small-q5_1',
                    child: Text('small quantized · 181 MiB · slower'),
                  ),
                ],
                onChanged: active ? null : (v) => setState(() => model = v!),
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                itemHeight: null,
                initialValue: language,
                decoration: const InputDecoration(labelText: 'Spoken language'),
                items: const [
                  DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(
                    value: 'auto',
                    child: Text('Detect language'),
                  ),
                ],
                onChanged: active ? null : (v) => setState(() => language = v!),
              ),
              Text(
                installed
                    ? 'Model installed and verified'
                    : 'Model not installed',
              ),
              if (installed)
                TextButton(
                  onPressed: active ? null : removeModel,
                  child: const Text('Remove downloaded model'),
                ),
              if (!installed)
                Wrap(
                  children: [
                    TextButton(
                      onPressed: active ? null : () => run(true),
                      child: const Text('Download model'),
                    ),
                    TextButton(
                      onPressed: active ? null : () => run(true, import: true),
                      child: const Text('Import downloaded .bin'),
                    ),
                  ],
                ),
              if (job != null) ...[
                LinearProgressIndicator(
                  value: job!.progress,
                  semanticsLabel: 'Speech operation progress',
                ),
                Text('${job!.phase} · ${(job!.progress * 100).round()}%'),
              ],
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (job?.state == TranscriptionState.completed &&
                  job!.cues.isNotEmpty)
                Text(
                  '${job!.cues.length} timed segments. Review and edit them before export.',
                ),
              if (job?.state == TranscriptionState.completed &&
                  job!.cues.isEmpty &&
                  job!.phase == 'completed')
                const Text(
                  'No speech recognized. Check the audio and language.',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: active ? null : () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (active)
            TextButton(
              onPressed: jobId == null
                  ? null
                  : () async {
                      await service.cancel(jobId!);
                      await poll();
                    },
              child: const Text('Cancel operation'),
            ),
          if (!active && installed)
            TextButton(
              onPressed: () => run(false),
              child: const Text('Recognize edited audio'),
            ),
          if (!active &&
              job?.state == TranscriptionState.completed &&
              job!.cues.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                SubtitleTrack(
                  job!.cues,
                  durationMs: widget.project.duration.inMilliseconds,
                ),
              ),
              child: const Text('Review subtitles'),
            ),
        ],
      ),
    );
  }
}
