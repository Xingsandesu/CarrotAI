// 这个文件是 User 模型，用于表示用户
// 它包含用户 ID、电子邮件和名称
//

class User {
  final int id;
  final String email;
  final String name;
  // 用户是否激活
  final bool isActive;
  // 用户创建和更新时间
  final int? createdAt; // 时间戳（毫秒）
  final int? updatedAt; // 时间戳（毫秒）
  // Token使用情况
  final int? tokenLimit;
  final int? tokenUsed;
  final int? promptTokensUsed;
  final int? completionTokensUsed;
  final int? promptCacheHitTokensUsed;
  final int? promptCacheMissTokensUsed;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.tokenLimit,
    this.tokenUsed,
    this.promptTokensUsed,
    this.completionTokensUsed,
    this.promptCacheHitTokensUsed,
    this.promptCacheMissTokensUsed,
  });

  // 从 JSON (Map) 创建 User 对象的工厂构造函数
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      name:
          json['username'] as String? ??
          json['name'] as String, // 支持后端username字段
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as int?,
      updatedAt: json['updated_at'] as int?,
      tokenLimit: json['token_limit'] as int?,
      tokenUsed: json['token_used'] as int?,
      promptTokensUsed: json['prompt_tokens_used'] as int?,
      completionTokensUsed: json['completion_tokens_used'] as int?,
      promptCacheHitTokensUsed: json['prompt_cache_hit_tokens_used'] as int?,
      promptCacheMissTokensUsed: json['prompt_cache_miss_tokens_used'] as int?,
    );
  }
}
