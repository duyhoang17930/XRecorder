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

/// [onRunInBackground] lets a caller that is itself a dialog explain the
/// background job inline; a snackbar would be hidden beneath that dialog.
Future<SubtitleTrack?> generateSubtitles(
  BuildContext context,
  EditProject project, {
  VoidCallback? onRunInBackground,
}) => showStudioDialog(
  context: context,
  builder: (_) => _TranscriptionDialog(
    project: project,
    onRunInBackground: onRunInBackground,
  ),
);

class _TranscriptionDialog extends StatefulWidget {
  const _TranscriptionDialog({required this.project, this.onRunInBackground});
  final EditProject project;
  final VoidCallback? onRunInBackground;
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

  /// When the current operation started, for the elapsed-time readout.
  DateTime? _since;

  /// Recognition runs natively, so the dialog may close without stopping it;
  /// reopening Subtitles restores the job. Model installs stay attached.
  bool get canRunInBackground =>
      !_restoring &&
      !busy &&
      jobId != null &&
      !jobId!.startsWith('model_') &&
      job?.type != 'model' &&
      job?.phase != 'saving job history' &&
      active;
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
        final created = (restored['createdAt'] as num?)?.toInt();
        _since = created == null || created <= 0
            ? DateTime.now()
            : DateTime.fromMillisecondsSinceEpoch(created);
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
      final preferences = SettingsScope.maybeOf(context);
      language = preferences?.preferredSpeechLanguage ?? 'auto';
      model = preferences?.preferredSpeechModel ?? 'base';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.removeDownloadedModel),
        content: Text(context.l10n.confirmRemoveSpeechModel),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.removeDownloadedModel),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || active) return;
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
      if (id == null) throw PlatformException(code: 'speech_start_failed');
      // Retain the terminal result until a replacement operation is accepted.
      // A cancelled picker or failed request must not pair its old ID with a
      // null snapshot, which would leave the dialog permanently active.
      setState(() {
        jobId = id;
        job = null;
        _since = DateTime.now();
      });
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
    if (active && jobId != null && !canRunInBackground) {
      unawaited(service.cancel(jobId!));
    }
    super.dispose();
  }

  // The PopScope callback tells people where to find the result.
  void runInBackground() => Navigator.pop(context);

  String _clock(Duration value) {
    final s = value.inSeconds.clamp(0, 359999);
    final mm = (s ~/ 60 % 60).toString().padLeft(2, '0'),
        ss = (s % 60).toString().padLeft(2, '0');
    return s >= 3600 ? '${s ~/ 3600}:$mm:$ss' : '${s ~/ 60}:$ss';
  }

  /// Live while running; the native total once the job has finished.
  String? get elapsedText {
    if (active && _since != null) {
      return _clock(DateTime.now().difference(_since!));
    }
    final done = job?.elapsedMs ?? 0;
    return done > 0 ? _clock(Duration(milliseconds: done)) : null;
  }

  @override
  Widget build(BuildContext context) {
    final installed = models.any(
      (v) => v['id'] == model && v['installed'] == true,
    );
    return PopScope(
      canPop: !active || canRunInBackground,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && active) {
          if (widget.onRunInBackground case final VoidCallback notify) {
            notify();
          } else {
            showNotice(context, context.l10n.speechContinuesInBackground);
          }
        }
      },
      child: StudioDialog(
        title: Text(context.l10n.offlineAutomaticSubtitles),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.sm,
            children: [
              Text(context.l10n.audioStaysOnThisDeviceTheFirst),
              if (_restoring)
                const LinearProgressIndicator(
                  minHeight: 6,
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                ),
              const SizedBox(height: AppSpacing.xxs),
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
                    : (v) {
                        if (v == null) return;
                        setState(() {
                          model = v;
                          _modelChosen = true;
                        });
                        SettingsScope.maybeOf(context)?.setSpeechModel(v);
                      },
              ),
              ListTile(
                tileColor: context.studioColors.surface,
                contentPadding: const EdgeInsetsDirectional.only(
                  start: AppSpacing.md,
                  end: AppSpacing.sm,
                ),
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
              Row(
                spacing: AppSpacing.xs,
                children: [
                  Icon(
                    installed ? AppIcons.ready : AppIcons.info,
                    size: AppIconSize.small,
                    color: installed
                        ? context.studioColors.cyan
                        : context.studioColors.muted,
                  ),
                  Expanded(
                    child: Text(
                      installed
                          ? context.l10n.modelInstalledAndVerified
                          : context.l10n.modelNotInstalled,
                      style: AppTypography.bodySmall.copyWith(
                        color: context.studioColors.text,
                      ),
                    ),
                  ),
                ],
              ),
              if (installed)
                OutlinedButton.icon(
                  onPressed: active ? null : removeModel,
                  icon: const Icon(AppIcons.trash, size: AppIconSize.medium),
                  label: Text(context.l10n.removeDownloadedModel),
                ),
              if (!installed)
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    FilledButton.tonal(
                      onPressed: active ? null : () => run(true),
                      child: Text(context.l10n.downloadModel),
                    ),
                    OutlinedButton(
                      onPressed: active ? null : () => run(true, import: true),
                      child: Text(context.l10n.importDownloadedBin),
                    ),
                  ],
                ),
              if (job == null && busy && !_restoring) ...[
                // The start request (audio probing, model checks) can take a
                // moment before the first progress snapshot arrives.
                const SizedBox(height: AppSpacing.xxs),
                LinearProgressIndicator(
                  minHeight: 6,
                  borderRadius: const BorderRadius.all(Radius.circular(3)),
                  semanticsLabel: context.l10n.speechOperationProgress,
                ),
                Text(context.l10n.processing),
              ],
              if (job != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                LinearProgressIndicator(
                  value: job!.progress,
                  minHeight: 6,
                  borderRadius: const BorderRadius.all(Radius.circular(3)),
                  semanticsLabel: context.l10n.speechOperationProgress,
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.operationProgress(
                          speechPhaseText(context.l10n, job!),
                          context.displayValue((job!.progress * 100).round()),
                        ),
                        style: AppTypography.bodyEmphasis.copyWith(
                          color: context.studioColors.text,
                        ),
                      ),
                    ),
                    if (elapsedText case final String elapsed)
                      Text(
                        context.l10n.speechElapsed(elapsed),
                        textDirection: TextDirection.ltr,
                        style: AppTypography.bodySmall.copyWith(
                          color: context.studioColors.muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
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
          if (canRunInBackground)
            TextButton(
              onPressed: runInBackground,
              child: Text(context.l10n.speechRunInBackground),
            )
          else
            TextButton(
              onPressed: active ? null : () => Navigator.pop(context),
              child: Text(context.l10n.close),
            ),
          if (active)
            TextButton(
              onPressed:
                  busy || jobId == null || job?.phase == 'saving job history'
                  ? null
                  : () async {
                      await service.cancel(jobId!);
                      await poll();
                    },
              child: Text(context.l10n.cancelOperation),
            ),
          if (!active && installed)
            FilledButton(
              onPressed: () => run(false),
              child: Text(context.l10n.recognizeEditedAudio),
            ),
          if (!active &&
              job?.state == TranscriptionState.completed &&
              job!.cues.isNotEmpty)
            FilledButton(
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
