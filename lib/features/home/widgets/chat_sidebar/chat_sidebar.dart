// 聊天侧边栏组件，显示在聊天界面左侧，可折叠

import 'package:flutter/material.dart';
import 'package:carrot/features/home/widgets/chat_sidebar/user_options_menu.dart';
import 'package:carrot/features/app_market/__export.dart'; // 导入 AppMarketPage
import 'package:carrot/features/home/providers/chat_provider.dart';
import 'package:provider/provider.dart';
import 'package:carrot/shared/models/__export.dart';
import 'package:carrot/core/providers/auth_provider.dart'; // 导入AuthProvider
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:carrot/shared/components/toast_notification.dart';

class ChatSidebar extends StatelessWidget {
  // 修改参数名为 onToggleAppMarket，类型为 VoidCallback?
  final VoidCallback? onToggleAppMarket;
  final VoidCallback? onToggleSearch; // 添加搜索回调
  final VoidCallback? onToggleSettings; // 添加设置回调
  final VoidCallback? onNewChat; // 添加新建会话回调

  const ChatSidebar({
    super.key,
    this.onToggleAppMarket,
    this.onToggleSearch,
    this.onToggleSettings,
    this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    // 获取Material 3的颜色方案
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // 定义宽度阈值，与 HomeScreen 保持一致
    const double breakpoint = 800.0;

    // 获取聊天提供者
    final chatProvider = Provider.of<ChatProvider>(context);
    final conversations = chatProvider.conversations;
    final activeConversation = chatProvider.activeConversation;

    // 不再需要 Drawer，因为背景由 HomeScreen 的 AnimatedContainer 或 Drawer 控制
    // Drawer 的 elevation 和 shape 应在 HomeScreen 中设置
    return Column(
      children: [
        // 增加顶部空白，为窗口指示器留出足够空间
        SizedBox(height: MediaQuery.of(context).padding.top + 25),

        // 侧边栏顶部 - 更符合Material 3设计
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Row(
            children: [
              // 添加 logo 图标
              Icon(Icons.auto_awesome, color: colorScheme.primary, size: 24),
              const SizedBox(width: 8),
              // 直接显示文字，移除图标
              Text(
                AppLocalizations.of(context)!.appName,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              // Material 3风格按钮，使用更大的尺寸
              IconButton(
                icon: const Icon(Icons.add, size: 24),
                onPressed: () async {
                  // 创建新会话
                  if (onNewChat != null) {
                    onNewChat!();
                  } else {
                    await chatProvider.createNewConversation();
                  }
                },
                color: colorScheme.primary,
                tooltip: AppLocalizations.of(context)!.createNewChat,
              ),
            ],
          ),
        ),

        // 重新设计的应用和搜索按钮 - 更符合Material 3
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.outlineVariant.withAlpha(
                  (255 * 0.3).round(),
                ),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(24),
                    ),
                    child: InkWell(
                      onTap: () {
                        // 获取认证提供者
                        final authProvider = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        );

                        // 如果未登录，则跳转到登录页面
                        if (!authProvider.isAuthenticated) {
                          // 显示提示
                          ToastNotification.showWarning(
                            message:
                                AppLocalizations.of(context)!.loginRequired,
                            context: context,
                          );

                          // 跳转到登录页面
                          Navigator.pushNamed(context, '/login');
                          return;
                        }

                        final bool isWideScreen =
                            MediaQuery.of(context).size.width >= breakpoint;
                        if (isWideScreen) {
                          // 宽屏：调用新的回调
                          onToggleAppMarket?.call();
                        } else {
                          // 窄屏：推入新页面
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AppMarketPage(),
                            ),
                          );
                        }
                      },
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(24),
                      ),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min, // 使用最小所需空间
                          children: [
                            Icon(
                              Icons.apps_rounded,
                              color: colorScheme.onSurfaceVariant,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              // 使用Flexible包装文本，允许文本在需要时缩小
                              child: Text(
                                AppLocalizations.of(context)!.appMarketShort,
                                style: textTheme.labelLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis, // 文本过长时显示省略号
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: VerticalDivider(
                    color: colorScheme.outlineVariant.withAlpha(
                      (255 * 0.3).round(),
                    ),
                    thickness: 0.5,
                    width: 1,
                  ),
                ),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(24),
                    ),
                    child: InkWell(
                      onTap: () {
                        // 搜索按钮点击事件
                        onToggleSearch?.call(); // 调用搜索回调
                      },
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(24),
                      ),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min, // 使用最小所需空间
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: colorScheme.onSurfaceVariant,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              // 使用Flexible包装文本，允许文本在需要时缩小
                              child: Text(
                                AppLocalizations.of(context)!.search,
                                style: textTheme.labelLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis, // 文本过长时显示省略号
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 聊天列表标题 - 更新样式
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Text(
                AppLocalizations.of(context)!.recentChats,
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              // 可选: 添加一个更多操作的按钮
              IconButton(
                icon: const Icon(Icons.more_horiz, size: 20),
                color: colorScheme.onSurfaceVariant,
                onPressed: () {},
              ),
            ],
          ),
        ),

        // 聊天列表
        Expanded(
          child:
              chatProvider.isLoading
                  ? Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
                  )
                  : conversations.isEmpty
                  ? _buildEmptyConversationsList(context)
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 4.0,
                    ),
                    // 添加缓存键以优化重建
                    key: const PageStorageKey('chat_sidebar_conversations'),
                    // 添加物理滚动行为优化
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    // 增加缓存范围以减少重建
                    cacheExtent: 500,
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      final isActive =
                          activeConversation?.conversationId ==
                          conversation.conversationId;

                      // 使用RepaintBoundary包装每个会话项以优化渲染
                      return RepaintBoundary(
                        child: _buildConversationItem(
                          context,
                          conversation,
                          isActive,
                          chatProvider,
                        ),
                      );
                    },
                  ),
        ),

        // 底部用户信息 - Material 3风格卡片
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withAlpha((255 * 0.3).round()),
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            children: [
              // 用户头像点击行为，根据登录状态决定显示菜单或跳转登录
              GestureDetector(
                onTap: () {
                  // 获取认证提供者
                  final authProvider = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );

                  // 如果已登录，显示用户选项菜单，否则跳转到登录页面
                  if (authProvider.isAuthenticated) {
                    UserOptionsMenu.showUserOptionsBottomSheet(context);
                  } else {
                    // 显示提示
                    ToastNotification.showWarning(
                      message: AppLocalizations.of(context)!.loginRequired,
                      context: context,
                    );

                    // 跳转到登录页面
                    Navigator.pushNamed(context, '/login');
                  }
                },
                child: Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    final user = authProvider.user;
                    return CircleAvatar(
                      radius: 22,
                      backgroundColor: colorScheme.secondaryContainer,
                      child:
                          user?.name.isNotEmpty == true
                              ? Text(
                                user!.name[0].toUpperCase(),
                                style: TextStyle(
                                  color: colorScheme.onSecondaryContainer,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                              : Icon(
                                Icons.person,
                                color: colorScheme.onSecondaryContainer,
                                size: 24,
                              ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    final user = authProvider.user;
                    return Text(
                      user?.name ?? AppLocalizations.of(context)!.unknownUser,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ),
              // Material 3风格设置按钮
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                onPressed: () {
                  final bool isWideScreen =
                      MediaQuery.of(context).size.width >= breakpoint;
                  if (isWideScreen && onToggleSettings != null) {
                    // 宽屏模式：调用设置回调
                    onToggleSettings?.call();
                  } else {
                    // 窄屏模式：推入新页面 - 由HomeScreen的回调处理
                    onToggleSettings?.call();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 构建空的会话列表提示
  Widget _buildEmptyConversationsList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: colorScheme.primary.withValues(alpha: 128),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noConversations,
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 179),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.clickToCreateNewChat,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 构建会话项
  Widget _buildConversationItem(
    BuildContext context,
    Conversation conversation,
    bool isActive,
    ChatProvider chatProvider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const double emojiFontSize = 32.0; // Emoji字体大小

    // 获取最后一条消息的预览（如果有）
    String? messagePreview;
    if (conversation.messages.isNotEmpty) {
      final lastMsg = conversation.messages.last;
      messagePreview = lastMsg.content;
      if (messagePreview.length > 30) {
        messagePreview = '${messagePreview.substring(0, 30)}...';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      elevation: 0,
      // 使用 primaryContainer 作为活动背景色
      color:
          isActive
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        // 活动时边框使用主色，非活动时使用 outlineVariant
        side: BorderSide(
          color:
              isActive
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withAlpha((255 * 0.3).round()),
          // 活动时边框可以稍粗一点以示强调
          width: isActive ? 0.8 : 0.5,
        ),
      ),
      child: InkWell(
        onTap: () {
          // 切换到此会话
          chatProvider.setActiveConversation(conversation.conversationId);

          // 关闭其他页面，但由于我们不知道哪些页面是打开的，所以用这种方式不会起作用
          // 在HomeScreen中通过相应的Provider来实现这个功能会更合适
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              // 移除背景容器，直接显示Emoji，并增大字体
              Container(
                width: 40, // 保持一致的宽度
                height: 40, // 保持一致的高度
                alignment: Alignment.center, // 居中显示
                child: Text(
                  '💬',
                  style: TextStyle(
                    fontSize: emojiFontSize,
                    // 活动状态下Emoji颜色使用 onPrimaryContainer
                    color: isActive ? colorScheme.onPrimaryContainer : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.title,
                      style: textTheme.titleMedium?.copyWith(
                        // 活动状态文字颜色使用 onPrimaryContainer
                        color:
                            isActive
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurface,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    if (messagePreview != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          messagePreview,
                          style: textTheme.bodySmall?.copyWith(
                            // 活动状态预览文字颜色使用 onPrimaryContainer (带透明度)
                            color:
                                isActive
                                    ? colorScheme.onPrimaryContainer.withValues(
                                      alpha: 179,
                                    )
                                    : colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.more_vert,
                  // 活动状态图标颜色使用 onPrimaryContainer
                  color:
                      isActive
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: () {
                  _showConversationOptionsMenu(
                    context,
                    conversation,
                    chatProvider,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 显示会话选项菜单
  void _showConversationOptionsMenu(
    BuildContext context,
    Conversation conversation,
    ChatProvider chatProvider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 重命名会话
                ListTile(
                  leading: Icon(
                    Icons.edit,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    AppLocalizations.of(context)!.rename,
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _renameConversation(context, conversation, chatProvider);
                  },
                ),
                // 删除会话
                ListTile(
                  leading: Icon(Icons.delete, color: colorScheme.error),
                  title: Text(
                    AppLocalizations.of(context)!.delete,
                    style: TextStyle(color: colorScheme.error),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await chatProvider.deleteConversation(
                      conversation.conversationId,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 重命名会话
  void _renameConversation(
    BuildContext context,
    Conversation conversation,
    ChatProvider chatProvider,
  ) async {
    final formKey = GlobalKey<FormState>();
    String? newTitle = conversation.title;

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.renameChat),
            content: Form(
              key: formKey,
              child: TextFormField(
                initialValue: conversation.title,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.chatName,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '${AppLocalizations.of(context)!.chatName} ${AppLocalizations.of(context)!.required}';
                  }
                  return null;
                },
                onSaved: (value) {
                  newTitle = value?.trim();
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    formKey.currentState?.save();
                    Navigator.pop(context, true);
                  }
                },
                child: Text(AppLocalizations.of(context)!.confirm),
              ),
            ],
          ),
    ).then((confirmed) {
      if (confirmed == true &&
          newTitle != null &&
          newTitle != conversation.title) {
        // 更新会话标题，并同步到服务器
        chatProvider.updateConversationTitle(
          conversation.conversationId,
          newTitle!,
        );
      }
    });
  }
}
