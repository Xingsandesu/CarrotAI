// 语言设置提供者
// 负责管理应用的语言设置

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 语言来源枚举
enum LocaleSource {
  system, // 跟随系统
  custom, // 自定义语言
}

/// 语言设置管理提供者
///
/// 使用ChangeNotifier管理语言设置，提供切换功能
class LocaleProvider extends ChangeNotifier {
  // 本地存储键名
  static const String _localeSourcePreferenceKey = 'locale_source';
  static const String _customLocalePreferenceKey = 'custom_locale';

  // 默认语言来源
  LocaleSource _localeSource = LocaleSource.system;
  LocaleSource get localeSource => _localeSource;

  // 自定义语言
  Locale? _customLocale;
  Locale? get customLocale => _customLocale;

  // 当前语言
  Locale? _currentLocale;
  Locale? get currentLocale => _currentLocale;

  // 支持的语言列表
  static const List<Locale> supportedLocales = [
    Locale('zh'), // 中文
    Locale('en'), // 英文
    Locale('ja'), // 日文
  ];

  // 构造函数，加载保存的设置
  LocaleProvider() {
    _loadPreferences();
  }

  // 初始化：从存储加载设置
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载语言来源
      final savedLocaleSource = prefs.getString(_localeSourcePreferenceKey);
      if (savedLocaleSource != null) {
        switch (savedLocaleSource) {
          case 'system':
            _localeSource = LocaleSource.system;
            break;
          case 'custom':
            _localeSource = LocaleSource.custom;
            break;
          default:
            _localeSource = LocaleSource.system;
            break;
        }
      }

      // 加载自定义语言
      final savedLocale = prefs.getString(_customLocalePreferenceKey);
      if (savedLocale != null) {
        final parts = savedLocale.split('_');
        if (parts.isNotEmpty) {
          final languageCode = parts[0];
          final countryCode = parts.length > 1 ? parts[1] : null;
          _customLocale = Locale(languageCode, countryCode);
        }
      } else {
        // 默认使用中文
        _customLocale = const Locale('zh');
      }

      // 根据语言来源设置当前语言
      _updateCurrentLocale();

      notifyListeners();
    } catch (e) {
      debugPrint('加载语言设置出错: $e');
    }
  }

  // 保存语言来源到本地存储
  Future<void> _saveLocaleSource() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String value;
      switch (_localeSource) {
        case LocaleSource.system:
          value = 'system';
          break;
        case LocaleSource.custom:
          value = 'custom';
          break;
      }
      await prefs.setString(_localeSourcePreferenceKey, value);
    } catch (e) {
      debugPrint('保存语言来源设置出错: $e');
    }
  }

  // 保存自定义语言到本地存储
  Future<void> _saveCustomLocale() async {
    try {
      if (_customLocale != null) {
        final prefs = await SharedPreferences.getInstance();
        final value =
            _customLocale!.countryCode != null
                ? '${_customLocale!.languageCode}_${_customLocale!.countryCode}'
                : _customLocale!.languageCode;
        await prefs.setString(_customLocalePreferenceKey, value);
      }
    } catch (e) {
      debugPrint('保存自定义语言设置出错: $e');
    }
  }

  // 更新当前语言
  void _updateCurrentLocale() {
    switch (_localeSource) {
      case LocaleSource.system:
        _currentLocale = null; // 使用系统语言
        break;
      case LocaleSource.custom:
        _currentLocale = _customLocale;
        break;
    }
  }

  // 设置跟随系统语言
  void setSystemLocale() {
    _localeSource = LocaleSource.system;
    _saveLocaleSource();
    _updateCurrentLocale();
    notifyListeners();
  }

  // 设置自定义语言
  void setCustomLocale(Locale locale) {
    _customLocale = locale;
    _localeSource = LocaleSource.custom;
    _saveCustomLocale();
    _saveLocaleSource();
    _updateCurrentLocale();
    notifyListeners();
  }

  // 设置中文
  void setChineseLocale() {
    setCustomLocale(const Locale('zh'));
  }

  // 设置英文
  void setEnglishLocale() {
    setCustomLocale(const Locale('en'));
  }

  // 设置日文
  void setJapaneseLocale() {
    setCustomLocale(const Locale('ja'));
  }

  // 获取语言显示名称
  String getLocaleDisplayName(Locale locale) {
    switch (locale.languageCode) {
      case 'zh':
        return '中文';
      case 'en':
        return 'English';
      case 'ja':
        return '日本語';
      default:
        return locale.languageCode;
    }
  }

  // 获取当前语言来源的显示名称
  String getCurrentLocaleSourceDisplayName() {
    switch (_localeSource) {
      case LocaleSource.system:
        return '跟随系统';
      case LocaleSource.custom:
        return getLocaleDisplayName(_customLocale ?? const Locale('zh'));
    }
  }
}
