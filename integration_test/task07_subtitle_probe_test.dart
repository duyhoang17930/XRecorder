import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'subtitle renderer resize and native grapheme transport are stable',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Native subtitle verification')),
        ),
      );
      final chunkText = '${List.filled(239, 'a').join()}👩🏽‍💻é終';
      final result = (await const MethodChannel('com.xrecorder/editor')
          .invokeMapMethod<String, dynamic>('subtitleDiagnostics', {
            'text': 'Unicode العربية हिन्दी 日本語 👩🏽‍💻',
            'chunkText': chunkText,
            'glyphClusters': [
              'a',
              'ế',
              '中',
              '字',
              'あ',
              '한',
              'क',
              'क्ष',
              'ع',
              'ي',
              '👩🏽‍💻',
              '👨‍👩‍👧‍👦',
              'é',
            ],
          }))!;
      final path = const bool.fromEnvironment('QA_PRIVATE_FIXTURES')
          ? '/data/user/0/com.xrecorder.xrecorder/files/trash/task07_probe_${DateTime.now().microsecondsSinceEpoch}/'
          : '/sdcard/Android/data/com.xrecorder.xrecorder/files/media/';
      await Directory(path).create(recursive: true);
      for (final name in ['first', 'reused', 'fresh']) {
        await File('${path}task07_subtitle_$name.png')
            .writeAsBytes(result[name] as Uint8List);
      }
      final cacheEquivalent = listEquals(
        result['reused'] as Uint8List,
        result['fresh'] as Uint8List,
      );
      final chunks = (result['chunks'] as List).cast<String>();
      final roundTrip = chunks.join() == chunkText;
      binding.reportData = {
        'cacheEquivalent': cacheEquivalent,
        'graphemeRoundTrip': roundTrip,
        'chunks': chunks,
        'glyphs': result['glyphs'],
        'pngDirectory': path,
        'pngFiles': [
          'task07_subtitle_first.png',
          'task07_subtitle_reused.png',
          'task07_subtitle_fresh.png',
        ],
      };
      expect(
        cacheEquivalent,
        isTrue,
        reason: 'Same-width height changes must rebuild the subtitle layout',
      );
      expect(
        roundTrip,
        isTrue,
        reason: 'Native serialization must not replace split surrogate pairs with question marks',
      );
      expect(
        (result['glyphs'] as List).cast<Map>().every(
          (row) => row['supported'] == true,
        ),
        isTrue,
        reason:
            'Every declared script/emoji probe must have a real system glyph.',
      );
    },
  );
}
