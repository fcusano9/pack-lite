/// Outbound links shown in Settings.
///
/// Kept in one place because a wrong URL here ships to users and can't be
/// hot-fixed — it needs a store release to correct.
class Links {
  /// The public repository. Also where users are pointed to report bugs.
  static const String sourceCode = 'https://github.com/fcusano9/pack-lite';

  /// GitHub Sponsors page. Pack Lite is free with no ads or IAP, so this is
  /// the only way anyone can support it.
  static const String sponsor = 'https://github.com/sponsors/fcusano9';
}
