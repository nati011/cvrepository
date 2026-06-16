import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Kifiya design system — matches web brand tokens (brand.kifiya.com).
class AppTheme {
  // Kifiya palette (web/lib/brand.ts, web/tailwind.config.ts).
  static const primary = Color(0xFF02404F);
  static const primaryDark = Color(0xFF013A47);
  static const secondary = Color(0xFFEB7D23);
  static const green = Color(0xFF10B981);
  static const gold = secondary;
  static const danger = Color(0xFFF43F5E);
  static const ink = Color(0xFF0A1A1F);
  static const bg = Color(0xFFF3F5F6);

  // Back-compat aliases used across screens.
  static const blue = primary;
  static const blueDark = primaryDark;
  static const peacock = primary;
  static const orange = secondary;
  static const mist = bg;
  static const seed = primary;

  static const brandGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: ink,
    );
    return _base(scheme).copyWith(scaffoldBackgroundColor: bg);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF4DA3B3),
      secondary: const Color(0xFFF0A052),
    );
    return _base(scheme).copyWith(scaffoldBackgroundColor: ink);
  }

  static ThemeData _base(ColorScheme scheme) {
    final isLight = scheme.brightness == Brightness.light;
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final cardBorder =
        BorderSide(color: scheme.outlineVariant.withValues(alpha: isLight ? 0.7 : 0.4));

    return base.copyWith(
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      textTheme: _textTheme(base.textTheme, scheme),

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        scrolledUnderElevation: 0.5,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle:
            isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      ),

      // Cards: white, 8px radius, hairline border + faint shadow.
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: ink.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        color: scheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: cardBorder,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isLight ? bg : Colors.white.withValues(alpha: 0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),

      // Pill (stadium) buttons.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.1),
          shape: const StadiumBorder(),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 48),
          elevation: 0,
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: const StadiumBorder(),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          side: BorderSide(color: scheme.primary, width: 1.4),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: const StadiumBorder(),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 2,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: ink.withValues(alpha: 0.1),
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: GoogleFonts.inter(
            color: Colors.white, fontWeight: FontWeight.w600),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearMinHeight: 4,
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    // Inter — the Kifiya web typeface.
    final inter = GoogleFonts.interTextTheme(base);
    return inter.copyWith(
      headlineSmall: inter.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: inter.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      titleMedium: inter.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      bodyMedium: inter.bodyMedium?.copyWith(height: 1.45),
      labelSmall: inter.labelSmall?.copyWith(letterSpacing: 0.1),
    );
  }

  /// Traffic-light color for a 0-100 fit score.
  static Color scoreColor(int score) {
    if (score >= 80) return green;
    if (score >= 60) return gold;
    return danger;
  }
}
