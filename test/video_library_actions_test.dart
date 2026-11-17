import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_actions.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

import 'fixtures/catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  Completer<String?>? response;
  EditProject? saved;
  setUp(() {
    calls.clear();
    saved = null;
    response = null;
    messenger.setMockMethodCallHandler(AndroidMediaActions.channel, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'openVideo' || call.method == 'videoOptions') {
        return response?.future;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      AndroidRecordingService.commands,
      (_) async => false,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.xrecorder/capture/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(AndroidEditProjectRepository.channel, (
      call,
    ) async {
      if (call.method == 'save') {
        saved = EditProject.fromJson(jsonDecode(call.arguments as String));
      }
      if (call.method == 'list') return <String>[];
      if (call.method == 'find') return jsonEncode(saved!.toJson());
      return null;
    });
  });
  tearDown(() {
    for (final channel in [
      AndroidMediaActions.channel,
      AndroidRecordingService.commands,
      const MethodChannel('com.xrecorder/capture/events'),
      AndroidEditProjectRepository.channel,
    ]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets(
    'card opens player directly; overflow opens shared menu; returning keeps list position',
    (tester) async {
      final catalog = TestCatalog();
      await tester.pumpWidget(XRecorderApp(mediaRepository: catalog));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Clip 0.mp4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clip 0.mp4'));
      await tester.pumpAndSettle();
      expect(calls.last.method, 'openVideo');
      expect(calls.last.arguments, {'uri': 'content://test/0'});
      expect(find.text('Media details'), findsNothing);
      final scroll = tester.state<ScrollableState>(
        find
            .ancestor(
              of: find.text('Clip 0.mp4'),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final offset = scroll.position.pixels;
      await tester.tap(find.byTooltip('Actions for Clip 0.mp4'));
      await tester.pumpAndSettle();
      expect(calls.last.method, 'videoOptions');
      // The native sheet follows the in-app theme.
      expect(calls.last.arguments, {'uri': 'content://test/0', 'dark': true});
      expect(scroll.position.pixels, offset);
      expect(find.text('Media details'), findsNothing);
      expect(saved, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      catalog.dispose();
    },
  );

  testWidgets(
    'edit from either menu resolves current URI and creates an editor project',
    (tester) async {
      final catalog = TestCatalog();
      final renamed = MediaItem(
        id: 'content://test/renamed',
        uri: Uri.parse('content://test/renamed'),
        kind: MediaKind.video,
        displayName: 'Renamed.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 2048,
        createdAt: DateTime(2026),
        modifiedAt: DateTime(2026),
        source: MediaSource.recording,
        duration: const Duration(seconds: 10),
      );
      catalog.items.add(renamed);
      response = Completer<String?>();
      await tester.pumpWidget(XRecorderApp(mediaRepository: catalog));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Clip 0.mp4'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Actions for Clip 0.mp4'));
      await tester.pump();
      expect(saved, isNull);
      response!.complete(renamed.id);
      await tester.pumpAndSettle();
      expect(saved?.title, 'Renamed.mp4');
      expect(saved?.clips.single.mediaId, renamed.uri.toString());
      expect(saved?.clips.single.duration, const Duration(seconds: 10));
      await tester.pumpWidget(const SizedBox.shrink());
      catalog.dispose();
    },
  );
}
