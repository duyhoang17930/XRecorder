import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/persistence/settings_store.dart';
import 'package:xrecorder/features/editor/transcription_dialog.dart';
import 'package:xrecorder/features/editor/subtitles.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/l10n/localization.dart';

class _MemoryStore implements SettingsStore {
  String? document;

  @override
  Future<String?> read() async => document;

  @override
  Future<void> write(String document) async => this.document = document;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const editor = MethodChannel('com.xrecorder/editor');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late bool modelInstalled;
  late int deleteRequests;

  setUp(() {
    modelInstalled = true;
    deleteRequests = 0;
    messenger.setMockMethodCallHandler(editor, (call) async {
      switch (call.method) {
        case 'transcriptionModels':
          return [
            {
              'id': 'tiny',
              'bytes': 77691713,
              'installed': modelInstalled,
              'multilingual': true,
              'supportedLanguageCount': 99,
            },
            {
              'id': 'base',
              'bytes': 147951465,
              'installed': true,
              'multilingual': true,
              'supportedLanguageCount': 99,
            },
          ];
        case 'transcriptionJobs':
          return <Object>[];
        case 'transcriptionDeleteModel':
          deleteRequests++;
          modelInstalled = false;
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(editor, null));

  final project = EditProject(
    id: 'subtitle-model-safety',
    clips: [
      TimelineClip(
        mediaId: 'content://fixture/video',
        title: 'Fixture',
        inPoint: Duration.zero,
        outPoint: const Duration(seconds: 5),
        sourceDuration: const Duration(seconds: 5),
      ),
    ],
    updatedAt: DateTime(2026),
  );

  testWidgets('model removal waits for explicit confirmation', (tester) async {
    final settings = SettingsController();
    addTearDown(settings.dispose);

    Future<SubtitleTrack?>? result;
    await tester.pumpWidget(
      SettingsScope(
        controller: settings,
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  result = generateSubtitles(context, project);
                },
                child: const Text('Open subtitles'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open subtitles'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove downloaded model'));
    await tester.pumpAndSettle();

    expect(deleteRequests, 0);
    expect(modelInstalled, isTrue);
    expect(
      find.text(
        'Remove this speech model from 3HRecorder? '
        'You can import it again later.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deleteRequests, 0);
    expect(modelInstalled, isTrue);

    await tester.tap(find.text('Remove downloaded model'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove downloaded model').last);
    await tester.pumpAndSettle();
    expect(deleteRequests, 1);
    expect(modelInstalled, isFalse);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await result;
  });

  testWidgets('selected model persists when the subtitle dialog is reopened', (
    tester,
  ) async {
    final store = _MemoryStore();
    var settings = SettingsController(store: store);
    await settings.restore();
    addTearDown(() => settings.dispose());

    Future<SubtitleTrack?>? result;
    Widget host() => SettingsScope(
      controller: settings,
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                result = generateSubtitles(context, project);
              },
              child: const Text('Open subtitles'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(host());

    await tester.tap(find.text('Open subtitles'));
    await tester.pumpAndSettle();
    var modelPicker = find.byType(DropdownButtonFormField<String>);
    expect(
      tester.widget<DropdownButtonFormField<String>>(modelPicker).initialValue,
      'base',
    );
    await tester.tap(modelPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fast · tiny · 74 MiB').last);
    await tester.pumpAndSettle();
    expect(settings.preferredSpeechModel, 'tiny');
    await settings.flushed;
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await result;

    settings.dispose();
    settings = SettingsController(store: store);
    await settings.restore();
    expect(settings.preferredSpeechModel, 'tiny');
    await tester.pumpWidget(host());
    await tester.tap(find.text('Open subtitles'));
    await tester.pumpAndSettle();
    modelPicker = find.byType(DropdownButtonFormField<String>);
    expect(
      tester.widget<DropdownButtonFormField<String>>(modelPicker).initialValue,
      'tiny',
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });
}
