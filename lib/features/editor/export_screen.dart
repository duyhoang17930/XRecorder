import 'package:xrecorder/l10n/localization.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'project_repository.dart';
import '../../core/widgets/studio_widgets.dart';
import '../media/media_repository.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});
  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen>
    with WidgetsBindingObserver {
  Timer? timer;
  List<Map<String, dynamic>> jobs = [];
  String? error;
  bool loading = false;
  bool refreshPending = false;
  bool foreground = true;
  bool routeCurrent = true;
  String? _document;
  final pendingCommands = <String>{};
  final notifiedUris = <String>{};
  bool get active => jobs.any(
    (job) => ['queued', 'running', 'finalizing'].contains(job['state']),
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  void schedule() {
    timer?.cancel();
    if (mounted && foreground && routeCurrent && (active || error != null)) {
      timer = Timer(const Duration(seconds: 1), () {
        refresh();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    final returned = !routeCurrent && current;
    routeCurrent = current;
    if (!current) timer?.cancel();
    if (returned && foreground) refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    timer?.cancel();
    if (foreground && routeCurrent) refresh();
  }

  Future<void> refresh() async {
    if (loading) {
      refreshPending = true;
      return;
    }
    refreshPending = false;
    loading = true;
    try {
      final value = await AndroidEditProjectRepository.channel
          .invokeMethod<String>('exportList');
      if (mounted && (value != _document || error != null)) {
        setState(() {
          jobs = (jsonDecode(value!) as List).cast<Map<String, dynamic>>();
          _document = value;
          error = null;
        });
        for (final job in jobs) {
          if (job['state'] == 'completed' &&
              job['uri'] is String &&
              notifiedUris.add(job['uri'] as String)) {
            context
                .getInheritedWidgetOfExactType<MediaScope>()
                ?.repository
                .refresh();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = UserMessages.failure(
            e,
            operation: UserOperation.export,
          ).text,
        );
      }
    } finally {
      loading = false;
      // A command or resume can arrive while an older list request is pending.
      // Re-read once it drains; a stale terminal response must not stop polling
      // a job that the user has just retried.
      if (refreshPending && mounted && foreground && routeCurrent) {
        unawaited(refresh());
      } else {
        schedule();
      }
    }
  }

  Future<void> command(String method, String id) async {
    if (!pendingCommands.add(id)) return;
    setState(() {});
    try {
      await AndroidEditProjectRepository.channel.invokeMethod<void>(method, id);
      await refresh();
    } catch (e) {
      if (mounted) {
        showFailure(context, e, operation: UserOperation.export);
      }
    } finally {
      pendingCommands.remove(id);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _job(BuildContext context, Map job) {
    final c = context.studioColors;
    final state = job['state'] as String?;
    final active = ['queued', 'running', 'finalizing'].contains(state);
    final (IconData icon, Color tint) = switch (state) {
      'completed' => (AppIcons.ready, c.cyan),
      'failed' => (AppIcons.warning, c.warning),
      'cancelled' => (AppIcons.close, c.muted),
      _ => (AppIcons.processing, c.primary),
    };
    final status = context.message(switch (state) {
      'queued' => 'Waiting',
      'running' => 'Exporting',
      'finalizing' => 'Saving…',
      'completed' => 'Saved',
      'failed' => 'Could not export',
      'cancelled' => 'Cancelled',
      _ => 'Processing',
    });
    final pending = pendingCommands.contains(job['id']);
    final muted = AppTypography.bodySmall.copyWith(color: c.muted);
    return StudioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          Row(
            children: [
              StudioIconTile(
                icon: icon,
                color: tint,
                size: 40,
                iconSize: AppIconSize.medium,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job['project']['title'] as String? ??
                          context.l10n.videoProject,
                      style: AppTypography.bodyEmphasis,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      // A failed or cancelled job's last progress value is
                      // not meaningful ("Could not export · 100%").
                      active || state == 'completed'
                          ? context.l10n.operationProgress(
                              status,
                              context.displayValue(job['progress']),
                            )
                          : status,
                      style: AppTypography.bodySmall.copyWith(color: tint),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (state == 'running')
            LinearProgressIndicator(
              value: (job['progress'] as num).toDouble() / 100,
              minHeight: 6,
              borderRadius: const BorderRadius.all(Radius.circular(3)),
            ),
          if (state == 'finalizing')
            const LinearProgressIndicator(
              minHeight: 6,
              borderRadius: BorderRadius.all(Radius.circular(3)),
            ),
          if (job['error'] != null)
            Text(
              context.message(
                UserMessages.failure(
                  job['error'],
                  operation: UserOperation.export,
                ).text,
              ),
              style: muted,
            ),
          if (job['warning'] is String)
            Text(context.message(job['warning'] as String), style: muted),
          if (state == 'completed' && (job['outputBytes'] as num? ?? 0) > 0)
            Text(
              context.l10n.savedFileSize(
                context.displayValue(
                  context.fileSize((job['outputBytes'] as num).toInt()),
                ),
              ),
              style: muted,
            ),
          if (['queued', 'running'].contains(state))
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: pending
                    ? null
                    : () => command('exportCancel', job['id'] as String),
                icon: const Icon(AppIcons.close, size: AppIconSize.medium),
                label: Text(context.l10n.cancelExport),
              ),
            ),
          if (['failed', 'cancelled'].contains(state))
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                onPressed: pending
                    ? null
                    : () => command('exportRetry', job['id'] as String),
                icon: const Icon(AppIcons.refresh, size: AppIconSize.medium),
                label: Text(context.l10n.retryExport),
              ),
            ),
          if (state == 'completed')
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                onPressed: () => context.push(
                  '/media/${Uri.encodeComponent(job['uri'] as String)}',
                ),
                icon: const Icon(AppIcons.open, size: AppIconSize.medium),
                label: Text(context.l10n.openSavedMedia),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.exports)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      children: [
        Text(
          context.l10n.keepTheAppOpenWhileExportingInterrupted,
          style: AppTypography.bodySmall.copyWith(
            color: context.studioColors.muted,
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              context.message(error!),
              style: TextStyle(color: context.studioColors.warning),
            ),
          ),
        for (final notice in jobs.where((j) => j['type'] == 'notice'))
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(context.message(notice['message'] as String)),
          ),
        if (jobs.isEmpty)
          StudioEmptyState(
            title: context.l10n.noExportsYet,
            icon: AppIcons.export,
          ),
        if (jobs.isNotEmpty) const SizedBox(height: AppSpacing.md),
        for (final job in jobs.reversed.where((j) => j['type'] != 'notice'))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _job(context, job),
          ),
      ],
    ),
  );
}
