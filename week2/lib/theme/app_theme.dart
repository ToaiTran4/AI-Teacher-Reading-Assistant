import 'package:flutter/material.dart';

/// Theme configuration file - Cập nhật các giá trị này từ Figma design
///
/// Cách lấy giá trị từ Figma:
/// 1. Mở Figma design
/// 2. Chọn element cần lấy màu/font/spacing
/// 3. Xem giá trị ở panel bên phải (Design tab)
/// 4. Copy giá trị và paste vào đây

class AppTheme {
  // ===== MÀU SẮC (Colors) =====
  // Lấy từ Figma: Chọn element -> Design panel -> Fill/Text color -> Copy hex code

  // Primary colors (Màu chính) - Dark theme với accent xanh dương
  static const Color primaryColor = Color(0xFF4A90E2); // Màu xanh dương nhẹ
  static const Color primaryLight = Color(0xFF6BA3E8);
  static const Color primaryDark = Color(0xFF357ABD);

  // Secondary colors (Màu phụ)
  static const Color secondaryColor = Color(0xFF50C878); // Màu xanh lá nhẹ
  static const Color secondaryLight = Color(0xFF6DD88F);
  static const Color secondaryDark = Color(0xFF3FA061);

  // Background colors - Dark theme
  static const Color backgroundColor = Color(0xFF1A1A1A); // Nền tối chính
  static const Color surfaceColor = Color(0xFF2A2A2A); // Nền card/dialog
  static const Color cardColor = Color(0xFF2D2D2D); // Nền card
  static const Color dividerColor = Color(0xFF3A3A3A); // Màu divider

  // Background colors - Light theme
  static const Color backgroundColorLight = Color(0xFFF5F5F5); // Nền sáng chính
  static const Color surfaceColorLight =
      Color(0xFFFFFFFF); // Nền card/dialog sáng
  static const Color cardColorLight = Color(0xFFFFFFFF); // Nền card sáng
  static const Color dividerColorLight = Color(0xFFE0E0E0); // Màu divider sáng

  // Text colors - Light text trên nền tối
  static const Color textPrimary = Color(0xFFFFFFFF); // Chữ chính (trắng)
  static const Color textSecondary = Color(0xFFB0B0B0); // Chữ phụ (xám nhạt)
  static const Color textHint = Color(0xFF808080); // Chữ hint (xám)
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Text colors - Dark text trên nền sáng
  static const Color textPrimaryLight = Color(0xFF212121); // Chữ chính (đen)
  static const Color textSecondaryLight =
      Color(0xFF757575); // Chữ phụ (xám đậm)
  static const Color textHintLight = Color(0xFF9E9E9E); // Chữ hint (xám)

  // Status colors
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color infoColor = Color(0xFF2196F3);

  // Chat message colors - Dark theme
  static const Color userMessageBg = Color(0xFF4A90E2);
  static const Color botMessageBg = Color(0xFF2A2A2A);
  static const Color userMessageText = Color(0xFFFFFFFF);
  static const Color botMessageText = Color(0xFFFFFFFF);

  // Chat message colors - Light theme
  static const Color userMessageBgLight = Color(0xFF4A90E2);
  static const Color botMessageBgLight = Color(0xFFF0F0F0);
  static const Color userMessageTextLight = Color(0xFFFFFFFF);
  static const Color botMessageTextLight = Color(0xFF212121);

  // ===== TYPOGRAPHY (Fonts) =====
  // Lấy từ Figma: Chọn text -> Design panel -> Text section -> Copy font family, size, weight

  // Font family - Thay bằng font từ Figma (ví dụ: 'Roboto', 'Inter', 'Poppins')
  static const String fontFamily = 'Roboto'; // Thay bằng font từ Figma

  // Text styles
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    fontFamily: fontFamily,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    fontFamily: fontFamily,
    color: textPrimary,
    letterSpacing: -0.25,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    fontFamily: fontFamily,
    color: textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    fontFamily: fontFamily,
    color: textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    fontFamily: fontFamily,
    color: textSecondary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    color: textOnPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    fontFamily: fontFamily,
    color: textSecondary,
  );

  // ===== SPACING (Khoảng cách) =====
  // Lấy từ Figma: Chọn element -> Design panel -> Layout section -> Xem padding/margin
  // Hoặc dùng spacing scale: 4, 8, 12, 16, 24, 32, 48, 64

  static const double spacingXS = 4;
  static const double spacingSM = 8;
  static const double spacingMD = 16;
  static const double spacingLG = 24;
  static const double spacingXL = 32;
  static const double spacingXXL = 48;

  // ===== BORDER RADIUS =====
  // Lấy từ Figma: Chọn element -> Design panel -> Corner radius

  static const double radiusSM = 8;
  static const double radiusMD = 12;
  static const double radiusLG = 16;
  static const double radiusXL = 24;
  static const double radiusRound = 999; // Fully rounded

  // ===== SHADOWS =====
  // Lấy từ Figma: Chọn element -> Design panel -> Effects -> Drop shadow

  static const List<BoxShadow> shadowSM = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> shadowMD = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> shadowLG = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];

  // ===== INPUT DECORATION - DARK =====
  static InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: surfaceColor,
    hintStyle: bodyMedium.copyWith(color: textHint),
    labelStyle: bodyMedium.copyWith(color: textSecondary),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMD),
      borderSide: BorderSide(color: dividerColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMD),
      borderSide: BorderSide(color: dividerColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMD),
      borderSide: const BorderSide(color: primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMD),
      borderSide: const BorderSide(color: errorColor),
    ),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: spacingMD, vertical: spacingMD),
  );

  // ===== INPUT DECORATION - LIGHT =====
  static InputDecorationTheme inputDecorationThemeLight = InputDecorationTheme(
    filled: true,
    fillColor: surfaceColorLight,
    hintStyle: bodyMedium.copyWith(color: textHintLight),
    labelStyle: bodyMedium.copyWith(color: textSecondaryLight),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMD),
      borderSide: BorderSide(color: dividerColorLight),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMD),
      borderSide: BorderSide(color: dividerColorLight),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMD),
      borderSide: const BorderSide(color: primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMD),
      borderSide: const BorderSide(color: errorColor),
    ),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: spacingMD, vertical: spacingMD),
  );

  // ===== BUTTON STYLES =====
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: textOnPrimary,
    padding:
        const EdgeInsets.symmetric(horizontal: spacingXL, vertical: spacingMD),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMD),
    ),
    elevation: 0,
    textStyle: button,
  );

  static ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primaryColor,
    padding:
        const EdgeInsets.symmetric(horizontal: spacingXL, vertical: spacingMD),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMD),
    ),
    side: const BorderSide(color: primaryColor),
    textStyle: button.copyWith(color: primaryColor),
  );

  // ===== LIGHT THEME (Giao diện Sáng) =====
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColorLight,
        background: backgroundColorLight,
        error: errorColor,
        onPrimary: textOnPrimary,
        onSecondary: textPrimaryLight,
        onSurface: textPrimaryLight,
        onBackground: textPrimaryLight,
        onError: textOnPrimary,
      ),
      scaffoldBackgroundColor: backgroundColorLight,
      fontFamily: fontFamily,
      textTheme: TextTheme(
        displayLarge: h1.copyWith(color: textPrimaryLight),
        displayMedium: h2.copyWith(color: textPrimaryLight),
        displaySmall: h3.copyWith(color: textPrimaryLight),
        bodyLarge: bodyLarge.copyWith(color: textPrimaryLight),
        bodyMedium: bodyMedium.copyWith(color: textPrimaryLight),
        bodySmall: bodySmall.copyWith(color: textSecondaryLight),
        labelLarge: button,
        labelSmall: caption.copyWith(color: textSecondaryLight),
      ),
      inputDecorationTheme: inputDecorationThemeLight,
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryButtonStyle),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: surfaceColorLight,
        foregroundColor: textPrimaryLight,
        iconTheme: IconThemeData(color: textPrimaryLight),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
          color: textPrimaryLight,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColorLight,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
      ),
      dividerColor: dividerColorLight,
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColorLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColorLight,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondaryLight,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  // ===== DARK THEME (Giao diện Tối) =====
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        background: backgroundColor,
        error: errorColor,
        onPrimary: textOnPrimary,
        onSecondary: textPrimary,
        onSurface: textPrimary,
        onBackground: textPrimary,
        onError: textOnPrimary,
      ),
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: fontFamily,
      textTheme: const TextTheme(
        displayLarge: h1,
        displayMedium: h2,
        displaySmall: h3,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: button,
        labelSmall: caption,
      ),
      inputDecorationTheme: inputDecorationTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryButtonStyle),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
      ),
      dividerColor: dividerColor,
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
