import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/features/editor/timeline_effects.dart';

void main() {
  test('trim and alignment constrain fades to the actual output range', () {
    const track = AudioTrack(
      uri: 'content://test/audio',
      sourceDurationMs: 10000,
      inMs: 1000,
      outMs: 5000,
      offsetMs: 2000,
      fadeInMs: 500,
      fadeOutMs: 500,
      volume: .75,
      voice: 'robot',
      noiseReduction: true,
    );
    track.validate(6000);
    final restored = AudioTrack.fromJson(track.toJson());
    expect(restored.toJson(), track.toJson());
    expect(() => track.validate(2500), throwsFormatException);
    expect(() => track.validate(2000), throwsFormatException);
  });
  test(
    'reject unreadable schemes, invalid gains and invalid source ranges',
    () {
      for (final track in [
        const AudioTrack(
          uri: 'file:///audio',
          sourceDurationMs: 1000,
          outMs: 1000,
        ),
        const AudioTrack(
          uri: 'content://a',
          sourceDurationMs: 1000,
          outMs: 2000,
        ),
        const AudioTrack(
          uri: 'content://a',
          sourceDurationMs: 1000,
          outMs: 1000,
          volume: double.nan,
        ),
        const AudioTrack(
          uri: 'content://a',
          sourceDurationMs: 1000,
          outMs: 1000,
          fadeInMs: 600,
          fadeOutMs: 600,
        ),
      ]) {
        expect(() => track.validate(3000), throwsFormatException);
      }
    },
  );
  test(
    'layer duration and drawing coordinates survive JSON and reject corruption',
    () {
      final layer = <String, Object>{
        'kind': 'drawing',
        'startMs': 0,
        'endMs': 2000,
        'x': .3,
        'y': .8,
        'scale': .5,
        'rotation': 45,
        'points': [
          [0.0, 0.0],
          [1.0, 1.0],
          null,
          [.5, .5],
        ],
      };
      validateLayer(layer, 3000);
      expect(
        () => validateLayer({...layer, 'endMs': 4000}, 3000),
        throwsFormatException,
      );
      expect(
        () => validateLayer({
          ...layer,
          'points': [
            [2, 0],
            [0, 0],
          ],
        }, 3000),
        throwsFormatException,
      );
      expect(
        () => validateLayer({...layer, 'scale': double.infinity}, 3000),
        throwsFormatException,
      );
    },
  );
}
