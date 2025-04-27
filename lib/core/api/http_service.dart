// 这个文件是 HttpService，用于发送请求到后端
// 它使用 Dio 发送请求
// 它使用 AuthInterceptor 在请求中添加认证信息 @auth_interceptor.dart
// 它使用 LogInterceptor 记录请求和响应
// 它使用 handleStandardResponse 处理后端标准响应格式 @api_response.dart
// 它使用 handleDioError 处理 DioException

import 'dart:convert';
import 'dart:async'; // Ensure dart:async is imported for StreamTransformer
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:carrot/core/config/app_config.dart';
import 'package:carrot/shared/models/api_response.dart';
import 'package:carrot/core/api/auth_interceptor.dart';

class HttpService {
  final Dio _dio;

  HttpService() : _dio = Dio() {
    _dio.options.baseUrl = AppConfig.baseUrl;
    _dio.options.connectTimeout = Duration(
      seconds: AppConfig.connectionTimeoutSeconds,
    );
    _dio.options.receiveTimeout = Duration(
      seconds: AppConfig.receiveTimeoutSeconds,
    );

    _dio.interceptors.add(AuthInterceptor());
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: false, // 设置为false，不记录流式响应体（这会很大）
        logPrint: (o) => debugPrint(o.toString()),
      ),
    );
  }

  Future<Response> get(String endpoint) async {
    try {
      final response = await _dio.get(endpoint);
      return response;
    } on DioException catch (e) {
      debugPrint('Dio GET错误: $e');
      rethrow;
    } catch (e) {
      debugPrint('通用GET错误: $e');
      rethrow;
    }
  }

  Future<Response> post(String endpoint, {dynamic data}) async {
    try {
      final response = await _dio.post(endpoint, data: data);
      return response;
    } on DioException catch (e) {
      debugPrint('Dio POST错误: $e');
      rethrow;
    } catch (e) {
      debugPrint('通用POST错误: $e');
      rethrow;
    }
  }

  Future<Response> put(String endpoint, {dynamic data}) async {
    try {
      final response = await _dio.put(endpoint, data: data);
      return response;
    } on DioException catch (e) {
      debugPrint('Dio PUT错误: $e');
      rethrow;
    } catch (e) {
      debugPrint('通用PUT错误: $e');
      rethrow;
    }
  }

  Future<Response> delete(String endpoint, {dynamic data}) async {
    try {
      final response = await _dio.delete(endpoint, data: data);
      return response;
    } on DioException catch (e) {
      debugPrint('Dio DELETE错误: $e');
      rethrow;
    } catch (e) {
      debugPrint('通用DELETE错误: $e');
      rethrow;
    }
  }

  Future<Response> postForm(
    String endpoint, {
    required Map<String, String> data,
  }) async {
    try {
      final response = await _dio.post(
        endpoint,
        data: FormData.fromMap(data),
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return response;
    } on DioException catch (e) {
      debugPrint('Dio POST表单错误: $e');
      rethrow;
    } catch (e) {
      debugPrint('通用POST表单错误: $e');
      rethrow;
    }
  }

  // 处理流式响应（Server-Sent Events）
  Stream<String> getStream(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    options ??= Options();
    options.responseType = ResponseType.stream;

    // 添加调试日志
    debugPrint('发起SSE请求: $endpoint');
    if (data != null) {
      debugPrint('请求数据: ${jsonEncode(data)}');
    }

    return Stream.fromFuture(
      _dio.post(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    ).asyncExpand((response) {
      debugPrint('收到SSE流响应 [${response.statusCode}]');
      // 确保流类型正确处理
      final stream = response.data.stream as Stream<Uint8List>;

      // 使用StreamTransformer.fromBind进行更可靠的类型处理
      return stream
          .transform(StreamTransformer.fromBind(utf8.decoder.bind))
          // 添加调试日志，显示原始解码数据
          .map((decodedChunk) {
            final trimmedChunk = decodedChunk.trim();
            if (trimmedChunk.isNotEmpty) {
              debugPrint(
                'SSE原始数据块: ${trimmedChunk.length > 200 ? '${trimmedChunk.substring(0, 200)}...' : trimmedChunk}',
              );
            }
            return decodedChunk;
          })
          .transform(const LineSplitter())
          // 过滤并提取有效的SSE数据行
          .where((line) {
            final valid = line.isNotEmpty && line.startsWith("data: ");
            if (!valid && line.isNotEmpty) {
              debugPrint('忽略非data行: $line');
            }
            return valid;
          })
          .map((line) {
            final content = line.substring(6); // 移除 "data: " 前缀
            debugPrint(
              '处理SSE数据: ${content.length > 100 ? '${content.substring(0, 100)}...' : content}',
            );
            return content;
          });
    });
  }

  // 处理标准响应格式
  ApiResponse<T> handleStandardResponse<T>(
    Response response, {
    T Function(dynamic)? dataFromJson,
  }) {
    try {
      final responseBody = response.data;

      // 检查响应是否为JSON格式
      if (responseBody is Map<String, dynamic>) {
        // 使用标准响应格式解析
        return ApiResponse<T>.fromStandardJson(
          responseBody,
          dataFromJson: dataFromJson,
        );
      } else {
        debugPrint("非预期的响应体格式: $responseBody");
        return ApiResponse<T>(
          success: false,
          message: "响应格式错误",
          error: ApiError(message: "响应格式错误: $responseBody"),
        );
      }
    } catch (e) {
      debugPrint("响应处理错误: $e");
      return ApiResponse<T>(
        success: false,
        message: "处理响应数据失败: $e",
        error: ApiError(message: "处理响应数据失败: $e"),
      );
    }
  }

  ApiResponse<T> handleDioError<T>(DioException e) {
    debugPrint('处理Dio错误: ${e.type} - ${e.message}');
    String errorMessage;
    int? statusCode = e.response?.statusCode;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        errorMessage = "网络连接超时，请检查网络连接并重试";
        break;
      case DioExceptionType.badResponse:
        if (e.response?.data is Map<String, dynamic>) {
          final responseData = e.response!.data as Map<String, dynamic>;
          // 尝试从标准响应格式中提取错误信息
          if (responseData.containsKey('message')) {
            errorMessage = responseData['message'];
          } else {
            errorMessage = responseData['detail'] ?? '服务器错误';
          }
        } else {
          errorMessage = "服务器返回错误: ${e.response?.statusCode}";
        }
        break;
      case DioExceptionType.cancel:
        errorMessage = "请求已取消";
        break;
      case DioExceptionType.connectionError:
        errorMessage = "网络连接错误，请检查网络连接";
        break;
      case DioExceptionType.unknown:
      default:
        errorMessage = "发生未知错误: ${e.message}";
        break;
    }

    return ApiResponse<T>(
      success: false,
      message: errorMessage,
      error: ApiError(message: errorMessage, code: statusCode),
    );
  }
}
