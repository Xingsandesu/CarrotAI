// 应用API客户端
// 处理所有与应用市场相关的API请求

import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:carrot/core/api/http_service.dart';
import 'package:carrot/shared/models/app_model.dart';
import 'package:carrot/shared/models/api_response.dart';

/// 应用API客户端
/// 处理应用市场相关的API请求
class AppApiClient {
  final HttpService _httpService;

  AppApiClient({HttpService? httpService})
    : _httpService = httpService ?? HttpService();

  /// 获取应用市场列表
  /// 参数 [lang] 指定语言代码，默认为空，使用系统语言
  Future<ApiResponse<List<AppModel>>> getApps({String? lang}) async {
    try {
      // 构建请求URL，如果指定了语言，则添加语言参数
      final url = lang != null ? '/config/apps?lang=$lang' : '/config/apps';
      final response = await _httpService.get(url);

      return _httpService.handleStandardResponse<List<AppModel>>(
        response,
        dataFromJson: (data) {
          if (data is List) {
            return data
                .map((item) => AppModel.fromJson(item as Map<String, dynamic>))
                .toList();
          }
          throw Exception('返回数据格式错误，预期为List但接收到: ${data.runtimeType}');
        },
      );
    } on DioException catch (e) {
      debugPrint('获取应用市场列表Dio错误: ${e.message}');
      return _httpService.handleDioError<List<AppModel>>(e);
    } catch (e, stackTrace) {
      log('获取应用市场列表失败', error: e, stackTrace: stackTrace, name: 'AppApiClient');
      return ApiResponse<List<AppModel>>(
        success: false,
        message: '获取应用市场列表失败: $e',
        error: ApiError(message: '获取应用市场列表失败: $e'),
      );
    }
  }
}
