// 聊天欢迎页面组件，显示在聊天开始前的欢迎信息

import 'package:flutter/material.dart';
// 导入 AppCard
import 'package:carrot/features/app_market/app_market_page.dart'; // 直接导入AppMarketPage，避免导入__export
import 'package:carrot/core/providers/auth_provider.dart'; // 导入AuthProvider
import 'package:provider/provider.dart'; // 导入Provider
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:carrot/shared/components/toast_notification.dart';

class ChatWelcome extends StatefulWidget {
  // 修改参数名为 onToggleAppMarket，类型为 VoidCallback?
  final VoidCallback? onToggleAppMarket;

  const ChatWelcome({super.key, this.onToggleAppMarket});

  @override
  State<ChatWelcome> createState() => _ChatWelcomeState();
}

class _ChatWelcomeState extends State<ChatWelcome>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  // 定义宽度阈值，与 HomeScreen 保持一致
  static const double breakpoint = 800.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 如果用户未登录，则显示登录按钮
    final authProvider = Provider.of<AuthProvider>(context);
    if (!authProvider.isAuthenticated) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                '欢迎来到 Carrot Chat！',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '登录后即可开启智能对话之旅',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('立即登录'),
              ),
            ],
          ),
        ),
      );
    }
    // 获取当前屏幕尺寸以便进行响应式调整
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400;

    // 预先构建内容以避免在动画中重建
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: isSmallScreen ? screenSize.width * 0.9 : 700,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 欢迎卡片
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.9),
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 20.0 : 32.0),
                child: Column(
                  children: [
                    // 主标题
                    Text(
                      AppLocalizations.of(context)!.chooseAppPlugins,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: isSmallScreen ? 22 : null,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // 副标题
                    Text(
                      AppLocalizations.of(context)!.enhanceAICapabilities,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: isSmallScreen ? 14 : null,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isSmallScreen ? 24.0 : 36.0),

                    // 操作按钮
                    _buildActionButtons(context, isSmallScreen),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 应用选择区
            _buildAppSelection(context, isSmallScreen),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        Center(
          // 使用RepaintBoundary包装动画内容，防止重绘传播
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return FadeTransition(
                  opacity: _scaleAnimation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.9,
                      end: 1.0,
                    ).animate(_scaleAnimation),
                    child: content,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isSmallScreen) {
    final colorScheme = Theme.of(context).colorScheme;
    // 使用从 build 方法获取的 isWideScreen
    final isWideScreen = MediaQuery.of(context).size.width >= breakpoint;

    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.shopping_bag_outlined),
        label: Text(
          isSmallScreen
              ? AppLocalizations.of(context)!.appMarketShort
              : AppLocalizations.of(context)!.browseAppMarket,
        ),
        onPressed: () {
          // 获取认证提供者
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );

          // 如果未登录，则跳转到登录页面
          if (!authProvider.isAuthenticated) {
            // 显示提示
            ToastNotification.showInfo(
              message: AppLocalizations.of(context)!.loginRequired,
              context: context,
            );

            // 跳转到登录页面
            Navigator.pushNamed(context, '/login');
            return;
          }

          if (isWideScreen) {
            // 宽屏：调用新的回调
            widget.onToggleAppMarket?.call();
          } else {
            // 窄屏：推入新页面
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AppMarketPage()),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 2,
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16 : 24,
            vertical: isSmallScreen ? 10 : 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          // 在深色模式添加边框，使按钮更加和谐
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  Widget _buildAppSelection(BuildContext context, bool isSmallScreen) {
    // 移除应用市场的提示
    return const SizedBox.shrink();
  }
}
