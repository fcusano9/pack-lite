import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Vibration strength chosen in Settings.
enum VibLevel { off, light, medium, strong }

/// App haptics, driven through the device vibrator directly so they work
/// regardless of Android's "touch vibration" system setting (Flutter's
/// HapticFeedback respects that setting, which is why taps felt dead when
/// it was off). Amplitude control lets Settings offer real strength levels.
class Haptics {
  static VibLevel level = VibLevel.medium;

  static bool _useVibrator = false;
  static bool _hasAmplitude = false;

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      _useVibrator = await Vibration.hasVibrator();
      _hasAmplitude = await Vibration.hasAmplitudeControl();
    } catch (_) {
      _useVibrator = false;
    }
  }

  static (int, int) _params() => switch (level) {
        VibLevel.off => (0, 0),
        VibLevel.light => (16, 80),
        VibLevel.medium => (24, 170),
        VibLevel.strong => (34, 255),
      };

  /// The check-off / drag-lift tick.
  static void tap() {
    if (level == VibLevel.off) return;
    final (duration, amplitude) = _params();
    if (_useVibrator) {
      try {
        Vibration.vibrate(
            duration: duration, amplitude: _hasAmplitude ? amplitude : -1);
        return;
      } catch (_) {}
    }
    // Fallback (iOS, web, or no vibrator API): system haptics.
    switch (level) {
      case VibLevel.light:
        HapticFeedback.lightImpact();
      case VibLevel.strong:
        HapticFeedback.heavyImpact();
      default:
        HapticFeedback.mediumImpact();
    }
  }

  /// The double-pulse for the "all packed" celebration.
  static void celebrate() {
    if (level == VibLevel.off) return;
    final (duration, amplitude) = _params();
    if (_useVibrator) {
      try {
        Vibration.vibrate(
          pattern: [0, duration + 14, 90, duration + 22],
          intensities: _hasAmplitude ? [0, amplitude, 0, 255] : [],
        );
        return;
      } catch (_) {}
    }
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 130), HapticFeedback.heavyImpact);
  }
}
