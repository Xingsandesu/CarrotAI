// 同步API客户端
// 处理所有与会话同步相关的API请求

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:carrot/core/api/http_service.dart';
import 'package:carrot/shared/models/__export.dart';

/// 同步API客户端
class SyncApiClient {
  final HttpService _httpService;

  SyncApiClient({HttpService? httpService})
    : _httpService = httpService ?? HttpService();

  /// 获取用户会话
  /// 从服务器获取用户的所有会话，用于初始加载
  Future<ApiResponse<SyncResponse>> fetchConversations() async {
    try {
      final response = await _httpService.get('/sync/conversations');

      return _httpService.handleStandardResponse<SyncResponse>(
        response,
        dataFromJson:
            (data) => SyncResponse.fromJson(data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      debugPrint('获取会话Dio错误: ${e.message}');
      return _httpService.handleDioError<SyncResponse>(e);
    } catch (e) {
      debugPrint('获取会话通用错误: $e');
      return ApiResponse<SyncResponse>(
        success: false,
        message: '获取会话失败: $e',
        error: ApiError(message: '获取会话失败: $e'),
      );
    }
  }

  /// 同步会话
  /// 增量同步用户会话数据，客户端发送自上次同步后的会话，服务器处理并返回更新后的数据
  Future<ApiResponse<SyncResponse>> syncConversations(
    SyncRequest request,
  ) async {
    try {
      final response = await _httpService.post(
        '/sync/conversations',
        data: request.toJson(),
      );

      return _httpService.handleStandardResponse<SyncResponse>(
        response,
        dataFromJson:
            (data) => SyncResponse.fromJson(data as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      debugPrint('同步会话Dio错误: ${e.message}');
      return _httpService.handleDioError<SyncResponse>(e);
    } catch (e) {
      debugPrint('同步会话通用错误: $e');
      return ApiResponse<SyncResponse>(
        success: false,
        message: '同步会话失败: $e',
        error: ApiError(message: '同步会话失败: $e'),
      );
    }
  }

  /// 删除指定会话
  Future<ApiResponse<void>> deleteConversation(String conversationId) async {
    try {
      final response = await _httpService.delete(
        '/sync/conversations/$conversationId',
      );

      return _httpService.handleStandardResponse<void>(response);
    } on DioException catch (e) {
      debugPrint('删除会话Dio错误: ${e.message}');
      return _httpService.handleDioError<void>(e);
    } catch (e) {
      debugPrint('删除会话通用错误: $e');
      return ApiResponse<void>(
        success: false,
        message: '删除会话失败: $e',
        error: ApiError(message: '删除会话失败: $e'),
      );
    }
  }

  /// 删除所有会话
  Future<ApiResponse<void>> deleteAllConversations({
    bool confirm = false,
  }) async {
    try {
      final request = DeleteAllConversationsRequest(confirm: confirm);
      final response = await _httpService.delete(
        '/sync/conversations',
        data: request.toJson(),
      );

      return _httpService.handleStandardResponse<void>(response);
    } on DioException catch (e) {
      debugPrint('删除所有会话Dio错误: ${e.message}');
      return _httpService.handleDioError<void>(e);
    } catch (e) {
      debugPrint('删除所有会话通用错误: $e');
      return ApiResponse<void>(
        success: false,
        message: '删除所有会话失败: $e',
        error: ApiError(message: '删除所有会话失败: $e'),
      );
    }
  }
}
