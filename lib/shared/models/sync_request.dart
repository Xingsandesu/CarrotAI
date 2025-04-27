// 这个文件实现同步请求模型，对应后端的SyncRequest schema

import 'conversation.dart';

/// 同步请求模型类
///
/// 表示发送到后端的会话同步请求数据结构
class SyncRequest {
  /// 需要同步的会话列表
  final List<Conversation> conversations;

  /// 上次同步的时间戳（秒）
  final int? lastSyncedAt;

  SyncRequest({required this.conversations, this.lastSyncedAt});

  /// 将SyncRequest对象转换为JSON/Map
  Map<String, dynamic> toJson() {
    return {
      'conversations': conversations.map((e) => e.toJson()).toList(),
      'last_synced_at': lastSyncedAt,
    };
  }
}

/// 同步响应模型类
///
/// 表示从后端接收的会话同步响应数据结构
class SyncResponse {
  /// 同步后的会话列表
  final List<Conversation> conversations;

  /// 删除的会话ID列表
  final List<String> deletedConversationIds;

  /// 当前同步的时间戳
  final int syncedAt;

  SyncResponse({
    required this.conversations,
    required this.deletedConversationIds,
    required this.syncedAt,
  });

  /// 从JSON/Map创建SyncResponse对象
  factory SyncResponse.fromJson(Map<String, dynamic> json) {
    return SyncResponse(
      conversations:
          (json['conversations'] as List<dynamic>)
              .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
              .toList(),
      deletedConversationIds:
          (json['deleted_conversation_ids'] as List<dynamic>)
              .map((e) => e as String)
              .toList(),
      syncedAt:
          (json['synced_at'] is int)
              ? json['synced_at'] as int
              : (json['synced_at'] is double)
              ? (json['synced_at'] as double).toInt()
              : json['synced_at'].toString().isEmpty
              ? 0
              : int.parse(json['synced_at'].toString()),
    );
  }
}

/// 删除所有会话请求模型
class DeleteAllConversationsRequest {
  /// 确认删除
  final bool confirm;

  DeleteAllConversationsRequest({required this.confirm});

  /// 将DeleteAllConversationsRequest对象转换为JSON/Map
  Map<String, dynamic> toJson() {
    return {'confirm': confirm};
  }
}
