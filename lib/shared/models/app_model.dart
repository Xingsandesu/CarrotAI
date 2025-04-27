/// 应用模型类
///
/// 用于表示应用市场中的应用
class AppModel {
  final String id; // 应用ID
  final String name; // 应用名称
  final String icon; // 应用图标
  final String type; // 应用类型
  final Map<String, dynamic> mcpServer; // MCP服务器信息
  final String description; // 应用描述
  final bool isInstalled; // 是否已安装
  final String usageGuide; // 使用方法

  AppModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
    required this.mcpServer,
    this.description = '',
    this.isInstalled = false,
    this.usageGuide = '',
  });

  // 从JSON创建AppModel
  factory AppModel.fromJson(Map<String, dynamic> json) {
    return AppModel(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      type: json['type'] as String,
      mcpServer: json['mcpServer'] as Map<String, dynamic>,
      description: json['description'] as String? ?? '',
      isInstalled: json['isInstalled'] as bool? ?? false,
      usageGuide: json['usageGuide'] as String? ?? '',
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'type': type,
      'mcpServer': mcpServer,
      'description': description,
      'isInstalled': isInstalled,
      'usageGuide': usageGuide,
    };
  }

  // 从AppModel创建副本，可以修改某些属性
  AppModel copyWith({
    String? id,
    String? name,
    String? icon,
    String? type,
    Map<String, dynamic>? mcpServer,
    String? description,
    bool? isInstalled,
    String? usageGuide,
  }) {
    return AppModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      type: type ?? this.type,
      mcpServer: mcpServer ?? this.mcpServer,
      description: description ?? this.description,
      isInstalled: isInstalled ?? this.isInstalled,
      usageGuide: usageGuide ?? this.usageGuide,
    );
  }
}
