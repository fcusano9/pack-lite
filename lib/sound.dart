import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// App sound effects, bundled WAVs on a small player pool.
///
/// Explicitly routed to the MEDIA stream on Android (usage: media, no audio
/// focus) so playback follows media volume and is never gated by the
/// system "touch sounds" setting.
class SoundEffects {
  static final List<AudioPlayer> _pool = [];
  static AudioPlayer? _big;
  static bool _ready = false;

  static Future<void> init() async {
    try {
      final audioContext = AudioContext(
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
      for (var index = 0; index < 3; index++) {
        final player = AudioPlayer();
        await player.setAudioContext(audioContext);
        await player.setReleaseMode(ReleaseMode.stop);
        _pool.add(player);
      }
      _big = AudioPlayer();
      await _big!.setAudioContext(audioContext);
      await _big!.setReleaseMode(ReleaseMode.stop);
      _ready = true;
    } catch (e) {
      debugPrint('SoundEffects init failed: $e');
    }
  }

  static int _next = 0;

  static void pop() {
    if (!_ready) return;
    final player = _pool[_next++ % _pool.length];
    player.stop();
    player.play(AssetSource('sounds/pop.wav'), volume: 0.9);
  }

  static void popBig() {
    if (!_ready) return;
    _big?.stop();
    _big?.play(AssetSource('sounds/pop_big.wav'), volume: 1.0);
  }
}
