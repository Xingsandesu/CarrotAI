// 存储工厂类
// 统一管理所有存储实例

import 'package:carrot/core/storage/secure_storage_manager.dart';
import 'package:carrot/core/storage/client/conversation_storage.dart';
import 'package:carrot/core/storage/client/config_storage.dart';
import 'package:carrot/core/storage/client/app_storage.dart';

/// 存储工厂类
///
/// 单例模式，统一管理所有存储实例
class StorageFactory {
  // 单例实例
  static final StorageFactory _instance = StorageFactory._internal();

  // 存储实例缓存
  SecureStorageManager? _secureStorage;
  ConversationStorage? _conversationStorage;
  ConfigStorage? _configStorage;
  AppStorage? _appStorage;

  // 私有构造函数
  StorageFactory._internal();

  // 工厂构造函数
  factory StorageFactory() {
    return _instance;
  }

  /// 获取安全存储实例
  Future<SecureStorageManager> getSecureStorage() async {
    _secureStorage ??= await SecureStorageManager.getInstance();
    return _secureStorage!;
  }

  /// 获取会话存储实例
  Future<ConversationStorage> getConversationStorage() async {
    _conversationStorage ??= await ConversationStorage.getInstance();
    return _conversationStorage!;
  }

  /// 获取配置存储实例
  Future<ConfigStorage> getConfigStorage() async {
    _configStorage ??= await ConfigStorage.getInstance();
    return _configStorage!;
  }

  /// 获取应用存储实例
  Future<AppStorage> getAppStorage() async {
    _appStorage ??= await AppStorage.getInstance();
    return _appStorage!;
  }
}

// 全局实例，方便访问
final storageFactory = StorageFactory();
