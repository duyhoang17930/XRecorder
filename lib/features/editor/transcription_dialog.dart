import 'package:xrecorder/l10n/localization.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/domain/models.dart';
import '../../core/widgets/studio_widgets.dart';
import 'subtitles.dart';
import 'transcription_service.dart';
import 'speech_languages.dart';
import 'speech_language_dialog.dart';
import 'transcription_presentation.dart';
import '../settings/settings_controller.dart';

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
  String model = 'base', language = 'auto';
  bool _preferencesRead = false;
  bool _restoring = true;
  bool allowUncertainSpeech = false;
  bool _modelChosen = false;
  String? jobId, error;
  bool busy = false, polling = false;
  TranscriptionJob? job;
  Timer? timer;
  bool get active =>
      _restoring ||
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
      final signature = transcriptionSourceSignature(widget.project);
      final list = await AndroidTranscriptionService.channel
          .invokeListMethod<dynamic>('transcriptionJobs', {
            'projectId': widget.project.id,
            'sourceSignature': signature,
            'limit': 1,
          });
      final matching =
          (list ?? [])
              .map((v) => Map<String, dynamic>.from(v as Map))
              .where(
                (v) =>
                    v['projectId'] == widget.project.id &&
                    (v['sourceSignature'] == null ||
                        v['sourceSignature'] == signature),
              )
              .toList()
            ..sort(
              (a, b) => ((b['createdAt'] as num?) ?? 0).compareTo(
                (a['createdAt'] as num?) ?? 0,
              ),
            );
      if (!mounted || matching.isEmpty || jobId != null) return;
      setState(() {
        final restored = matching.first;
        allowUncertainSpeech = restored['allowUncertainSpeech'] == true;
        jobId = restored['id'] as String;
        if (['tiny', 'base', 'small-q5_1'].contains(restored['model'])) {
          model = restored['model'] as String;
        }
        language =
            restored['language'] is String &&
                SpeechLanguages.supports(restored['language'] as String)
            ? restored['language'] as String
            : 'auto';
        _modelChosen = true;
      });
      await poll();
      if ([
        TranscriptionState.queued,
        TranscriptionState.running,
      ].contains(job?.state)) {
        timer = Timer.periodic(
          const Duration(milliseconds: 500),
          (_) => poll(),
        );
      }
    } catch (e) {
      if (mounted) {
        jobId = null;
        job = null;
        setState(() => error = speechRequestFailureMessage(e));
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_preferencesRead) {
      language =
          SettingsScope.maybeOf(context)?.preferredSpeechLanguage ?? 'auto';
      _preferencesRead = true;
    }
  }

  Future<void> refresh() async {
    try {
      final values = await AndroidTranscriptionService.channel
          .invokeListMethod<dynamic>('transcriptionModels');
      if (mounted) {
        setState(() {
          models = values!
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList();
          if (!_modelChosen) {
            final installed = models
                .where((v) => v['installed'] == true)
                .toList();
            if (!installed.any((v) => v['id'] == model) &&
                installed.isNotEmpty) {
              model = installed.first['id'] as String;
            }
            _modelChosen = true;
          }
        });
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
        setState(() => error = speechRequestFailureMessage(e));
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
            allowUncertainSpeech: allowUncertainSpeech,
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
        setState(() => error = speechRequestFailureMessage(e));
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
                'Speech operation failed. Retry or choose a smaller model.',
          );
        }
      }
    } on FormatException catch (e) {
      // A legacy job can outlive a trim/speed edit. Retain its journal and
      // manual cues, but allow a new recognition instead of staying busy forever.
      timer?.cancel();
      if (mounted) {
        setState(() {
          jobId = null;
          job = null;
          error = speechRequestFailureMessage(e);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = speechRequestFailureMessage(e));
      }
    } finally {
      polling = false;
    }
  }

  Future<void> retryHistorySave() async {
    if (active || jobId == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AndroidTranscriptionService.channel.invokeMethod<void>(
        'transcriptionSaveHistory',
        jobId,
      );
      await poll();
    } catch (e) {
      if (mounted) setState(() => error = speechRequestFailureMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
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
        title: Text(context.l10n.offlineAutomaticSubtitles),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.audioStaysOnThisDeviceTheFirst),
              if (_restoring) const LinearProgressIndicator(),
              DropdownButtonFormField<String>(
                isExpanded: true,
                itemHeight: null,
                initialValue: model,
                decoration: InputDecoration(
                  labelText: context.l10n.speechModel,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'tiny',
                    child: Text(context.l10n.fastTiny74Mib),
                  ),
                  DropdownMenuItem(
                    value: 'base',
                    child: Text(context.l10n.balancedBase141Mib),
                  ),
                  DropdownMenuItem(
                    value: 'small-q5_1',
                    child: Text(context.l10n.carefulSmall181MibSlower),
                  ),
                ],
                onChanged: active
                    ? null
                    : (v) => setState(() {
                        model = v!;
                        _modelChosen = true;
                      }),
              ),
              ListTile(
                title: Text(context.l10n.speechLanguage),
                subtitle: Text(
                  SpeechLanguages.find(language)!.displayName(context.l10n),
                ),
                trailing: const Icon(AppIcons.chevronDown),
                enabled: !active,
                onTap: active
                    ? null
                    : () async {
                        final preferences = SettingsScope.maybeOf(context);
                        final selected = await chooseSpeechLanguage(
                          context,
                          language,
                        );
                        if (!mounted || selected == null) return;
                        setState(() => language = selected.code);
                        preferences?.setSpeechLanguage(selected.code);
                      },
              ),
              Text(
                installed
                    ? context.l10n.modelInstalledAndVerified
                    : context.l10n.modelNotInstalled,
              ),
              if (installed)
                TextButton(
                  onPressed: active ? null : removeModel,
                  child: Text(context.l10n.removeDownloadedModel),
                ),
              if (!installed)
                Wrap(
                  children: [
                    TextButton(
                      onPressed: active ? null : () => run(true),
                      child: Text(context.l10n.downloadModel),
                    ),
                    TextButton(
                      onPressed: active ? null : () => run(true, import: true),
                      child: Text(context.l10n.importDownloadedBin),
                    ),
                  ],
                ),
              if (job != null) ...[
                LinearProgressIndicator(
                  value: job!.progress,
                  semanticsLabel: context.l10n.speechOperationProgress,
                ),
                Text(
                  context.l10n.operationProgress(
                    speechPhaseText(context.l10n, job!),
                    context.displayValue((job!.progress * 100).round()),
                  ),
                ),
              ],
              if (error != null)
                Text(
                  job?.state == TranscriptionState.failed
                      ? speechFailureText(context.l10n, job!)
                      : context.message(error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (job?.errorCode == 'history_write_failed' &&
                  job?.state != TranscriptionState.failed)
                Text(context.l10n.speechHistoryNotSaved),
              if (job?.errorCode == 'history_write_failed' && !active)
                TextButton(
                  onPressed: retryHistorySave,
                  child: Text(context.l10n.retrySaving),
                ),
              if (job?.state == TranscriptionState.completed &&
                  job!.cues.isNotEmpty)
                Text(
                  '${context.l10n.segmentCount(job!.cues.length)}. ${context.l10n.reviewSubtitles}',
                ),
              if (job?.detectedLanguage case final String detected)
                Text(
                  context.l10n.speechDetectedLanguage(
                    SpeechLanguages.find(detected)?.displayName(context.l10n) ??
                        detected,
                  ),
                ),
              if (job?.state == TranscriptionState.completed &&
                  job!.cues.isEmpty &&
                  job!.type == 'speech')
                Text(context.l10n.noSpeechRecognizedCheckTheAudioAnd),
              if (job?.state == TranscriptionState.completed &&
                  job!.noSpeechDetected &&
                  job!.speechActivity != null &&
                  job!.cues.isEmpty &&
                  !allowUncertainSpeech) ...[
                Text(context.l10n.speechActivityReview),
                TextButton(
                  onPressed: active
                      ? null
                      : () async {
                          setState(() => allowUncertainSpeech = true);
                          await run(false);
                        },
                  child: Text(context.l10n.speechRecognizeAnyway),
                ),
              ],
              if (job?.state == TranscriptionState.completed &&
                  speechNeedsWritingSystemReview(job!))
                Text(context.l10n.speechWritingSystemWarning),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: active ? null : () => Navigator.pop(context),
            child: Text(context.l10n.close),
          ),
          if (active)
            TextButton(
              onPressed: jobId == null || job?.phase == 'saving job history'
                  ? null
                  : () async {
                      await service.cancel(jobId!);
                      await poll();
                    },
              child: Text(context.l10n.cancelOperation),
            ),
          if (!active && installed)
            TextButton(
              onPressed: () => run(false),
              child: Text(context.l10n.recognizeEditedAudio),
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
              child: Text(context.l10n.reviewSubtitles),
            ),
        ],
      ),
    );
  }
}
