// 聊天状态管理提供者
import 'package:flutter/material.dart';
import 'package:carrot/core/providers/auth_provider.dart';
import 'package:carrot/shared/models/__export.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:carrot/features/chat/data/models/sse_message_model.dart';
import 'package:carrot/features/chat/data/repositories/chat_repository.dart';
import 'package:carrot/core/api/api_client_factory.dart';
import 'package:carrot/core/storage/client/conversation_storage.dart';
import 'package:carrot/core/storage/storage_factory.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:carrot/core/services/global_service.dart';

/// 聊天状态管理提供者
///
/// 管理会话状态、处理消息发送等
class ChatProvider with ChangeNotifier {
  // 引入 ChatRepository
  final ChatRepository _chatRepository = ChatRepository();
  // SSE 订阅管理
  StreamSubscription<String>? _sseSubscription;
  // 同步API客户端
  final _syncApiClient = apiClientFactory.syncApiClient;
  // 会话存储实例
  ConversationStorage? _conversationStorage;
  // 认证提供者引用
  final AuthProvider _authProvider;

  // 当前会话列表
  List<Conversation> _conversations = [];
  // 当前激活的会话
  Conversation? _activeConversation;
  // 是否正在发送消息
  bool _isSending = false;
  // 是否正在加载会话
  bool _isLoading = false;
  // 是否正在同步
  bool _isSyncing = false;
  // 错误信息
  String? _errorMessage;
  // 上次同步时间戳
  int _lastSyncedAt = 0;
  // 共享存储
  late SharedPreferences _prefs;

  // 添加回调函数，在会话切换时关闭其他页面
  VoidCallback? onConversationChanged;

  // 构造函数
  ChatProvider(AuthProvider authProvider) : _authProvider = authProvider {
    _initialize();
  }

  // 获取会话列表
  List<Conversation> get conversations => _conversations;
  // 获取当前激活的会话
  Conversation? get activeConversation => _activeConversation;
  // 是否正在发送消息
  bool get isSending => _isSending;
  // 是否正在加载会话
  bool get isLoading => _isLoading;
  // 是否正在同步
  bool get isSyncing => _isSyncing;
  // 获取错误信息
  String? get errorMessage => _errorMessage;

  /// 初始化
  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _prefs = await SharedPreferences.getInstance();
      _conversationStorage = await ConversationStorage.getInstance();

      // 从本地存储获取上次同步时间戳
      _lastSyncedAt = await _conversationStorage?.getLastSyncTimestamp() ?? 0;

      // 从本地存储加载会话
      await _loadConversationsFromStorage();

      // 如果用户已登录，从服务器获取会话
      if (_authProvider.isAuthenticated) {
        try {
          _isSyncing = true;
          final response = await _syncApiClient.fetchConversations();

          if (response.success && response.data != null) {
            final syncResponse = response.data!;

            // 更新本地会话列表
            _updateLocalConversations(syncResponse.conversations);

            // 处理已删除的会话
            _handleDeletedConversations(syncResponse.deletedConversationIds);

            // 更新最后同步时间
            _lastSyncedAt = syncResponse.syncedAt;
            await _conversationStorage?.saveLastSyncTimestamp(_lastSyncedAt);

            debugPrint('会话获取成功，共 ${syncResponse.conversations.length} 个会话');

            // 保存更新后的会话到本地存储
            await _saveConversationsToStorage();
          } else {
            debugPrint('获取会话失败: ${response.message}');
          }
          _isSyncing = false;
        } catch (e) {
          debugPrint('获取会话时出错: $e');
          _isSyncing = false;
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = "初始化聊天提供者时出错: $e";
      _isLoading = false;
      notifyListeners();
      debugPrint("初始化错误: $_errorMessage");
    }
  }

  /// 从存储中加载会话
  Future<void> _loadConversationsFromStorage() async {
    try {
      final conversationsJson = _prefs.getString('synced_conversations_json');

      if (conversationsJson != null) {
        final List<dynamic> conversationsData = jsonDecode(conversationsJson);
        _conversations =
            conversationsData.map((data) {
              // 直接将原始数据传递给Conversation.fromJson，让它处理不同类型的字段
              final Map<String, dynamic> jsonData = {
                'conversation_id': data['conversation_id'],
                'title': data['title'] ?? _getDefaultChatTitle(),
                'messages': data['messages'] ?? [],
                'meta_data': data['meta_data'],
                'is_deleted': data['is_deleted'] ?? false,
                'created_at': data['created_at'],
                'updated_at': data['updated_at'],
                'last_synced_at': data['last_synced_at'],
              };
              return Conversation.fromJson(jsonData);
            }).toList();

        debugPrint("从存储中加载了 ${_conversations.length} 个会话");
      }
    } catch (e) {
      debugPrint("加载会话时出错: $e");
      _errorMessage = "加载会话时出错: $e";
    }
  }

  /// 保存会话到存储
  Future<void> _saveConversationsToStorage() async {
    try {
      final List<Map<String, dynamic>> conversationsData =
          _conversations.map((conversation) {
            return conversation.toJson();
          }).toList();

      await _prefs.setString(
        'synced_conversations_json',
        jsonEncode(conversationsData),
      );
      debugPrint("已保存 ${_conversations.length} 个会话到存储");
    } catch (e) {
      debugPrint("保存会话时出错: $e");
      _errorMessage = "保存会话时出错: $e";
    }
  }

  /// 创建新会话
  Future<Conversation> createNewConversation() async {
    final String conversationId = const Uuid().v4();

    // 使用国际化字符串作为新对话的标题
    String title = '新对话'; // 默认标题
    final context = globalService.currentContext;
    if (context != null) {
      final appLocalizations = AppLocalizations.of(context);
      if (appLocalizations != null) {
        title = appLocalizations.newChat;
      }
    }

    final newConversation = Conversation.create(
      conversationId: conversationId,
      title: title,
    );

    _conversations.add(newConversation);
    _activeConversation = newConversation;
    await _saveConversationsToStorage();
    notifyListeners();

    return newConversation;
  }

  /// 切换到指定会话
  void setActiveConversation(String conversationId) {
    final conversation = _conversations.firstWhere(
      (c) => c.conversationId == conversationId,
      orElse: () => throw Exception("找不到会话: $conversationId"),
    );

    _activeConversation = conversation;
    // 触发回调函数
    if (onConversationChanged != null) {
      onConversationChanged!();
    }
    notifyListeners();
  }

  /// 发送消息
  Future<void> sendMessage(
    String content, {
    bool useDeepThinking = false,
  }) async {
    final text = content.trim(); // 使用传入的 content
    if (text.isEmpty || _isSending) return;

    // 确保有活动会话
    if (_activeConversation == null) {
      await createNewConversation();
      // 如果刚创建了新会话，确保 activeConversation 已设置
      if (_activeConversation == null) {
        _errorMessage = "无法创建或找到活动会话";
        notifyListeners();
        return;
      }
    }

    // 1. 创建用户消息并添加到列表
    final userMessage = ChatMessage.user(text);
    _activeConversation!.addMessage(userMessage);
    notifyListeners(); // 立即显示用户消息

    // 2. 设置加载状态
    _isSending = true;
    _errorMessage = null; // 清除之前的错误
    notifyListeners();

    // 3. 准备上下文消息
    List<ChatMessage> contextMessages = [];
    // 注意: 这里的上下文逻辑可能需要根据你的具体需求调整
    // 这里我们使用活动会话中除了最后一条（用户刚发的消息）之外的所有消息
    // 并限制数量，例如最后 5 条对话 (10条消息)
    const int maxContextMessages = 10; // 5轮对话
    if (_activeConversation!.messages.length > 1) {
      int startIndex =
          _activeConversation!.messages.length - 1 - maxContextMessages;
      if (startIndex < 0) startIndex = 0;
      // 获取不包括当前用户消息的上下文
      contextMessages = _activeConversation!.messages.sublist(
        startIndex,
        _activeConversation!.messages.length - 1,
      );
    }

    // 4. 添加助手消息占位符
    final assistantPlaceholder = ChatMessage.assistant(_getThinkingString());
    _activeConversation!.addMessage(assistantPlaceholder);
    notifyListeners(); // 显示占位符气泡

    // 5. 发送请求并处理 SSE 流
    try {
      await _sseSubscription?.cancel(); // 取消之前的订阅

      // 读取MCP设置
      bool useMcp = false;
      bool useBaseTools = false;
      // 读取温度设置
      double temperature = 0.7; // 默认温度
      // 用户自定义MCP配置
      Map<String, dynamic>? userMcpConfig;

      try {
        final prefs = await SharedPreferences.getInstance();
        useMcp = prefs.getBool('mcp_global_enabled') ?? false;
        useBaseTools = prefs.getBool('mcp_basic_enabled') ?? false;

        // 读取温度设置
        temperature = prefs.getDouble('temperature_setting') ?? 0.7;

        // 读取MCP服务器JSON配置
        final String? jsonConfigStr = prefs.getString('mcp_server_json_config');
        if (jsonConfigStr != null && jsonConfigStr.isNotEmpty && useMcp) {
          try {
            // 尝试解析JSON
            final dynamic parsedJson = jsonDecode(jsonConfigStr);

            // 处理不同格式的JSON配置
            if (parsedJson is Map<String, dynamic>) {
              // 检查是否有mcpServers字段（前端格式）
              if (parsedJson.containsKey('mcpServers')) {
                // 前端格式，需要提取mcpServers字段
                userMcpConfig = parsedJson['mcpServers'];
              } else {
                // 直接使用解析的JSON（可能是后端格式）
                userMcpConfig = parsedJson;
              }
              debugPrint("成功解析MCP服务器配置: ${userMcpConfig.toString()}");
            }
          } catch (e) {
            debugPrint("解析MCP服务器JSON配置失败: $e");
          }
        }

        // 读取已安装应用的启用状态
        final String? appStatusJson = prefs.getString('mcp_app_status');
        if (appStatusJson != null && useMcp) {
          try {
            final Map<String, dynamic> appStatus = jsonDecode(appStatusJson);

            // 获取已安装的应用列表
            final appStorage = await storageFactory.getAppStorage();
            final installedApps = await appStorage.getInstalledApps();

            // 初始化用户MCP配置（如果还没有初始化）
            userMcpConfig ??= {};

            // 遍历已安装的应用，将启用的应用的MCP配置添加到userMcpConfig
            for (var app in installedApps) {
              final bool isEnabled = appStatus[app.id] ?? false;
              if (isEnabled) {
                // 将应用的MCP服务器配置添加到userMcpConfig
                // 确保env字段格式正确
                final Map<String, dynamic> mcpConfig =
                    Map<String, dynamic>.from(app.mcpServer);

                // 处理env字段，确保没有空键
                if (mcpConfig.containsKey('env')) {
                  final rawEnv = mcpConfig['env'];
                  if (rawEnv is Map) {
                    final filteredEnv = <String, dynamic>{};
                    for (final entry in rawEnv.entries) {
                      final key = entry.key.toString();
                      if (key.trim().isNotEmpty) {
                        filteredEnv[key] = entry.value;
                      }
                    }
                    mcpConfig['env'] =
                        filteredEnv.isEmpty ? <String, String>{} : filteredEnv;
                  } else {
                    // 如果env不是Map类型，设置为空Map
                    mcpConfig['env'] = <String, String>{};
                  }
                } else {
                  // 如果没有env字段，添加空的env
                  mcpConfig['env'] = <String, String>{};
                }

                userMcpConfig[app.id] = mcpConfig;
                debugPrint("添加已启用应用的MCP配置: ${app.id}");
              }
            }
          } catch (e) {
            debugPrint("处理已安装应用的MCP配置失败: $e");
          }
        }

        // 如果开启了深度思考，需要禁用MCP功能
        if (useDeepThinking) {
          useMcp = false;
          useBaseTools = false;
          userMcpConfig = null;
        }

        debugPrint(
          "请求参数: 深度思考=$useDeepThinking, MCP启用=$useMcp, 基础工具=$useBaseTools, 温度=$temperature, 自定义MCP=${userMcpConfig != null}",
        );
      } catch (e) {
        debugPrint("读取设置出错: $e, 将使用默认值");
      }

      // 构建并打印完整请求体
      final requestBody = {
        'current_message': userMessage.toJson(),
        'context_messages': contextMessages.map((msg) => msg.toJson()).toList(),
        'model': 'deepseek',
        'use_deep_thinking': useDeepThinking,
        'use_mcp': useMcp,
        'use_base_tools': useBaseTools,
        'temperature': temperature, // 使用读取到的温度值
        'context_length': 5,
      };

      // 添加用户自定义MCP配置（如果有）
      if (userMcpConfig != null) {
        requestBody['user_mcp_config'] = userMcpConfig;
      }

      debugPrint("发送聊天请求体: ${jsonEncode(requestBody)}");

      _sseSubscription = _chatRepository
          .sendChatMessageStream(
            currentMessage: userMessage,
            contextMessages: contextMessages,
            useDeepThinking: useDeepThinking,
            useMcp: useMcp,
            useBaseTools: useBaseTools,
            temperature: temperature, // 传递温度参数
            userMcpConfig: userMcpConfig, // 传递用户自定义MCP配置
          )
          .listen(
            (sseData) {
              final sseMessage = SseMessage.fromJson(sseData);

              // 调试输出工具调用信息
              if (sseMessage.toolCalls != null &&
                  sseMessage.toolCalls!.isNotEmpty) {
                debugPrint("收到工具调用: ${jsonEncode(sseMessage.toolCalls)}");
              }

              // 优先检查 SSE 数据中是否包含后端错误
              if (sseMessage.error != null && sseMessage.error!.isNotEmpty) {
                _handleStreamError(sseMessage.error!); // 使用后端返回的错误信息
                _sseSubscription?.cancel(); // 收到错误后通常可以取消订阅
              } else if (sseMessage.content == '[DONE]') {
                _handleStreamDone();
              } else {
                // 处理消息内容和工具调用
                _handleMessageContent(sseMessage);

                // 处理推理内容
                _handleReasoningContent(sseMessage);
              }
            },
            onError: (error) {
              // 这个 onError 处理的是流传输本身的错误
              _handleStreamError(error);
            },
            onDone: () {
              _handleStreamDone(); // 确保即使没有 [DONE] 也结束
            },
            cancelOnError: true,
          );

      // 注意：不再需要这里的 finally 块来设置 _isSending = false
      // 因为状态会在 _handleStreamDone 或 _handleStreamError 中处理
    } catch (e) {
      _handleStreamError(e);
    }
  }

  /// 处理消息内容和工具调用
  void _handleMessageContent(SseMessage sseMessage) {
    // 确保有活动会话
    if (_activeConversation == null) return;

    // 检查是否有新的工具调用
    final hasToolCalls =
        sseMessage.toolCalls != null && sseMessage.toolCalls!.isNotEmpty;

    // 处理内容（即使内容为空，也可能有工具调用需要处理）
    final lastMessage = _activeConversation!.messages.last;

    // 检查占位符是否是本地化的"思考中..."
    final thinkingString = _getThinkingString();
    if (lastMessage.content == thinkingString) {
      // 第一次接收内容，替换占位符
      _activeConversation!.messages[_activeConversation!.messages.length -
          1] = ChatMessage.assistant(
        sseMessage.content.isEmpty ? '' : sseMessage.content,
        toolCalls: hasToolCalls ? sseMessage.toolCalls : null,
        reasoningContent: lastMessage.reasoningContent,
      );
    } else if (sseMessage.content.isNotEmpty) {
      // 追加内容
      _updateLastAssistantMessageContent(
        sseMessage.content,
        toolCalls: hasToolCalls ? sseMessage.toolCalls : lastMessage.toolCalls,
      );
    } else if (hasToolCalls) {
      // 只有工具调用，没有新内容
      _updateLastAssistantMessageContent(
        lastMessage.content,
        toolCalls: sseMessage.toolCalls,
      );
    }

    if (sseMessage.content.isNotEmpty || hasToolCalls) {
      notifyListeners();
    }
  }

  /// 处理推理内容
  void _handleReasoningContent(SseMessage sseMessage) {
    if (sseMessage.reasoningContent == null ||
        sseMessage.reasoningContent!.isEmpty) {
      return;
    }

    // 确保有活动会话
    if (_activeConversation == null) return;

    // 累加推理内容
    final lastMessage = _activeConversation!.messages.last;
    final currentReasoning = lastMessage.reasoningContent ?? "";
    final newReasoning = currentReasoning + sseMessage.reasoningContent!;

    _activeConversation!.messages[_activeConversation!.messages.length -
        1] = ChatMessage.assistant(
      lastMessage.content,
      toolCalls: lastMessage.toolCalls,
      reasoningContent: newReasoning,
    );

    debugPrint("累加推理内容: ${sseMessage.reasoningContent}");
    notifyListeners();
  }

  // --- 私有辅助方法 --- //

  /// 获取默认的对话标题（国际化）
  String _getDefaultChatTitle() {
    String title = '新对话'; // 默认标题
    final context = globalService.currentContext;
    if (context != null) {
      final appLocalizations = AppLocalizations.of(context);
      if (appLocalizations != null) {
        title = appLocalizations.newChat;
      }
    }
    return title;
  }

  /// 获取本地化的 "思考中..." 字符串
  String _getThinkingString() {
    String thinking = '思考中...'; // 默认回退值
    final context = globalService.currentContext;
    if (context != null) {
      final appLocalizations = AppLocalizations.of(context);
      if (appLocalizations != null) {
        thinking = appLocalizations.thinking;
      }
    }
    return thinking;
  }

  /// 更新最后一条助手消息的内容
  void _updateLastAssistantMessageContent(
    String contentChunk, {
    List<Map<String, dynamic>>? toolCalls,
  }) {
    if (_activeConversation != null &&
        _activeConversation!.messages.isNotEmpty &&
        _activeConversation!.messages.last.role == 'assistant') {
      final lastMessage = _activeConversation!.messages.last;

      // 创建新的消息对象来更新列表，确保 ChangeNotifier 检测到变化
      _activeConversation!.messages[_activeConversation!.messages.length -
          1] = ChatMessage.assistant(
        lastMessage.content + contentChunk,
        // 如果新的工具调用不为空，使用新的；否则保留现有的
        toolCalls: toolCalls ?? lastMessage.toolCalls,
        reasoningContent: lastMessage.reasoningContent, // 保留推理内容
      );
      notifyListeners(); // 更新UI
    }
  }

  /// 处理 SSE 流结束
  void _handleStreamDone() async {
    if (_isSending) {
      _isSending = false;
      _sseSubscription = null;

      // 确保活动会话存在
      if (_activeConversation != null) {
        // 可以在这里更新会话标题或保存
        if (_activeConversation!.messages.length <= 3 &&
            _activeConversation!.messages.isNotEmpty &&
            _activeConversation!.messages.first.role == 'user') {
          // <=3 因为有用户消息、空助手消息、第一条响应
          final firstUserMessage = _activeConversation!.messages.first.content;
          _activeConversation!.title =
              firstUserMessage.length > 20
                  ? "${firstUserMessage.substring(0, 20)}..."
                  : firstUserMessage;
        }

        // 保存最终的会话状态到本地存储
        await _saveConversationsToStorage();

        // 只有在用户已登录的情况下才进行会话同步
        if (_authProvider.isAuthenticated) {
          try {
            await syncConversationsWithServer();
          } catch (e) {
            debugPrint("同步会话时出错: $e");
            // 同步错误不应该影响用户体验，所以我们只记录错误
          }
        } else {
          debugPrint("用户未登录，跳过会话同步");
        }
      }

      notifyListeners();
    }
  }

  /// 处理 SSE 流错误
  void _handleStreamError(Object error) {
    debugPrint("SSE Stream Error: $error");
    _errorMessage = "接收 AI 响应时出错: ${error.toString()}";
    // 在最后一条助手消息上附加错误信息
    if (_activeConversation != null &&
        _activeConversation!.messages.isNotEmpty &&
        _activeConversation!.messages.last.role == 'assistant') {
      final lastMessage = _activeConversation!.messages.last;
      _activeConversation!.messages[_activeConversation!.messages.length -
          1] = ChatMessage.assistant(
        "${lastMessage.content}\n\n[错误: ${_errorMessage!}]",
      );
    }

    _isSending = false;
    _sseSubscription = null;
    notifyListeners();
  }

  /// 删除会话
  Future<void> deleteConversation(String conversationId) async {
    _conversations.removeWhere((c) => c.conversationId == conversationId);

    // 如果删除的是当前活动会话，则重置活动会话
    if (_activeConversation?.conversationId == conversationId) {
      _activeConversation =
          _conversations.isNotEmpty ? _conversations.first : null;
    }

    await _saveConversationsToStorage();

    // 如果用户已登录，同步删除操作到服务器
    if (_authProvider.isAuthenticated) {
      try {
        await _syncDeleteConversation(conversationId);
      } catch (e) {
        debugPrint("同步删除会话时出错: $e");
        // 同步错误不应该影响用户体验，所以我们只记录错误
      }
    } else {
      debugPrint("用户未登录，跳过同步删除会话");
    }

    notifyListeners();
  }

  /// 更新会话标题
  Future<void> updateConversationTitle(
    String conversationId,
    String newTitle,
  ) async {
    final index = _conversations.indexWhere(
      (c) => c.conversationId == conversationId,
    );
    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(title: newTitle);

      if (_activeConversation?.conversationId == conversationId) {
        _activeConversation = _conversations[index];
      }

      await _saveConversationsToStorage();

      // 如果用户已登录，同步更新到服务器
      if (_authProvider.isAuthenticated) {
        try {
          await syncConversationsWithServer();
        } catch (e) {
          debugPrint("同步更新会话标题时出错: $e");
          // 同步错误不应该影响用户体验，所以我们只记录错误
        }
      } else {
        debugPrint("用户未登录，跳过同步更新会话标题");
      }

      notifyListeners();
    }
  }

  /// 清除当前活动会话
  void clearActiveConversation() {
    _activeConversation = null;
    notifyListeners();
  }

  /// 清除错误信息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 重新生成最后一条助手回复
  Future<void> regenerateLastResponse() async {
    // 如果没有活动会话或正在发送消息，则退出
    if (_activeConversation == null || _isSending) return;

    // 找到最后一条助手消息和用户消息
    ChatMessage? lastAssistantMessage;
    ChatMessage? lastUserMessage;

    for (int i = _activeConversation!.messages.length - 1; i >= 0; i--) {
      final message = _activeConversation!.messages[i];
      if (message.role == 'assistant' && lastAssistantMessage == null) {
        lastAssistantMessage = message;
      } else if (message.role == 'user' && lastUserMessage == null) {
        lastUserMessage = message;
        break; // 找到最后一条用户消息后就停止
      }
    }

    // 如果找不到助手消息或用户消息，则退出
    if (lastAssistantMessage == null || lastUserMessage == null) return;

    // 移除最后一条助手消息
    _activeConversation!.messages.remove(lastAssistantMessage);

    // 设置加载状态
    _isSending = true;
    _errorMessage = null; // 清除之前的错误
    notifyListeners();

    // 准备上下文消息
    List<ChatMessage> contextMessages = [];
    const int maxContextMessages = 10; // 5轮对话
    if (_activeConversation!.messages.length > 1) {
      int startIndex =
          _activeConversation!.messages.length - maxContextMessages;
      if (startIndex < 0) startIndex = 0;
      contextMessages = _activeConversation!.messages.sublist(startIndex);
    }

    // 添加"思考中..."助手消息占位符
    final assistantPlaceholder = ChatMessage.assistant(_getThinkingString());
    _activeConversation!.addMessage(assistantPlaceholder);
    notifyListeners(); // 显示"思考中..."气泡

    // 发送请求并处理 SSE 流
    try {
      await _sseSubscription?.cancel(); // 取消之前的订阅

      // 读取MCP设置
      bool useMcp = false;
      bool useBaseTools = false;
      // 读取温度设置
      double temperature = 0.7; // 默认温度
      // 深度思考状态
      bool useDeepThinking = false;
      // 用户自定义MCP配置
      Map<String, dynamic>? userMcpConfig;

      try {
        final prefs = await SharedPreferences.getInstance();
        useMcp = prefs.getBool('mcp_global_enabled') ?? false;
        useBaseTools = prefs.getBool('mcp_basic_enabled') ?? false;
        temperature = prefs.getDouble('temperature_setting') ?? 0.7;
        useDeepThinking = prefs.getBool('deep_thinking_enabled') ?? false;

        // 读取MCP服务器JSON配置
        final String? jsonConfigStr = prefs.getString('mcp_server_json_config');
        if (jsonConfigStr != null && jsonConfigStr.isNotEmpty && useMcp) {
          try {
            // 尝试解析JSON
            final dynamic parsedJson = jsonDecode(jsonConfigStr);

            // 处理不同格式的JSON配置
            if (parsedJson is Map<String, dynamic>) {
              // 检查是否有mcpServers字段（前端格式）
              if (parsedJson.containsKey('mcpServers')) {
                // 前端格式，需要提取mcpServers字段
                userMcpConfig = parsedJson['mcpServers'];
              } else {
                // 直接使用解析的JSON（可能是后端格式）
                userMcpConfig = parsedJson;
              }
              debugPrint("成功解析MCP服务器配置: ${userMcpConfig.toString()}");
            }
          } catch (e) {
            debugPrint("解析MCP服务器JSON配置失败: $e");
          }
        }

        // 读取已安装应用的启用状态
        final String? appStatusJson = prefs.getString('mcp_app_status');
        if (appStatusJson != null && useMcp) {
          try {
            final Map<String, dynamic> appStatus = jsonDecode(appStatusJson);

            // 获取已安装的应用列表
            final appStorage = await storageFactory.getAppStorage();
            final installedApps = await appStorage.getInstalledApps();

            // 初始化用户MCP配置（如果还没有初始化）
            userMcpConfig ??= {};

            // 遍历已安装的应用，将启用的应用的MCP配置添加到userMcpConfig
            for (var app in installedApps) {
              final bool isEnabled = appStatus[app.id] ?? false;
              if (isEnabled) {
                // 将应用的MCP服务器配置添加到userMcpConfig
                // 确保env字段格式正确
                final Map<String, dynamic> mcpConfig =
                    Map<String, dynamic>.from(app.mcpServer);

                // 处理env字段，确保没有空键
                if (mcpConfig.containsKey('env')) {
                  final rawEnv = mcpConfig['env'];
                  if (rawEnv is Map) {
                    final filteredEnv = <String, dynamic>{};
                    for (final entry in rawEnv.entries) {
                      final key = entry.key.toString();
                      if (key.trim().isNotEmpty) {
                        filteredEnv[key] = entry.value;
                      }
                    }
                    mcpConfig['env'] =
                        filteredEnv.isEmpty ? <String, String>{} : filteredEnv;
                  } else {
                    // 如果env不是Map类型，设置为空Map
                    mcpConfig['env'] = <String, String>{};
                  }
                } else {
                  // 如果没有env字段，添加空的env
                  mcpConfig['env'] = <String, String>{};
                }

                userMcpConfig[app.id] = mcpConfig;
                debugPrint("添加已启用应用的MCP配置: ${app.id}");
              }
            }
          } catch (e) {
            debugPrint("处理已安装应用的MCP配置失败: $e");
          }
        }

        // 如果开启了深度思考，需要禁用MCP功能
        if (useDeepThinking) {
          useMcp = false;
          useBaseTools = false;
          userMcpConfig = null;
        }

        debugPrint(
          "重新生成请求参数: 深度思考=$useDeepThinking, MCP启用=$useMcp, 基础工具=$useBaseTools, 温度=$temperature, 自定义MCP=${userMcpConfig != null}",
        );
      } catch (e) {
        debugPrint("读取设置出错: $e, 将使用默认值");
      }

      _sseSubscription = _chatRepository
          .sendChatMessageStream(
            currentMessage: lastUserMessage,
            contextMessages: contextMessages,
            useDeepThinking: useDeepThinking,
            useMcp: useMcp,
            useBaseTools: useBaseTools,
            temperature: temperature,
            userMcpConfig: userMcpConfig,
          )
          .listen(
            (sseData) {
              final sseMessage = SseMessage.fromJson(sseData);

              // 调试输出工具调用信息
              if (sseMessage.toolCalls != null &&
                  sseMessage.toolCalls!.isNotEmpty) {
                debugPrint("收到工具调用: ${jsonEncode(sseMessage.toolCalls)}");
              }

              // 优先检查 SSE 数据中是否包含后端错误
              if (sseMessage.error != null && sseMessage.error!.isNotEmpty) {
                _handleStreamError(sseMessage.error!); // 使用后端返回的错误信息
                _sseSubscription?.cancel(); // 收到错误后通常可以取消订阅
              } else if (sseMessage.content == '[DONE]') {
                _handleStreamDone();
              } else {
                // 处理消息内容和工具调用
                _handleMessageContent(sseMessage);

                // 处理推理内容
                _handleReasoningContent(sseMessage);
              }
            },
            onError: (error) {
              _handleStreamError(error);
            },
            onDone: () {
              _handleStreamDone();
            },
            cancelOnError: true,
          );
    } catch (e) {
      _handleStreamError(e);
    }
  }

  // --- 会话同步相关方法 --- //

  /// 与服务器同步会话
  Future<bool> syncConversationsWithServer() async {
    // 如果未登录，直接返回而不尝试同步
    if (!_authProvider.isAuthenticated) {
      debugPrint("用户未登录，跳过会话同步");
      return false;
    }

    // 如果正在同步，防止重复同步
    if (_isSyncing) {
      debugPrint("正在同步中，跳过重复请求");
      return false;
    }

    _isSyncing = true;
    debugPrint("开始同步会话...");

    try {
      // 过滤掉空会话（没有消息或只有一条消息的会话）
      final conversationsToSync =
          _conversations.where((conv) {
            return conv.messages.length > 1; // 至少有一问一答
          }).toList();

      debugPrint(
        "准备同步 ${conversationsToSync.length} 个非空会话，上次同步时间: $_lastSyncedAt",
      );

      // 构建同步请求
      final syncRequest = SyncRequest(
        conversations: conversationsToSync,
        lastSyncedAt: _lastSyncedAt,
      );

      // 发送同步请求
      final response = await _syncApiClient.syncConversations(syncRequest);

      if (response.success && response.data != null) {
        final syncResponse = response.data!;

        // 更新本地会话列表
        _updateLocalConversations(syncResponse.conversations);

        // 处理已删除的会话
        _handleDeletedConversations(syncResponse.deletedConversationIds);

        // 更新最后同步时间
        _lastSyncedAt = syncResponse.syncedAt;
        await _conversationStorage?.saveLastSyncTimestamp(_lastSyncedAt);

        debugPrint("会话同步成功，最新同步时间: $_lastSyncedAt");

        // 保存更新后的会话到本地存储
        await _saveConversationsToStorage();
        notifyListeners();

        _isSyncing = false;
        return true;
      } else {
        _errorMessage = "同步会话失败: ${response.message}";
        debugPrint(_errorMessage);
        _isSyncing = false;
        return false;
      }
    } catch (e) {
      _errorMessage = "同步会话时出错: $e";
      debugPrint(_errorMessage);
      _isSyncing = false;
      return false;
    }
  }

  /// 更新本地会话列表
  void _updateLocalConversations(List<Conversation> serverConversations) {
    // 创建本地会话ID映射，用于快速查找
    final Map<String, Conversation> localConvMap = {
      for (var conv in _conversations) conv.conversationId: conv,
    };

    // 创建服务器会话ID映射，用于快速查找
    final Map<String, Conversation> serverConvMap = {
      for (var conv in serverConversations) conv.conversationId: conv,
    };

    // 合并会话列表
    final List<Conversation> mergedConversations = [];

    // 首先处理服务器上的会话
    for (final serverConv in serverConversations) {
      final String convId = serverConv.conversationId;

      if (localConvMap.containsKey(convId)) {
        // 会话同时存在于本地和服务器
        final localConv = localConvMap[convId]!;

        // 选择消息更多的版本（通常服务器版本会更新）
        if (serverConv.messages.length >= localConv.messages.length) {
          mergedConversations.add(serverConv);
        } else {
          mergedConversations.add(localConv);
        }
      } else {
        // 会话只存在于服务器，添加到合并列表
        mergedConversations.add(serverConv);
      }
    }

    // 然后处理只存在于本地的会话
    for (final localConv in _conversations) {
      final String convId = localConv.conversationId;

      if (!serverConvMap.containsKey(convId)) {
        // 会话只存在于本地，添加到合并列表
        mergedConversations.add(localConv);
      }
    }

    // 更新会话列表
    _conversations = mergedConversations;

    // 更新当前活动会话（如果有）
    if (_activeConversation != null) {
      final String activeId = _activeConversation!.conversationId;
      final activeIndex = _conversations.indexWhere(
        (c) => c.conversationId == activeId,
      );

      if (activeIndex != -1) {
        _activeConversation = _conversations[activeIndex];
      } else {
        // 活动会话不在更新后的列表中，重置
        _activeConversation =
            _conversations.isNotEmpty ? _conversations.first : null;
      }
    }

    debugPrint("本地会话已更新，共 ${_conversations.length} 个会话");
  }

  /// 处理已删除的会话
  void _handleDeletedConversations(List<String> deletedIds) {
    if (deletedIds.isEmpty) return;

    // 从本地移除已删除的会话
    _conversations.removeWhere(
      (conv) => deletedIds.contains(conv.conversationId),
    );

    // 如果当前活动会话被删除，重置活动会话
    if (_activeConversation != null &&
        deletedIds.contains(_activeConversation!.conversationId)) {
      _activeConversation =
          _conversations.isNotEmpty ? _conversations.first : null;
    }

    debugPrint("已从本地移除 ${deletedIds.length} 个被删除的会话");
  }

  /// 同步删除会话到服务器
  Future<bool> _syncDeleteConversation(String conversationId) async {
    // 如果未登录，直接返回而不尝试同步
    if (!_authProvider.isAuthenticated) {
      debugPrint("用户未登录，跳过同步删除会话 $conversationId");
      return false;
    }

    try {
      // 调用API删除会话
      final response = await _syncApiClient.deleteConversation(conversationId);

      if (response.success) {
        debugPrint("会话 $conversationId 已成功从服务器删除");
        return true;
      } else {
        _errorMessage = "从服务器删除会话失败: ${response.message}";
        debugPrint(_errorMessage);
        return false;
      }
    } catch (e) {
      _errorMessage = "删除会话时出错: $e";
      debugPrint(_errorMessage);
      return false;
    }
  }

  /// 登录成功后的处理
  /// 该方法将在用户登录成功后被调用
  Future<void> onLoginSuccess() async {
    debugPrint('登录成功，开始获取会话数据...');

    // 重新加载会话数据
    await _loadConversationsFromStorage();

    // 从服务器获取会话，而不是同步
    try {
      _isSyncing = true;
      final response = await _syncApiClient.fetchConversations();

      if (response.success && response.data != null) {
        final syncResponse = response.data!;

        // 更新本地会话列表
        _updateLocalConversations(syncResponse.conversations);

        // 处理已删除的会话
        _handleDeletedConversations(syncResponse.deletedConversationIds);

        // 更新最后同步时间
        _lastSyncedAt = syncResponse.syncedAt;
        await _conversationStorage?.saveLastSyncTimestamp(_lastSyncedAt);

        debugPrint('会话获取成功，共 ${syncResponse.conversations.length} 个会话');

        // 保存更新后的会话到本地存储
        await _saveConversationsToStorage();
      } else {
        debugPrint('获取会话失败: ${response.message}');
      }
      _isSyncing = false;
    } catch (e) {
      debugPrint('获取会话时出错: $e');
      _isSyncing = false;
    }

    // 通知UI更新
    notifyListeners();
  }

  /// 清除所有会话数据
  /// 该方法将在用户注销时被调用
  Future<void> clearAllData() async {
    debugPrint('清除所有会话数据...');

    // 清除内存中的会话数据
    _conversations = [];
    _activeConversation = null;

    // 清除本地存储的会话数据
    if (_conversationStorage != null) {
      await _conversationStorage!.clearAllConversations();
    }

    // 重置同步时间戳
    _lastSyncedAt = 0;
    await _conversationStorage?.saveLastSyncTimestamp(0);

    // 清除SharedPreferences中的会话数据
    await _prefs.remove('synced_conversations_json');

    // 通知UI更新
    notifyListeners();

    debugPrint('所有会话数据已清除');
  }

  // --- 清理 --- //
  @override
  void dispose() {
    // 取消SSE订阅以避免内存泄漏
    _sseSubscription?.cancel();

    // 清理不再需要的大型对象引用
    _conversations = [];
    _activeConversation = null;
    _errorMessage = null;

    super.dispose();
  }
}
