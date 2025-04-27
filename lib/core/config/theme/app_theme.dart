// 应用主题配置文件
// 实现符合Material 3设计风格的主题配置
// 提供深色和浅色主题，支持动态颜色和自定义种子颜色

import 'package:flutter/material.dart';
import 'package:carrot/core/config/app_config.dart';

/// 应用主题配置类
///
/// 提供Material 3风格的主题配置，支持深色和浅色主题
class AppTheme {
  // 定义默认种子颜色 (例如，一个比较中性的蓝色)
  static const Color defaultSeedColor = Color(AppConfig.defaultSeedColorValue);

  // 定义侧边栏颜色 - 比默认表面颜色更深一些
  static const Color sidebarBackgroundLight = Color(
    AppConfig.sidebarBackgroundLightValue,
  ); // 浅模式下的侧边栏颜色
  static const Color sidebarBackgroundDark = Color(
    AppConfig.sidebarBackgroundDarkValue,
  ); // 深模式下的侧边栏颜色

  // 定义主内容区颜色 - 比侧边栏更浅
  static const Color mainContentBackgroundLight = Color(
    AppConfig.mainContentBackgroundLightValue,
  ); // 浅模式下的主内容区颜色
  static const Color mainContentBackgroundDark = Color(
    AppConfig.mainContentBackgroundDarkValue,
  ); // 深模式下的主内容区颜色

  static final String? _windowsChineseFontFamily = null;

  /// 获取浅色主题
  /// [seedColor] 用于生成颜色方案的种子颜色
  /// [brightness] 主题亮度
  static ThemeData lightTheme({
    Color seedColor = defaultSeedColor,
    ColorScheme? dynamicColorScheme, // 可选的动态颜色方案
  }) {
    final ColorScheme colorScheme =
        dynamicColorScheme ??
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
          surfaceContainerLowest: sidebarBackgroundLight, // 侧边栏背景色
          surface: mainContentBackgroundLight, // 主内容区背景色
        );

    // Material 3主题配置
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light, // 明确指定亮度
      fontFamily: _windowsChineseFontFamily, // 使用修正后的字体变量
      // 卡片主题 - 增加阴影和圆角
      cardTheme: CardTheme(
        elevation: 1, // M3 推荐较小的 Elevation
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ), // M3 推荐圆角
        shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent, // 避免 M3 的色调叠加效果
      ),

      // 列表瓦片主题
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 4.0,
        ), // 调整垂直内边距
        minLeadingWidth: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ), // 为 ListTile 添加圆角
      ),

      // 分割线主题
      dividerTheme: DividerThemeData(
        space: 1.0,
        thickness: 1.0,
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),

      // AppBar主题
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0, // M3 通常 AppBar 无阴影
        scrolledUnderElevation: 1, // 滚动时微小的阴影
        shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
      ),

      // 侧边导航菜单主题
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest, // 使用侧边栏颜色
        elevation: 1, // M3 推荐较小的 Elevation
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
        surfaceTintColor: colorScheme.surfaceContainerLowest, // 使用侧边栏颜色作为 tint
      ),

      // 输入装饰主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest, // M3 推荐颜色
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 1, // M3 推荐较小的 Elevation
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        // 为 FilledButton 添加样式
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        // 为 OutlinedButton 添加样式
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: colorScheme.outline), // 使用 outline 颜色
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        // 为 TextButton 添加样式
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),

      // 弹出菜单主题
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainer, // M3 推荐颜色
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        surfaceTintColor: Colors.transparent,
      ),

      // SegmentedButton 主题
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: colorScheme.secondaryContainer,
          selectedForegroundColor: colorScheme.onSecondaryContainer,
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Dialog 主题
      dialogTheme: DialogTheme(
        backgroundColor: colorScheme.surfaceContainerHigh, // M3 推荐颜色
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ), // M3 推荐更大圆角
        elevation: 3,
        surfaceTintColor: Colors.transparent,
      ),

      // BottomSheet 主题
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainer, // M3 推荐颜色
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        elevation: 2,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colorScheme.surfaceContainer, // 确保模态背景色一致
        modalElevation: 2,
      ),
    );
  }

  /// 获取深色主题
  /// [seedColor] 用于生成颜色方案的种子颜色
  /// [brightness] 主题亮度
  static ThemeData darkTheme({
    Color seedColor = defaultSeedColor,
    ColorScheme? dynamicColorScheme, // 可选的动态颜色方案
  }) {
    final ColorScheme colorScheme =
        dynamicColorScheme ??
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark, // 必须指定为深色
          surfaceContainerLowest: sidebarBackgroundDark, // 侧边栏背景色
          surface: mainContentBackgroundDark, // 主内容区背景色
        );

    // Material 3主题配置 (与浅色主题类似，但基于深色 colorScheme)
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark, // 明确指定亮度
      fontFamily: _windowsChineseFontFamily, // 使用修正后的字体变量
      // 卡片主题
      cardTheme: CardTheme(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
      ),

      // 列表瓦片主题
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 4.0,
        ),
        minLeadingWidth: 24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // 分割线主题
      dividerTheme: DividerThemeData(
        space: 1.0,
        thickness: 1.0,
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),

      // AppBar主题
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
      ),

      // 侧边导航菜单主题
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        elevation: 0, // 深色模式中通常无阴影
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        surfaceTintColor: Colors.transparent,
      ),

      // 输入装饰主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.7),
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      // 按钮主题 - 暗色模式下特殊调整
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // 暗色模式下使用更暗的背景色，避免高对比度
          backgroundColor: colorScheme.surfaceContainerHighest,
          foregroundColor: colorScheme.primary,
          elevation: 0, // 暗色模式下建议无阴影
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          // 添加边框增强可见性
          side: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.5),
            width: 1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // 为填充按钮使用主色，但略微降低亮度
          backgroundColor: colorScheme.primary.withValues(alpha: 0.8),
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          // 微调边框使其更加可见但不刺眼
          side: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          // 文本按钮使用稍微淡化的主色
          foregroundColor: colorScheme.primary.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),

      // 弹出菜单主题
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerHigh,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        surfaceTintColor: Colors.transparent,
      ),

      // Dialog 主题
      dialogTheme: DialogTheme(
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0, // 暗色模式下通常无阴影
        surfaceTintColor: Colors.transparent,
      ),

      // BottomSheet 主题
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        elevation: 0, // 暗色模式下通常无阴影
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colorScheme.surfaceContainerHigh,
        modalElevation: 0,
      ),
    );
  }
}
