import 'dart:async'; // 导入 Timer

import 'package:flutter/material.dart';
import 'package:carrot/shared/components/__export.dart'; // 导入统一组件
import 'package:carrot/features/home/providers/chat_provider.dart'; // 导入ChatProvider
import 'package:carrot/core/storage/__export.dart'; // 导入存储
import 'package:carrot/core/api/__export.dart'; // 导入API
import 'package:carrot/shared/models/__export.dart'; // 导入模型
import 'package:provider/provider.dart'; // 导入Provider
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 搜索页面
class SearchPage extends StatefulWidget {
  // 添加关闭回调
  final VoidCallback? onClose;

  const SearchPage({super.key, this.onClose});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  // 搜索类型选项
  List<String> _getSearchTypes(BuildContext context) {
    return [
      AppLocalizations.of(context)!.all,
      AppLocalizations.of(context)!.apps,
      AppLocalizations.of(context)!.conversations,
    ];
  }

  // 状态变量
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String _selectedType = ''; // 将在initState中初始化为"全部"类型
  List<dynamic> _searchResults = [];
  Timer? _debounce;
  bool _isLoading = true;
  String? _errorMessage;

  // 应用和对话数据
  List<AppModel> _apps = [];
  List<Conversation> _conversations = [];

  // 定义宽度阈值，与 HomeScreen 保持一致
  static const double breakpoint = 800.0;

  // 过滤器是否展开
  bool _isFilterExpanded = false;

  // 动画控制器
  late AnimationController _filterAnimationController;
  late Animation<double> _filterHeightAnimation;

  @override
  void initState() {
    super.initState();

    // 初始化动画控制器
    _filterAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _filterHeightAnimation = Tween<double>(
      begin: 0.0,
      end: 50.0, // 过滤器展开高度
    ).animate(
      CurvedAnimation(
        parent: _filterAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);

    // 初始化加载状态
    _isLoading = true;
    _errorMessage = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 在 didChangeDependencies 中初始化选中类型
    if (_selectedType.isEmpty) {
      setState(() {
        // 初始化选中类型为"全部"
        _selectedType = _getSearchTypes(context)[0]; // 选择第一个类型（全部）
      });
    }

    // 加载数据
    _loadData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounce?.cancel();
    _filterAnimationController.dispose();
    super.dispose();
  }

  // 加载应用和会话数据
  Future<void> _loadData() async {
    // 避免重复加载
    if (!_isLoading) return;

    try {
      // 获取会话数据
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      _conversations = chatProvider.conversations;

      // 获取当前语言设置
      final locale = Localizations.localeOf(context);

      // 获取应用数据，传递当前语言设置
      final appsResponse = await apiClientFactory.appApiClient.getApps(
        lang: locale.languageCode,
      );

      if (!mounted) return;

      if (!appsResponse.success) {
        setState(() {
          _isLoading = false;
          _errorMessage = appsResponse.message;
        });
      } else {
        try {
          // 获取本地已安装的应用
          final appStorage = await storageFactory.getAppStorage();
          final installedApps = await appStorage.getInstalledApps();

          // 设置已安装标记
          final List<AppModel> apps =
              appsResponse.data!.map((app) {
                final isInstalled = installedApps.any(
                  (installedApp) => installedApp.id == app.id,
                );
                return app.copyWith(isInstalled: isInstalled);
              }).toList();

          setState(() {
            _apps = apps;
          });
        } catch (e) {
          // 如果获取已安装应用失败，至少显示API返回的应用
          setState(() {
            _apps = appsResponse.data ?? [];
          });
        }
      }

      // 更新搜索结果
      _updateSearchResults();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '${AppLocalizations.of(context)!.failedToLoadData}: $e';
      });
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // 搜索防抖
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
          _updateSearchResults();
        });
      }
    });
  }

  void _toggleFilter() {
    setState(() {
      _isFilterExpanded = !_isFilterExpanded;
      if (_isFilterExpanded) {
        _filterAnimationController.forward();
      } else {
        _filterAnimationController.reverse();
      }
    });
  }

  void _selectSearchType(String type) {
    setState(() {
      _selectedType = type;
      _updateSearchResults();
    });
  }

  // 更新搜索结果
  void _updateSearchResults() {
    if (_searchQuery.isEmpty) {
      // 如果搜索框为空，显示全部结果
      final List<dynamic> results = [];
      final searchTypes = _getSearchTypes(context);

      // 添加应用
      if (_selectedType == searchTypes[0] || _selectedType == searchTypes[1]) {
        results.addAll(_apps);
      }

      // 添加会话
      if (_selectedType == searchTypes[0] || _selectedType == searchTypes[2]) {
        results.addAll(_conversations);
      }

      setState(() {
        _searchResults = results;
      });
    } else {
      // 否则根据搜索关键词和类型过滤
      final List<dynamic> results = [];
      final searchTypes = _getSearchTypes(context);

      // 过滤应用
      if (_selectedType == searchTypes[0] || _selectedType == searchTypes[1]) {
        final filteredApps =
            _apps.where((app) {
              return app.name.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  app.description.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  );
            }).toList();
        results.addAll(filteredApps);
      }

      // 过滤会话
      if (_selectedType == searchTypes[0] || _selectedType == searchTypes[2]) {
        final filteredConversations =
            _conversations.where((conversation) {
              // 搜索会话标题
              if (conversation.title.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              )) {
                return true;
              }

              // 搜索会话内容
              for (var message in conversation.messages) {
                if (message.content.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                )) {
                  return true;
                }
              }

              return false;
            }).toList();
        results.addAll(filteredConversations);
      }

      setState(() {
        _searchResults = results;
      });
    }
  }

  // 滚动监听
  void _onScroll() {
    // 可以在这里添加上拉加载更多的逻辑
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bool isWideScreen = MediaQuery.of(context).size.width >= breakpoint;

    // 定义AppBar的leading widget
    Widget? leadingWidget;
    if (isWideScreen && widget.onClose != null) {
      // 宽屏模式下，如果提供了onClose回调，显示关闭按钮
      leadingWidget = IconButton(
        icon: const Icon(Icons.close),
        onPressed: widget.onClose,
        tooltip: AppLocalizations.of(context)!.closeSearch,
        color: colorScheme.onSurface,
      );
    } else if (!isWideScreen && Navigator.canPop(context)) {
      // 窄屏模式下，如果可以返回，显示默认返回按钮
      leadingWidget = null; // AppBar 会自动添加返回按钮
    }

    return Scaffold(
      appBar: AppBar(
        leading: leadingWidget,
        automaticallyImplyLeading: !isWideScreen,
        title: Text(AppLocalizations.of(context)!.search),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          // 过滤器按钮
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _toggleFilter,
            tooltip: AppLocalizations.of(context)!.filter,
          ),
        ],
        // 在 AppBar 底部添加搜索栏
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            kToolbarHeight + (_isFilterExpanded ? 50 : 0),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
                child: AppSearchBar(
                  controller: _searchController,
                  hintText:
                      AppLocalizations.of(context)!.searchAppsAndConversations,
                  autofocus: true,
                  onChanged: (_) {
                    _onSearchChanged();
                  },
                  onClear: () {
                    setState(() {
                      _searchQuery = '';
                      _updateSearchResults();
                    });
                  },
                  onSubmitted: (_) {
                    _updateSearchResults();
                  },
                ),
              ),
              // 过滤器栏，使用动画
              AnimatedBuilder(
                animation: _filterHeightAnimation,
                builder: (context, child) {
                  return SizedBox(
                    height: _filterHeightAnimation.value,
                    child: _isFilterExpanded ? child : const SizedBox.shrink(),
                  );
                },
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children:
                        _getSearchTypes(context).map((type) {
                          final bool isSelected = _selectedType == type;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(type),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  _selectSearchType(type);
                                }
                              },
                              backgroundColor: colorScheme.surfaceContainerLow,
                              selectedColor: colorScheme.primaryContainer,
                              labelStyle: TextStyle(
                                color:
                                    isSelected
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              )
              : _errorMessage != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: colorScheme.error.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.loadingFailed,
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _errorMessage!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: Text(AppLocalizations.of(context)!.retry),
                    ),
                  ],
                ),
              )
              : _searchResults.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 64,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty
                          ? AppLocalizations.of(
                            context,
                          )!.pleaseEnterSearchKeywords
                          : AppLocalizations.of(context)!.noResultsFound,
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final item = _searchResults[index];

                  // 根据项目类型构建不同的UI
                  if (item is AppModel) {
                    return _buildAppItem(item, context);
                  } else if (item is Conversation) {
                    return _buildConversationItem(item, context);
                  } else {
                    return const SizedBox.shrink(); // 不应该出现的情况
                  }
                },
              ),
    );
  }

  // 构建应用项
  Widget _buildAppItem(AppModel app, BuildContext context) {
    return AppListCard(
      icon: app.icon,
      name: app.name,
      type: AppLocalizations.of(context)!.apps,
      description: app.description,
      onTap: () {
        // 处理应用点击事件
        // 可以跳转到应用详情或启动应用
      },
    );
  }

  // 构建会话项
  Widget _buildConversationItem(
    Conversation conversation,
    BuildContext context,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // 获取最后一条消息的预览（如果有）
    String messagePreview = '';
    if (conversation.messages.isNotEmpty) {
      final lastMsg = conversation.messages.last;
      messagePreview = lastMsg.content;
      if (messagePreview.length > 60) {
        messagePreview = '${messagePreview.substring(0, 60)}...';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('💬', style: TextStyle(fontSize: 24)),
        ),
        title: Text(
          conversation.title,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                AppLocalizations.of(context)!.conversations,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              messagePreview,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        onTap: () {
          // 处理会话点击事件
          final chatProvider = Provider.of<ChatProvider>(
            context,
            listen: false,
          );
          chatProvider.setActiveConversation(conversation.conversationId);
          widget.onClose?.call(); // 关闭搜索页面
        },
      ),
    );
  }
}
