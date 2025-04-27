// 这个文件是 AppConfig，用于存储应用程序配置
// 它包含基础 URL 和其他配置
//

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppConfig {
  // API 和网络配置
  static String get baseUrl {
    if (kReleaseMode) {
      // 请将下面的 URL 替换为您的生产环境 API 地址
      return "http://127.0.0.1:8000"; // 生产环境
    } else {
      // 调试或开发环境
      return "http://127.0.0.1:8000"; // 本地开发环境
    }
  }

  static Future<String> get appVersion async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  static Future<String> get appBuildNumber async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.buildNumber;
  }

  static const int connectionTimeoutSeconds = 15; // 连接超时时间
  static const int receiveTimeoutSeconds = 15; // 接收超时时间

  // 性能跟踪配置
  // 注意：此开关仅在调试模式下生效，正式版本中不会包含性能跟踪代码
  static const bool enablePerformanceTracking = false; // 是否启用性能跟踪

  /// 检查是否应该进行性能跟踪
  /// 只有在调试模式且性能跟踪开关打开时才返回 true
  static bool get shouldTrackPerformance =>
      kDebugMode && enablePerformanceTracking;

  // 应用基本信息
  static const String appName = "CarrotAI"; // 应用名称

  // 主题配置
  static const int defaultSeedColorValue = 0xFF0061A4; // 默认种子颜色
  static const int sidebarBackgroundLightValue = 0xFFE6EDF4; // 浅模式下的侧边栏颜色
  static const int sidebarBackgroundDarkValue = 0xFF1A2027; // 深模式下的侧边栏颜色
  static const int mainContentBackgroundLightValue = 0xFFF8FAFC; // 浅模式下的主内容区颜色
  static const int mainContentBackgroundDarkValue = 0xFF282E33; // 深模式下的主内容区颜色

  // 安全存储键名
  static const String tokenStorageKey = 'auth_token'; // 令牌存储键名
  static const String userIdKey = 'user_id'; // 用户ID存储键名
  static const String userEmailKey = 'user_email'; // 用户邮箱存储键名
  static const String userNameKey = 'user_name'; // 用户名称存储键名
  static const String syncedConversationsKey =
      'synced_conversations_json'; // 同步会话存储键名

  // 安全加密配置
  /// 备用加密密钥，仅在无法获取设备密钥时使用
  /// 正常情况下，系统会使用 DeviceKeyGenerator 生成的设备唯一密钥
  static const String fallbackEncryptionKey = 'jintongshu_secure_key_12345';

  /// 设备ID存储键名
  static const String deviceIdStorageKey = 'device_id_key';

  /// 安全盐值存储键名
  static const String saltStorageKey = 'security_salt_key';

  /// 设备信息存储键名
  static const String deviceInfoStorageKey = 'device_info';

  // API路径配置
  static const List<String> publicApiPaths = [
    // 这里定义不需要认证的公开API路径
    '/auth/login',
    '/auth/register',
    '/auth/verify-code',
    '/auth/reset-password',
  ];
}
