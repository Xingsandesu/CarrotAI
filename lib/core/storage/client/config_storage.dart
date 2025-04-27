// 配置存储管理类
// 负责处理应用配置的本地持久化

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 配置存储管理类
///
/// 使用SharedPreferences实现配置的本地持久化存储
class ConfigStorage {
  // 单例实例
  static ConfigStorage? _instance;

  // SharedPreferences实例
  late SharedPreferences _prefs;

  // 存储键名前缀
  static const String _keyPrefix = 'config_';

  // 常用配置键名
  static const String keyThemeMode = '${_keyPrefix}theme_mode';
  static const String keyLanguage = '${_keyPrefix}language';
  static const String keyDefaultModel = '${_keyPrefix}default_model';
  static const String keyUseDeepThinking = '${_keyPrefix}use_deep_thinking';
  static const String keyUseMcp = '${_keyPrefix}use_mcp';
  static const String keyUseBaseTools = '${_keyPrefix}use_base_tools';
  static const String keyContextLength = '${_keyPrefix}context_length';
  static const String keyTemperature = '${_keyPrefix}temperature';

  // 私有构造函数
  ConfigStorage._();

  /// 获取单例实例
  static Future<ConfigStorage> getInstance() async {
    if (_instance == null) {
      _instance = ConfigStorage._();
      await _instance!._init();
    }
    return _instance!;
  }

  /// 初始化
  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 保存字符串配置
  Future<bool> setString(String key, String value) async {
    return await _prefs.setString(key, value);
  }

  /// 获取字符串配置
  String? getString(String key, {String? defaultValue}) {
    return _prefs.getString(key) ?? defaultValue;
  }

  /// 保存整数配置
  Future<bool> setInt(String key, int value) async {
    return await _prefs.setInt(key, value);
  }

  /// 获取整数配置
  int? getInt(String key, {int? defaultValue}) {
    return _prefs.getInt(key) ?? defaultValue;
  }

  /// 保存双精度浮点数配置
  Future<bool> setDouble(String key, double value) async {
    return await _prefs.setDouble(key, value);
  }

  /// 获取双精度浮点数配置
  double? getDouble(String key, {double? defaultValue}) {
    return _prefs.getDouble(key) ?? defaultValue;
  }

  /// 保存布尔值配置
  Future<bool> setBool(String key, bool value) async {
    return await _prefs.setBool(key, value);
  }

  /// 获取布尔值配置
  bool? getBool(String key, {bool? defaultValue}) {
    return _prefs.getBool(key) ?? defaultValue;
  }

  /// 保存字符串列表配置
  Future<bool> setStringList(String key, List<String> value) async {
    return await _prefs.setStringList(key, value);
  }

  /// 获取字符串列表配置
  List<String>? getStringList(String key, {List<String>? defaultValue}) {
    return _prefs.getStringList(key) ?? defaultValue;
  }

  /// 保存JSON配置
  Future<bool> setJson(String key, Map<String, dynamic> value) async {
    final jsonString = jsonEncode(value);
    return await _prefs.setString(key, jsonString);
  }

  /// 获取JSON配置
  Map<String, dynamic>? getJson(
    String key, {
    Map<String, dynamic>? defaultValue,
  }) {
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return defaultValue;

    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('解析JSON配置失败: $e');
      return defaultValue;
    }
  }

  /// 删除配置
  Future<bool> remove(String key) async {
    return await _prefs.remove(key);
  }

  /// 清空所有配置
  Future<bool> clear() async {
    return await _prefs.clear();
  }

  /// 获取所有配置键名
  Set<String> getKeys() {
    return _prefs.getKeys();
  }

  /// 检查配置是否存在
  bool containsKey(String key) {
    return _prefs.containsKey(key);
  }
}
