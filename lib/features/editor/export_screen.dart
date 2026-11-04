import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'project_repository.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});
  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  Timer? timer;
  List<Map<String, dynamic>> jobs = [];
  String? error;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    try {
      final value = await AndroidEditProjectRepository.channel
          .invokeMethod<String>('exportList');
      if (mounted) {
        setState(() {
          jobs = (jsonDecode(value!) as List).cast<Map<String, dynamic>>();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      loading = false;
    }
  }

  Future<void> command(String method, String id) async {
    try {
      await AndroidEditProjectRepository.channel.invokeMethod<void>(method, id);
      await refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
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
        if (jobs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No exports yet'),
          ),
        for (final job in jobs.reversed)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job['project']['title'] as String? ?? 'Video project'),
                  Text('${job['state']} · ${job['progress']}%'),
                  if (job['state'] == 'running')
                    LinearProgressIndicator(
                      value: (job['progress'] as num).toDouble() / 100,
                    ),
                  if (job['error'] != null) Text(job['error'] as String),
                  if (['queued', 'running'].contains(job['state']))
                    TextButton(
                      onPressed: () =>
                          command('exportCancel', job['id'] as String),
                      child: const Text('Cancel export'),
                    ),
                  if (['failed', 'cancelled'].contains(job['state']))
                    TextButton(
                      onPressed: () =>
                          command('exportRetry', job['id'] as String),
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
