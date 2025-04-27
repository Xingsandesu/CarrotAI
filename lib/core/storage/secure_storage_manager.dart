import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:carrot/core/config/app_config.dart';
import 'package:carrot/core/security/device_key_generator.dart';

/// 安全存储管理器抽象类
abstract class SecureStorageManager {
  /// 写入数据
  Future<void> write(String key, String? value);

  /// 读取数据
  Future<String?> read(String key);

  /// 删除数据
  Future<void> delete(String key);

  /// 清除所有数据
  Future<void> deleteAll();

  /// 获取安全存储管理器实例
  static Future<SecureStorageManager> getInstance() async {
    // 所有平台都使用SharedPreferences + 加密
    return await EncryptedPrefsStorage.getInstance();
  }
}

/// 基于SharedPreferences + 加密的安全存储实现
/// 适用于所有平台
class EncryptedPrefsStorage implements SecureStorageManager {
  static EncryptedPrefsStorage? _instance;
  late SharedPreferences _prefs;
  String? _encryptionKey;

  EncryptedPrefsStorage._();

  static Future<EncryptedPrefsStorage> getInstance() async {
    if (_instance == null) {
      _instance = EncryptedPrefsStorage._();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();

    // 初始化加密密钥 - 尝试获取设备唯一密钥
    try {
      _encryptionKey = await DeviceKeyGenerator.getDeviceKey();
      debugPrint('已成功初始化设备唯一密钥');

      // 检查是否需要迁移旧数据
      await _migrateOldData();
    } catch (e) {
      // 如果获取设备密钥失败，使用备用密钥
      _encryptionKey = AppConfig.fallbackEncryptionKey;
      debugPrint('无法获取设备密钥，使用备用密钥: $e');

      // 不再持久化存储密钥，使用派生方法
      debugPrint('使用备用加密密钥');
    }
  }

  /// 迁移旧数据
  ///
  /// 检查并迁移使用旧密钥加密的数据
  Future<void> _migrateOldData() async {
    final keys = _prefs.getKeys();
    int migratedCount = 0;

    for (final key in keys) {
      if (key.startsWith('secure_')) {
        final encryptedValue = _prefs.getString(key);
        if (encryptedValue != null) {
          try {
            final decoded = utf8.decode(base64.decode(encryptedValue));
            final parts = decoded.split(':');
            if (parts.length != 2) continue;

            final storedHash = parts[0];
            final value = parts[1];

            // 检查是否是旧密钥加密的
            final oldKey = utf8.encode('jintongshu_secure_key_12345');
            final bytes = utf8.encode(value);
            final oldHmac = crypto.Hmac(crypto.sha256, oldKey);
            final oldDigest = oldHmac.convert(bytes).toString();

            if (oldDigest == storedHash) {
              // 是旧密钥加密的数据，重新加密
              final actualKey = key.substring(7); // 移除 'secure_' 前缀
              await write(actualKey, value); // 使用新密钥重新加密并存储
              migratedCount++;
            }
          } catch (e) {
            // 忽略解析错误
          }
        }
      }
    }

    if (migratedCount > 0) {
      debugPrint('已成功迁移 $migratedCount 条旧数据到新密钥');
    }
  }

  @override
  Future<void> write(String key, String? value) async {
    try {
      if (value == null) {
        debugPrint('安全存储: 删除键 "$key"');
        await _prefs.remove('secure_$key');
        // 同时删除备份
        await _prefs.remove('backup_$key');
        return;
      }

      debugPrint('安全存储: 写入键 "$key"');
      final encryptedValue = _encrypt(value);

      // 写入加密值
      final result = await _prefs.setString('secure_$key', encryptedValue);

      if (result) {
        // 立即验证写入是否成功
        final verifyValue = _prefs.getString('secure_$key');
        if (verifyValue == null) {
          debugPrint('安全存储: 警告 - 写入后无法读取键 "$key"');
        } else if (verifyValue != encryptedValue) {
          debugPrint('安全存储: 警告 - 写入值与读取值不匹配');
        } else {
          debugPrint('安全存储: 验证成功 - 键 "$key" 已正确写入');
        }

        // 对于重要的键（如令牌），同时保存一个加密备份
        if (key == AppConfig.tokenStorageKey) {
          await _prefs.setString('backup_$key', encryptedValue);
          debugPrint('安全存储: 已创建加密备份');
        }
      } else {
        debugPrint('安全存储: 写入键 "$key" 失败');
      }
    } catch (e) {
      debugPrint('安全存储: 写入键 "$key" 时出错: $e');
    }
  }

  @override
  Future<String?> read(String key) async {
    try {
      debugPrint('安全存储: 尝试读取键 "$key"');
      final encryptedValue = _prefs.getString('secure_$key');

      if (encryptedValue == null) {
        debugPrint('安全存储: 键 "$key" 不存在');

        // 对于重要的键（如令牌），尝试从备份恢复
        if (key == AppConfig.tokenStorageKey) {
          final backupValue = _prefs.getString('backup_$key');
          if (backupValue != null) {
            debugPrint('安全存储: 找到令牌备份，尝试恢复');
            // 恢复备份
            await _prefs.setString('secure_$key', backupValue);
            final decryptedBackup = _decrypt(backupValue);
            if (decryptedBackup != null) {
              debugPrint('安全存储: 成功从备份恢复令牌');
              return decryptedBackup;
            }
          }
        }

        return null;
      }

      final decryptedValue = _decrypt(encryptedValue);
      if (decryptedValue == null) {
        debugPrint('安全存储: 键 "$key" 解密失败');

        // 对于重要的键（如令牌），尝试从备份恢复
        if (key == AppConfig.tokenStorageKey) {
          final backupValue = _prefs.getString('backup_$key');
          if (backupValue != null && backupValue != encryptedValue) {
            debugPrint('安全存储: 尝试使用备份解密');
            final decryptedBackup = _decrypt(backupValue);
            if (decryptedBackup != null) {
              debugPrint('安全存储: 成功从备份解密令牌');
              // 更新主存储
              await _prefs.setString('secure_$key', backupValue);
              return decryptedBackup;
            }
          }
        }

        return null;
      }

      debugPrint('安全存储: 成功读取并解密键 "$key"');
      return decryptedValue;
    } catch (e) {
      debugPrint('安全存储: 读取键 "$key" 时出错: $e');
      return null;
    }
  }

  @override
  Future<void> delete(String key) async {
    await _prefs.remove('secure_$key');
  }

  @override
  Future<void> deleteAll() async {
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('secure_')) {
        await _prefs.remove(key);
      }
    }
  }

  String _encrypt(String value) {
    // 使用AES加密更安全，但这里使用简单的哈希+编码方案
    final encKey = _encryptionKey ?? AppConfig.fallbackEncryptionKey;
    final key = utf8.encode(encKey);
    final bytes = utf8.encode(value);
    final hmacSha256 = crypto.Hmac(crypto.sha256, key);
    final digest = hmacSha256.convert(bytes);

    // 将原始值与哈希组合，并进行base64编码
    final combined = '$digest:$value';
    return base64.encode(utf8.encode(combined));
  }

  String? _decrypt(String encryptedValue) {
    try {
      final decoded = utf8.decode(base64.decode(encryptedValue));
      final parts = decoded.split(':');
      if (parts.length != 2) return null;

      // 检查哈希值以确保数据未被篡改
      final storedHash = parts[0];
      final value = parts[1];

      // 使用当前密钥
      final encKey = _encryptionKey ?? AppConfig.fallbackEncryptionKey;
      final key = utf8.encode(encKey);
      final bytes = utf8.encode(value);
      final hmacSha256 = crypto.Hmac(crypto.sha256, key);
      final digest = hmacSha256.convert(bytes).toString();

      // 如果密钥不匹配，尝试使用备用密钥
      if (digest != storedHash) {
        debugPrint('警告: 当前密钥无法解密数据，尝试使用备用密钥');

        // 尝试使用备用密钥解密
        final fallbackKey = utf8.encode(AppConfig.fallbackEncryptionKey);
        final fallbackHmac = crypto.Hmac(crypto.sha256, fallbackKey);
        final fallbackDigest = fallbackHmac.convert(bytes).toString();

        if (fallbackDigest == storedHash) {
          debugPrint('使用备用密钥成功解密数据');

          // 更新当前密钥为备用密钥
          _encryptionKey = AppConfig.fallbackEncryptionKey;

          // 不再持久化存储密钥
          debugPrint('已更新为备用加密密钥');

          return value;
        }

        debugPrint('警告: 所有密钥都无法解密数据，可能是数据已被篡改');
        return null;
      }

      return value;
    } catch (e) {
      debugPrint('解密失败: $e');
      return null;
    }
  }
}
