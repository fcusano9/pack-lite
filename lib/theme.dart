import 'package:flutter/material.dart';

/// The Harbor design language: cool grey-blue neutrals, one deep cobalt
/// accent for actions and in-progress state, green reserved for "done".
class Harbor extends ThemeExtension<Harbor> {
  const Harbor({
    required this.bg,
    required this.card,
    required this.ink,
    required this.mut,
    required this.line,
    required this.accent,
    required this.accentSoft,
    required this.tile,
    required this.good,
    required this.danger,
  });

  final Color bg;
  final Color card;
  final Color ink;
  final Color mut;
  final Color line;
  final Color accent;
  final Color accentSoft;
  final Color tile;
  final Color good;
  final Color danger;

  static const light = Harbor(
    bg: Color(0xFFF5F6F8),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF17202B),
    mut: Color(0xFF66707D),
    line: Color(0xFFE7EAEF),
    accent: Color(0xFF2251CC),
    accentSoft: Color(0xFFEDF1FC),
    tile: Color(0xFFEEF1F6),
    good: Color(0xFF199A6D),
    danger: Color(0xFFD64541),
  );

  static const dark = Harbor(
    bg: Color(0xFF0F131A),
    card: Color(0xFF171D26),
    ink: Color(0xFFE7EAF0),
    mut: Color(0xFF8B94A3),
    line: Color(0xFF262E3B),
    accent: Color(0xFF5B82F0),
    accentSoft: Color(0xFF1C2536),
    tile: Color(0xFF20293A),
    good: Color(0xFF2FB985),
    danger: Color(0xFFE66A62),
  );

  @override
  Harbor copyWith({
    Color? bg,
    Color? card,
    Color? ink,
    Color? mut,
    Color? line,
    Color? accent,
    Color? accentSoft,
    Color? tile,
    Color? good,
    Color? danger,
  }) {
    return Harbor(
      bg: bg ?? this.bg,
      card: card ?? this.card,
      ink: ink ?? this.ink,
      mut: mut ?? this.mut,
      line: line ?? this.line,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      tile: tile ?? this.tile,
      good: good ?? this.good,
      danger: danger ?? this.danger,
    );
  }

  @override
  Harbor lerp(ThemeExtension<Harbor>? other, double progress) {
    if (other is! Harbor) return this;
    return Harbor(
      bg: Color.lerp(bg, other.bg, progress)!,
      card: Color.lerp(card, other.card, progress)!,
      ink: Color.lerp(ink, other.ink, progress)!,
      mut: Color.lerp(mut, other.mut, progress)!,
      line: Color.lerp(line, other.line, progress)!,
      accent: Color.lerp(accent, other.accent, progress)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, progress)!,
      tile: Color.lerp(tile, other.tile, progress)!,
      good: Color.lerp(good, other.good, progress)!,
      danger: Color.lerp(danger, other.danger, progress)!,
    );
  }
}

extension HarborContext on BuildContext {
  Harbor get harbor => Theme.of(this).extension<Harbor>()!;
}

ThemeData harborTheme(Harbor harbor, Brightness brightness) {
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: harbor.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: harbor.accent,
      onPrimary: Colors.white,
      surface: harbor.card,
      onSurface: harbor.ink,
      error: harbor.danger,
    ),
    extensions: [harbor],
    textTheme: base.textTheme.apply(bodyColor: harbor.ink, displayColor: harbor.ink),
    splashColor: harbor.accent.withValues(alpha: 0.08),
    highlightColor: harbor.accent.withValues(alpha: 0.05),
    dividerColor: harbor.line,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: harbor.accent,
      selectionColor: harbor.accent.withValues(alpha: 0.25),
      selectionHandleColor: harbor.accent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: harbor.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: harbor.ink),
      contentTextStyle: TextStyle(fontSize: 14, color: harbor.mut, height: 1.45),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: harbor.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1D2430),
      contentTextStyle: const TextStyle(fontSize: 13.5, color: Color(0xFFEDF0F5)),
      actionTextColor: const Color(0xFF7D9BF2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
