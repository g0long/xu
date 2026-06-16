import 'package:flutter/material.dart';

/// 全局颜色常量 — 简洁白色风格
///
/// 设计理念：白色为主，干净克制
/// - 背景：白色系，层次分明
/// - 主色：清爽蓝
/// - 文字：深灰 → 中灰 → 浅灰，三层信息层级
class AppColors {
  AppColors._();

  // ===== 背景层级（白色系，由浅到深）=====
  static const Color background  = Color(0xFFFFFFFF); // 纯白
  static const Color background2 = Color(0xFFFAFAFA); // 专注页
  static const Color background3 = Color(0xFFFCFCFC); // 统计页
  static const Color background4 = Color(0xFFF8F8F8); // 习惯页
  static const Color sidebar     = Color(0xFFF5F5F5);

  // ===== 卡片 / 表面 =====
  static const Color secondaryBg = Color(0xFFF5F5F5); // 输入框填充
  static const Color cardBg      = Color(0xFFFFFFFF); // 卡片背景
  static const Color cardBg2     = Color(0xFFFAFAFA);

  // ===== 强调色 — 清爽蓝 =====
  static const Color accent      = Color(0xFF5B9BD5); // 主蓝
  static const Color accent2     = Color(0xFF7AB8E8); // 浅蓝
  static const Color accent3     = Color(0xFF4A84C4); // 深蓝
  static const Color accentSoft  = Color(0x1A5B9BD5); // 半透明蓝

  // ===== 暖色点缀 =====
  static const Color gold        = Color(0xFFE8A840); // 金
  static const Color goldLight   = Color(0xFFF0C060);
  static const Color goldSoft    = Color(0x1AE8A840);

  // ===== 状态色 =====
  static const Color success     = Color(0xFF5CB85C); // 绿
  static const Color warning     = Color(0xFFF0AD4E); // 琥珀
  static const Color purple      = Color(0xFF8B7FAA); // 紫
  static const Color danger      = Color(0xFFE06C6C); // 红

  // ===== 文字颜色 =====
  static const Color textPrimary   = Color(0xFF1A1A1A); // 深黑
  static const Color textSecondary = Color(0xFF666666); // 中灰
  static const Color textMuted     = Color(0xFF999999); // 浅灰
  static const Color textMuted2    = Color(0xFFBBBBBB);

  // ===== 分隔线 =====
  static const Color divider = Color(0xFFEEEEEE);
}

/// 全局主题：简洁白色风格
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.accent,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        secondary: AppColors.accent2,
        surface: AppColors.cardBg,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
        elevation: 4,
      ),
      cardTheme: CardTheme(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          height: 1.6,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.secondaryBg,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 28,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 22,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 18,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
        labelSmall: TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// 兼容旧代码的别名
  static ThemeData get darkTheme => lightTheme;
}
