// 聊天头部组件，显示在聊天界面顶部

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ChatHeader extends StatelessWidget {
  final VoidCallback? onMenuPressed;
  final VoidCallback? onHomePressed;
  final bool showSidebar;
  final String title;

  const ChatHeader({
    super.key,
    this.onMenuPressed,
    this.onHomePressed,
    this.showSidebar = true,
    this.title = 'CarrotAI',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 使用 SafeArea 自动处理状态栏安全区，无需手动计算
    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13), // 使用withAlpha替代withValues
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          children: [
            // 菜单按钮
            IconButton(
              icon: Icon(
                showSidebar ? Icons.menu_open : Icons.menu,
                color: colorScheme.primary,
              ),
              onPressed:
                  onMenuPressed ??
                  () {
                    Scaffold.of(context).openDrawer();
                  },
            ),

            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // 返回主页按钮放在右侧
            IconButton(
              icon: Icon(Icons.home, color: colorScheme.primary),
              onPressed: onHomePressed,
              tooltip: AppLocalizations.of(context)!.backToHome,
            ),
          ],
        ),
      ),
    );
  }
}
