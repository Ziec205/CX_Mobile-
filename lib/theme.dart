import 'package:flutter/material.dart';

/// Bộ màu lấy từ globals.css của web (thang emerald / stone / wood / water).
class CxColors {
  static const emerald50 = Color(0xFFE9F3EA);
  static const emerald100 = Color(0xFFD3E8D6);
  static const emerald200 = Color(0xFFA9D2B0);
  static const emerald500 = Color(0xFF2F8249);
  static const emerald600 = Color(0xFF1F6B3A);
  static const emerald700 = Color(0xFF19582F); // màu chủ đạo
  static const emerald800 = Color(0xFF144726);
  static const emerald900 = Color(0xFF10361E);

  static const stone50 = Color(0xFFEEF2EA); // nền
  static const stone100 = Color(0xFFE3E9DE);
  static const stone200 = Color(0xFFD3DCCD);
  static const stone300 = Color(0xFFBCC8B5);
  static const stone500 = Color(0xFF66725F);
  static const stone600 = Color(0xFF4F5A49);
  static const stone700 = Color(0xFF3B4536);
  static const stone900 = Color(0xFF14281B);

  static const wood100 = Color(0xFFFDF3CF);
  static const wood200 = Color(0xFFF9E08A);
  static const wood400 = Color(0xFFF2C230); // điểm nhấn
  static const wood800 = Color(0xFF5A4000);

  static const water50 = Color(0xFFE8F1F9);
  static const water100 = Color(0xFFCFE2F2);
  static const water500 = Color(0xFF2A6FAE); // chỉ dùng cho nhắc tưới
  static const water700 = Color(0xFF1D5388);

  static const danger = Color(0xFFB42318);
}

/// Font đóng gói sẵn trong app (assets/fonts), không cần mạng: Be Vietnam Pro cho chữ thường,
/// Bricolage Grotesque (font biến thiên) cho tiêu đề — giống web.
const fontBody = 'BeVietnamPro';
const fontDisplay = 'BricolageGrotesque';

TextStyle _display(double size, double weight) => TextStyle(
      fontFamily: fontDisplay,
      fontSize: size,
      fontWeight: weight >= 800 ? FontWeight.w800 : FontWeight.w700,
      fontVariations: [FontVariation('wght', weight), const FontVariation('opsz', 36)],
      letterSpacing: -0.4,
      height: 1.15,
      color: CxColors.stone900,
    );

TextTheme _textTheme() {
  final body = ThemeData.light().textTheme.apply(fontFamily: fontBody, bodyColor: CxColors.stone900, displayColor: CxColors.stone900);
  return body.copyWith(
    headlineLarge: _display(30, 800),
    headlineMedium: _display(26, 800),
    headlineSmall: _display(22, 700),
    titleLarge: _display(20, 700),
    titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: CxColors.stone900),
    bodyLarge: body.bodyLarge?.copyWith(fontSize: 16, height: 1.5, color: CxColors.stone900),
    bodyMedium: body.bodyMedium?.copyWith(fontSize: 15, height: 1.5, color: CxColors.stone700),
    bodySmall: body.bodySmall?.copyWith(fontSize: 13, color: CxColors.stone500),
    labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: CxColors.emerald700,
    primary: CxColors.emerald700,
    onPrimary: Colors.white,
    secondary: CxColors.wood400,
    onSecondary: CxColors.stone900,
    tertiary: CxColors.water500,
    surface: Colors.white,
    onSurface: CxColors.stone900,
    error: CxColors.danger,
  );
  final text = _textTheme();
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));
  return ThemeData(
    useMaterial3: true,
    fontFamily: fontBody,
    colorScheme: scheme,
    scaffoldBackgroundColor: CxColors.stone50,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: CxColors.stone50,
      foregroundColor: CxColors.stone900,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: CxColors.stone200)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CxColors.emerald700,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: shape,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CxColors.emerald800,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: CxColors.stone300),
        shape: shape,
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: CxColors.emerald700, minimumSize: const Size(44, 44))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CxColors.stone300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CxColors.stone300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CxColors.emerald600, width: 2)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: CxColors.emerald100,
      labelTextStyle: WidgetStatePropertyAll(text.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: CxColors.stone700)),
      iconTheme: WidgetStateProperty.resolveWith((s) =>
          IconThemeData(color: s.contains(WidgetState.selected) ? CxColors.emerald800 : CxColors.stone500)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: CxColors.emerald700,
      side: const BorderSide(color: CxColors.stone300),
      shape: shape,
      labelStyle: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: const DividerThemeData(color: CxColors.stone100, space: 1),
  );
}
