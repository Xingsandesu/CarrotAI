//
// 这个文件是 ApiResponse，用于表示 API 响应
// 它适配后端的标准响应格式：{ status_code: 真实状态码, message: "消息", result: {} }
//

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final ApiError? error;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.error,
  });

  // 从后端标准格式的JSON创建ApiResponse
  factory ApiResponse.fromStandardJson(
    Map<String, dynamic> json, {
    T Function(dynamic)? dataFromJson,
  }) {
    // 获取状态码，成功范围为 200-299
    final int statusCode = json['status_code'] as int? ?? 500;
    final bool isSuccess = statusCode >= 200 && statusCode < 300;

    // 获取消息
    final String message =
        json['message'] as String? ?? (isSuccess ? '操作成功' : '操作失败');

    // 处理数据
    T? parsedData;
    if (json.containsKey('result') && json['result'] != null) {
      if (dataFromJson != null) {
        parsedData = dataFromJson(json['result']);
      } else {
        parsedData = json['result'] as T?;
      }
    }

    // 构建响应
    return ApiResponse<T>(
      success: isSuccess,
      message: message,
      data: parsedData,
      error: !isSuccess ? ApiError(message: message, code: statusCode) : null,
    );
  }
}

class ApiError {
  final String message;
  final int? code; // 状态码

  ApiError({required this.message, this.code});
}
