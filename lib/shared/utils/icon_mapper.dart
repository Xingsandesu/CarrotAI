import 'package:flutter/material.dart';

/// 工具类，用于将字符串名称映射到 Flutter Material 图标
class IconMapper {
  // 存储字符串名称到 IconData 的映射
  static final Map<String, IconData> _iconMap = {
    // 模型图标
    'psychology': Icons.psychology,
    'smart_toy_outlined': Icons.smart_toy_outlined,
    'smart_toy': Icons.smart_toy,
    'chat_bubble': Icons.chat_bubble,
    'auto_awesome': Icons.auto_awesome,

    // MCP 工具图标
    'terminal': Icons.terminal,
    'note': Icons.note,
    'code': Icons.code,
    'text_fields': Icons.text_fields,
    'computer': Icons.computer,

    // 上传文件图标
    'upload_file': Icons.upload_file,
    'photo': Icons.photo,
    'screenshot': Icons.screenshot,
    'camera_alt': Icons.camera_alt,

    // 其他常用图标
    'add': Icons.add,
    'send': Icons.send,
    'public': Icons.public,
    'extension_outlined': Icons.extension_outlined,
    'psychology_outlined': Icons.psychology_outlined,
    'question_mark': Icons.question_mark, // 默认或未知图标
    // 在这里添加更多需要的图标映射...
  };

  /// 根据字符串名称获取 IconData
  /// 如果找不到对应的图标，返回默认的问号图标
  static IconData getIcon(String iconName) {
    return _iconMap[iconName.toLowerCase()] ?? Icons.question_mark;
  }
}
