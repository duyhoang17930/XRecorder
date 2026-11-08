import 'package:xrecorder/l10n/localization.dart';
import 'package:flutter/material.dart';

import '../../core/widgets/studio_widgets.dart';

const helpTopics = <({String category, String question, String answer})>[
  (
    category: 'Recording',
    question: 'How do I record my screen?',
    answer: 'Tap +, choose your recording settings, then accept the Android screen-sharing prompt. Use the in-app controls or recording notification to pause, resume or stop. A file appears only after saving finishes.',
  ),
  (
    category: 'Recording',
    question: 'Why is a video black or silent?',
    answer: 'Android blocks protected windows and some apps disallow playback-audio capture. Internal audio requires Android 10 or later. Choose microphone audio to record your voice; protected app audio cannot be bypassed.',
  ),
  (
    category: 'Recording',
    question: 'How do countdown and duration differ?',
    answer: 'Countdown delays the start after consent. Duration limits active recording time and stops automatically; paused time does not count. Settings apply to the next session.',
  ),
  (
    category: 'Recording',
    question: 'How do facecam and touch indicators work?',
    answer: 'Facecam needs a front camera, camera permission and display-over-other-apps access. Its visible preview is captured with your screen. For taps, enable Show taps in Android Developer options yourself. The app cannot observe arbitrary touches in other apps.',
  ),
  (
    category: 'Recording',
    question: 'What if recording fails or the phone locks?',
    answer: 'Android can revoke screen capture, and device behavior varies when locked. Reopen the app to see native session status. Interrupted sessions are not shown as saved. Free storage and retry; reduce resolution or frame rate if the encoder is overloaded.',
  ),
  (
    category: 'Editing',
    question: 'Will editing change my originals?',
    answer: 'No. Drafts store clip references, ranges and effects. Export creates a new file. Keep source media available until export finishes. Undo and redo operate on the current editing session; saved drafts survive restart.',
  ),
  (
    category: 'Editing',
    question: 'How do I merge, crop and export?',
    answer: 'Create a video project, add clips and reorder them. Use the playhead to split and range handles to trim. Crop and rotate each clip. Apply project effects, then tap Export. Keep the app open; interrupted exports can be retried in Export queue.',
  ),
  (
    category: 'Editing',
    question: 'What are the GIF and audio limits?',
    answer: 'GIF uses the trimmed timeline, has no audio and is limited to 15 seconds. Choose 5/10/20 FPS and 160/320/480 pixels on the longest edge; colors are reduced to 256. Audio gain and pitch affect all audio in each clip; they do not isolate a voice. Added music loops to the project duration.',
  ),
  (
    category: 'Storage',
    question: 'Where are files saved?',
    answer: 'On Android 10 and later, videos go to Movies/XRecorder and images to Pictures/XRecorder through MediaStore. Older versions use app-specific external storage, which Android may remove on uninstall. Drafts and trash are private app data.',
  ),
  (
    category: 'Storage',
    question: 'How does Trash work?',
    answer: 'Only app-owned media can be moved to private Trash. Restore creates a new file after verifying its backup. Items become eligible for permanent cleanup after 24 hours when Trash is opened. Permanent deletion cannot be undone. External selected media stays read-only.',
  ),
  (
    category: 'Storage',
    question: 'Why did folder access stop working?',
    answer: 'A document provider, moved file or revoked permission can invalidate a saved URI. Select the folder again. Projects keep their original references and may require re-adding a moved clip.',
  ),
  (
    category: 'Privacy',
    question: 'What leaves my device?',
    answer: 'Capture, editing, drafts, exports and offline subtitles run on your device. Speech models need a download or local import; transcription does not upload your media. Sharing opens an Android chooser; you decide the receiving app. A support report includes only your text, optional selected attachment and device details if you explicitly enable them.',
  ),
];

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key, this.initialTopic});
  final String? initialTopic;
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String query = '';
  final expanded = <String>{};
  late final TextEditingController search;
  @override
  void initState() {
    super.initState();
    final question = switch (widget.initialTopic) {
      'protected-capture' => 'Why is a video black or silent?',
      'recording-stopped' => 'What if recording fails or the phone locks?',
      _ => '',
    };
    query = question;
    if (question.isNotEmpty) expanded.add(question);
    search = TextEditingController(text: query);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = helpTopics.where(
      (t) =>
          '${context.message(t.category)} ${context.message(t.question)} ${context.message(t.answer)} ${t.question}'
              .toLowerCase()
              .contains(query.toLowerCase()),
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.helpGuides)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StudioSearchField(
            controller: search,
            hintText: context.l10n.searchHelp,
            onChanged: (v) => setState(() => query = v),
          ),
          if (matches.isEmpty)
            Padding(
              padding: EdgeInsets.all(24),
              child: Text(context.l10n.noMatchingGuides),
            ),
          for (final topic in matches)
            ExpansionTile(
              key: ValueKey(topic.question),
              initiallyExpanded: expanded.contains(topic.question),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              iconColor: context.studioColors.primary,
              collapsedIconColor: context.studioColors.muted,
              expansionAnimationStyle: AnimationStyle(
                duration: context.motion(AppMotion.standard),
              ),
              trailing: Icon(
                expanded.contains(topic.question)
                    ? AppIcons.chevronUp
                    : AppIcons.chevronDown,
              ),
              onExpansionChanged: (value) => setState(() {
                if (value) {
                  expanded.add(topic.question);
                } else {
                  expanded.remove(topic.question);
                }
              }),
              title: Text(
                context.message(topic.question),
                style: AppTypography.title.copyWith(
                  color: context.studioColors.text,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Text(
                  context.message(topic.category),
                  style: AppTypography.caption.copyWith(
                    color: context.studioColors.muted,
                  ),
                ),
              ),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    context.message(topic.answer),
                    style: AppTypography.body.copyWith(
                      color: context.studioColors.muted,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
