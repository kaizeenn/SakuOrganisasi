import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ============================================================
/// SAKU ORGANISASI — DESIGN SYSTEM
/// Arah: "Refined Fintech" — iris-violet + amber, tipografi Jakarta.
/// ============================================================

/// Palet semantik (akses via `context.palette`).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color brand;
  final Color brandDeep;
  final Color brandSoft;
  final Color accent;
  final Color income;
  final Color expense;
  final Color transfer;
  final Color textMuted;
  final Color border;
  final Color surfaceAlt;
  final List<Color> heroGradient;
  final Color shadow;

  const AppPalette({
    required this.brand,
    required this.brandDeep,
    required this.brandSoft,
    required this.accent,
    required this.income,
    required this.expense,
    required this.transfer,
    required this.textMuted,
    required this.border,
    required this.surfaceAlt,
    required this.heroGradient,
    required this.shadow,
  });

  @override
  AppPalette copyWith({
    Color? brand,
    Color? brandDeep,
    Color? brandSoft,
    Color? accent,
    Color? income,
    Color? expense,
    Color? transfer,
    Color? textMuted,
    Color? border,
    Color? surfaceAlt,
    List<Color>? heroGradient,
    Color? shadow,
  }) {
    return AppPalette(
      brand: brand ?? this.brand,
      brandDeep: brandDeep ?? this.brandDeep,
      brandSoft: brandSoft ?? this.brandSoft,
      accent: accent ?? this.accent,
      income: income ?? this.income,
      expense: expense ?? this.expense,
      transfer: transfer ?? this.transfer,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      heroGradient: heroGradient ?? this.heroGradient,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      brand: Color.lerp(brand, other.brand, t)!,
      brandDeep: Color.lerp(brandDeep, other.brandDeep, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      heroGradient: [
        Color.lerp(heroGradient.first, other.heroGradient.first, t)!,
        Color.lerp(heroGradient.last, other.heroGradient.last, t)!,
      ],
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension PaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
}

/// Radius standar.
class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static BorderRadius all(double r) => BorderRadius.circular(r);
}

/// Warna brand inti (dipakai untuk konstanta di luar ThemeExtension).
class AppColors {
  static const brand = Color(0xFF4E45E4);
  static const brandDeep = Color(0xFF2E2596);
  static const brandSoft = Color(0xFFECEAFE);
  static const accent = Color(0xFFF7A325);
  static const income = Color(0xFF0E9F6E);
  static const expense = Color(0xFFE02424);
  static const transfer = Color(0xFF0BA5EC);
}

const _lightPalette = AppPalette(
  brand: AppColors.brand,
  brandDeep: AppColors.brandDeep,
  brandSoft: AppColors.brandSoft,
  accent: AppColors.accent,
  income: AppColors.income,
  expense: AppColors.expense,
  transfer: AppColors.transfer,
  textMuted: Color(0xFF6B7280),
  border: Color(0xFFE7E9F2),
  surfaceAlt: Color(0xFFF1F2F9),
  heroGradient: [Color(0xFF5B51EE), Color(0xFF2E2596)],
  shadow: Color(0x14403A8F),
);

const _darkPalette = AppPalette(
  brand: Color(0xFF918BFF),
  brandDeep: Color(0xFF6C63F5),
  brandSoft: Color(0xFF262554),
  accent: Color(0xFFFBBF24),
  income: Color(0xFF34D399),
  expense: Color(0xFFF87171),
  transfer: Color(0xFF38BDF8),
  textMuted: Color(0xFF94A0B8),
  border: Color(0xFF2A3350),
  surfaceAlt: Color(0xFF1D2540),
  heroGradient: [Color(0xFF4A42D8), Color(0xFF1E1A5E)],
  shadow: Color(0x33000000),
);

class AppTheme {
  static ThemeData get light => _build(_lightPalette, Brightness.light);
  static ThemeData get dark => _build(_darkPalette, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF0B0F1E) : const Color(0xFFF5F6FB);
    final surface = isDark ? const Color(0xFF141A2E) : Colors.white;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.brand,
      onPrimary: isDark ? const Color(0xFF14122E) : Colors.white,
      primaryContainer: p.brandSoft,
      onPrimaryContainer: isDark ? const Color(0xFFE4E1FF) : p.brandDeep,
      secondary: p.accent,
      onSecondary: const Color(0xFF2A1B00),
      secondaryContainer: isDark
          ? const Color(0xFF3A2E12)
          : const Color(0xFFFFF0D6),
      onSecondaryContainer: isDark
          ? const Color(0xFFFFDFA3)
          : const Color(0xFF5A3B00),
      tertiary: p.transfer,
      onTertiary: const Color(0xFF00243A),
      error: p.expense,
      onError: Colors.white,
      surface: surface,
      onSurface: isDark ? const Color(0xFFEDEFF7) : const Color(0xFF12172B),
      onSurfaceVariant: p.textMuted,
      outline: p.border,
      outlineVariant: p.border,
      shadow: p.shadow,
      scrim: Colors.black,
      inverseSurface: isDark ? const Color(0xFFEDEFF7) : const Color(0xFF12172B),
      onInverseSurface: isDark ? const Color(0xFF12172B) : const Color(0xFFEDEFF7),
      inversePrimary: p.brandDeep,
      surfaceTint: Colors.transparent,
    );

    // --- Tipografi: Plus Jakarta Sans (body/UI) + Sora (heading/brand) ---
    final baseText = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    final heading = GoogleFonts.soraTextTheme();

    TextStyle h(TextStyle? s, {double? size, FontWeight weight = FontWeight.w700, double? spacing}) =>
        (s ?? const TextStyle()).copyWith(
          fontSize: size,
          fontWeight: weight,
          letterSpacing: spacing,
          color: scheme.onSurface,
        );

    final text = baseText.copyWith(
      displayLarge: h(heading.displayLarge, size: 40, spacing: -1.0),
      displayMedium: h(heading.displayMedium, size: 34, spacing: -0.8),
      displaySmall: h(heading.displaySmall, size: 28, spacing: -0.6),
      headlineLarge: h(heading.headlineLarge, size: 26, spacing: -0.4),
      headlineMedium: h(heading.headlineMedium, size: 22, spacing: -0.3),
      headlineSmall: h(heading.headlineSmall, size: 19, spacing: -0.2),
      titleLarge: h(baseText.titleLarge, size: 18),
      titleMedium: h(baseText.titleMedium, size: 15),
      titleSmall: h(baseText.titleSmall, size: 13, weight: FontWeight.w600),
      bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 15, height: 1.45),
      bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 13.5, height: 1.45),
      bodySmall: baseText.bodySmall?.copyWith(fontSize: 12, height: 1.4),
      labelLarge: h(baseText.labelLarge, size: 14, weight: FontWeight.w700),
      labelMedium: h(baseText.labelMedium, size: 12, weight: FontWeight.w600),
      labelSmall: h(baseText.labelSmall, size: 11, weight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      cardColor: surface,
      dividerColor: p.border,
      splashFactory: InkSparkle.splashFactory,
      textTheme: text,
      fontFamily: 'PlusJakartaSans',
      extensions: [p],

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      ),

      // Card
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: p.border),
        ),
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.brand,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.brand,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          elevation: 0,
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.brand,
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(0, 52),
          side: BorderSide(color: p.border, width: 1.2),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? p.surfaceAlt : const Color(0xFFF7F8FC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: text.bodyMedium?.copyWith(color: p.textMuted),
        labelStyle: text.bodyMedium?.copyWith(color: p.textMuted),
        prefixIconColor: p.textMuted,
        suffixIconColor: p.textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.brand, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.expense),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: p.expense, width: 1.8),
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? p.surfaceAlt : const Color(0xFFF1F2F9),
        selectedColor: p.brandSoft,
        side: BorderSide(color: Colors.transparent),
        labelStyle: text.labelMedium!,
        secondaryLabelStyle: text.labelMedium!.copyWith(color: p.brandDeep),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),

      // Navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.brandSoft,
        height: 68,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelSmall!.copyWith(
            color: selected ? p.brand : p.textMuted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? p.brand : p.textMuted,
            size: 24,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: p.brand,
        unselectedItemColor: p.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Dialog & Sheet
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF28304A) : const Color(0xFF1B1F33),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      // Misc
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: p.textMuted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.brand,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.brand,
        unselectedLabelColor: p.textMuted,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: p.brand, width: 2.5),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.brand,
        linearTrackColor: p.surfaceAlt,
        circularTrackColor: p.surfaceAlt,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? p.brand : null),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? p.brand : Colors.transparent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: p.border, width: 1.6),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
    );
  }
}

/// System UI overlay (status bar transparan).
const systemOverlayLight = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
);
