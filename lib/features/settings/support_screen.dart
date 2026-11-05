import 'package:flutter/material.dart';

import '../../core/widgets/studio_widgets.dart';

import 'package:flutter/services.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const channel = MethodChannel('com.xrecorder/support');
  final text = TextEditingController();
  String? attachment, diagnostics, message;
  bool consent = false, busy = false;
  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => message = UserMessages.failure(
            e,
            operation: UserOperation.support,
          ).text,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Feedback & issue report')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Describe what happened, what you expected, and how to reproduce it. Remove passwords, account details and private content before sharing. Nothing is uploaded here.',
        ),
        TextField(
          controller: text,
          maxLength: 8000,
          minLines: 5,
          maxLines: 12,
          decoration: const InputDecoration(labelText: 'Your report'),
        ),
        CheckboxListTile(
          value: consent,
          title: const Text('Include device diagnostics'),
          subtitle: const Text(
            'App version, Android API, manufacturer, model and ABI only. No logs, media paths or identifiers.',
          ),
          onChanged: busy
              ? null
              : (v) => run(() async {
                  final details = v == true
                      ? await channel.invokeMethod<String>('diagnostics')
                      : null;
                  if (mounted) {
                    setState(() {
                      consent = v!;
                      diagnostics = details;
                    });
                  }
                }),
        ),
        if (diagnostics != null) SelectableText(diagnostics!),
        TextButton.icon(
          onPressed: busy
              ? null
              : () => run(() async {
                  final selected = await channel.invokeMethod<String>(
                    'pickAttachment',
                  );
                  if (selected != null && mounted) {
                    setState(() => attachment = selected);
                  }
                }),
          icon: const Icon(AppIcons.attachment),
          label: Text(
            attachment == null
                ? 'Attach image or video (up to 25 MB)'
                : 'Replace selected attachment',
          ),
        ),
        if (attachment != null)
          TextButton(
            onPressed: busy ? null : () => setState(() => attachment = null),
            child: const Text('Remove attachment'),
          ),
        if (busy) const LinearProgressIndicator(),
        if (message != null) Text(message!),
        FilledButton(
          onPressed: busy
              ? null
              : () => run(() async {
                  if (text.text.trim().isEmpty) {
                    throw const FormatException(
                      'Write a report before sharing.',
                    );
                  }
                  await channel.invokeMethod<void>('share', {
                    'text':
                        '${text.text.trim()}${consent && diagnostics != null ? '\n\n$diagnostics' : ''}',
                    'attachment': attachment,
                  });
                  if (mounted) {
                    setState(
                      () => message = 'Android share sheet opened. Delivery depends on the app and recipient you choose.',
                    );
                  }
                }),
          child: const Text('Open share sheet'),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () => run(() => channel.invokeMethod<void>('openIssues')),
          child: const Text('Open GitHub issues in browser'),
        ),
        const Text(
          'GitHub issues are public. Opening the browser does not submit this report.',
        ),
      ],
    ),
  );
}
