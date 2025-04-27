import 'package:flutter/material.dart';
import 'package:carrot/features/home/widgets/chat_sidebar/chat_sidebar.dart';

/// 侧边栏组件
///
/// 这是一个包装器组件，实际使用ChatSidebar实现
class Sidebar extends StatelessWidget {
  final VoidCallback? onToggleAppMarket;
  final VoidCallback? onToggleSearch;
  final VoidCallback? onToggleSettings;
  final VoidCallback? onNewChat;

  const Sidebar({
    super.key,
    this.onToggleAppMarket,
    this.onToggleSearch,
    this.onToggleSettings,
    this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    return ChatSidebar(
      onToggleAppMarket: onToggleAppMarket,
      onToggleSearch: onToggleSearch,
      onToggleSettings: onToggleSettings,
      onNewChat: onNewChat,
    );
  }
}
