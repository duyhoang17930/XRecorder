import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(
      AndroidRecordingService.commands,
      null,
    ),
  );
  test(
    'legacy screenshot without PNG dimensions does not invent video size',
    () {
      for (final dimensions in [
        <Object?, Object?>{},
        <Object?, Object?>{'width': 0, 'height': 0},
        <Object?, Object?>{'width': 720, 'height': -1},
      ]) {
        final session = AndroidRecordingService.decode({
          'id': 'legacy-shot',
          'state': 'completed',
          'screenshot': true,
          'outputUri': 'content://media/external/images/media/42',
          'config': {'width': 1280, 'height': 720},
          ...dimensions,
        });
        expect(session.configSnapshot.width, 0);
        expect(session.configSnapshot.height, 0);
        expect(
          session.outputUri.toString(),
          'content://media/external/images/media/42',
        );
      }
    },
  );
  test(
    'video dimensions fall back to valid root metadata if nested size is zero',
    () {
      final session = AndroidRecordingService.decode({
        'id': 'video',
        'state': 'completed',
        'width': 720,
        'height': 1280,
        'config': {'width': 0, 'height': 0},
      });
      expect(
        (session.configSnapshot.width, session.configSnapshot.height),
        (720, 1280),
      );
    },
  );

  test(
    'screenshot dimensions use captured image size rather than video defaults',
    () {
      final data = <Object?, Object?>{
        'id': 'shot',
        'state': 'completed',
        'screenshot': true,
        'width': 1440,
        'height': 3200,
        'config': {'width': 1280, 'height': 720},
      };
      final screenshot = AndroidRecordingService.decode(data);
      expect(screenshot.configSnapshot.width, 1440);
      expect(screenshot.configSnapshot.height, 3200);
      data['screenshot'] = false;
      final video = AndroidRecordingService.decode(data);
      expect(video.configSnapshot.width, 1280);
      expect(video.configSnapshot.height, 720);
    },
  );
  for (final source in AudioSource.values) {
    test(
      'audio mode ${source.name} preserves source and independent gains',
      () async {
        messenger.setMockMethodCallHandler(AndroidRecordingService.commands, (
          call,
        ) async {
          if (call.method == 'capabilities') return {'noiseReduction': false};
          final config = call.arguments as Map<Object?, Object?>;
          expect(config['audio'], source.name);
          expect(config['micGain'], 0.25);
          expect(config['internalGain'], 1.75);
          return {
            'id': 'audio-${source.name}',
            'state': 'awaitingPermission',
            'config': config,
          };
        });
        final session = await AndroidRecordingService().start(
          RecordingSettings(
            audioSource: source,
            micGain: 0.25,
            internalGain: 1.75,
          ),
        );
        expect(session.configSnapshot.audioSource, source);
        expect(session.configSnapshot.micGain, 0.25);
        expect(session.configSnapshot.internalGain, 1.75);
        expect(session.state, RecordingState.awaitingPermission);
        expect(session.outputUri, isNull);
      },
    );
  }
  test(
    'codec capabilities preserve AVC and HEVC configuration identity',
    () async {
      messenger.setMockMethodCallHandler(
        AndroidRecordingService.commands,
        (call) async => {
          'audioSources': ['mute'],
          'hevc': true,
          'presets': [
            {'width': 1280, 'height': 720, 'fps': 30, 'codec': 'avc'},
            {'width': 1920, 'height': 1080, 'fps': 60, 'codec': 'hevc'},
          ],
        },
      );
      final caps = await AndroidRecordingService().capabilities();
      expect(caps.configurations.map((c) => c.codec), [
        VideoCodec.avc,
        VideoCodec.hevc,
      ]);
      expect(caps.audioSources, {AudioSource.mute});
    },
  );

  test('start forwards quality, audio gains and existing hardware preference unchanged', () async {
    Map<Object?, Object?>? arguments;
    messenger.setMockMethodCallHandler(AndroidRecordingService.commands, (
      call,
    ) async {
      if (call.method == 'capabilities') return {'noiseReduction': true};
      expect(call.method, 'start');
      arguments = call.arguments as Map<Object?, Object?>;
      return {
        'id': 'native-session',
        'state': 'awaitingPermission',
        'config': arguments,
      };
    });
    final result = await AndroidRecordingService().start(
      const RecordingSettings(
        width: 1920,
        height: 1080,
        fps: 60,
        bitrate: 12000000,
        codec: VideoCodec.hevc,
        orientation: CaptureOrientation.landscape,
        mode: RecordingMode.normal,
        audioSource: AudioSource.mixed,
        micGain: 0.5,
        internalGain: 1.5,
        noiseReduction: true,
        hardwareEncoding: false,
      ),
    );
    expect(arguments, containsPair('width', 1920));
    expect(arguments, containsPair('height', 1080));
    expect(arguments, containsPair('fps', 60));
    expect(arguments, containsPair('bitrate', 12000000));
    expect(arguments, containsPair('codec', 'hevc'));
    expect(arguments, containsPair('orientation', 'landscape'));
    expect(arguments, containsPair('audio', 'mixed'));
    expect(arguments, containsPair('micGain', 0.5));
    expect(arguments, containsPair('internalGain', 1.5));
    expect(arguments, containsPair('hardwareEncoding', false));
    expect(result.state, RecordingState.awaitingPermission);
    expect(result.configSnapshot.hardwareEncoding, isFalse);
    expect(result.configSnapshot.noiseReduction, isTrue);
  });

  test('start passes shakeToStop and showTouches and decodes them correctly', () async {
    Map<Object?, Object?>? arguments;
    messenger.setMockMethodCallHandler(AndroidRecordingService.commands, (call) async {
      if (call.method == 'capabilities') {
        return {
          'audioSources': ['mute', 'microphone', 'internal', 'mixed'],
          'presets': [
            {'width': 1280, 'height': 720, 'fps': 30, 'codec': 'avc'},
          ],
          'noiseReduction': true,
          'hevc': true,
          'facecam': true,
        };
      }
      expect(call.method, 'start');
      arguments = call.arguments as Map<Object?, Object?>;
      return {
        'id': 'session-shake-touches',
        'state': 'awaitingPermission',
        'config': arguments,
      };
    });

    final session = await AndroidRecordingService().start(
      const RecordingSettings(
        width: 1280,
        height: 720,
        fps: 30,
        shakeToStop: true,
        showTouches: true,
      ),
    );

    expect(arguments, containsPair('shakeToStop', true));
    expect(arguments, containsPair('showTouches', true));
    expect(session.configSnapshot.shakeToStop, isTrue);
    expect(session.configSnapshot.showTouches, isTrue);
  });
}
