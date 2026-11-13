import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/features/editor/project_effects.dart';
import 'package:xrecorder/features/editor/editor_workspace.dart';
import 'package:xrecorder/features/media/photo_tools_screen.dart';
import 'package:xrecorder/features/media/photo_editor_panels.dart';
import 'package:xrecorder/l10n/localization.dart';

import 'fixtures/visual_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('com.xrecorder/media');
  Future<void> photo(
    WidgetTester tester, {
    Size size = const Size(411, 920),
    double scale = 1,
    bool dark = false,
    bool rtl = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final bytes = (await tester.runAsync(fixtureImage))!;
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'decodePhoto' ? bytes : null,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        locale: Locale(rtl ? 'ar' : 'en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: scale == 1.5,
          ),
          child: child!,
        ),
        home: const PhotoToolsScreen(uri: 'content://qa/hci'),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pumpAndSettle();
  }

  Finder key(String name) => find.byKey(
    ValueKey(name == 'photo-tool-eraser' ? 'photo-context-eraser' : name),
  );
  bool selectedTool(WidgetTester tester, Finder finder) =>
      switch (tester.widget(finder)) {
        EditorTool(:final selected) => selected,
        ChoiceChip(:final selected) => selected,
        _ => throw StateError('Unexpected tool presentation'),
      };
  Finder getCanvas() => find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is PhotoPainter,
  );
  PhotoPainter painter(WidgetTester tester) =>
      tester.widget<CustomPaint>(getCanvas()).painter! as PhotoPainter;
  Future<void> tool(WidgetTester tester, String name) async {
    if (name == 'eraser') await tool(tester, 'pen');
    final control = key('photo-tool-$name');
    await tester.ensureVisible(control);
    await tester.tap(control);
    await tester.pumpAndSettle();
  }

  Future<void> draw(WidgetTester tester) async {
    final rect = tester.getRect(getCanvas());
    await tester.dragFrom(
      rect.center - Offset(rect.width * .2, 0),
      Offset(rect.width * .3, 5),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('short RTL landscape retains canvas and reachable tools', (
    tester,
  ) async {
    await photo(tester, size: const Size(800, 320), scale: 2, rtl: true);
    // Match Android status/gesture insets; a zero-inset desktop fixture leaves
    // more height and did not exercise the device's short-workspace fallback.
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await tester.pumpAndSettle();
    expect(getCanvas(), findsOneWidget);
    final image = painter(tester).image;
    expect(key('photo-tool-text'), findsOneWidget);
    await tool(tester, 'text');
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Short viewport');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    expect(selectedTool(tester, key('photo-tool-text')), isTrue);
    expect(identical(painter(tester).image, image), isTrue);
    expect(painter(tester).marks, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accessibility changes retain manually scrolled photo tools', (
    tester,
  ) async {
    await photo(tester, size: const Size(360, 800), scale: 1.5);
    final strip = find.ancestor(
      of: key('photo-tool-text'),
      matching: find.byType(SingleChildScrollView),
    );
    final scrollable = find.descendant(
      of: strip,
      matching: find.byType(Scrollable),
    );
    await tester.drag(strip, const Offset(-240, 0));
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(scrollable).position;
    final before = position.pixels;
    expect(before, greaterThan(80));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(before, .1));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(before, .1));
    await tester.tap(key('photo-tool-text'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(selectedTool(tester, key('photo-tool-text')), isTrue);
    expect(painter(tester).marks, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'photo contextual controls retain color, drawing and undo across panels',
    (tester) async {
      await photo(tester);
      expect(find.text('Yellow ink'), findsNothing);
      await tester.tap(key('photo-current-color'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yellow ink'));
      await tester.pumpAndSettle();
      await draw(tester);
      expect(painter(tester).marks.single.color, Colors.yellow);
      final points = List.of(painter(tester).marks.single.points);
      await tester.tap(key('photo-current-color'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(painter(tester).marks.single.points, points);
      await tool(tester, 'eraser');
      expect(find.byType(Slider), findsNothing);
      expect(key('photo-current-color'), findsNothing);
      await tool(tester, 'text');
      expect(find.byType(Slider), findsNothing);
      await tester.enterText(find.byType(TextField), 'A real annotation');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await draw(tester);
      expect(painter(tester).marks.last.text, 'A real annotation');
      expect(painter(tester).marks.last.color, Colors.yellow);
      await tester.tap(find.byTooltip('Undo photo edit'));
      await tester.pumpAndSettle();
      expect(painter(tester).marks.length, 1);
      await tester.tap(find.byTooltip('Redo photo edit'));
      await tester.pumpAndSettle();
      expect(painter(tester).marks.length, 2);
      final image = painter(tester).image;
      final retained = painter(tester).marks
          .map((mark) => List.of(mark.points))
          .toList();
      tester.view.physicalSize = const Size(920, 411);
      await tester.pumpAndSettle();
      expect(identical(painter(tester).image, image), isTrue);
      expect(
        painter(tester).marks.map((mark) => mark.points).toList(),
        retained,
      );
      tester.view.physicalSize = const Size(411, 920);
      await tester.pumpAndSettle();
      expect(painter(tester).marks.length, 2);
      await tool(tester, 'crop');
      expect(find.byType(RangeSlider), findsNWidgets(2));
      final crop = tester.widget<RangeSlider>(key('photo-crop-horizontal'));
      crop.onChangeStart!(crop.values);
      crop.onChanged!(const RangeValues(.1, .9));
      await tester.pump();
      await tester.tap(find.byTooltip('Undo photo edit'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<RangeSlider>(key('photo-crop-horizontal')).values,
        const RangeValues(0, 1),
      );
      expect(painter(tester).marks.length, 2);
    },
  );

  testWidgets(
    'tool pickers preserve edits on Back and agree on selected shape',
    (tester) async {
      await photo(tester);
      await draw(tester);
      final points = List.of(painter(tester).marks.single.points);
      await tester.tap(find.byTooltip('All tools'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ListTile>(find.widgetWithText(ListTile, 'Pen')).selected,
        isTrue,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(painter(tester).marks.single.points, points);
      expect(selectedTool(tester, key('photo-tool-pen')), isTrue);
      await tester.tap(find.byTooltip('All tools'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Circle'));
      await tester.pumpAndSettle();
      await tester.tap(key('photo-tool-shapes'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Circle'))
            .selected,
        isTrue,
      );
      await tester.tap(find.widgetWithText(ListTile, 'Arrow'));
      await tester.pumpAndSettle();
      await draw(tester);
      expect(painter(tester).marks.last.tool, 'Arrow');
      expect(painter(tester).marks.first.points, points);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('photo text remains editable with a landscape keyboard', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await photo(tester, size: const Size(920, 411));
    await tool(tester, 'text');
    await tester.enterText(find.byType(TextField), 'Retained text');
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Retained text',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Retained text',
    );
  });

  testWidgets('Text Apply places a reversible mark without a hidden gesture', (
    tester,
  ) async {
    await photo(tester);
    await tool(tester, 'text');
    await tester.enterText(find.byType(TextField), 'UI06 text');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final apply = find.widgetWithText(TextButton, 'Apply');
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(painter(tester).marks.single.text, 'UI06 text');
    expect(painter(tester).marks.single.points, [const Offset(.5, .5)]);
    await tester.tap(find.byTooltip('Undo photo edit'));
    await tester.pumpAndSettle();
    expect(painter(tester).marks, isEmpty);
    await tester.tap(find.byTooltip('Redo photo edit'));
    await tester.pumpAndSettle();
    expect(painter(tester).marks.single.text, 'UI06 text');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('selected tool remains visible after viewport rotation', (
    tester,
  ) async {
    await photo(tester);
    await tool(tester, 'crop');
    for (final size in [const Size(920, 411), const Size(411, 920)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      final selected = key('photo-tool-crop');
      final scroll = find
          .ancestor(of: selected, matching: find.byType(SingleChildScrollView))
          .first;
      final viewport = tester.getRect(scroll);
      final bounds = tester.getRect(selected);
      expect(bounds.left, greaterThanOrEqualTo(viewport.left));
      expect(bounds.right, lessThanOrEqualTo(viewport.right));
      expect(selectedTool(tester, selected), isTrue);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pointer samples repaint the canvas without rebuilding tools', (
    tester,
  ) async {
    await photo(tester);
    final rect = tester.getRect(getCanvas());
    final gesture = await tester.startGesture(
      rect.center - const Offset(40, 0),
    );
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();
    final button = tester.widget(key('photo-tool-pen'));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(2, 1));
      await tester.pump();
      expect(identical(tester.widget(key('photo-tool-pen')), button), isTrue);
    }
    await gesture.up();
    expect(painter(tester).marks.single.points.length, greaterThan(15));
  });

  testWidgets(
    'stroke and crop inputs stay valid at endpoints and invalid samples',
    (tester) async {
      await photo(tester);
      for (final value in [
        .002,
        .020000000000000004,
        double.nan,
        double.infinity,
        -.1,
        .01,
      ]) {
        tester.widget<Slider>(key('photo-stroke-width')).onChanged!(value);
        await tester.pump();
        expect(
          tester.widget<Slider>(key('photo-stroke-width')).value,
          inInclusiveRange(.002, .02),
        );
        expect(tester.takeException(), isNull);
      }
      await tool(tester, 'crop');
      for (final value in [
        const RangeValues(-1, 2),
        const RangeValues(.5, .5),
        const RangeValues(double.nan, 1),
      ]) {
        tester.widget<RangeSlider>(key('photo-crop-horizontal')).onChanged!(
          value,
        );
        await tester.pump();
        final actual = tester
            .widget<RangeSlider>(key('photo-crop-horizontal'))
            .values;
        expect(actual.start, inInclusiveRange(0, 1));
        expect(actual.end - actual.start, greaterThanOrEqualTo(.02));
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final width in [320.0, 360.0, 393.0, 411.0]) {
    for (final landscape in [false, true]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('photo editor $width landscape=$landscape scale=$scale', (
          tester,
        ) async {
          final size = landscape ? Size(920, width) : Size(width, 920);
          await photo(
            tester,
            size: size,
            scale: scale,
            dark: landscape,
            rtl: scale == 2,
          );
          final strings = tester.element(find.byType(PhotoToolsScreen)).l10n;
          final save = find.widgetWithText(FilledButton, strings.saveCopy);
          expect(tester.getRect(save).bottom, lessThanOrEqualTo(size.height));
          expect(tester.getRect(save).height, greaterThanOrEqualTo(48));
          final canvas = tester.getSize(getCanvas());
          expect(canvas.height, greaterThan(24));
          expect(
            canvas.width / canvas.height,
            closeTo(
              painter(tester).image.width / painter(tester).image.height,
              .001,
            ),
          );
          for (final name in ['crop', 'transform', 'pen', 'text', 'eraser']) {
            await tool(tester, name);
            expect(selectedTool(tester, key('photo-tool-$name')), isTrue);
            expect(tester.takeException(), isNull);
          }
          await tester.tap(find.byTooltip(strings.editorExportQuality));
          await tester.pumpAndSettle();
          expect(
            find.text(strings.editAnSrgbCopyWithOrientationApplied),
            findsOneWidget,
          );
          final cancel = find.text(strings.cancel);
          await tester.ensureVisible(cancel);
          await tester.tap(cancel);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tool(tester, 'pen');
          await tester.tap(key('photo-current-color'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final close = find.text(strings.close);
          await tester.ensureVisible(close);
          await tester.tap(close);
          await tester.pumpAndSettle();
          expect(selectedTool(tester, key('photo-tool-pen')), isTrue);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  testWidgets(
    'effects cancel is isolated; apply retains unknown values and retimes cues',
    (tester) async {
      final current = <String, Object>{
        'speed': 1.0,
        'vendor': {'keep': true},
        'subtitles': [
          {'startMs': 0, 'endMs': 4000, 'text': 'Keep timed text'},
        ],
      };
      final before = jsonEncode(current);
      Map<String, Object>? output;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => output = await editProjectEffects(
                  context,
                  current,
                  durationMs: 4000,
                ),
                child: const Text('Open effects'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open effects'));
      await tester.pumpAndSettle();
      await tester.tap(key('effect-speed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(output, isNull);
      expect(jsonEncode(current), before);
      await tester.tap(find.text('Open effects'));
      await tester.pumpAndSettle();
      await tester.tap(key('effect-speed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply to project'));
      await tester.pumpAndSettle();
      expect(output!['speed'], 2);
      expect((output!['subtitles'] as List).single['endMs'], 2000);
      expect(output!['vendor'], current['vendor']);
      expect(jsonEncode(current), before);
    },
  );

  testWidgets(
    'photo output options cancel does not apply, apply preserves the selected contract',
    (tester) async {
      const initial = (format: 'png', maxEdge: 2048, quality: 95);
      PhotoExportOptions? output;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    output = await editPhotoExportOptions(context, initial),
                child: const Text('Output'),
              ),
            ),
          ),
        ),
      );
      Future<void> jpeg() async {
        await tester.tap(find.text('Output'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('JPEG · smaller file').last);
        await tester.pumpAndSettle();
      }

      await jpeg();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(output, isNull);
      await jpeg();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(output, (format: 'jpeg', maxEdge: 2048, quality: 95));
      expect(initial.format, 'png');
    },
  );

  for (final width in [320.0, 360.0, 393.0, 411.0]) {
    for (final landscape in [false, true]) {
      testWidgets(
        'effects categories stay reachable $width landscape=$landscape text200 RTL',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = landscape
              ? Size(920, width)
              : Size(width, 920);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: landscape ? AppTheme.dark : AppTheme.light,
              locale: const Locale('ar'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () =>
                        editProjectEffects(context, {}, durationMs: 4000),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          for (var section = 0; section < 5; section++) {
            final category = key('effects-section-$section');
            await tester.ensureVisible(category);
            await tester.pumpAndSettle();
            await tester.tap(category);
            await tester.pumpAndSettle();
            final chip = tester.widget<ChoiceChip>(category);
            expect(chip.selected, isTrue);
            expect(
              chip.chipAnimationStyle!.selectAnimation!.duration,
              Duration.zero,
            );
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
