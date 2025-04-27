// 这个文件实现聊天消息模型，对应后端的ChatMessage schema

/// 聊天消息模型类
///
/// 表示聊天中的单个消息，包含角色和内容
/// 角色可以是：user（用户）, assistant（助手）, system（系统）
class ChatMessage {
  final String role;
  final String content;

  /// 可选的工具调用信息
  final List<Map<String, dynamic>>? toolCalls;

  /// 可选的深度思考内容
  final String? reasoningContent;

  ChatMessage({
    required this.role,
    required this.content,
    this.toolCalls,
    this.reasoningContent,
  });

  /// 从JSON/Map创建ChatMessage对象
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      toolCalls:
          json['tool_calls'] != null
              ? List<Map<String, dynamic>>.from(json['tool_calls'])
              : null,
      reasoningContent: json['reasoning_content'] as String?,
    );
  }

  /// 将ChatMessage对象转换为JSON/Map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {'role': role, 'content': content};

    if (toolCalls != null) {
      data['tool_calls'] = toolCalls;
    }

    if (reasoningContent != null) {
      data['reasoning_content'] = reasoningContent;
    }

    return data;
  }

  /// 创建用户消息
  static ChatMessage user(String content) {
    return ChatMessage(role: 'user', content: content);
  }

  /// 创建助手消息
  static ChatMessage assistant(
    String content, {
    List<Map<String, dynamic>>? toolCalls,
    String? reasoningContent,
  }) {
    return ChatMessage(
      role: 'assistant',
      content: content,
      toolCalls: toolCalls,
      reasoningContent: reasoningContent,
    );
  }

  /// 创建系统消息
  static ChatMessage system(String content) {
    return ChatMessage(role: 'system', content: content);
  }
}
