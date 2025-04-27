// 聊天API客户端
// 处理所有与聊天相关的API请求

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:carrot/core/api/http_service.dart';
import 'package:carrot/shared/models/__export.dart';

/// 聊天API客户端
class ChatApiClient {
  final HttpService _httpService;

  ChatApiClient({HttpService? httpService})
    : _httpService = httpService ?? HttpService();

  /// 发送聊天请求并获取流式响应
  Stream<String> sendChatStream(ChatRequest request) {
    try {
      return _httpService.getStream('/chat/stream', data: request.toJson());
    } catch (e) {
      debugPrint('发送聊天请求时出错: $e');
      return Stream.error('发送聊天请求时出错: $e');
    }
  }

  /// 解析聊天流响应
  Stream<Map<String, dynamic>> parseChatStream(Stream<String> stream) {
    return stream.where((data) => data != '[DONE]').map((data) {
      try {
        return json.decode(data) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('解析聊天响应时出错: $e');
        return <String, dynamic>{'error': '解析聊天响应时出错: $e'};
      }
    });
  }

  /// 发送聊天请求并获取完整解析后的流式响应
  Stream<Map<String, dynamic>> chat(ChatRequest request) {
    return parseChatStream(sendChatStream(request));
  }

  /// 发送简单的聊天请求
  ///
  /// [message] 用户消息
  /// [contextMessages] 上下文消息列表
  /// [model] 模型名称，默认为 "deepseek"
  /// [useDeepThinking] 是否使用深度思考
  Stream<Map<String, dynamic>> sendMessage({
    required String message,
    List<ChatMessage> contextMessages = const [],
    String model = 'deepseek',
    bool useDeepThinking = false,
    bool useMcp = false,
    bool useBaseTools = false,
  }) {
    final request = ChatRequest(
      currentMessage: ChatMessage.user(message),
      contextMessages: contextMessages,
      model: model,
      useDeepThinking: useDeepThinking,
      useMcp: useMcp, // 默认关闭MCP
      useBaseTools: useBaseTools, // 默认关闭工具
    );

    return chat(request);
  }
}
