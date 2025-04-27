// 这个文件是 ApiClientFactory，用于创建和管理所有API客户端
// 集中处理所有API调用的统一入口

import 'package:carrot/core/api/http_service.dart';
import 'package:carrot/core/api/client/auth_api_client.dart';
import 'package:carrot/core/api/client/chat_api_client.dart';
import 'package:carrot/core/api/client/sync_api_client.dart';
import 'package:carrot/core/api/client/user_api_client.dart';
import 'package:carrot/core/api/client/config_api_client.dart';
import 'package:carrot/core/api/client/app_api_client.dart';

/// API客户端工厂
/// 单例模式，确保整个应用只有一个实例
class ApiClientFactory {
  // 单例实例
  static final ApiClientFactory _instance = ApiClientFactory._internal();

  // 内部构造函数
  ApiClientFactory._internal();

  // 工厂构造函数
  factory ApiClientFactory() {
    return _instance;
  }

  // HTTP服务实例
  final HttpService _httpService = HttpService();

  // 客户端缓存
  AuthApiClient? _authApiClient;
  ChatApiClient? _chatApiClient;
  SyncApiClient? _syncApiClient;
  UserApiClient? _userApiClient;
  ConfigApiClient? _configApiClient;
  AppApiClient? _appApiClient;

  /// 获取认证API客户端
  AuthApiClient get authApiClient {
    _authApiClient ??= AuthApiClient();
    return _authApiClient!;
  }

  /// 获取聊天API客户端
  ChatApiClient get chatApiClient {
    _chatApiClient ??= ChatApiClient(httpService: _httpService);
    return _chatApiClient!;
  }

  /// 获取同步API客户端
  SyncApiClient get syncApiClient {
    _syncApiClient ??= SyncApiClient(httpService: _httpService);
    return _syncApiClient!;
  }

  /// 获取用户API客户端
  UserApiClient get userApiClient {
    _userApiClient ??= UserApiClient(httpService: _httpService);
    return _userApiClient!;
  }

  /// 获取配置API客户端
  ConfigApiClient get configApiClient {
    _configApiClient ??= ConfigApiClient(_httpService);
    return _configApiClient!;
  }

  /// 获取应用API客户端
  AppApiClient get appApiClient {
    _appApiClient ??= AppApiClient(httpService: _httpService);
    return _appApiClient!;
  }

  /// 获取HTTP服务实例
  HttpService get httpService => _httpService;
}

// 全局实例，方便访问
final apiClientFactory = ApiClientFactory();
