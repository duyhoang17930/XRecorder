import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/widgets/studio_widgets.dart';
import 'package:xrecorder/core/ui/theme/app_theme.dart';
import 'package:xrecorder/features/editor/editor_timeline.dart';
import 'package:xrecorder/features/editor/editor_workspace.dart';
import 'package:xrecorder/l10n/localization.dart';

void main() {
  testWidgets('video Export action adapts to narrow and wide app bars', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var exports = 0;

    for (final width in [320.0, 411.0]) {
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Project'),
              actions: [
                EditorExportAction(
                  enabled: true,
                  exporting: false,
                  onPressed: () => exports++,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (width <= 380) {
        final compact = find.byKey(const ValueKey('editor-export-compact'));
        expect(compact, findsOneWidget);
        expect(
          find.byKey(const ValueKey('editor-export-labeled')),
          findsNothing,
        );
        expect(find.text('Export'), findsNothing);
        expect(tester.getSize(compact).width, greaterThanOrEqualTo(48));
        await tester.tap(compact);
      } else {
        final labeled = find.byKey(const ValueKey('editor-export-labeled'));
        expect(labeled, findsOneWidget);
        expect(find.text('Export'), findsOneWidget);
        await tester.tap(labeled);
      }
      expect(tester.takeException(), isNull);
    }

    expect(exports, 2);
  });

  testWidgets(
    'video transport has an icon-only play action and readable time',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final position = ValueNotifier(const Duration(milliseconds: 3200));
      var toggles = 0;
      Duration? sought;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: EditorPlaybackControls(
                position: position,
                duration: const Duration(milliseconds: 14100),
                playing: false,
                onToggle: () => toggles++,
                onSeek: (value) => sought = value,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Play preview'), findsNothing);
      final play = find.byTooltip('Play preview');
      expect(play, findsOneWidget);
      expect(tester.getSize(play).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(play).height, greaterThanOrEqualTo(48));
      expect(find.text('00:00:03 / 00:00:14'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(play);
      expect(toggles, 1);
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('editor-playhead')),
      );
      slider.onChanged!(const Duration(seconds: 6).inMilliseconds.toDouble());
      expect(sought, const Duration(seconds: 6));

      await tester.pumpWidget(const SizedBox.shrink());
      position.dispose();
    },
  );

  test('editor timecode keeps hh:mm:ss for long durations', () {
    expect(formatEditorTimestamp(Duration.zero), '00:00:00');
    expect(
      formatEditorTimestamp(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '01:02:03',
    );
    expect(
      formatEditorTimestamp(const Duration(hours: 27, minutes: 4, seconds: 5)),
      '27:04:05',
    );
  });

  for (final width in [320.0, 360.0, 393.0, 411.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final landscape in [false, true]) {
        testWidgets(
          'video workspace $width scale=$scale landscape=$landscape',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = landscape
                ? Size(800, width)
                : Size(width, 800);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPhysicalSize);
            final position = ValueNotifier(Duration.zero);
            final scroll = ScrollController();
            final project = EditProject(
              id: 'layout',
              updatedAt: DateTime(2026),
              clips: [
                for (var i = 0; i < 8; i++)
                  TimelineClip(
                    mediaId: 'content://qa/$i',
                    inPoint: Duration.zero,
                    outPoint: const Duration(seconds: 5),
                    sourceDuration: const Duration(seconds: 5),
                  ),
              ],
            );
            var panel = false;
            await tester.pumpWidget(
              MaterialApp(
                theme: scale == 1.5 ? AppTheme.dark : AppTheme.light,
                locale: Locale(scale == 2 ? 'ar' : 'en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  appBar: AppBar(title: const Text('QA')),
                  body: StatefulBuilder(
                    builder: (context, update) => VideoEditorWorkspace(
                      // Layout oracle only; Android tests validate the actual native surface.
                      preview: Column(
                        children: [
                          const Expanded(
                            child: SizedBox(
                              width: double.infinity,
                              child: ColoredBox(
                                key: ValueKey('layout-surface'),
                                color: Colors.black,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: Text(context.l10n.playPreview),
                          ),
                        ],
                      ),
                      status: Text(context.l10n.savedOriginalsUnchanged),
                      transport: Column(
                        children: [
                          Text(context.l10n.playheadTime('0', '40')),
                          Slider(value: 0, onChanged: (_) {}),
                        ],
                      ),
                      timeline: EditorTimeline(
                        project: project,
                        selected: 0,
                        position: position,
                        scrollController: scroll,
                        frame: (_, _) async => null,
                        onSelect: (_) {},
                        onSeek: (_) {},
                        onTrim: (_, _) {},
                      ),
                      tools: EditorToolStrip(
                        children: [
                          EditorTool(
                            key: const ValueKey('edit-context'),
                            label: context.l10n.edit,
                            icon: AppIcons.edit,
                            selected: panel,
                            onPressed: () => update(() => panel = !panel),
                          ),
                          EditorTool(
                            label: context.l10n.editorAudio,
                            icon: AppIcons.microphone,
                            onPressed: () {},
                          ),
                          EditorTool(
                            label: context.l10n.editorTransform,
                            icon: AppIcons.crop,
                            onPressed: () {},
                          ),
                          EditorTool(
                            label: context.l10n.editorExportQuality,
                            icon: AppIcons.settings,
                            onPressed: () {},
                          ),
                        ],
                      ),
                      history: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: () {},
                            tooltip: context.l10n.undoEdit,
                            icon: const Icon(AppIcons.undo),
                          ),
                          IconButton(
                            onPressed: () {},
                            tooltip: context.l10n.redoEdit,
                            icon: const Icon(AppIcons.redo),
                          ),
                        ],
                      ),
                      contextual: !panel
                          ? null
                          : Column(
                              children: [
                                Text(context.l10n.selectedClipName('QA clip')),
                                for (var i = 0; i < 3; i++)
                                  TextButton(
                                    onPressed: () {},
                                    child: Text(context.l10n.duplicateClip),
                                  ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final trimSlider = tester.widget<RangeSlider>(
              find.byType(RangeSlider),
            );
            expect(trimSlider.values.start, lessThan(trimSlider.values.end));
            final trimTheme = tester.widget<SliderTheme>(
              find
                  .ancestor(
                    of: find.byType(RangeSlider),
                    matching: find.byType(SliderTheme),
                  )
                  .first,
            );
            expect(trimTheme.data.trackHeight, 4);
            expect(
              trimTheme.data.rangeThumbShape,
              isA<RoundRangeSliderThumbShape>(),
            );
            final surface = tester.getSize(
              find.byKey(const ValueKey('layout-surface')),
            );
            expect(surface.height, greaterThan(24));
            expect(surface.width, greaterThan(48));
            final tool = find.byKey(const ValueKey('edit-context'));
            expect(tester.getSize(tool).height, greaterThanOrEqualTo(48));
            await tester.tap(tool);
            await tester.pumpAndSettle();
            expect(tester.widget<EditorTool>(tool).selected, isTrue);
            expect(tester.takeException(), isNull);
            await tester.tap(tool);
            await tester.pumpAndSettle();
            expect(tester.widget<EditorTool>(tool).selected, isFalse);
            await tester.pumpWidget(const SizedBox.shrink());
            position.dispose();
            scroll.dispose();
          },
        );
      }
    }
  }
}
