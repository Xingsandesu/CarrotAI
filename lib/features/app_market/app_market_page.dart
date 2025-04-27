import 'dart:async'; // 导入 Timer

import 'package:flutter/material.dart';
import 'package:carrot/core/api/__export.dart';
import 'package:carrot/core/storage/__export.dart';
import 'package:carrot/shared/components/__export.dart';
import 'package:carrot/shared/models/__export.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:carrot/features/app_market/env_editor_dialog.dart';
import 'package:carrot/shared/components/toast_notification.dart';

/// 应用市场页面
class AppMarketPage extends StatefulWidget {
  // 添加关闭回调
  final VoidCallback? onClose;

  const AppMarketPage({super.key, this.onClose});

  @override
  State<AppMarketPage> createState() => _AppMarketPageState();
}

class _AppMarketPageState extends State<AppMarketPage> {
  // 状态变量
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String? _selectedCategory;
  List<AppModel> _filteredApps = []; // 显示的列表（分页后）
  List<AppModel> _currentlyFilteredFullList = []; // 当前过滤条件下的完整列表
  List<AppModel> _allApps = []; // 从API获取的所有应用
  Set<String> _categories = {}; // 所有分类
  Timer? _debounce;
  bool _isLoading = true; // 加载状态
  String? _errorMessage; // 错误信息

  // 分页状态
  int _currentPage = 1;
  final int _itemsPerPage = 8; // 每页加载8个
  bool _isLoadingMore = false;
  bool _hasMoreItems = true; // 是否还有更多项可加载

  // 定义宽度阈值，与 HomeScreen 保持一致
  static const double breakpoint = 800.0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    // 不在 initState 中直接调用依赖 context 的方法
    _isLoading = true;
    _errorMessage = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 在 didChangeDependencies 中加载应用数据，这里可以安全地访问 context
    _loadApps();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // 从API加载应用数据
  Future<void> _loadApps() async {
    // 避免重复加载
    if (!_isLoading) return;

    try {
      // 获取当前语言设置
      final locale = Localizations.localeOf(context);

      // 获取API数据，传递当前语言设置
      final appsResponse = await apiClientFactory.appApiClient.getApps(
        lang: locale.languageCode,
      );

      if (!mounted) return;

      if (!appsResponse.success) {
        setState(() {
          _isLoading = false;
          _errorMessage = appsResponse.message;
        });
        return;
      }

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

      if (mounted) {
        setState(() {
          _allApps = apps;
          _categories = apps.map((app) => app.type).toSet();
          _currentlyFilteredFullList = List.from(_allApps);
          _isLoading = false;
          _loadInitialItems(); // 加载初始页数据
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              '${AppLocalizations.of(context)!.failedToLoadApps}: $e';
        });
      }
    }
  }

  // 查看应用环境变量
  void _viewAppEnvironment(AppModel app) {
    // 获取主题颜色
    final colorScheme = Theme.of(context).colorScheme;

    // 获取环境变量
    final Map<dynamic, dynamic> rawEnv =
        (app.mcpServer['env'] as Map<dynamic, dynamic>?) ?? {};
    // 转换为 Map<String, dynamic>
    final Map<String, dynamic> env = {};
    for (final entry in rawEnv.entries) {
      env[entry.key.toString()] = entry.value;
    }

    // 显示环境变量查看对话框
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              '${AppLocalizations.of(context)!.appStorage} - ${app.name}',
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // URL 显示
                  Text(
                    'MCP Server URL:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 77,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Text(
                      app.mcpServer['url']?.toString() ?? '',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 环境变量标题
                  Text(
                    '${AppLocalizations.of(context)!.appStorage}:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // 环境变量列表
                  if (env.isEmpty)
                    Text(AppLocalizations.of(context)!.noResults)
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: env.length,
                        itemBuilder: (context, index) {
                          final key = env.keys.elementAt(index);
                          final value = env[key];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                // 键
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    key.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // 值
                                Expanded(
                                  flex: 3,
                                  child: Text(value.toString()),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context)!.close),
              ),
            ],
          ),
    );
  }

  // 编辑应用环境变量
  Future<void> _editAppEnvironment(AppModel app) async {
    if (!mounted) return;

    // 显示环境变量编辑对话框
    final updatedApp = await showEnvEditorDialog(
      context: context,
      app: app,
      isInstalling: false,
    );

    // 如果用户取消了编辑，则不更新
    if (updatedApp == null || !mounted) {
      return;
    }

    // 更新应用
    final appStorage = await storageFactory.getAppStorage();
    final success = await appStorage.installApp(updatedApp);

    if (success && mounted) {
      // 更新应用状态
      setState(() {
        // 更新特定应用的安装状态
        final int index = _allApps.indexWhere((a) => a.id == app.id);
        if (index >= 0) {
          _allApps[index] = updatedApp;
        }

        // 更新过滤后的列表
        final int filteredIndex = _currentlyFilteredFullList.indexWhere(
          (a) => a.id == app.id,
        );
        if (filteredIndex >= 0) {
          _currentlyFilteredFullList[filteredIndex] = updatedApp;
        }

        // 更新当前显示的列表
        final int visibleIndex = _filteredApps.indexWhere(
          (a) => a.id == app.id,
        );
        if (visibleIndex >= 0) {
          _filteredApps[visibleIndex] = updatedApp;
        }
      });

      // 显示成功消息
      ToastNotification.showSuccess(
        message: '${AppLocalizations.of(context)!.appEdit}: ${updatedApp.name}',
        context: context,
        duration: const Duration(seconds: 2),
      );
    }
  }

  // 安装或卸载应用
  Future<void> _toggleAppInstallation(AppModel app) async {
    try {
      final appStorage = await storageFactory.getAppStorage();
      bool success;

      if (app.isInstalled) {
        // 卸载应用
        success = await appStorage.uninstallApp(app.id);
      } else {
        // 安装应用
        // 检查组件是否仍然挂载
        if (!mounted) return;

        // 显示环境变量编辑对话框
        final updatedApp = await showEnvEditorDialog(
          context: context,
          app: app,
          isInstalling: true,
        );

        // 如果用户取消了编辑或组件已经卸载，则不安装
        if (updatedApp == null || !mounted) {
          return;
        }

        // 安装更新后的应用
        success = await appStorage.installApp(updatedApp);
      }

      if (success && mounted) {
        // 更新应用状态
        setState(() {
          // 更新特定应用的安装状态
          final int index = _allApps.indexWhere((a) => a.id == app.id);
          if (index >= 0) {
            _allApps[index] = _allApps[index].copyWith(
              isInstalled: !app.isInstalled,
            );
          }

          // 更新过滤后的列表
          final int filteredIndex = _currentlyFilteredFullList.indexWhere(
            (a) => a.id == app.id,
          );
          if (filteredIndex >= 0) {
            _currentlyFilteredFullList[filteredIndex] =
                _currentlyFilteredFullList[filteredIndex].copyWith(
                  isInstalled: !app.isInstalled,
                );
          }

          // 更新当前显示的列表
          final int visibleIndex = _filteredApps.indexWhere(
            (a) => a.id == app.id,
          );
          if (visibleIndex >= 0) {
            _filteredApps[visibleIndex] = _filteredApps[visibleIndex].copyWith(
              isInstalled: !app.isInstalled,
            );
          }
        });

        // 显示成功消息
        ToastNotification.showSuccess(
          message:
              app.isInstalled
                  ? '${AppLocalizations.of(context)!.uninstalled}: ${app.name}'
                  : '${AppLocalizations.of(context)!.installed}: ${app.name}',
          context: context,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.showError(
          message: '${AppLocalizations.of(context)!.operationFailed}: $e',
          context: context,
        );
      }
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // 搜索防抖
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
          _resetPaginationAndFilter();
        });
      }
    });
  }

  // 重置分页并重新过滤
  void _resetPaginationAndFilter() {
    _currentPage = 1;
    _hasMoreItems = true;
    _filterApps();
  }

  // 过滤应用逻辑（不直接修改 _filteredApps）
  void _filterApps() {
    _currentlyFilteredFullList =
        _allApps.where((app) {
          final nameMatches = app.name.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
          final typeMatches = app.type.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
          final descriptionMatches = app.description.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
          final categoryMatches =
              _selectedCategory == null || app.type == _selectedCategory;

          return (nameMatches || typeMatches || descriptionMatches) &&
              categoryMatches;
        }).toList();

    _loadInitialItems(); // 加载过滤后的第一页
  }

  // 加载初始项（第一页）
  void _loadInitialItems() {
    final totalFilteredItems = _currentlyFilteredFullList.length;
    final endIndex =
        totalFilteredItems < _itemsPerPage ? totalFilteredItems : _itemsPerPage;

    _filteredApps =
        endIndex > 0 ? _currentlyFilteredFullList.sublist(0, endIndex) : [];

    _hasMoreItems = _filteredApps.length < totalFilteredItems;
    _isLoadingMore = false; // 确保初始加载后 loading 状态为 false
  }

  // 滚动监听
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        !_isLoadingMore &&
        _hasMoreItems) {
      _loadMoreItems();
    }
  }

  // 加载更多项目
  Future<void> _loadMoreItems() async {
    if (_isLoadingMore || !_hasMoreItems) return;

    setState(() {
      _isLoadingMore = true;
    });

    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return; // 检查 widget 是否还在树中

    setState(() {
      final startIndex = _currentPage * _itemsPerPage;
      final totalFilteredItems = _currentlyFilteredFullList.length;
      final endIndex =
          (startIndex + _itemsPerPage) > totalFilteredItems
              ? totalFilteredItems
              : startIndex + _itemsPerPage;

      if (startIndex < totalFilteredItems) {
        _filteredApps.addAll(
          _currentlyFilteredFullList.sublist(startIndex, endIndex),
        );
        _currentPage++;
      }

      _hasMoreItems = _filteredApps.length < totalFilteredItems;
      _isLoadingMore = false;
    });
  }

  // 修改 _onCategorySelected 以重置分页
  void _onCategorySelected(String category) {
    setState(() {
      if (category == '全部') {
        _selectedCategory = null;
      } else if (_selectedCategory == category) {
        _selectedCategory = null; // 再次点击取消选择
      } else {
        _selectedCategory = category;
      }
      _resetPaginationAndFilter(); // 重置分页并过滤
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isWideScreen = MediaQuery.of(context).size.width >= breakpoint;

    // 定义AppBar的leading widget
    Widget? leadingWidget;
    if (isWideScreen && widget.onClose != null) {
      // 宽屏模式下，如果提供了onClose回调，显示关闭按钮
      leadingWidget = IconButton(
        icon: const Icon(Icons.close),
        onPressed: widget.onClose,
        tooltip: AppLocalizations.of(context)!.closeAppMarket,
        color: colorScheme.onSurface, // 确保图标颜色与标题一致
      );
    } else if (!isWideScreen && Navigator.canPop(context)) {
      // 窄屏模式下，返回按钮由 AppBar.automaticallyImplyLeading 自动处理
      leadingWidget = null;
    }

    return Scaffold(
      appBar: AppBar(
        leading: leadingWidget, // 使用上面定义的 leading
        automaticallyImplyLeading: !isWideScreen, // 窄屏时自动显示返回按钮
        title: Text(AppLocalizations.of(context)!.appMarket),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          // 添加刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppLocalizations.of(context)!.refreshAppList,
            onPressed: _loadApps,
          ),
        ],
        // 在 AppBar 底部添加搜索栏
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
            child: AppSearchBar(
              controller: _searchController,
              hintText: AppLocalizations.of(context)!.searchApps,
              onChanged: (_) {
                _onSearchChanged();
              },
              onClear: () {
                setState(() {
                  _searchQuery = '';
                  _resetPaginationAndFilter();
                });
              },
              onSubmitted: (_) {
                _resetPaginationAndFilter();
              },
            ),
          ),
        ),
      ),
      backgroundColor: colorScheme.surface,
      body:
          _isLoading
              // 加载中显示加载指示器
              ? const Center(child: CircularProgressIndicator())
              // 发生错误显示错误信息
              : _errorMessage != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadApps,
                      child: Text(AppLocalizations.of(context)!.reload),
                    ),
                  ],
                ),
              )
              // 正常显示应用列表
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 分类筛选器
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                        spacing: 8.0,
                        children: _buildFilterChips(colorScheme, isDarkMode),
                      ),
                    ),
                  ),
                  // 应用列表
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                      child:
                          _currentlyFilteredFullList.isEmpty && !_isLoadingMore
                              ? Center(
                                child: Text(
                                  AppLocalizations.of(context)!.noAppsFound,
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                              : ListView.builder(
                                controller: _scrollController, // 绑定 controller
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                // 添加缓存键以优化重建
                                key: const PageStorageKey('app_market_list'),
                                // 增加缓存范围以减少重建
                                cacheExtent: 500,
                                // itemCount 包含加载指示器
                                itemCount:
                                    _filteredApps.length +
                                    (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  // 如果是最后一项且正在加载，显示指示器
                                  if (index == _filteredApps.length &&
                                      _isLoadingMore) {
                                    return const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  }

                                  // 显示应用列表项
                                  final app = _filteredApps[index];
                                  // 使用RepaintBoundary包装每个卡片以优化渲染
                                  return RepaintBoundary(
                                    child: AppListCard(
                                      key: ValueKey('app_${app.id}'),
                                      icon: app.icon,
                                      name: app.name,
                                      type: app.type,
                                      description: app.description,
                                      isInstalled: app.isInstalled,
                                      actionLabel:
                                          app.isInstalled
                                              ? AppLocalizations.of(
                                                context,
                                              )!.uninstall
                                              : AppLocalizations.of(
                                                context,
                                              )!.install,
                                      onTap: () {
                                        // 点击卡片显示应用详情
                                        _showAppDetails(app);
                                      },
                                      onActionTap: () {
                                        // 点击安装/卸载按钮
                                        _toggleAppInstallation(app);
                                      },
                                    ),
                                  );
                                },
                              ),
                    ),
                  ),
                ],
              ),
    );
  }

  // 构建分类筛选 Chip
  List<Widget> _buildFilterChips(ColorScheme colorScheme, bool isDarkMode) {
    List<Widget> chips = [];

    // "全部" 选项
    chips.add(
      FilterChip(
        label: Text(AppLocalizations.of(context)!.all),
        selected: _selectedCategory == null,
        onSelected: (_) => _onCategorySelected('全部'), // 使用特殊值触发清除
        showCheckmark: false,
        selectedColor: colorScheme.primaryContainer,
        checkmarkColor: colorScheme.onPrimaryContainer,
        labelStyle: TextStyle(
          color:
              _selectedCategory == null
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
        ),
        backgroundColor: colorScheme.surfaceContainer,
        shape: StadiumBorder(
          side: BorderSide(
            color:
                _selectedCategory == null
                    ? Colors.transparent
                    : colorScheme.outlineVariant.withAlpha((255 * 0.5).round()),
          ),
        ),
        elevation: _selectedCategory == null ? 1 : 0,
      ),
    );

    // 其他分类
    for (String category in _categories) {
      final bool isSelected = _selectedCategory == category;
      chips.add(
        FilterChip(
          label: Text(category),
          selected: isSelected,
          onSelected: (_) => _onCategorySelected(category),
          showCheckmark: false,
          selectedColor: colorScheme.primaryContainer,
          checkmarkColor: colorScheme.onPrimaryContainer,
          labelStyle: TextStyle(
            color:
                isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
          ),
          backgroundColor: colorScheme.surfaceContainer,
          shape: StadiumBorder(
            side: BorderSide(
              color:
                  isSelected
                      ? Colors.transparent
                      : colorScheme.outlineVariant.withAlpha(
                        (255 * 0.5).round(),
                      ),
            ),
          ),
          elevation: isSelected ? 1 : 0,
        ),
      );
    }
    return chips;
  }

  // 显示应用详情对话框
  void _showAppDetails(AppModel app) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(app.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${AppLocalizations.of(context)!.type}: ${app.type}'),
                const SizedBox(height: 8),
                Text(
                  '${AppLocalizations.of(context)!.description}: ${app.description}',
                ),
                const SizedBox(height: 16),
                Text(
                  '${AppLocalizations.of(context)!.status}: ${app.isInstalled ? AppLocalizations.of(context)!.installed : AppLocalizations.of(context)!.notInstalled}',
                  style: TextStyle(
                    color:
                        app.isInstalled
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                    fontWeight:
                        app.isInstalled ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppLocalizations.of(context)!.close),
              ),
              // 如果应用已安装，显示查看和编辑环境变量按钮
              if (app.isInstalled) ...[
                // 查看环境变量按钮
                TextButton(
                  onPressed: () {
                    // 显示环境变量查看对话框
                    _viewAppEnvironment(app);
                  },
                  child: Text(AppLocalizations.of(context)!.appShow),
                ),
                // 编辑环境变量按钮
                TextButton(
                  onPressed: () {
                    // 关闭当前对话框
                    Navigator.of(context).pop();

                    // 显示环境变量编辑对话框
                    _editAppEnvironment(app);
                  },
                  child: Text(AppLocalizations.of(context)!.appEdit),
                ),
              ],
              ElevatedButton(
                onPressed: () {
                  _toggleAppInstallation(app);
                  Navigator.of(context).pop();
                },
                child: Text(
                  app.isInstalled
                      ? AppLocalizations.of(context)!.uninstall
                      : AppLocalizations.of(context)!.install,
                ),
              ),
            ],
          ),
    );
  }
}
