// 这个文件实现聊天请求模型，对应后端的ChatRequest schema

import 'chat_message.dart';

/// 聊天请求模型类
///
/// 表示发送到后端的聊天请求数据结构
class ChatRequest {
  /// 当前消息
  final ChatMessage currentMessage;

  /// 上下文消息列表
  final List<ChatMessage> contextMessages;

  /// 使用的模型，如 "deepseek"
  final String model;

  /// 是否使用深度思考模式
  final bool useDeepThinking;

  /// 是否使用MCP（可能是自定义处理器）
  final bool useMcp;

  /// 是否使用基础工具
  final bool useBaseTools;

  /// 用户自定义MCP配置
  final Map<String, dynamic>? userMcpConfig;

  /// 模型温度参数，控制输出的随机性
  final double? temperature;

  /// 指定使用的MCP服务器名称
  final String? mcpServerName;

  /// 上下文长度，控制发送API时只使用最后N条消息作为上下文
  final int contextLength;

  ChatRequest({
    required this.currentMessage,
    this.contextMessages = const [],
    required this.model,
    this.useDeepThinking = false,
    this.useMcp = true,
    this.useBaseTools = true,
    this.userMcpConfig,
    this.temperature,
    this.mcpServerName,
    this.contextLength = 5,
  });

  /// 将ChatRequest对象转换为JSON/Map
  Map<String, dynamic> toJson() {
    return {
      'current_message': currentMessage.toJson(),
      'context_messages': contextMessages.map((e) => e.toJson()).toList(),
      'model': model,
      'use_deep_thinking': useDeepThinking,
      'use_mcp': useMcp,
      'use_base_tools': useBaseTools,
      if (userMcpConfig != null) 'user_mcp_config': userMcpConfig,
      if (temperature != null) 'temperature': temperature,
      if (mcpServerName != null) 'mcp_server_name': mcpServerName,
      'context_length': contextLength,
    };
  }
}
