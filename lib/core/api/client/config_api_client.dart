import 'dart:developer'; // Import developer log
import 'package:carrot/core/api/http_service.dart';
import 'package:carrot/shared/models/api_response.dart';

/// 配置相关的 API 客户端
class ConfigApiClient {
  final HttpService _httpService;

  ConfigApiClient(this._httpService);

  /// 获取模型配置列表
  /// 参数 [lang] 指定语言代码，默认为空，使用系统语言
  Future<List<Map<String, dynamic>>> getModelConfigs({String? lang}) async {
    try {
      // 构建请求URL，如果指定了语言，则添加语言参数
      final url = lang != null ? '/config/models?lang=$lang' : '/config/models';
      final response = await _httpService.get(url);

      // 检查响应数据是否是 Map 类型
      if (response.data is Map<String, dynamic>) {
        final responseData = response.data as Map<String, dynamic>;
        // 检查 'result' 字段是否存在且为 List 类型
        if (responseData.containsKey('result') &&
            responseData['result'] is List) {
          final data = responseData['result'] as List;
          // 将 List<dynamic> 转换为 List<Map<String, dynamic>>
          return data.map((item) => item as Map<String, dynamic>).toList();
        } else {
          // 如果 'result' 字段不存在或类型不正确，则抛出异常
          throw Exception('未能获取模型配置数据，响应格式缺少 "result" 列表');
        }
      } else {
        // 如果响应数据不是 Map 类型，则抛出异常
        throw Exception('未能获取模型配置数据，响应格式不正确');
      }
    } catch (e, stackTrace) {
      // Capture stack trace for better logging
      // 使用 log 替换 print
      log(
        '获取模型配置失败',
        error: e,
        stackTrace: stackTrace,
        name: 'ConfigApiClient',
      );
      rethrow; // 重新抛出异常，让调用者处理
    }
  }

  /// 获取版本信息
  /// 参数 [lang] 指定语言代码，默认为空，使用系统语言
  Future<ApiResponse<Map<String, dynamic>>> getVersionInfo({
    String? lang,
  }) async {
    try {
      // 仅针对 Web 平台
      const platformType = 'web';
      var url = '/config/version?platform_type=$platformType';
      if (lang != null) {
        url += '&lang=$lang';
      }

      final response = await _httpService.get(url);
      return _httpService.handleStandardResponse<Map<String, dynamic>>(
        response,
        dataFromJson: (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      log('获取版本信息失败', error: e, name: 'ConfigApiClient');
      if (e is Exception) {
        return _httpService.handleDioError<Map<String, dynamic>>(e as dynamic);
      }
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: '获取版本信息失败: $e',
        error: ApiError(message: '获取版本信息失败: $e'),
      );
    }
  }
}
