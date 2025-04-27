import 'dart:async';
import 'package:carrot/core/api/http_service.dart';
import 'package:carrot/shared/models/chat_message.dart';
import 'package:carrot/core/api/api_client_factory.dart';
import 'package:flutter/foundation.dart';

class ChatRepository {
  // 使用全局的ApiClientFactory实例来获取HttpService，遵循现有模式
  final HttpService _httpService = apiClientFactory.httpService;

  /// 发送聊天消息并获取流式响应
  ///
  /// [currentMessage]: 当前用户发送的消息
  /// [contextMessages]: 上下文消息列表
  /// [useDeepThinking]: 是否启用深度思考
  /// [model]: 使用的模型 (例如 'deepseek')
  /// [useMcp]: 是否使用 MCP (根据后端测试脚本添加)
  /// [useBaseTools]: 是否使用基础工具 (根据后端测试脚本添加)
  /// [temperature]: 温度参数
  /// [contextLength]: 上下文长度限制
  /// [userMcpConfig]: 用户自定义MCP服务器配置
  Stream<String> sendChatMessageStream({
    required ChatMessage currentMessage,
    required List<ChatMessage> contextMessages,
    required bool useDeepThinking,
    String model = 'deepseek', // 默认值来自后端测试脚本
    bool useMcp = false,
    bool useBaseTools = false,
    double temperature = 0.7,
    int contextLength = 5,
    Map<String, dynamic>? userMcpConfig,
  }) {
    const String endpoint = '/chat/stream'; // 后端SSE端点

    final requestBody = {
      'current_message': currentMessage.toJson(),
      'context_messages': contextMessages.map((msg) => msg.toJson()).toList(),
      'model': model,
      'use_deep_thinking': useDeepThinking,
      'use_mcp': useMcp,
      'use_base_tools': useBaseTools,
      'temperature': temperature,
      'context_length': contextLength,
    };

    // 添加用户自定义MCP配置（如果有）
    if (userMcpConfig != null) {
      // 确保用户自定义MCP配置的格式正确
      // 后端需要的格式是一个对象，其中服务器名称作为键，对应的配置作为值
      // 例如：{"math-tools": {"url": "http://localhost:8001/sse", "env": {}}}
      Map<String, dynamic> formattedConfig = {};

      // 处理不同的配置格式
      userMcpConfig.forEach((key, value) {
        // 检查值是否是一个包含 url 字段的对象
        if (value is Map<String, dynamic> && value.containsKey('url')) {
          // 确保配置包含 env 字段
          if (!value.containsKey('env')) {
            value['env'] = {};
          }
          formattedConfig[key] = value;
        }
      });

      // 如果格式化后的配置不为空，则添加到请求体
      if (formattedConfig.isNotEmpty) {
        requestBody['user_mcp_config'] = formattedConfig;
        debugPrint("添加用户自定义MCP配置: ${formattedConfig.toString()}");
      }
    }

    debugPrint("准备发送请求，温度设置: $temperature");

    try {
      // 调用 HttpService 的 getStream 方法
      final stream = _httpService.getStream(endpoint, data: requestBody);
      debugPrint("聊天请求发送成功");
      return stream;
    } catch (e) {
      debugPrint('发送聊天消息流失败: $e');
      // 返回一个错误的流，让上层处理
      return Stream.error('发送聊天消息失败: $e');
    }
  }
}
