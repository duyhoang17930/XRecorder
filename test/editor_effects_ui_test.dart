import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/features/editor/audio_tracks_editor.dart';
import 'package:xrecorder/features/editor/layers_editor.dart';
import 'package:xrecorder/features/editor/project_effects.dart';
import 'package:xrecorder/features/editor/transcription_dialog.dart';
import 'package:xrecorder/features/editor/subtitles.dart';
import 'package:xrecorder/features/editor/transcription_service.dart';
import 'package:xrecorder/core/domain/models.dart';

void main() {
  for (final outcome in ['cancel', 'picker failure', 'import failure']) {
    testWidgets(
      'model $outcome retains previous speech result and releases the dialog',
      (tester) async {
        const editor = MethodChannel('com.xrecorder/editor');
        const media = MethodChannel('com.xrecorder/media');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        var imports = 0, cancels = 0;
        messenger.setMockMethodCallHandler(editor, (call) async {
          switch (call.method) {
            case 'transcriptionModels':
              return [
                {'id': 'base', 'installed': false},
              ];
            case 'transcriptionJobs':
              return [
                {
                  'id': 'previous',
                  'model': 'base',
                  'language': 'en',
                  'projectId': 'picker_retry',
                  'createdAt': 1,
                },
              ];
            case 'transcriptionPoll':
              return {
                'id': 'previous',
                'type': 'speech',
                'state': 'completed',
                'phase': 'completed',
                'progress': 1.0,
                'segments': [
                  {'startMs': 0, 'endMs': 1000, 'text': 'Retain this result'},
                ],
              };
            case 'transcriptionImportModel':
              imports++;
              throw PlatformException(code: 'model_install_failed');
            case 'transcriptionCancel':
              cancels++;
              return null;
            default:
              return null;
          }
        });
        messenger.setMockMethodCallHandler(media, (call) async {
          expect(call.method, 'selectModel');
          if (outcome == 'picker failure') {
            throw PlatformException(code: 'permission_denied');
          }
          return outcome == 'cancel' ? null : 'content://qa/model.bin';
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(editor, null);
          messenger.setMockMethodCallHandler(media, null);
        });
        final project = EditProject(
          id: 'picker_retry',
          updatedAt: DateTime(2026),
          clips: [
            TimelineClip(
              mediaId: 'content://qa/video',
              inPoint: Duration.zero,
              outPoint: const Duration(seconds: 4),
              sourceDuration: const Duration(seconds: 4),
            ),
          ],
        );
        SubtitleTrack? reviewed;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    reviewed = await generateSubtitles(context, project);
                  },
                  child: const Text('Open model'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open model'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Import downloaded .bin'));
        await tester.tap(find.text('Import downloaded .bin'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Close'))
              .onPressed,
          isNotNull,
        );
        expect(
          tester
              .widget<TextButton>(
                find.widgetWithText(TextButton, 'Import downloaded .bin'),
              )
              .onPressed,
          isNotNull,
        );
        expect(find.text('Cancel operation'), findsNothing);
        expect(imports, outcome == 'import failure' ? 1 : 0);
        final review = find.widgetWithText(TextButton, 'Review subtitles');
        await tester.ensureVisible(review);
        await tester.tap(review);
        await tester.pumpAndSettle();
        expect(reviewed?.cues.single.text, 'Retain this result');
        expect(cancels, 0);
        expect(project.effects, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'speech history retry saves recognized cues without repeating inference',
    (tester) async {
      const channel = MethodChannel('com.xrecorder/editor');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var saved = false, starts = 0, saves = 0;
      final project = EditProject(
        id: 'history_retry',
        updatedAt: DateTime(2026),
        clips: [
          TimelineClip(
            mediaId: 'content://qa/video',
            inPoint: Duration.zero,
            outPoint: const Duration(seconds: 4),
            sourceDuration: const Duration(seconds: 4),
          ),
        ],
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'transcriptionModels':
            return [
              {'id': 'base', 'installed': true},
            ];
          case 'transcriptionJobs':
            expect(call.arguments, {
              'projectId': project.id,
              'sourceSignature': transcriptionSourceSignature(project),
              'limit': 1,
            });
            return [
              {
                'id': 'retained',
                'projectId': project.id,
                'model': 'base',
                'language': 'vi',
                'createdAt': 1,
              },
            ];
          case 'transcriptionPoll':
            return {
              'id': 'retained',
              'type': 'speech',
              'state': 'completed',
              'phase': 'completed',
              'progress': 1.0,
              'errorCode': saved ? null : 'history_write_failed',
              'segments': [
                {
                  'startMs': 0,
                  'endMs': 1000,
                  'text': 'Unit-test retained cue 👩🏽‍💻',
                },
              ],
            };
          case 'transcriptionSaveHistory':
            saves++;
            saved = true;
            return null;
          case 'transcriptionStart':
            starts++;
            return 'unexpected';
          default:
            return null;
        }
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      SubtitleTrack? reviewed;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  reviewed = await generateSubtitles(context, project);
                },
                child: const Text('Open history'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open history'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Speech history could not be saved.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Retry saving'));
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(starts, 0);
      expect(
        find.textContaining('Speech history could not be saved.'),
        findsNothing,
      );
      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Review subtitles'),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Review subtitles'));
      await tester.pumpAndSettle();
      expect(reviewed?.cues.single.text, 'Unit-test retained cue 👩🏽‍💻');
      expect(project.effects, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unreadable speech history explains preservation and stays closable',
    (tester) async {
      const channel = MethodChannel('com.xrecorder/editor');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'transcriptionJobs') {
          throw PlatformException(code: 'history_unavailable');
        }
        if (call.method == 'transcriptionModels') {
          return [
            {'id': 'base', 'installed': true},
          ];
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final project = EditProject(
        id: 'readonly_history',
        updatedAt: DateTime(2026),
        clips: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => generateSubtitles(context, project),
                child: const Text('Open readonly'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open readonly'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Existing data was kept.'), findsOneWidget);
      expect(find.text('speech.history.unavailable'), findsNothing);
      await tester.ensureVisible(find.text('Close'));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'incompatible legacy subtitle job releases the busy UI without applying or deleting cues',
    (tester) async {
      const channel = MethodChannel('com.xrecorder/editor');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => switch (call.method) {
          'transcriptionModels' => [
            {'id': 'base', 'installed': true},
          ],
          'transcriptionJobs' => [
            {
              'id': 'old',
              'model': 'base',
              'projectId': 'trimmed',
              'createdAt': 1,
            },
          ],
          'transcriptionPoll' => {
            'id': 'old',
            'state': 'completed',
            'phase': 'completed',
            'progress': 1.0,
            'segments': [
              {
                'startMs': 3000,
                'endMs': 7000,
                'text': 'Existing job text retained',
              },
            ],
          },
          _ => null,
        },
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => generateSubtitles(
                  context,
                  EditProject(
                    id: 'trimmed',
                    updatedAt: DateTime(2026),
                    clips: [
                      TimelineClip(
                        mediaId: 'content://qa/video',
                        inPoint: Duration.zero,
                        outPoint: const Duration(seconds: 2),
                        sourceDuration: const Duration(seconds: 4),
                      ),
                    ],
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Recognize edited audio'));
      final button = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Recognize edited audio'),
          matching: find.byType(TextButton),
        ),
      );
      expect(button.onPressed, isNotNull);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  for (final restore in [false, true]) {
    testWidgets(
      restore
          ? 'restored speech job retains model and language'
          : 'speech setup uses an installed model before proposing a download',
      (tester) async {
        const channel = MethodChannel('com.xrecorder/editor');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          channel,
          (call) async => switch (call.method) {
            'transcriptionModels' => [
              {'id': 'tiny', 'installed': true},
              {'id': 'base', 'installed': false},
            ],
            'transcriptionJobs' =>
              restore
                  ? [
                      {
                        'id': 'restored',
                        'model': 'base',
                        'language': 'en',
                        'projectId': 'restore_qa',
                        'createdAt': 1,
                      },
                    ]
                  : [],
            'transcriptionPoll' => {
              'id': 'restored',
              'state': 'completed',
              'phase': 'completed',
              'progress': 1.0,
              'segments': [],
            },
            _ => null,
          },
        );
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final project = EditProject(
          id: 'restore_qa',
          updatedAt: DateTime(2026),
          clips: [
            TimelineClip(
              mediaId: 'content://qa/video',
              inPoint: Duration.zero,
              outPoint: const Duration(seconds: 4),
              sourceDuration: const Duration(seconds: 4),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => generateSubtitles(context, project),
                  child: const Text('Open subtitles'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open subtitles'));
        await tester.pumpAndSettle();
        final fields = find.byType(DropdownButtonFormField<String>);
        expect(
          tester.state<FormFieldState<String>>(fields.at(0)).value,
          restore ? 'base' : 'tiny',
        );
        expect(fields, findsOneWidget);
        expect(find.text(restore ? 'English' : 'Auto Detect'), findsOneWidget);
        await tester.ensureVisible(find.text('Close'));
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'recognize-anyway retries the real request contract and still requires review',
    (tester) async {
      const channel = MethodChannel('com.xrecorder/editor');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      Map<Object?, Object?>? request;
      var applied = false;
      final project = EditProject(
        id: 'quiet_voice_review',
        updatedAt: DateTime(2026),
        clips: [
          TimelineClip(
            mediaId: 'content://qa/quiet_voice',
            inPoint: Duration.zero,
            outPoint: const Duration(seconds: 4),
            sourceDuration: const Duration(seconds: 4),
          ),
        ],
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        return switch (call.method) {
          'transcriptionModels' => [
            {'id': 'base', 'installed': true},
          ],
          'transcriptionAvailability' => 'onDevice',
          'transcriptionJobs' => [
            {
              'id': 'quiet_before',
              'type': 'speech',
              'model': 'base',
              'language': 'vi',
              'projectId': project.id,
              'createdAt': 1,
            },
          ],
          'transcriptionPoll' => {
            'id': call.arguments,
            'type': 'speech',
            'state': 'completed',
            'phase': 'completed',
            'progress': 1.0,
            'noSpeechDetected': true,
            'allowUncertainSpeech': call.arguments == 'quiet_retry',
            'speechActivity': {
              'max': .325,
              'observedFrames': 590,
              'noClearSpeech': true,
            },
            'segments': call.arguments == 'quiet_retry'
                ? [
                    {
                      'startMs': 0,
                      'endMs': 1000,
                      'text': 'Test-only mock voice',
                    },
                  ]
                : [],
          },
          'transcriptionStart' => () {
            request = (call.arguments as Map).cast<Object?, Object?>();
            return 'quiet_retry';
          }(),
          _ => null,
        };
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  applied = await generateSubtitles(context, project) != null;
                },
                child: const Text('Open quiet speech'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open quiet speech'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Recognize anyway'));
      await tester.tap(find.text('Recognize anyway'));
      await tester.pumpAndSettle();
      expect(request?['allowUncertainSpeech'], isTrue);
      expect(request?['language'], 'vi');
      expect(request?['model'], 'base');
      expect(
        applied,
        isFalse,
        reason: 'Recognition does not apply subtitles without a review action',
      );
      await tester.ensureVisible(find.text('Close'));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(applied, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 411.0]) {
    testWidgets('audio/layers/effects remain usable at $width and text200', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      Future<void> open(
        String label,
        Future<Object?> Function(BuildContext) dialog,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => dialog(context),
                  child: Text(label),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await open(
        'Audio',
        (context) => editAudioTracks(context, [
          {
            'uri': 'content://qa/audio',
            'sourceDurationMs': 4000,
            'inMs': 0,
            'outMs': 3000,
            'offsetMs': 500,
            'volume': .5,
          },
        ], 4000),
      );
      await tester.ensureVisible(find.text('Track 1'));
      await tester.tap(find.text('Track 1'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Use audio'));
      await tester.tap(find.text('Use audio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use tracks'));
      await tester.pumpAndSettle();
      await open(
        'Layers',
        (context) => editLayers(context, [
          {
            'kind': 'text',
            'text': 'Xin chào Việt Nam',
            'startMs': 0,
            'endMs': 4000,
          },
        ], 4000),
      );
      await tester.ensureVisible(find.text('1. Text'));
      await tester.tap(find.text('1. Text'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Use layer'));
      await tester.tap(find.text('Use layer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use layers'));
      await tester.pumpAndSettle();
      await open(
        'Effects',
        (context) => editProjectEffects(context, {}, durationMs: 4000),
      );
      await tester.ensureVisible(find.text('Apply to project'));
      await tester.tap(find.text('Apply to project'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      const channel = MethodChannel('com.xrecorder/editor');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => switch (call.method) {
              'transcriptionModels' => [
                {'id': 'tiny', 'installed': false, 'bytes': 77691713},
              ],
              'transcriptionJobs' => <Object>[],
              _ => null,
            },
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await open(
        'ASR',
        (context) => generateSubtitles(
          context,
          EditProject(
            id: 'ui_qa',
            updatedAt: DateTime(2026),
            clips: [
              TimelineClip(
                mediaId: 'content://qa/video',
                inPoint: Duration.zero,
                outPoint: const Duration(seconds: 4),
                sourceDuration: const Duration(seconds: 4),
              ),
            ],
          ),
        ),
      );
      expect(find.text('Download model'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
