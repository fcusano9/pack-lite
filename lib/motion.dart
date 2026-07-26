import 'package:flutter/material.dart';

/// Harbor motion timings.
///
/// Menus are transient surfaces you're already reaching past to get at the thing
/// behind them, so they open fast and close faster. Flutter's defaults (300ms
/// for a popup menu, 250/200ms for a bottom sheet) are tuned for first-time
/// delight and read as sluggish once you're tapping through them repeatedly.
class Motion {
  /// Popup menus (`···`, `+`) and the long-press action sheets.
  ///
  /// Exit is quicker than entry: on the way in the menu is new information to
  /// land on, on the way out it's just clutter to get rid of.
  static const AnimationStyle menu = AnimationStyle(
    duration: Duration(milliseconds: 140),
    reverseDuration: Duration(milliseconds: 90),
  );
}
