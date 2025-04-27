import 'package:flutter/material.dart';
import 'package:carrot/features/app_market/__export.dart'; // 导入 AppMarketPage
import 'package:carrot/features/search/__export.dart'; // 导入 SearchPage
import 'package:carrot/features/settings/__export.dart'; // 导入 SettingsPage
import 'package:carrot/features/home/widgets/chat_input/chat_input.dart';
import 'package:carrot/features/home/widgets/chat_sidebar/chat_sidebar.dart';
import 'package:carrot/features/home/widgets/chat_welcome/chat_welcome.dart';
import 'package:carrot/features/home/widgets/chat_header/chat_header.dart'; // 导入ChatHeader组件
import 'package:carrot/features/home/widgets/chat_message_area/chat_message_area.dart'; // 导入ChatMessageArea组件
import 'package:carrot/features/home/providers/chat_provider.dart'; // 导入ChatProvider
import 'package:provider/provider.dart'; // 导入Provider
// 导入AuthProvider
import 'package:carrot/features/auth/widgets/auth_wrapper.dart'; // 导入AuthWrapper
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// 添加 TickerProviderStateMixin 用于动画控制器
class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showSidebar = true;
  bool _showAppMarket = false; // 应用市场显示状态
  bool _showSearch = false; // 搜索页面显示状态
  bool _showSettings = false; // 设置页面显示状态
  // 定义侧边栏宽度
  final double _sidebarWidth = 280.0;
  // 定义动画时长
  final Duration _animationDuration = const Duration(milliseconds: 300);
  // 定义宽度阈值
  final double _breakpoint = 800.0;
  // 用于跟踪上一次的自动显隐状态
  bool? _previousShouldShowSidebarBasedOnWidth;

  // 应用市场动画控制器和动画
  late AnimationController _appMarketAnimationController;
  late Animation<Offset> _appMarketSlideAnimation;

  // 搜索页面动画控制器和动画
  late AnimationController _searchAnimationController;
  late Animation<Offset> _searchSlideAnimation;

  // 设置页面动画控制器和动画
  late AnimationController _settingsAnimationController;
  late Animation<Offset> _settingsSlideAnimation;

  @override
  void initState() {
    super.initState();
    // 初始化应用市场动画控制器
    _appMarketAnimationController = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );

    final appMarketCurvedAnimation = CurvedAnimation(
      parent: _appMarketAnimationController,
      curve: Curves.easeInOutCubic,
    );

    // 初始化应用市场滑动动画 (从右侧滑入)
    _appMarketSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(appMarketCurvedAnimation);

    // 初始化搜索页面动画控制器
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );

    final searchCurvedAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOutCubic,
    );

    // 初始化搜索页面滑动动画 (从右侧滑入)
    _searchSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(searchCurvedAnimation);

    // 初始化设置页面动画控制器
    _settingsAnimationController = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );

    final settingsCurvedAnimation = CurvedAnimation(
      parent: _settingsAnimationController,
      curve: Curves.easeInOutCubic,
    );

    // 初始化设置页面滑动动画 (从右侧滑入)
    _settingsSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(settingsCurvedAnimation);

    // 添加应用市场动画监听器
    _appMarketAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        // 动画完全隐藏后，不再渲染 AppMarketPage
        if (mounted) {
          setState(() {
            _showAppMarket = false;
          });
        }
      }
    });

    // 添加搜索页面动画监听器
    _searchAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        // 动画完全隐藏后，不再渲染 SearchPage
        if (mounted) {
          setState(() {
            _showSearch = false;
          });
        }
      }
    });

    // 添加设置页面动画监听器
    _settingsAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        // 动画完全隐藏后，不再渲染 SettingsPage
        if (mounted) {
          setState(() {
            _showSettings = false;
          });
        }
      }
    });

    // 根据初始宽度设置侧边栏状态 (避免动画闪烁)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bool initialShouldShow =
          MediaQuery.of(context).size.width >= _breakpoint;
      final bool isMobile = MediaQuery.of(context).size.width < 600;
      if (!isMobile) {
        setState(() {
          _showSidebar = initialShouldShow;
          _previousShouldShowSidebarBasedOnWidth = initialShouldShow;
        });
      }

      // 设置会话切换回调
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.onConversationChanged = _closeAllPanels;
    });
  }

  @override
  void dispose() {
    _appMarketAnimationController.dispose();
    _searchAnimationController.dispose();
    _settingsAnimationController.dispose();
    super.dispose();
  }

  // 发送消息前检查登录状态
  void _handleSendMessage(String text, {bool? deepThinking}) async {
    // 检查用户是否已登录，如果未登录则跳转到登录页面
    if (!AuthWrapper.checkAuthAndRedirect(context)) {
      return; // 未登录，不继续操作
    }

    try {
      // 获取ChatProvider
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      // 使用传入的深度思考状态
      final useDeepThinking = deepThinking ?? false;

      // 发送消息，传递深度思考状态
      await chatProvider.sendMessage(text, useDeepThinking: useDeepThinking);
    } catch (e) {
      debugPrint("Failed to send message: $e");
    }
  }

  // 添加创建新会话的方法
  void _createNewChat() async {
    // 检查用户是否已登录，如果未登录则跳转到登录页面
    if (!AuthWrapper.checkAuthAndRedirect(context)) {
      return; // 未登录，不继续操作
    }

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    await chatProvider.createNewConversation();

    // 确保关闭其他页面
    if (_showAppMarket) {
      _toggleAppMarketView(show: false);
    }
    if (_showSearch) {
      _toggleSearchView(show: false);
    }
    if (_showSettings) {
      _toggleSettingsView(show: false);
    }
  }

  // 添加返回欢迎页面的方法
  void _returnToWelcome() {
    // 清除活动会话以返回欢迎页
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.clearActiveConversation();

    // 如果有其他页面（如AppMarket, Search, Settings）打开，也需要关闭
    if (_showAppMarket) {
      _toggleAppMarketView(show: false);
    }
    if (_showSearch) {
      _toggleSearchView(show: false);
    }
    if (_showSettings) {
      _toggleSettingsView(show: false);
    }
    // 不再需要setState，因为ChatProvider会通知更新
  }

  void _toggleSidebar() {
    setState(() {
      _showSidebar = !_showSidebar;
    });
  }

  // 修改：切换应用市场视图
  void _toggleAppMarketView({required bool show}) {
    // 如果要显示应用市场，需要检查登录状态
    if (show && !AuthWrapper.checkAuthAndRedirect(context)) {
      return; // 未登录，不继续操作
    }

    final bool isWideScreen = MediaQuery.of(context).size.width >= _breakpoint;
    if (isWideScreen) {
      if (show && !_showAppMarket) {
        // 显示应用市场前，确保其他页面关闭
        if (_showSearch) {
          _searchAnimationController.reverse();
        }
        if (_showSettings) {
          _settingsAnimationController.reverse();
        }

        // 只有当需要显示且当前未显示时才触发
        setState(() {
          _showAppMarket = true; // 先渲染 AppMarketPage
        });
        _appMarketAnimationController.forward();
      } else if (!show && _showAppMarket) {
        // 只有当需要隐藏且当前已显示时才触发
        _appMarketAnimationController.reverse();
      }
      // 如果状态已是目标状态，则不执行任何操作
    } else {
      // 窄屏模式：保持 Navigator.push，但仍需检查登录状态
      if (show) {
        // 登录检查已在方法开头完成，这里可以直接导航
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AppMarketPage()),
        );
      }
    }
  }

  // 添加：切换搜索页面视图
  void _toggleSearchView({required bool show}) {
    // 如果要显示搜索页面，需要检查登录状态
    if (show && !AuthWrapper.checkAuthAndRedirect(context)) {
      return; // 未登录，不继续操作
    }

    final bool isWideScreen = MediaQuery.of(context).size.width >= _breakpoint;
    if (isWideScreen) {
      if (show && !_showSearch) {
        // 显示搜索页面前，确保其他页面关闭
        if (_showAppMarket) {
          _appMarketAnimationController.reverse();
        }
        if (_showSettings) {
          _settingsAnimationController.reverse();
        }

        // 只有当需要显示且当前未显示时才触发
        setState(() {
          _showSearch = true; // 先渲染 SearchPage
        });
        _searchAnimationController.forward();
      } else if (!show && _showSearch) {
        // 只有当需要隐藏且当前已显示时才触发
        _searchAnimationController.reverse();
      }
      // 如果状态已是目标状态，则不执行任何操作
    } else {
      // 窄屏模式：保持 Navigator.push
      if (show) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SearchPage()),
        );
      }
    }
  }

  // 添加：切换设置页面视图
  void _toggleSettingsView({required bool show}) {
    // 如果要显示设置页面，需要检查登录状态
    if (show && !AuthWrapper.checkAuthAndRedirect(context)) {
      return; // 未登录，不继续操作
    }

    final bool isWideScreen = MediaQuery.of(context).size.width >= _breakpoint;
    if (isWideScreen) {
      if (show && !_showSettings) {
        // 显示设置页面前，确保其他页面关闭
        if (_showAppMarket) {
          _appMarketAnimationController.reverse();
        }
        if (_showSearch) {
          _searchAnimationController.reverse();
        }

        // 只有当需要显示且当前未显示时才触发
        setState(() {
          _showSettings = true; // 先渲染 SettingsPage
        });
        _settingsAnimationController.forward();
      } else if (!show && _showSettings) {
        // 只有当需要隐藏且当前已显示时才触发
        _settingsAnimationController.reverse();
      }
      // 如果状态已是目标状态，则不执行任何操作
    } else {
      // 窄屏模式：保持 Navigator.push
      if (show) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsPage()),
        );
      }
    }
  }

  // 关闭所有面板
  void _closeAllPanels() {
    if (_showAppMarket) {
      _toggleAppMarketView(show: false);
    }
    if (_showSearch) {
      _toggleSearchView(show: false);
    }
    if (_showSettings) {
      _toggleSettingsView(show: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 检测屏幕尺寸，确定是否为移动设备
    final bool isMobileView = MediaQuery.of(context).size.width < 600;
    final bool isWideScreen = MediaQuery.of(context).size.width >= _breakpoint;
    final colorScheme = Theme.of(context).colorScheme;

    // 使用 Material 3 表面色阶来区分左右面板
    // 左侧面板使用更深的颜色 - surfaceContainerLowest
    final leftPanelColor = colorScheme.surfaceContainerLowest;
    // 右侧面板使用更浅的表面颜色 - surface
    final rightPanelColor = colorScheme.surface;

    // 获取聊天提供者
    final chatProvider = Provider.of<ChatProvider>(context);
    final hasActiveConversation = chatProvider.activeConversation != null;

    // 获取当前会话标题，如果有活动会话
    final String currentTitle =
        hasActiveConversation
            ? chatProvider.activeConversation!.title
            : AppLocalizations.of(context)!.appName;

    return Scaffold(
      key: _scaffoldKey,
      appBar:
          isMobileView
              ? PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: ChatHeader(
                  onMenuPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                  onHomePressed: _returnToWelcome,
                  title: currentTitle,
                ),
              )
              : null,
      // 移动端 Drawer 使用主题默认背景色
      drawer:
          isMobileView
              ? Drawer(
                child: ChatSidebar(
                  onToggleAppMarket: () => _toggleAppMarketView(show: true),
                  onToggleSearch: () => _toggleSearchView(show: true), // 添加搜索回调
                  onToggleSettings:
                      () => _toggleSettingsView(show: true), // 添加设置回调
                  onNewChat: _createNewChat, // 添加新建会话回调
                ),
              )
              : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 根据 LayoutBuilder 提供的宽度判断是否应该自动显示/隐藏侧边栏
          final bool shouldShowSidebarBasedOnWidth =
              constraints.maxWidth >= _breakpoint;

          // 使用 addPostFrameCallback 避免在 build 过程中调用 setState
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // 检查是否挂载，避免在 dispose 后调用 setState
            if (!mounted) return;

            // 仅当 shouldShowSidebarBasedOnWidth 状态发生变化时（即跨越断点）
            // 并且不是移动视图时，才自动更新侧边栏状态
            if (_previousShouldShowSidebarBasedOnWidth != null &&
                shouldShowSidebarBasedOnWidth !=
                    _previousShouldShowSidebarBasedOnWidth &&
                !isMobileView) {
              setState(() {
                _showSidebar = shouldShowSidebarBasedOnWidth;
              });
            }
            // 更新上一次的状态
            _previousShouldShowSidebarBasedOnWidth =
                shouldShowSidebarBasedOnWidth;
          });

          // 决定实际是否显示侧边栏（考虑手动触发和宽度判断）
          // 在非移动端，侧边栏的显示状态由 _showSidebar 控制
          final bool actuallyShowSidebar = !isMobileView && _showSidebar;

          return Row(
            children: [
              // 1. Left Sidebar (conditionally animated)
              if (!isMobileView)
                AnimatedContainer(
                  duration: _animationDuration,
                  curve: Curves.easeInOutCubic,
                  width: actuallyShowSidebar ? _sidebarWidth : 0,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: leftPanelColor,
                    border: Border(
                      right: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    boxShadow:
                        actuallyShowSidebar
                            ? [
                              BoxShadow(
                                color: colorScheme.shadow.withValues(
                                  alpha: 0.08,
                                ),
                                blurRadius: 8,
                                spreadRadius: 0,
                                offset: const Offset(1, 0),
                              ),
                            ]
                            : [],
                  ),
                  child: OverflowBox(
                    maxWidth: _sidebarWidth,
                    minWidth: _sidebarWidth,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: _sidebarWidth,
                      child: ChatSidebar(
                        onToggleAppMarket:
                            () => _toggleAppMarketView(show: true),
                        onToggleSearch: () => _toggleSearchView(show: true),
                        onToggleSettings: () => _toggleSettingsView(show: true),
                        onNewChat: _createNewChat, // 添加新建会话回调
                      ),
                    ),
                  ),
                ),

              // 2. Main Content Area (Central + Right Panels managed by Stack)
              Expanded(
                child: Column(
                  children: [
                    // Optional Header for Wide Screens
                    if (!isMobileView)
                      ChatHeader(
                        showSidebar: _showSidebar,
                        onMenuPressed: _toggleSidebar,
                        onHomePressed: _returnToWelcome,
                        title: currentTitle,
                      ),

                    // Stack to manage Central and Right Panels
                    Expanded(
                      child: Stack(
                        children: [
                          // Bottom Layer: Central Panel (Chat/Welcome + Input)
                          _buildCentralPanel(
                            colorScheme,
                            isWideScreen,
                            () => _toggleAppMarketView(show: true),
                            hasActiveConversation,
                          ),

                          // 应用市场面板
                          if (_showAppMarket)
                            SlideTransition(
                              position: _appMarketSlideAnimation,
                              child: Container(
                                // 确保此容器覆盖整个区域
                                width: double.infinity,
                                height: double.infinity,
                                color: rightPanelColor,
                                child: AppMarketPage(
                                  onClose:
                                      () => _toggleAppMarketView(show: false),
                                ),
                              ),
                            ),

                          // 搜索页面面板
                          if (_showSearch)
                            SlideTransition(
                              position: _searchSlideAnimation,
                              child: Container(
                                // 确保此容器覆盖整个区域
                                width: double.infinity,
                                height: double.infinity,
                                color: rightPanelColor,
                                child: SearchPage(
                                  onClose: () => _toggleSearchView(show: false),
                                ),
                              ),
                            ),

                          // 设置页面面板
                          if (_showSettings)
                            SlideTransition(
                              position: _settingsSlideAnimation,
                              child: Container(
                                // 确保此容器覆盖整个区域
                                width: double.infinity,
                                height: double.infinity,
                                color: rightPanelColor,
                                child: SettingsPage(
                                  onClose:
                                      () => _toggleSettingsView(show: false),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Helper to build the central panel (Chat/Welcome + Input)
  Widget _buildCentralPanel(
    ColorScheme colorScheme,
    bool isWideScreen,
    VoidCallback onToggleAppMarket,
    bool hasActiveConversation,
  ) {
    // 获取聊天提供者
    final chatProvider = Provider.of<ChatProvider>(context);

    return Column(
      children: [
        Expanded(
          child:
              hasActiveConversation
                  ? ChatMessageArea(
                    conversation: chatProvider.activeConversation,
                    isLoading: chatProvider.isSending,
                  )
                  : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ChatWelcome(onToggleAppMarket: onToggleAppMarket),
                  ),
        ),
        // Add Padding around ChatInput
        Padding(
          padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            bottom: 20.0, // Add bottom padding
            top: 8.0, // Keep some top padding if needed
          ),
          child: ChatInput(onSendMessage: _handleSendMessage),
        ),
      ],
    );
  }
}
