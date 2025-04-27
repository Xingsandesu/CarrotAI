import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';

/// 设备密钥生成器
///
/// 用于生成和管理基于设备唯一标识的加密密钥
class DeviceKeyGenerator {
  // 缓存的设备密钥，避免频繁重新计算
  static String? _cachedDeviceKey;

  /// 获取设备唯一密钥
  ///
  /// 每次从设备信息、设备ID和盐值派生密钥，不直接存储密钥
  /// 这样更安全，因为密钥不会持久化存储
  static Future<String> getDeviceKey() async {
    // 如果已有缓存的密钥，直接返回（仅在内存中缓存，应用重启后会重新派生）
    if (_cachedDeviceKey != null) {
      return _cachedDeviceKey!;
    }

    try {
      // 获取设备标识符和盐值
      final deviceId = await _getOrCreateDeviceId();
      final salt = await _getOrCreateSalt();
      final deviceInfo = await _getDeviceInfo();

      // 组合设备信息、设备ID和盐值
      final baseString = '$deviceInfo:$deviceId:$salt';

      // 使用SHA-256生成密钥
      final bytes = utf8.encode(baseString);
      final digest = crypto.sha256.convert(bytes);
      final derivedKey = digest.toString();

      // 仅在内存中缓存密钥，不持久化存储
      _cachedDeviceKey = derivedKey;

      debugPrint('已成功派生设备密钥');

      // 返回派生的密钥
      return derivedKey;
    } catch (e) {
      debugPrint('派生设备密钥失败: $e');
      // 如果派生失败，使用备用密钥
      final fallbackKey = AppConfig.fallbackEncryptionKey;
      _cachedDeviceKey = fallbackKey;
      return fallbackKey;
    }
  }

  /// 获取或创建随机盐值
  ///
  /// 盐值存储在SharedPreferences中
  /// 如果不存在，则创建一个新的随机盐值
  static Future<String> _getOrCreateSalt() async {
    final prefs = await SharedPreferences.getInstance();
    String? salt = prefs.getString(AppConfig.saltStorageKey);

    if (salt == null) {
      // 生成新的随机盐值
      final random = Random.secure();
      final values = List<int>.generate(32, (_) => random.nextInt(256));
      salt = base64Url.encode(values);
      await prefs.setString(AppConfig.saltStorageKey, salt);
      debugPrint('已创建新的随机盐值');
    }

    return salt;
  }

  /// 获取或创建设备ID
  ///
  /// 设备ID存储在SharedPreferences中
  /// 如果不存在，则创建一个新的UUID
  static Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(AppConfig.deviceIdStorageKey);

    if (deviceId == null) {
      // 生成新的UUID作为设备ID
      deviceId = const Uuid().v4();
      await prefs.setString(AppConfig.deviceIdStorageKey, deviceId);
      debugPrint('已创建新的设备ID');
    }

    return deviceId;
  }

  /// 获取设备信息
  ///
  /// 根据不同平台获取不同的设备标识信息
  static Future<String> _getDeviceInfo() async {
    // 尝试从SharedPreferences读取已保存的设备信息
    final prefs = await SharedPreferences.getInstance();
    final savedDeviceInfo = prefs.getString(AppConfig.deviceInfoStorageKey);

    if (savedDeviceInfo != null) {
      return savedDeviceInfo;
    }

    String deviceInfoString = "";
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceInfoString =
            '${webInfo.browserName}:${webInfo.platform}:${webInfo.userAgent}';
      } else {
        deviceInfoString = DateTime.now().millisecondsSinceEpoch.toString();
      }

      // 保存设备信息到SharedPreferences
      await prefs.setString(AppConfig.deviceInfoStorageKey, deviceInfoString);
      debugPrint('已保存设备信息');
    } catch (e) {
      debugPrint('获取设备信息失败: $e');
      // 如果无法获取设备信息，使用时间戳作为备用
      deviceInfoString = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString(AppConfig.deviceInfoStorageKey, deviceInfoString);
    }

    return deviceInfoString;
  }
}
