// 认证提供者
// 负责管理认证状态和处理认证相关操作

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carrot/core/api/api_client_factory.dart';
import 'package:carrot/shared/models/__export.dart';
import 'package:carrot/core/storage/__export.dart';
import 'package:carrot/core/config/app_config.dart';

/// 认证状态管理提供者
///
/// 使用ChangeNotifier管理认证状态，提供登录、登出等功能
class AuthProvider with ChangeNotifier {
  // 使用工厂获取 AuthApiClient
  final _authApiClient = apiClientFactory.authApiClient;
  // 使用安全存储管理器
  late SecureStorageManager _secureStorage;
  // SharedPreferences 用于存储非敏感信息
  late SharedPreferences _prefs;

  String? _token;
  User? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  String? get token => _token;
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _initialize();
  }

  /// 初始化时尝试从本地存储加载Token和用户信息
  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 初始化安全存储管理器
      _secureStorage = await SecureStorageManager.getInstance();
      _prefs = await SharedPreferences.getInstance();

      // 尝试从SharedPreferences读取用户基本信息
      final userId = _prefs.getInt(AppConfig.userIdKey);
      final userEmail = _prefs.getString(AppConfig.userEmailKey);
      final userName = _prefs.getString(AppConfig.userNameKey);

      debugPrint(
        "从SharedPreferences读取用户信息: ID=$userId, Email=$userEmail, Name=$userName",
      );

      // 尝试从安全存储读取令牌
      _token = await _secureStorage.read(AppConfig.tokenStorageKey);
      debugPrint("从安全存储读取令牌: ${_token != null ? '成功' : '未找到'}");

      // 如果有令牌和基本用户信息，可以先恢复用户状态
      if (_token != null &&
          userId != null &&
          userEmail != null &&
          userName != null) {
        // 从本地存储恢复用户对象
        _user = User(id: userId, email: userEmail, name: userName);
        debugPrint("已从本地存储恢复用户状态: ${_user?.email}");

        // 异步验证令牌，但不阻塞UI初始化
        _validateTokenAsync();
      } else if (_token != null) {
        debugPrint("有令牌但缺少用户信息，尝试获取用户资料");
        // 有令牌但没有完整的用户信息，尝试获取用户资料
        try {
          final profileResponse = await _authApiClient.getCurrentUserProfile();
          if (profileResponse.success && profileResponse.data != null) {
            _user = profileResponse.data;

            // 保存用户信息到SharedPreferences
            await _prefs.setInt(AppConfig.userIdKey, _user!.id);
            await _prefs.setString(AppConfig.userEmailKey, _user!.email);
            await _prefs.setString(AppConfig.userNameKey, _user!.name);

            debugPrint("成功获取并保存用户资料: ${_user?.email}");
          } else {
            // 令牌无效，清除
            debugPrint("令牌验证失败，清除令牌");
            _token = null;
            _user = null;
            await _secureStorage.delete(AppConfig.tokenStorageKey);
          }
        } catch (e) {
          // 网络错误，但保留令牌
          debugPrint("获取用户资料出错，但保留令牌以便稍后重试: $e");
          // 不设置_user，这样isAuthenticated会返回false
        }
      } else {
        debugPrint("未找到令牌，用户未登录");
        // 没有令牌，确保是登出状态
        _token = null;
        _user = null;
      }
    } catch (e) {
      debugPrint("初始化认证提供者时出错: $e");
      // 出错时确保用户处于登出状态
      _token = null;
      _user = null;
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// 异步验证令牌
  ///
  /// 在后台验证令牌，不阻塞UI初始化
  Future<void> _validateTokenAsync() async {
    // 延迟一段时间再验证，避免应用启动时的网络压力
    await Future.delayed(const Duration(seconds: 2));

    try {
      debugPrint("开始异步验证令牌");
      final profileResponse = await _authApiClient.getCurrentUserProfile();
      if (profileResponse.success && profileResponse.data != null) {
        // 更新用户信息
        _user = profileResponse.data;
        debugPrint("异步令牌验证成功，已更新用户信息");
        notifyListeners();
      } else {
        // 令牌无效，但不立即登出
        debugPrint("异步令牌验证失败，令牌可能已过期");
        // 在用户下次交互时再处理登出
      }
    } catch (e) {
      // 网络错误，记录但不做处理
      debugPrint("异步验证令牌时出错: $e");
    }
  }

  /// 用户登录
  ///
  /// [email] 用户邮箱
  /// [password] 用户密码
  /// [onLoginSuccess] 可选的登录成功回调，用于通知其他组件登录成功
  Future<bool> login(
    String email,
    String password, {
    Function? onLoginSuccess,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authApiClient.login(email, password);

      if (response.success && response.data != null) {
        final responseData = response.data!;

        _token = responseData['token'];
        final userMap = responseData['user'];
        final conversations = responseData['conversations']; // 获取会话数据
        _user = User.fromJson(userMap);

        // 存储到本地
        await _secureStorage.write(AppConfig.tokenStorageKey, _token);
        // 存储非敏感信息到SharedPreferences
        await _prefs.setInt(AppConfig.userIdKey, _user!.id);
        await _prefs.setString(AppConfig.userEmailKey, _user!.email);
        await _prefs.setString(AppConfig.userNameKey, _user!.name);

        // 存储同步的聊天记录
        if (conversations != null && conversations is List) {
          final conversationsJson = jsonEncode(conversations);
          await _prefs.setString(
            AppConfig.syncedConversationsKey,
            conversationsJson,
          );
          debugPrint("Synced conversations stored in SharedPreferences.");
        } else {
          await _prefs.remove(AppConfig.syncedConversationsKey);
          debugPrint("No valid synced conversations found in response.");
        }

        debugPrint(
          "Login successful. Token securely stored. User: ${_user?.email}",
        );

        _isLoading = false;
        notifyListeners();

        // 调用登录成功回调，通知其他组件（如ChatProvider）登录成功
        if (onLoginSuccess != null) {
          onLoginSuccess();
        }

        return true;
      } else {
        _errorMessage = response.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 用户登出
  /// 清除所有本地存储的用户数据和设置
  /// [onLogoutCallback] 可选的注销回调，用于通知其他组件（如ChatProvider）清除数据
  Future<void> logout({Function? onLogoutCallback}) async {
    debugPrint("Logging out...");
    _token = null;
    _user = null;
    _errorMessage = null;

    // 0. 如果有注销回调，先调用它来清除其他组件的数据
    // 这样可以确保其他组件（如ChatProvider）先清除它们的数据
    if (onLogoutCallback != null) {
      await onLogoutCallback();
    }

    // 1. 清除所有安全存储的数据
    await _secureStorage.deleteAll();
    debugPrint("All secure storage data cleared");

    // 2. 清除所有SharedPreferences数据
    // 包括用户数据、会话数据、设置数据等
    final keys = _prefs.getKeys();
    for (final key in keys) {
      await _prefs.remove(key);
    }
    debugPrint("All SharedPreferences data cleared: ${keys.length} keys");

    // 3. 通知监听器更新UI
    notifyListeners();

    debugPrint("Logout complete, all local data cleared");
  }

  /// 清除错误消息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 重新初始化认证提供者
  ///
  /// 当应用需要重新加载认证状态时调用
  Future<void> reinitialize() async {
    debugPrint("重新初始化认证提供者");
    _isInitialized = false;
    _isLoading = true;
    notifyListeners();

    await _initialize();
  }

  /// 刷新认证状态
  ///
  /// 当应用从后台返回前台时调用，验证令牌是否有效
  Future<void> refreshAuthState() async {
    // 如果没有令牌，尝试从存储中读取
    if (_token == null) {
      debugPrint("刷新认证状态: 没有令牌，尝试从存储中读取");

      try {
        // 尝试从安全存储读取令牌
        final storedToken = await _secureStorage.read(
          AppConfig.tokenStorageKey,
        );

        if (storedToken != null) {
          debugPrint("刷新认证状态: 从存储中找到令牌，尝试验证");
          _token = storedToken;

          // 尝试从SharedPreferences读取用户基本信息
          final userId = _prefs.getInt(AppConfig.userIdKey);
          final userEmail = _prefs.getString(AppConfig.userEmailKey);
          final userName = _prefs.getString(AppConfig.userNameKey);

          // 如果有基本用户信息，先恢复用户状态
          if (userId != null && userEmail != null && userName != null) {
            _user = User(id: userId, email: userEmail, name: userName);
            debugPrint("刷新认证状态: 已从本地存储恢复用户状态");
            notifyListeners();
          }
        } else {
          debugPrint("刷新认证状态: 存储中没有令牌");
          return;
        }
      } catch (e) {
        debugPrint("刷新认证状态: 读取存储时出错: $e");
        return;
      }
    }

    debugPrint("刷新认证状态: 验证令牌有效性");

    try {
      // 尝试获取用户信息以验证令牌
      final profileResponse = await _authApiClient.getCurrentUserProfile();
      if (profileResponse.success && profileResponse.data != null) {
        // 令牌有效，更新用户信息
        _user = profileResponse.data;

        // 确保用户信息保存到SharedPreferences
        await _prefs.setInt(AppConfig.userIdKey, _user!.id);
        await _prefs.setString(AppConfig.userEmailKey, _user!.email);
        await _prefs.setString(AppConfig.userNameKey, _user!.name);

        debugPrint("刷新认证状态: 令牌有效，已更新用户信息");
        notifyListeners();
      } else {
        // 令牌无效，但不立即登出
        debugPrint("刷新认证状态: 令牌无效，但保留令牌");
        // 在用户下次交互时再处理登出
      }
    } catch (e) {
      // 网络错误或其他问题，记录错误但不登出
      // 避免因为临时网络问题导致用户被登出
      debugPrint("刷新认证状态出错: $e");
    }
  }
}
