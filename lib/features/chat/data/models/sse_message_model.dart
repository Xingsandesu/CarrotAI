import 'dart:convert';

/// 用于解析 SSE `data:` 块内容的模型
class SseMessage {
  final String content;
  final String? reasoningContent; // 根据后端测试输出添加，可能为空
  final List<Map<String, dynamic>>? toolCalls; // 根据后端测试输出添加，可能为空
  final String? error; // 新增：用于存储来自后端的错误信息

  SseMessage({
    required this.content,
    this.reasoningContent,
    this.toolCalls,
    this.error,
  });

  factory SseMessage.fromJson(String jsonStr) {
    try {
      final Map<String, dynamic> data = json.decode(jsonStr);

      return SseMessage(
        content: data['content'] ?? '',
        error: data['error'],
        reasoningContent: data['reasoning_content'],
        toolCalls:
            data['tool_calls'] != null
                ? List<Map<String, dynamic>>.from(data['tool_calls'])
                : null,
      );
    } catch (e) {
      // 处理特殊的[DONE]消息
      if (jsonStr.trim() == '[DONE]') {
        return SseMessage(content: '[DONE]');
      }

      // 返回错误消息
      return SseMessage(content: '', error: '解析SSE消息失败: $e, 原始消息: $jsonStr');
    }
  }
}
