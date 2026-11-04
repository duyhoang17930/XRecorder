import 'package:flutter/material.dart';

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
    answer: 'GIF exports have no audio and are limited to 15 seconds, 10 FPS and 320 pixels on the longest edge with 256 colors. Audio gain and pitch affect all audio in each clip; they do not isolate a voice from other sounds. Added music loops to the project duration.',
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
    answer: 'Capture, editing, drafts and exports run locally. No transcription or livestream connection is enabled. Sharing opens an Android chooser; you decide the receiving app. A support report includes only your text, optional selected attachment and device details if you explicitly enable them.',
  ),
];

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final matches = helpTopics.where(
      (t) => '${t.category} ${t.question} ${t.answer}'.toLowerCase().contains(
        query.toLowerCase(),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Help & guides')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search help',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          if (matches.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No matching guides'),
            ),
          for (final topic in matches)
            ExpansionTile(
              title: Text(topic.question),
              subtitle: Text(topic.category),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(topic.answer),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
