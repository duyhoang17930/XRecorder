import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/widgets/studio_widgets.dart';
import 'package:xrecorder/features/editor/speech_language_dialog.dart';
import 'package:xrecorder/features/editor/speech_languages.dart';
import 'package:xrecorder/features/editor/transcription_service.dart';
import 'package:xrecorder/l10n/app_languages.dart';
import 'package:xrecorder/l10n/localization.dart';
import 'package:xrecorder/l10n/generated/app_localizations_en.dart';
import 'package:xrecorder/features/editor/transcription_presentation.dart';
import 'package:xrecorder/features/editor/subtitles.dart';
import 'package:xrecorder/core/domain/models.dart';

void main() {
  test('ASR timeline identity survives locale/title/style changes but detects trim and speed', () {
    final project = EditProject(
      id: 'identity',
      updatedAt: DateTime(2026),
      clips: [
        TimelineClip(
          mediaId: 'content://qa/video',
          inPoint: Duration.zero,
          outPoint: const Duration(seconds: 4),
          sourceDuration: const Duration(seconds: 4),
        ),
      ],
      effects: {'speed': 1.0, 'volume': .5},
    );
    final signature = transcriptionSourceSignature(project);
    expect(
      transcriptionSourceSignature(
        project.copyWith(
          clips: [
            project.clips.single.copyWith(
              title: 'العربية',
              rotation: 90,
              cropLeft: .1,
            ),
          ],
        ),
      ),
      signature,
      reason: 'Visual-only clip edits do not change rendered audio.',
    );
    expect(
      transcriptionSourceSignature(
        project.copyWith(
          title: 'العربية',
          effects: {'subtitleColor': 'yellow', 'volume': .5, 'speed': 1.0},
        ),
      ),
      signature,
    );
    expect(
      transcriptionSourceSignature(
        project.copyWith(effects: {'speed': 2.0, 'volume': .5}),
      ),
      isNot(signature),
    );
    expect(
      transcriptionSourceSignature(
        project.copyWith(
          clips: [
            project.clips.single.copyWith(inPoint: const Duration(seconds: 1)),
          ],
        ),
      ),
      isNot(signature),
    );
  });
  test(
    'speech override is explicit and review warnings preserve recognized text',
    () {
      final request = TranscriptionRequest(
        audioUri: Uri.parse('content://qa/quiet'),
        durationMs: 1000,
        language: 'hi',
        operationId: 'quiet_retry',
        allowUncertainSpeech: true,
      );
      expect(request.toJson()['allowUncertainSpeech'], isTrue);
      final cue = SubtitleCue(startMs: 0, endMs: 1000, text: 'کچھ عالموں میں');
      final job = TranscriptionJob(
        id: 'hi_review',
        state: TranscriptionState.completed,
        progress: 1,
        language: 'hi',
        resultLanguage: 'hi',
        cues: [cue],
      );
      expect(speechNeedsWritingSystemReview(job), isTrue);
      expect(job.cues.single.text, cue.text);
      final hindi = TranscriptionJob(
        id: 'hi_deva',
        state: TranscriptionState.completed,
        progress: 1,
        language: 'hi',
        resultLanguage: 'hi',
        cues: [SubtitleCue(startMs: 0, endMs: 1000, text: 'कुछ अणुओं में')],
      );
      expect(speechNeedsWritingSystemReview(hindi), isFalse);
      final strings = AppLocalizationsEn();
      expect(
        speechPhaseText(
          strings,
          TranscriptionJob(
            id: 'old_model',
            state: TranscriptionState.completed,
            progress: 1,
            type: 'model',
            phase: 'restored',
          ),
        ),
        strings.modelInstalledAndVerified,
      );
    },
  );

  test(
    'catalog includes 99 model languages, Auto, and unavailable Cantonese',
    () {
      expect(SpeechLanguages.values.length, 101);
      expect(
        SpeechLanguages.values.where((language) => language.available).length,
        100,
      );
      expect(
        SpeechLanguages.values.map((language) => language.code).toSet().length,
        101,
      );
      expect(SpeechLanguages.find('yue')!.nativeCode, 99);
      expect(SpeechLanguages.supports('yue'), isFalse);
      for (final language in SpeechLanguages.values.where(
        (language) => language.available,
      )) {
        final request = TranscriptionRequest(
          audioUri: Uri.parse('content://qa/speech'),
          durationMs: 1000,
          language: language.code,
          operationId: 'language_${language.code}',
          model: 'base',
        );
        expect(request.toJson()['language'], language.code);
        expect(request.toJson()['contractVersion'], 2);
      }
      for (final language in ['', 'EN', 'eng', 'pt-BR', 'yue', 'invalid']) {
        expect(
          () => TranscriptionRequest(
            audioUri: Uri.parse('content://qa/speech'),
            durationMs: 1000,
            language: language,
            operationId: 'invalid_language',
          ).toJson(),
          throwsFormatException,
        );
      }
    },
  );

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets(
      'speech picker searches English names in ${locale.languageCode} and disables unsupported models',
      (tester) async {
        SpeechLanguage? selected;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLanguages.supported,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    selected = await chooseSpeechLanguage(context, 'auto');
                  },
                  child: const Text('Open speech picker'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open speech picker'));
        await tester.pumpAndSettle();
        final input = find.descendant(
          of: find.byType(StudioSearchField),
          matching: find.byType(TextField),
        );
        await tester.enterText(input, 'cantonese');
        await tester.pumpAndSettle();
        expect(tester.widget<ListTile>(find.byType(ListTile)).enabled, isFalse);
        await tester.enterText(input, 'portuguese');
        await tester.pumpAndSettle();
        expect(find.byType(ListTile), findsOneWidget);
        await tester.tap(find.byType(ListTile));
        await tester.pumpAndSettle();
        expect(selected?.code, 'pt');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
