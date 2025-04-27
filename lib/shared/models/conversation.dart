// 这个文件实现会话模型，对应后端的Conversation schema

import 'chat_message.dart';

/// 会话模型类
///
/// 表示一个完整的会话，包含会话ID、标题、消息列表等信息
class Conversation {
  /// 会话唯一标识
  final String conversationId;

  /// 会话标题
  String title;

  /// 消息列表
  final List<ChatMessage> messages;

  /// 元数据，可存储额外信息如使用的模型等
  Map<String, dynamic>? metaData;

  /// 是否已删除
  bool isDeleted;

  /// 最后同步时间戳
  DateTime? lastSyncedAt;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  DateTime updatedAt;

  Conversation({
    required this.conversationId,
    required this.title,
    required this.messages,
    this.metaData,
    this.isDeleted = false,
    this.lastSyncedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从JSON/Map创建Conversation对象
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      conversationId: json['conversation_id'] as String,
      title: json['title'] as String? ?? '新对话',
      messages:
          (json['messages'] as List<dynamic>?)
              ?.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      metaData: json['meta_data'] as Map<String, dynamic>?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      lastSyncedAt:
          json['last_synced_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                (json['last_synced_at'] as num).toInt() * 1000,
              )
              : null,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  /// 辅助方法：解析日期时间值，处理不同格式
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) {
      return DateTime.now(); // 如果为空，返回当前时间
    }

    if (value is String) {
      // 如果是字符串，尝试解析ISO日期
      return DateTime.parse(value);
    } else if (value is int) {
      // 如果是整数，假设是毫秒时间戳
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is double) {
      // 如果是浮点数，转换为整数后作为毫秒时间戳
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    } else {
      // 其他情况，尝试转换为字符串后解析
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return DateTime.now(); // 解析失败返回当前时间
      }
    }
  }

  /// 将Conversation对象转换为JSON/Map
  Map<String, dynamic> toJson() {
    return {
      'conversation_id': conversationId,
      'title': title,
      'messages': messages.map((e) => e.toJson()).toList(),
      'meta_data': metaData,
      'is_deleted': isDeleted,
      'last_synced_at':
          lastSyncedAt != null
              ? lastSyncedAt!.millisecondsSinceEpoch ~/ 1000
              : null,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// 创建一个新的空会话
  factory Conversation.create({
    required String conversationId,
    String? title,
    Map<String, dynamic>? metaData,
  }) {
    final now = DateTime.now();
    return Conversation(
      conversationId: conversationId,
      title: title ?? '新对话',
      messages: [],
      metaData: metaData,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 添加消息到会话
  void addMessage(ChatMessage message) {
    messages.add(message);
    updatedAt = DateTime.now();
  }

  /// 创建当前会话的副本并更新指定字段
  Conversation copyWith({
    String? title,
    List<ChatMessage>? messages,
    Map<String, dynamic>? metaData,
    bool? isDeleted,
    DateTime? lastSyncedAt,
    DateTime? updatedAt,
  }) {
    return Conversation(
      conversationId: conversationId,
      title: title ?? this.title,
      messages: messages ?? List.from(this.messages),
      metaData: metaData ?? this.metaData,
      isDeleted: isDeleted ?? this.isDeleted,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
