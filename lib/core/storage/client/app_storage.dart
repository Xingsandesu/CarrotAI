// 应用存储管理类
// 负责处理用户已安装应用的本地持久化

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carrot/shared/models/app_model.dart';

/// 应用存储管理类
///
/// 使用SharedPreferences实现用户已安装应用的本地持久化存储
class AppStorage {
  // 单例实例
  static AppStorage? _instance;

  // SharedPreferences实例
  late SharedPreferences _prefs;

  // 存储键名前缀
  static const String _keyPrefix = 'app_';

  // 常用配置键名
  static const String keyInstalledApps = '${_keyPrefix}installed_apps';

  // 私有构造函数
  AppStorage._();

  /// 获取单例实例
  static Future<AppStorage> getInstance() async {
    if (_instance == null) {
      _instance = AppStorage._();
      await _instance!._init();
    }
    return _instance!;
  }

  /// 初始化
  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 获取所有已安装的应用
  Future<List<AppModel>> getInstalledApps() async {
    try {
      final String? appsJson = _prefs.getString(keyInstalledApps);
      if (appsJson == null) {
        return [];
      }

      final List<dynamic> appsList = jsonDecode(appsJson);
      return appsList
          .map((json) => AppModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('获取已安装应用失败: $e');
      return [];
    }
  }

  /// 保存所有已安装的应用
  Future<bool> saveInstalledApps(List<AppModel> apps) async {
    try {
      final List<Map<String, dynamic>> jsonList =
          apps.map((app) => app.toJson()).toList();
      final String appsJson = jsonEncode(jsonList);
      return await _prefs.setString(keyInstalledApps, appsJson);
    } catch (e) {
      debugPrint('保存已安装应用失败: $e');
      return false;
    }
  }

  /// 安装应用
  Future<bool> installApp(AppModel app) async {
    try {
      final List<AppModel> installedApps = await getInstalledApps();
      // 检查应用是否已安装
      final int existingIndex = installedApps.indexWhere((a) => a.id == app.id);

      if (existingIndex >= 0) {
        // 如果已安装，则更新
        installedApps[existingIndex] = app.copyWith(isInstalled: true);
      } else {
        // 否则添加到列表
        installedApps.add(app.copyWith(isInstalled: true));
      }

      return await saveInstalledApps(installedApps);
    } catch (e) {
      debugPrint('安装应用失败: $e');
      return false;
    }
  }

  /// 卸载应用
  Future<bool> uninstallApp(String appId) async {
    try {
      final List<AppModel> installedApps = await getInstalledApps();
      final List<AppModel> updatedApps =
          installedApps.where((app) => app.id != appId).toList();
      return await saveInstalledApps(updatedApps);
    } catch (e) {
      debugPrint('卸载应用失败: $e');
      return false;
    }
  }

  /// 检查应用是否已安装
  Future<bool> isAppInstalled(String appId) async {
    try {
      final List<AppModel> installedApps = await getInstalledApps();
      return installedApps.any((app) => app.id == appId);
    } catch (e) {
      debugPrint('检查应用是否安装失败: $e');
      return false;
    }
  }
}
