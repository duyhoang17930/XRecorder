import 'package:xrecorder/l10n/localization.dart';
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
    appBar: AppBar(title: Text(context.l10n.feedbackIssueReport)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(context.l10n.describeWhatHappenedWhatYouExpectedAnd),
        TextField(
          controller: text,
          maxLength: 8000,
          minLines: 5,
          maxLines: 12,
          decoration: InputDecoration(labelText: context.l10n.yourReport),
        ),
        CheckboxListTile(
          value: consent,
          title: Text(context.l10n.includeDeviceDiagnostics),
          subtitle: Text(context.l10n.appVersionAndroidApiManufacturerModelAnd),
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
                ? context.l10n.attachImageOrVideoUpTo25
                : context.l10n.replaceSelectedAttachment,
          ),
        ),
        if (attachment != null)
          TextButton(
            onPressed: busy ? null : () => setState(() => attachment = null),
            child: Text(context.l10n.removeAttachment),
          ),
        if (busy) const LinearProgressIndicator(),
        if (message != null) Text(context.message(message!)),
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
          child: Text(context.l10n.openShareSheet),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () => run(() => channel.invokeMethod<void>('openIssues')),
          child: Text(context.l10n.openGithubIssuesInBrowser),
        ),
        Text(context.l10n.githubIssuesArePublicOpeningTheBrowser),
      ],
    ),
  );
}
