// 用户API客户端
// 处理所有与用户信息相关的API请求

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:carrot/core/api/http_service.dart';
import 'package:carrot/shared/models/__export.dart';

/// 用户API客户端
class UserApiClient {
  final HttpService _httpService;

  UserApiClient({HttpService? httpService})
    : _httpService = httpService ?? HttpService();

  /// 获取当前用户信息
  Future<ApiResponse<Map<String, dynamic>>> getCurrentUser() async {
    try {
      final response = await _httpService.get('/users/me');

      return _httpService.handleStandardResponse<Map<String, dynamic>>(
        response,
        dataFromJson: (data) {
          // 确保返回数据包含用户信息和Token使用情况
          final Map<String, dynamic> result = {};

          if (data is Map<String, dynamic>) {
            // 处理用户信息
            if (data.containsKey('user')) {
              result['user'] = data['user'];
            }

            // 处理Token使用情况
            if (data.containsKey('token_usage')) {
              result['token_usage'] = data['token_usage'];
            }

            return result;
          }

          return data as Map<String, dynamic>;
        },
      );
    } on DioException catch (e) {
      debugPrint('获取用户信息Dio错误: ${e.message}');
      return _httpService.handleDioError<Map<String, dynamic>>(e);
    } catch (e) {
      debugPrint('获取用户信息通用错误: $e');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: '获取用户信息失败: $e',
        error: ApiError(message: '获取用户信息失败: $e'),
      );
    }
  }

  /// 更新当前用户密码
  Future<ApiResponse<void>> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final data = {
        'current_password': currentPassword,
        'new_password': newPassword,
      };

      final response = await _httpService.put('/users/me/password', data: data);

      return _httpService.handleStandardResponse<void>(response);
    } on DioException catch (e) {
      debugPrint('更新密码Dio错误: ${e.message}');
      return _httpService.handleDioError<void>(e);
    } catch (e) {
      debugPrint('更新密码通用错误: $e');
      return ApiResponse<void>(
        success: false,
        message: '更新密码失败: $e',
        error: ApiError(message: '更新密码失败: $e'),
      );
    }
  }
}
