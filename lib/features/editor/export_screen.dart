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
    if (loading) return;
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
      schedule();
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Exports')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Keep the app open while exporting. Interrupted jobs can be retried. Each export saves a new file; your draft and original media are kept.',
        ),
        if (error != null) Text(error!),
        for (final notice in jobs.where((j) => j['type'] == 'notice'))
          Text(notice['message'] as String),
        if (jobs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No exports yet'),
          ),
        for (final job in jobs.reversed.where((j) => j['type'] != 'notice'))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job['project']['title'] as String? ?? 'Video project'),
                  Text(
                    '${switch (job['state']) {
                      'queued' => 'Waiting',
                      'running' => 'Exporting',
                      'finalizing' => 'Saving…',
                      'completed' => 'Saved',
                      'failed' => 'Could not export',
                      'cancelled' => 'Cancelled',
                      _ => 'Processing',
                    }} · ${job['progress']}%',
                  ),
                  if (job['state'] == 'running')
                    LinearProgressIndicator(
                      value: (job['progress'] as num).toDouble() / 100,
                    ),
                  if (job['error'] != null)
                    Text(
                      UserMessages.failure(
                        job['error'],
                        operation: UserOperation.export,
                      ).text,
                    ),
                  if (job['warning'] is String) Text(job['warning'] as String),
                  if (job['state'] == 'completed' &&
                      (job['outputBytes'] as num? ?? 0) > 0)
                    Text(
                      'Saved file: ${formatBytes((job['outputBytes'] as num).toInt())}',
                    ),
                  if (['queued', 'running'].contains(job['state']))
                    TextButton(
                      onPressed: pendingCommands.contains(job['id'])
                          ? null
                          : () => command('exportCancel', job['id'] as String),
                      child: const Text('Cancel export'),
                    ),
                  if (['failed', 'cancelled'].contains(job['state']))
                    TextButton(
                      onPressed: pendingCommands.contains(job['id'])
                          ? null
                          : () => command('exportRetry', job['id'] as String),
                      child: const Text('Retry export'),
                    ),
                  if (job['state'] == 'completed')
                    TextButton(
                      onPressed: () => context.push(
                        '/media/${Uri.encodeComponent(job['uri'] as String)}',
                      ),
                      child: const Text('Open saved media'),
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
