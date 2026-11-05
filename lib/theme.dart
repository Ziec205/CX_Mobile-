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

/// Font đóng gói sẵn (assets/fonts, giấy phép OFL), không cần mạng:
/// - Nunito: tiêu đề — nét tròn, thân thiện mà vẫn lịch sự.
/// - Be Vietnam Pro: nội dung — do nhóm thiết kế Việt Nam làm, dấu tiếng Việt rõ ở cỡ nhỏ.
const fontBody = 'BeVietnamPro';
const fontDisplay = 'Nunito';

TextStyle _display(double size, FontWeight weight) => TextStyle(
      fontFamily: fontDisplay,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -0.2,
      height: 1.2,
      color: CxColors.stone900,
    );

TextTheme _textTheme() {
  final body = ThemeData.light().textTheme.apply(fontFamily: fontBody, bodyColor: CxColors.stone900, displayColor: CxColors.stone900);
  return body.copyWith(
    displaySmall: _display(34, FontWeight.w800),
    headlineLarge: _display(30, FontWeight.w800),
    headlineMedium: _display(26, FontWeight.w800),
    headlineSmall: _display(22, FontWeight.w800),
    titleLarge: _display(20, FontWeight.w800),
    titleMedium: _display(17, FontWeight.w700),
    titleSmall: body.titleSmall?.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: CxColors.stone900),
    bodyLarge: body.bodyLarge?.copyWith(fontSize: 17, height: 1.5, color: CxColors.stone900),
    bodyMedium: body.bodyMedium?.copyWith(fontSize: 15.5, height: 1.5, color: CxColors.stone700),
    bodySmall: body.bodySmall?.copyWith(fontSize: 13.5, height: 1.4, color: CxColors.stone500),
    labelLarge: _display(16, FontWeight.w800).copyWith(letterSpacing: 0.1),
  );
}

/// Bóng đổ mềm dùng chung cho thẻ nổi.
const softShadow = [BoxShadow(color: Color(0x14102E1B), blurRadius: 18, offset: Offset(0, 6))];

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: CxColors.stone100)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CxColors.emerald700,
        foregroundColor: Colors.white,
        minimumSize: const Size(52, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: shape,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CxColors.emerald800,
        minimumSize: const Size(52, 52),
        side: const BorderSide(color: CxColors.stone300),
        shape: shape,
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: CxColors.emerald700, minimumSize: const Size(44, 44))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: CxColors.stone300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: CxColors.stone300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: CxColors.emerald600, width: 2)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      height: 72,
      elevation: 3,
      shadowColor: const Color(0x22000000),
      indicatorColor: CxColors.emerald100,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => text.bodySmall?.copyWith(
          fontSize: 12.5, fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? CxColors.emerald800 : CxColors.stone600)),
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
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: CxColors.emerald900,
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      actionTextColor: CxColors.wood400,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: CxColors.emerald700,
      foregroundColor: Colors.white,
      extendedTextStyle: text.labelLarge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: text.titleLarge,
    ),
    dividerTheme: const DividerThemeData(color: CxColors.stone100, space: 1),
  );
}
