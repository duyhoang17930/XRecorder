import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/widgets/studio_shell.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

import 'fixtures/catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final orientationRequests = <List<Object?>>[];

  setUp(() {
    orientationRequests.clear();
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        orientationRequests.add(List<Object?>.from(call.arguments as List));
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      AndroidRecordingService.commands,
      (call) async => call.method == 'overlayPermissionStatus'
          ? false
          : {'id': '', 'state': 'idle'},
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.xrecorder/capture/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.xrecorder/media'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(AndroidEditProjectRepository.channel, (
      call,
    ) async {
      if (call.method == 'list') return <String>[];
      if (call.method == 'find') {
        return jsonEncode(
          EditProject(
            id: call.arguments as String,
            title: 'QA draft',
            updatedAt: DateTime(2026),
            clips: [],
          ).toJson(),
        );
      }
      return null;
    });
  });

  tearDown(() {
    for (final channel in [
      SystemChannels.platform,
      AndroidRecordingService.commands,
      const MethodChannel('com.xrecorder/capture/events'),
      const MethodChannel('com.xrecorder/media'),
      AndroidEditProjectRepository.channel,
    ]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets(
    'main tabs/Create lock portrait; actual viewer/editor release the lock',
    (tester) async {
      await tester.pumpWidget(XRecorderApp(mediaRepository: TestCatalog()));
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(StudioShell)));
      try {
        expect(orientationRequests.last, ['DeviceOrientation.portraitUp']);
        for (final tab in {
          'Photo': '/photos',
          'Edit': '/editor',
          'Settings': '/settings',
          'Video': '/videos',
        }.entries) {
          await tester.tap(find.text(tab.key).last);
          await tester.pumpAndSettle();
          expect(
            router.routerDelegate.currentConfiguration.uri.path,
            tab.value,
          );
          expect(orientationRequests.last, ['DeviceOrientation.portraitUp']);
        }
        await tester.tap(find.byTooltip('Create'));
        await tester.pumpAndSettle();
        expect(router.routerDelegate.currentConfiguration.uri.path, '/videos');
        expect(orientationRequests.last, ['DeviceOrientation.portraitUp']);
        await tester.tap(find.byTooltip('Close').last);
        await tester.pumpAndSettle();
        router.go('/media/${Uri.encodeComponent('content://test/0')}');
        await tester.pumpAndSettle();
        expect(orientationRequests.last, isEmpty);
        expect(find.text('Clip 0.mp4'), findsOneWidget);
        router.go('/editor/project/qa');
        await tester.pumpAndSettle();
        expect(orientationRequests.last, isEmpty);
        router.go('/videos');
        await tester.pumpAndSettle();
        expect(orientationRequests.last, ['DeviceOrientation.portraitUp']);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
      expect(orientationRequests.last, isEmpty);
    },
  );
}
