// 主题提供者
// 负责管理主题模式和处理主题相关操作

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carrot/core/config/theme/app_theme.dart'; // 导入 AppTheme 获取默认种子颜色

/// 颜色来源枚举
enum ColorSource {
  defaultSeed, // 使用默认种子颜色
  system, // 使用系统/动态颜色（如果支持）
  customSeed, // 使用自定义种子颜色
}

/// 主题模式管理提供者
///
/// 使用ChangeNotifier管理主题模式和颜色来源，提供切换功能
class ThemeProvider extends ChangeNotifier {
  // 本地存储键名
  static const String _themePreferenceKey = 'theme_mode';
  static const String _colorSourcePreferenceKey = 'color_source';
  static const String _customSeedColorPreferenceKey = 'custom_seed_color';
  static const String _fontSizePreferenceKey = 'font_size'; // 新增字体大小键

  // 默认主题模式
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  // 颜色来源
  ColorSource _colorSource = ColorSource.defaultSeed;
  ColorSource get colorSource => _colorSource;

  // 自定义种子颜色
  Color _customSeedColor = AppTheme.defaultSeedColor;
  Color get customSeedColor => _customSeedColor;

  // 字体大小缩放比例，默认为中号字体（1.0）
  double _fontSizeScale = 1.0; // 中号字体
  double get fontSizeScale => _fontSizeScale;

  // 构造函数，加载保存的设置
  ThemeProvider() {
    _loadPreferences();
  }

  // 初始化：从存储加载设置
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载主题模式
      final savedThemeMode = prefs.getString(_themePreferenceKey);
      if (savedThemeMode != null) {
        switch (savedThemeMode) {
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          case 'system':
          default:
            _themeMode = ThemeMode.system;
            break;
        }
      }

      // 加载颜色来源
      final savedColorSource = prefs.getString(_colorSourcePreferenceKey);
      if (savedColorSource != null) {
        switch (savedColorSource) {
          case 'defaultSeed':
            _colorSource = ColorSource.defaultSeed;
            break;
          case 'system':
            _colorSource = ColorSource.system;
            break;
          case 'customSeed':
            _colorSource = ColorSource.customSeed;
            break;
          default:
            _colorSource = ColorSource.defaultSeed;
            break;
        }
      }

      // 加载自定义种子颜色
      final savedCustomSeedColor = prefs.getInt(_customSeedColorPreferenceKey);
      if (savedCustomSeedColor != null) {
        _customSeedColor = Color(savedCustomSeedColor);
      }

      // 加载字体大小缩放比例
      final savedFontSizeScale = prefs.getDouble(_fontSizePreferenceKey);
      if (savedFontSizeScale != null) {
        _fontSizeScale = savedFontSizeScale;
      } else {
        // 如果没有保存的设置，默认使用中号字体
        _fontSizeScale = 1.0; // 中号字体
      }

      notifyListeners();
    } catch (e) {
      debugPrint('加载主题设置出错: $e');
    }
  }

  // 保存主题模式到本地存储
  Future<void> _saveThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String themeModeString;

      switch (_themeMode) {
        case ThemeMode.light:
          themeModeString = 'light';
          break;
        case ThemeMode.dark:
          themeModeString = 'dark';
          break;
        case ThemeMode.system:
          themeModeString = 'system';
          break;
      }

      await prefs.setString(_themePreferenceKey, themeModeString);
    } catch (e) {
      debugPrint('保存主题设置出错: $e');
    }
  }

  // 保存颜色来源到本地存储
  Future<void> _saveColorSource() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String colorSourceString;

      switch (_colorSource) {
        case ColorSource.defaultSeed:
          colorSourceString = 'defaultSeed';
          break;
        case ColorSource.system:
          colorSourceString = 'system';
          break;
        case ColorSource.customSeed:
          colorSourceString = 'customSeed';
          break;
      }

      await prefs.setString(_colorSourcePreferenceKey, colorSourceString);
    } catch (e) {
      debugPrint('保存颜色来源设置出错: $e');
    }
  }

  // 保存自定义种子颜色到本地存储
  Future<void> _saveCustomSeedColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _customSeedColorPreferenceKey,
        _customSeedColor.toARGB32(),
      );
    } catch (e) {
      debugPrint('保存自定义颜色设置出错: $e');
    }
  }

  // 保存字体大小设置到本地存储
  Future<void> _saveFontSizeScale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_fontSizePreferenceKey, _fontSizeScale);
    } catch (e) {
      debugPrint('保存字体大小设置出错: $e');
    }
  }

  // 设置浅色主题
  void setLightMode() {
    _themeMode = ThemeMode.light;
    _saveThemeMode();
    notifyListeners();
  }

  // 设置深色主题
  void setDarkMode() {
    _themeMode = ThemeMode.dark;
    _saveThemeMode();
    notifyListeners();
  }

  // 设置跟随系统主题
  void setSystemMode() {
    _themeMode = ThemeMode.system;
    _saveThemeMode();
    notifyListeners();
  }

  // 设置颜色来源
  void setColorSource(ColorSource source) {
    _colorSource = source;
    _saveColorSource();
    notifyListeners();
  }

  // 设置自定义种子颜色
  void setCustomSeedColor(Color color) {
    _customSeedColor = color;
    _saveCustomSeedColor();

    // 如果当前不是自定义颜色模式，则自动切换
    if (_colorSource != ColorSource.customSeed) {
      _colorSource = ColorSource.customSeed;
      _saveColorSource();
    }

    notifyListeners();
  }

  // 设置字体大小缩放比例
  void setFontSizeScale(double scale) {
    _fontSizeScale = scale;
    _saveFontSizeScale();
    notifyListeners();
  }
}
