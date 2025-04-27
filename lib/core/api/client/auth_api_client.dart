// 聊天API客户端
// 处理所有与认证相关的API请求

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:carrot/core/api/http_service.dart';
import 'package:carrot/shared/models/__export.dart';

/// 认证API客户端
///
/// 处理登录、注册、密码重置等认证相关的API请求
class AuthApiClient {
  final HttpService _httpService;

  AuthApiClient({HttpService? httpService})
    : _httpService = httpService ?? HttpService();

  /// 用户登录
  ///
  /// [email] 用户邮箱
  /// [password] 用户密码
  Future<ApiResponse<Map<String, dynamic>>> login(
    String email,
    String password,
  ) async {
    try {
      // 注意：登录接口使用 x-www-form-urlencoded
      final response = await _httpService.postForm(
        '/auth/login',
        data: {
          'username': email, // 后端需要 username
          'password': password,
        },
      );

      // 使用标准响应处理器
      return _httpService.handleStandardResponse<Map<String, dynamic>>(
        response,
      );
    } on DioException catch (e) {
      // 捕获 DioException
      debugPrint("登录Dio错误: ${e.message}");
      return _httpService.handleDioError<Map<String, dynamic>>(e);
    } catch (e) {
      // 捕获其他通用错误
      debugPrint("登录通用错误: $e");
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: "登录请求时发生未知错误: $e",
        error: ApiError(message: "登录请求时发生未知错误: $e"),
      );
    }
  }

  /// 发送邮箱验证码
  ///
  /// [email] 用户邮箱
  Future<ApiResponse<void>> sendVerificationCode(String email) async {
    try {
      // 后端需要 JSON body
      final response = await _httpService.post(
        '/auth/send-verification-code',
        data: {'email': email},
      );
      // 使用标准响应处理器
      return _httpService.handleStandardResponse<void>(response);
    } on DioException catch (e) {
      debugPrint("发送验证码Dio错误: ${e.message}");
      return _httpService.handleDioError<void>(e);
    } catch (e) {
      debugPrint("发送验证码通用错误: $e");
      return ApiResponse<void>(
        success: false,
        message: "发送验证码时发生未知错误: $e",
        error: ApiError(message: "发送验证码时发生未知错误: $e"),
      );
    }
  }

  /// 注册新用户
  ///
  /// [email] 用户邮箱
  /// [username] 用户名
  /// [password] 密码
  /// [verificationCode] 验证码
  Future<ApiResponse<Map<String, dynamic>>> register({
    required String email,
    required String username,
    required String password,
    required String verificationCode,
  }) async {
    try {
      // 后端需要 UserCreate schema 对应的 JSON body
      final body = {
        'email': email,
        'username': username,
        'password': password,
        'verification_code': verificationCode,
      };
      final response = await _httpService.post('/auth/register', data: body);
      // 使用标准响应处理器
      return _httpService.handleStandardResponse<Map<String, dynamic>>(
        response,
      );
    } on DioException catch (e) {
      debugPrint("注册Dio错误: ${e.message}");
      return _httpService.handleDioError<Map<String, dynamic>>(e);
    } catch (e) {
      debugPrint("注册通用错误: $e");
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: "注册时发生未知错误: $e",
        error: ApiError(message: "注册时发生未知错误: $e"),
      );
    }
  }

  /// 请求密码重置
  ///
  /// [email] 用户邮箱
  Future<ApiResponse<void>> requestPasswordReset(String email) async {
    try {
      // 后端需要 PasswordResetRequest schema 对应的 JSON body
      final response = await _httpService.post(
        '/auth/password-reset-request',
        data: {'email': email},
      );
      // 使用标准响应处理器
      return _httpService.handleStandardResponse<void>(response);
    } on DioException catch (e) {
      debugPrint("密码重置请求Dio错误: ${e.message}");
      return _httpService.handleDioError<void>(e);
    } catch (e) {
      debugPrint("密码重置请求通用错误: $e");
      return ApiResponse<void>(
        success: false,
        message: "请求密码重置时发生未知错误: $e",
        error: ApiError(message: "请求密码重置时发生未知错误: $e"),
      );
    }
  }

  /// 确认密码重置
  ///
  /// [token] 重置令牌
  /// [newPassword] 新密码
  Future<ApiResponse<void>> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    try {
      // 后端需要 PasswordResetConfirm schema 对应的 JSON body
      final body = {'token': token, 'new_password': newPassword};
      final response = await _httpService.post(
        '/auth/password-reset-confirm',
        data: body,
      );
      // 使用标准响应处理器
      return _httpService.handleStandardResponse<void>(response);
    } on DioException catch (e) {
      debugPrint("密码重置确认Dio错误: ${e.message}");
      return _httpService.handleDioError<void>(e);
    } catch (e) {
      debugPrint("密码重置确认通用错误: $e");
      return ApiResponse<void>(
        success: false,
        message: "确认密码重置时发生未知错误: $e",
        error: ApiError(message: "确认密码重置时发生未知错误: $e"),
      );
    }
  }

  /// 获取当前用户信息
  ///
  /// 需要已登录状态
  Future<ApiResponse<User>> getCurrentUserProfile() async {
    try {
      final response = await _httpService.get('/users/me');
      // 使用标准响应处理器
      return _httpService.handleStandardResponse<User>(
        response,
        dataFromJson: (data) => User.fromJson(data), // 从 result 字段解析 User
      );
    } on DioException catch (e) {
      debugPrint("获取用户信息Dio错误: ${e.message}");
      return _httpService.handleDioError<User>(e);
    } catch (e) {
      debugPrint("获取用户信息通用错误: $e");
      return ApiResponse<User>(
        success: false,
        message: "获取用户信息失败: $e",
        error: ApiError(message: "获取用户信息失败: $e"),
      );
    }
  }
}
