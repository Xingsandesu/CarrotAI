//
// 这个文件是 AuthInterceptor，用于在请求中添加认证信息
// 它使用 SecureStorageManager 存储敏感信息如 JWT Token
// 它还使用 ChangeNotifier 来管理认证状态
//

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carrot/core/storage/secure_storage_manager.dart';
import 'package:carrot/core/providers/auth_provider.dart';
import 'package:carrot/core/services/global_service.dart'; // 将创建这个服务来管理全局状态
import 'package:carrot/features/home/providers/chat_provider.dart'; // 导入ChatProvider
import 'package:carrot/core/config/app_config.dart'; // 导入AppConfig

class AuthInterceptor extends Interceptor {
  late SecureStorageManager _secureStorage;
  bool _isInitialized = false;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      _secureStorage = await SecureStorageManager.getInstance();
      _isInitialized = true;
    }
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 确保存储管理器已初始化
    await _ensureInitialized();

    // 检查路径是否在公开API列表中
    final isPublicPath = _isPublicApiPath(options.path);

    // 检查请求是否需要认证
    // 只有公开API路径不需要认证
    // 注意：/config/models 不是公开API，需要认证
    final needsAuth = !isPublicPath;

    if (needsAuth) {
      final token = await _secureStorage.read('auth_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
        debugPrint(
          'Interceptor: Added auth token to header for ${options.path}',
        );
      } else {
        debugPrint(
          'Interceptor: No auth token found for ${options.path}, sending request without token',
        );
        // 如果是需要认证的路径但没有令牌，可以选择中断请求
        // 但对于公开API，我们允许其继续请求
        // return handler.reject(DioException(requestOptions: options, error: 'Auth Token Not Found'));
      }
    } else if (isPublicPath) {
      // 如果是公开API路径，记录日志
      debugPrint(
        'Interceptor: ${options.path} is a public API path, no auth needed',
      );
    }

    // 继续请求
    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // 可以在这里处理响应，例如统一处理成功日志
    debugPrint(
      'Interceptor response: ${response.requestOptions.method} ${response.requestOptions.path} -> ${response.statusCode}',
    );
    super.onResponse(response, handler);
  }

  // 检查路径是否在公开API列表中
  bool _isPublicApiPath(String path) {
    return AppConfig.publicApiPaths.any(
      (publicPath) => path.contains(publicPath),
    );
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 记录错误信息
    debugPrint(
      'Interceptor error: ${err.requestOptions.method} ${err.requestOptions.path} -> ${err.response?.statusCode} ${err.message}',
    );

    // 检查是否为401未授权错误（令牌过期或无效）
    if (err.response?.statusCode == 401) {
      final path = err.requestOptions.path;

      // 如果是公开API路径，不触发自动登出
      if (_isPublicApiPath(path)) {
        debugPrint(
          'Detected 401 error, but path $path is a public API, not triggering auto logout',
        );
      } else {
        // 如果是需要认证的API，触发自动登出
        // 注意：/config/models 不是公开API，需要认证，但我们不应该在未登录时触发自动登出
        // 所以我们需要检查用户是否已经登录
        final context = globalService.currentContext;
        if (context != null) {
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          if (authProvider.isAuthenticated) {
            debugPrint(
              'Detected 401 unauthorized error, user is logged in, token may have expired, triggering auto logout',
            );
            _handleTokenExpiration();
          } else {
            debugPrint(
              'Detected 401 unauthorized error, but user is not logged in, not triggering auto logout',
            );
          }
        } else {
          debugPrint('Unable to get context to handle token expiration');
        }
      }
    }

    // 继续错误处理
    super.onError(err, handler);
  }

  // 用于跟踪是否正在处理令牌过期，避免重复触发
  bool _isHandlingTokenExpiration = false;

  // 处理令牌过期的方法
  Future<void> _handleTokenExpiration() async {
    // 如果已经在处理令牌过期，则直接返回
    if (_isHandlingTokenExpiration) {
      debugPrint(
        'Already handling token expiration, ignoring duplicate request',
      );
      return;
    }

    _isHandlingTokenExpiration = true;

    try {
      // 使用全局服务获取上下文
      final context = globalService.currentContext;

      if (context != null) {
        // 获取AuthProvider和ChatProvider
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        // 检查是否已经登录，只有已登录的用户才需要执行登出
        if (authProvider.isAuthenticated) {
          final chatProvider = Provider.of<ChatProvider>(
            context,
            listen: false,
          );

          // 执行登出，并传入回调清除会话数据
          await authProvider.logout(
            onLogoutCallback: () => chatProvider.clearAllData(),
          );

          // 使用全局服务显示通知
          globalService.showSnackBar('Session expired, please login again');

          // 跳转到主页
          if (globalService.currentState != null) {
            globalService.navigateTo('/home');
          }
        } else {
          debugPrint('User is already logged out, no need to execute logout');
        }
      } else {
        debugPrint('Unable to get context to handle token expiration');
      }
    } catch (e) {
      debugPrint('Error handling token expiration: $e');
    } finally {
      // 无论成功失败，都重置状态
      _isHandlingTokenExpiration = false;
    }
  }
}
