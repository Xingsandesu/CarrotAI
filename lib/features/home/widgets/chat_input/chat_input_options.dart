// 聊天输入栏选项菜单组件

import 'dart:developer'; // Import developer log
import 'package:flutter/material.dart';
import 'package:carrot/shared/components/bottom_sheet_menu.dart';
import 'package:carrot/core/api/api_client_factory.dart';
import 'package:carrot/shared/utils/icon_mapper.dart'; // 引入图标映射工具
import 'package:carrot/core/storage/storage_factory.dart'; // 引入存储工厂
import 'package:carrot/shared/models/app_model.dart'; // 引入应用模型
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:carrot/shared/components/toast_notification.dart';

/// 聊天输入栏的各种菜单选项
class ChatInputOptions {
  // MCP应用状态存储

  /// 从后端获取模型配置列表
  /// 参数 [locale] 指定语言区域设置，用于获取相应语言的配置
  static Future<List<Map<String, dynamic>>> fetchModelConfigs({
    Locale? locale,
  }) async {
    try {
      final client = apiClientFactory.configApiClient;

      // 根据当前语言设置调用相应的API
      String? lang;
      if (locale != null) {
        lang = locale.languageCode;
      }

      final configs = await client.getModelConfigs(lang: lang);
      // 注意：后端返回的 icon 是字符串，需要在这里或使用的地方进行转换
      return configs;
    } catch (e, stackTrace) {
      // Capture stack trace
      // 使用 log 替换 print
      log(
        "Failed to get model configurations",
        error: e,
        stackTrace: stackTrace,
        name: 'ChatInputOptions',
      );
      // 返回空列表或抛出异常，根据需要处理
      return [];
    }
  }

  /// 获取指定名称的模型配置 (现在需要传入配置列表)
  static Map<String, dynamic>? getModelConfig(
    String modelName,
    List<Map<String, dynamic>> modelConfigs,
  ) {
    for (var config in modelConfigs) {
      if (config['name'] == modelName) {
        return config;
      }
    }
    return null;
  }

  /// 显示模型选择菜单 (现在需要传入配置列表)
  static void showModelSelectionMenu(
    BuildContext context,
    String currentModel,
    Function(String) onModelSelected,
    List<Map<String, dynamic>> modelConfigs, // 接收配置列表
  ) {
    if (modelConfigs.isEmpty) {
      // 可以显示一个提示或错误信息
      ToastNotification.showError(message: '无法加载模型列表', context: context);
      return;
    }

    // 获取当前语言
    final locale = Localizations.localeOf(context);
    // 在异步操作前获取所需的本地化信息
    final selectModelText = AppLocalizations.of(context)!.selectModel;

    log(
      "Showing model selection menu with language: ${locale.languageCode}",
      name: 'ChatInputOptions',
    );

    // 预先准备底部弹出菜单的函数，避免在异步回调中使用context
    void showMenuWithConfigs(List<Map<String, dynamic>> configsToUse) {
      // 将模型信息转换为菜单选项
      final options =
          configsToUse.map((model) {
            final iconName =
                model['icon'] as String? ?? 'question_mark'; // 默认图标
            final iconData = IconMapper.getIcon(iconName); // 使用映射器获取IconData

            return MenuOption(
              title: model['name'] as String,
              icon: iconData, // 使用转换后的 IconData
              subtitle: model['description'] as String,
              onTap: () {
                onModelSelected(model['name'] as String);
              },
              isHighlighted: model['name'] == currentModel,
            );
          }).toList();

      // 使用提前获取的本地化信息，以避免在异步回调中使用context
      AppBottomSheetMenu.show(
        context: context,
        title: selectModelText,
        options: options,
      );
    }

    // 确保模型配置反映当前语言
    ChatInputOptions.fetchModelConfigs(locale: locale)
        .then((updatedConfigs) {
          // 如果成功获取了新的配置列表，就使用它，否则使用旧的
          final configsToUse =
              updatedConfigs.isNotEmpty ? updatedConfigs : modelConfigs;
          showMenuWithConfigs(configsToUse);
        })
        .catchError((error) {
          // 如果获取最新配置失败，则使用当前配置
          log(
            "Failed to fetch updated model configs: $error, using existing configs",
            name: 'ChatInputOptions',
            error: error,
          );

          showMenuWithConfigs(modelConfigs);
        });
  }

  /// 显示我的应用菜单 (原MCP工具菜单)
  static void showMyAppsMenu(BuildContext context) {
    // 使用StatefulBuilder来创建一个有状态的底部弹出菜单
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true, // 允许更大的高度
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            // 创建一个状态管理器，处理加载应用列表和状态切换
            return _MyAppsMenuContent(setState: setState);
          },
        );
      },
    );
  }

  /// 获取已安装的应用列表
  static Future<List<AppModel>> fetchInstalledApps() async {
    final appStorage = await storageFactory.getAppStorage();
    return await appStorage.getInstalledApps();
  }

  /// 获取已安装应用的启用状态
  static Future<Map<String, bool>> getAppEnabledStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final String? statusJson = prefs.getString('mcp_app_status');
    final Map<String, bool> status = {};
    if (statusJson != null) {
      final Map<String, dynamic> decoded = jsonDecode(statusJson);
      decoded.forEach((key, value) {
        status[key] = value as bool;
      });
    }
    return status;
  }

  /// 启用或禁用指定应用
  static Future<void> setAppEnabled(String appId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final String? statusJson = prefs.getString('mcp_app_status');
    Map<String, dynamic> statusMap = {};
    if (statusJson != null) {
      statusMap = jsonDecode(statusJson);
    }
    statusMap[appId] = enabled;
    await prefs.setString('mcp_app_status', jsonEncode(statusMap));
  }

  /// 设置全局MCP开关
  static Future<void> setGlobalMcpEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mcp_global_enabled', enabled);
  }

  // 构建分区标题
  static Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  // 构建分区选项
  static Widget _buildSectionOptions(
    BuildContext context,
    List<MenuOption> options,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        final textColor =
            option.isHighlighted == true
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface;

        return ListTile(
          title: Text(
            option.title,
            style: TextStyle(
              color: textColor,
              fontWeight: option.isHighlighted == true ? FontWeight.bold : null,
            ),
          ),
          subtitle: option.subtitle != null ? Text(option.subtitle!) : null,
          trailing: option.trailing,
          onTap: option.onTap,
        );
      },
    );
  }
}

/// 我的应用菜单内容组件，用于处理应用列表加载和状态管理
class _MyAppsMenuContent extends StatefulWidget {
  final StateSetter setState;

  const _MyAppsMenuContent({required this.setState});

  @override
  State<_MyAppsMenuContent> createState() => _MyAppsMenuContentState();
}

class _MyAppsMenuContentState extends State<_MyAppsMenuContent> {
  // 应用状态
  bool _mcpGlobalEnabled = false;
  bool _mcpBasicEnabled = false;

  // 已安装应用列表及其状态
  List<AppModel> _installedApps = [];
  Map<String, bool> _appEnabledStatus = {};

  // 加载状态
  bool _isLoading = true;
  String? _errorMessage;

  // JSON配置的文本控制器
  final TextEditingController _jsonConfigController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
    _loadMcpSettings();
  }

  @override
  void dispose() {
    _jsonConfigController.dispose();
    super.dispose();
  }

  // 加载已安装的应用
  Future<void> _loadInstalledApps() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 从存储中获取已安装的应用
      final appStorage = await storageFactory.getAppStorage();
      final apps = await appStorage.getInstalledApps();

      // 初始化应用启用状态，默认为禁用状态
      final Map<String, bool> enabledStatus = {};

      // 从本地存储中获取应用启用状态
      final prefs = await SharedPreferences.getInstance();
      final String? appStatusJson = prefs.getString('mcp_app_status');

      if (appStatusJson != null) {
        // 如果存在已保存的状态，使用它
        final Map<String, dynamic> savedStatus = jsonDecode(appStatusJson);

        // 遍历所有应用，设置它们的启用状态
        for (var app in apps) {
          // 如果本地存储中有这个应用的状态，则使用该状态，否则默认为禁用
          enabledStatus[app.id] = savedStatus[app.id] ?? false;
        }
      } else {
        // 没有保存的状态，默认所有应用都是禁用的
        for (var app in apps) {
          enabledStatus[app.id] = false;
        }
      }

      setState(() {
        _installedApps = apps;
        _appEnabledStatus = enabledStatus;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '加载应用列表失败: $e';
      });
    }
  }

  // 切换应用启用状态
  void _toggleAppEnabled(String appId) {
    setState(() {
      if (_appEnabledStatus.containsKey(appId)) {
        _appEnabledStatus[appId] = !(_appEnabledStatus[appId] ?? false);
      }
    });
    // 保存设置到本地存储
    _saveMcpSettings();
  }

  // 切换全局MCP开关 - 由主界面处理，这里不需要

  // 切换基础MCP开关
  void _toggleMcpBasic(bool value) {
    setState(() {
      _mcpBasicEnabled = value;
    });
    // 保存设置到本地存储
    _saveMcpSettings();
  }

  // 保存MCP设置到本地存储
  Future<void> _saveMcpSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('mcp_basic_enabled', _mcpBasicEnabled);

      // 保存应用启用状态
      final Map<String, dynamic> appStatus = {};
      _appEnabledStatus.forEach((key, value) {
        appStatus[key] = value;
      });
      await prefs.setString('mcp_app_status', jsonEncode(appStatus));

      debugPrint('MCP设置已保存');
    } catch (e) {
      debugPrint('保存MCP设置失败: $e');
    }
  }

  // 保存MCP服务器JSON配置
  Future<void> _saveMcpJsonConfig(String jsonConfig) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mcp_server_json_config', jsonConfig);
      debugPrint('MCP服务器JSON配置已保存');
    } catch (e) {
      debugPrint('保存MCP服务器JSON配置失败: $e');
    }
  }

  // 加载MCP设置
  Future<void> _loadMcpSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _mcpGlobalEnabled = prefs.getBool('mcp_global_enabled') ?? false;
        _mcpBasicEnabled = prefs.getBool('mcp_basic_enabled') ?? false;

        // 加载应用启用状态在_loadInstalledApps方法中处理

        // 加载MCP服务器JSON配置
        final String? jsonConfig = prefs.getString('mcp_server_json_config');
        if (jsonConfig != null && jsonConfig.isNotEmpty) {
          _jsonConfigController.text = jsonConfig;
        }
      });
      debugPrint('MCP设置已加载');
    } catch (e) {
      debugPrint('加载MCP设置失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.myApps,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // MCP应用总控制
          ChatInputOptions._buildSectionHeader(
            context,
            AppLocalizations.of(context)!.mcpGlobalControl,
          ),
          _buildGlobalControlSection(),
          const Divider(thickness: 1, height: 24),

          // 基础MCP应用
          ChatInputOptions._buildSectionHeader(
            context,
            AppLocalizations.of(context)!.basicMcpApps,
          ),
          _buildBasicAppSection(),
          const Divider(thickness: 1, height: 24),

          // 已安装应用
          ChatInputOptions._buildSectionHeader(
            context,
            AppLocalizations.of(context)!.installedApps,
          ),
          _buildInstalledAppsSection(),

          // 底部内容 - JSON配置
          _buildJsonConfigInput(),
        ],
      ),
    );
  }

  // 构建全局控制部分
  Widget _buildGlobalControlSection() {
    // 返回空容器，移除原来的全局控制部分，因为现在总开关在主界面
    return Container();
  }

  // 构建基础应用部分
  Widget _buildBasicAppSection() {
    final basicOptions = [
      MenuOption(
        title: AppLocalizations.of(context)!.basicMcpApps,
        icon: Icons.apps,
        subtitle: AppLocalizations.of(context)!.controlBasicMcpApps,
        onTap: () {
          if (_mcpGlobalEnabled) {
            _toggleMcpBasic(!_mcpBasicEnabled);
          }
        },
        trailing: Switch(
          value: _mcpBasicEnabled,
          onChanged: _mcpGlobalEnabled ? _toggleMcpBasic : null,
        ),
      ),
    ];

    return ChatInputOptions._buildSectionOptions(context, basicOptions);
  }

  // 构建已安装应用部分
  Widget _buildInstalledAppsSection() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    if (_installedApps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                AppLocalizations.of(context)!.noInstalledApps,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 转换已安装应用为菜单选项
    final appOptions =
        _installedApps.map((app) {
          // 获取图标
          IconData iconData;
          try {
            // 先尝试使用IconMapper解析图标名称
            iconData = IconMapper.getIcon(app.icon);
          } catch (e) {
            // 如果失败，使用默认图标
            // 使用if-else替代switch，因为switch不能使用非常量值作为case表达式
            if (app.type == '文档处理') {
              iconData = Icons.text_fields;
            } else if (app.type == '数据处理') {
              iconData = Icons.data_usage;
            } else if (app.type == '服务集成') {
              iconData = Icons.integration_instructions;
            } else if (app.type == '咨询顾问') {
              iconData = Icons.support_agent;
            } else if (app.type == '科学计算') {
              iconData = Icons.calculate;
            } else if (app.type == '实用工具') {
              iconData = Icons.build;
            } else {
              iconData = Icons.extension;
            }
          }

          return MenuOption(
            title: app.name,
            icon: iconData,
            subtitle: app.description,
            onTap: () {
              if (_mcpGlobalEnabled) {
                _toggleAppEnabled(app.id);
              }
            },
            trailing: Switch(
              value: _appEnabledStatus[app.id] ?? false,
              onChanged:
                  _mcpGlobalEnabled
                      ? (value) {
                        _toggleAppEnabled(app.id);
                      }
                      : null,
            ),
          );
        }).toList();

    return ChatInputOptions._buildSectionOptions(context, appOptions);
  }

  // 构建自定义MCP服务器JSON配置输入框
  Widget _buildJsonConfigInput() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.mcpServerConfig,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _jsonConfigController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: AppLocalizations.of(context)!.enterMcpServerConfig,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  _jsonConfigController.clear();
                },
                child: Text(AppLocalizations.of(context)!.clear),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  // 保存JSON配置
                  final jsonConfig = _jsonConfigController.text;
                  log(
                    'Saving MCP server config: $jsonConfig',
                    name: 'ChatInputOptions',
                  );
                  _saveMcpJsonConfig(jsonConfig);
                  Navigator.of(context).pop(); // 关闭菜单
                },
                child: Text(AppLocalizations.of(context)!.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
