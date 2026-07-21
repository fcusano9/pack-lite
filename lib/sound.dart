import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// App sound effects, bundled WAVs on a small player pool.
///
/// Explicitly routed to the MEDIA stream on Android (usage: media, no audio
/// focus) so playback follows media volume and is never gated by the
/// system "touch sounds" setting.
class Sfx {
  static final List<AudioPlayer> _pool = [];
  static AudioPlayer? _big;
  static bool _ready = false;

  static Future<void> init() async {
    try {
      final ctx = AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {},
        ),
      );
      for (var k = 0; k < 3; k++) {
        final p = AudioPlayer();
        await p.setAudioContext(ctx);
        await p.setReleaseMode(ReleaseMode.stop);
        _pool.add(p);
      }
      _big = AudioPlayer();
      await _big!.setAudioContext(ctx);
      await _big!.setReleaseMode(ReleaseMode.stop);
      _ready = true;
    } catch (e) {
      debugPrint('Sfx init failed: $e');
    }
  }

  static int _next = 0;

  static void pop() {
    if (!_ready) return;
    final p = _pool[_next++ % _pool.length];
    p.stop();
    p.play(AssetSource('sounds/pop.wav'), volume: 0.9);
  }

  static void popBig() {
    if (!_ready) return;
    _big?.stop();
    _big?.play(AssetSource('sounds/pop_big.wav'), volume: 1.0);
  }
}
