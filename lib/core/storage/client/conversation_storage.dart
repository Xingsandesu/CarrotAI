// 会话存储管理类
// 负责处理会话的本地持久化

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carrot/shared/models/__export.dart';

/// 会话存储管理类
///
/// 使用SharedPreferences实现会话的本地持久化存储
class ConversationStorage {
  // 单例实例
  static ConversationStorage? _instance;

  // SharedPreferences实例
  late SharedPreferences _prefs;

  // 存储键名前缀
  static const String _keyPrefix = 'conversation_';
  static const String _metaKey = 'conversation_meta';
  static const String _lastSyncKey = 'last_sync_timestamp';

  // 私有构造函数
  ConversationStorage._();

  /// 获取单例实例
  static Future<ConversationStorage> getInstance() async {
    if (_instance == null) {
      _instance = ConversationStorage._();
      await _instance!._init();
    }
    return _instance!;
  }

  /// 初始化
  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 保存会话
  Future<bool> saveConversation(Conversation conversation) async {
    try {
      final json = jsonEncode(conversation.toJson());
      final result = await _prefs.setString(
        _keyPrefix + conversation.conversationId,
        json,
      );

      // 更新会话元数据
      await _updateConversationMeta(conversation.conversationId);

      return result;
    } catch (e) {
      debugPrint('保存会话失败: $e');
      return false;
    }
  }

  /// 获取会话
  Future<Conversation?> getConversation(String conversationId) async {
    try {
      final json = _prefs.getString(_keyPrefix + conversationId);
      if (json == null) return null;

      final Map<String, dynamic> data = jsonDecode(json);
      return Conversation.fromJson(data);
    } catch (e) {
      debugPrint('获取会话失败: $e');
      return null;
    }
  }

  /// 删除会话
  Future<bool> deleteConversation(String conversationId) async {
    try {
      final result = await _prefs.remove(_keyPrefix + conversationId);

      // 更新会话元数据
      await _removeConversationMeta(conversationId);

      return result;
    } catch (e) {
      debugPrint('删除会话失败: $e');
      return false;
    }
  }

  /// 获取所有会话ID
  Future<List<String>> getAllConversationIds() async {
    try {
      final metaJson = _prefs.getString(_metaKey);
      if (metaJson == null) return [];

      final List<dynamic> meta = jsonDecode(metaJson);
      return meta.cast<String>();
    } catch (e) {
      debugPrint('获取所有会话ID失败: $e');
      return [];
    }
  }

  /// 获取所有会话
  Future<List<Conversation>> getAllConversations() async {
    try {
      final ids = await getAllConversationIds();
      final List<Conversation> conversations = [];

      for (final id in ids) {
        final conversation = await getConversation(id);
        if (conversation != null) {
          conversations.add(conversation);
        }
      }

      return conversations;
    } catch (e) {
      debugPrint('获取所有会话失败: $e');
      return [];
    }
  }

  /// 清空所有会话
  Future<bool> clearAllConversations() async {
    try {
      final ids = await getAllConversationIds();

      for (final id in ids) {
        await _prefs.remove(_keyPrefix + id);
      }

      await _prefs.remove(_metaKey);

      return true;
    } catch (e) {
      debugPrint('清空所有会话失败: $e');
      return false;
    }
  }

  /// 更新会话元数据
  Future<void> _updateConversationMeta(String conversationId) async {
    try {
      List<String> meta = [];
      final metaJson = _prefs.getString(_metaKey);

      if (metaJson != null) {
        final List<dynamic> decoded = jsonDecode(metaJson);
        meta = decoded.cast<String>();
      }

      if (!meta.contains(conversationId)) {
        meta.add(conversationId);
        await _prefs.setString(_metaKey, jsonEncode(meta));
      }
    } catch (e) {
      debugPrint('更新会话元数据失败: $e');
    }
  }

  /// 从元数据中移除会话
  Future<void> _removeConversationMeta(String conversationId) async {
    try {
      final metaJson = _prefs.getString(_metaKey);
      if (metaJson == null) return;

      final List<dynamic> decoded = jsonDecode(metaJson);
      final meta = decoded.cast<String>();

      meta.remove(conversationId);
      await _prefs.setString(_metaKey, jsonEncode(meta));
    } catch (e) {
      debugPrint('从元数据中移除会话失败: $e');
    }
  }

  /// 保存最后同步时间戳
  Future<bool> saveLastSyncTimestamp(int timestamp) async {
    return await _prefs.setInt(_lastSyncKey, timestamp);
  }

  /// 获取最后同步时间戳
  Future<int?> getLastSyncTimestamp() async {
    return _prefs.getInt(_lastSyncKey);
  }

  /// 替换所有会话
  /// 用于从服务器同步后完全替换本地会话
  Future<bool> replaceAllConversations(List<Conversation> conversations) async {
    try {
      // 先清空所有现有会话
      await clearAllConversations();

      // 保存新会话
      for (final conversation in conversations) {
        await saveConversation(conversation);
      }

      return true;
    } catch (e) {
      debugPrint('替换所有会话失败: $e');
      return false;
    }
  }
}
