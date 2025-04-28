// 聊天输入栏组件，包含 @ 应用快捷选择及 Material3 动态主题支持

import 'dart:developer'; // Import developer log
// 导入UI相关功能，包括ImageFilter
import 'package:flutter/material.dart';
import 'package:carrot/features/home/widgets/chat_input/chat_input_options.dart';
import 'package:carrot/features/home/widgets/chat_input/file_parser.dart'; // 导入文件解析组件
import 'dart:io'; // 导入文件操作支持
import 'package:carrot/shared/utils/icon_mapper.dart'; // 引入图标映射工具
import 'package:file_picker/file_picker.dart'; // 导入文件选择器
import 'package:shared_preferences/shared_preferences.dart'; // 导入SharedPreferences
import 'package:carrot/shared/components/safe_text_field.dart'; // 导入安全文本输入框
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart'; // 导入Provider
import 'package:carrot/core/providers/auth_provider.dart'; // 导入AuthProvider
import 'package:carrot/shared/components/toast_notification.dart';
import 'package:flutter/services.dart';
import 'package:carrot/shared/models/app_model.dart';

class ChatInput extends StatefulWidget {
  final Function(String, {bool? deepThinking})? onSendMessage;
  final Function(File)? onFileUpload; // 添加文件上传回调

  const ChatInput({super.key, this.onSendMessage, this.onFileUpload});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  bool _isComposing = false;
  bool _isDeepThinking = false; // 深度思考开关状态
  String _currentModel = "DeepSeek"; // 默认选择的模型
  bool _isMcpEnabled = false; // MCP总开关状态
  double _temperature = 0.7; // 模型温度，默认值0.7

  // 状态变量，用于存储从后端加载的模型配置
  List<Map<String, dynamic>> _modelConfigs = [];
  bool _isLoadingConfigs = true; // 标记是否正在加载配置
  String? _loadingError; // 存储加载错误信息

  // 动画控制器
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  // 记录上次使用的语言，用于检测语言变化

  // 添加 @ 应用选择相关状态
  List<AppModel> _allApps = [];
  List<AppModel> _filteredApps = [];
  List<AppModel> _selectedApps = [];
  bool _showSuggestions = false;
  int _mentionIndex = -1;

  @override
  void initState() {
    super.initState();
    _isLoadingConfigs = true;
    _loadingError = null;

    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // 从SharedPreferences加载MCP状态
    _loadMcpState();

    // 加载温度设置
    _loadTemperature();

    // 在初始化时加载已安装应用
    _loadApps();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 在 didChangeDependencies 中加载配置，这里可以安全地访问 context
    _loadModelConfigs();
  }

  // 加载模型配置的方法
  Future<void> _loadModelConfigs() async {
    if (!_isLoadingConfigs) return;
    try {
      final locale = Localizations.localeOf(context);
      final configs = await ChatInputOptions.fetchModelConfigs(locale: locale);
      if (mounted) {
        setState(() {
          _modelConfigs = configs;
          _isLoadingConfigs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingError = "加载模型配置失败: $e";
          _isLoadingConfigs = false;
        });
        ToastNotification.showError(message: _loadingError!, context: context);
      }
    }
  }

  // 加载MCP状态
  Future<void> _loadMcpState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isMcpEnabled = prefs.getBool('mcp_global_enabled') ?? false;
      });
    } catch (e) {
      log("加载 MCP 状态失败: $e");
    }
  }

  // 加载温度设置
  Future<void> _loadTemperature() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _temperature = prefs.getDouble('temperature_setting') ?? 0.7;
      });
    } catch (e) {
      log("加载温度失败: $e");
    }
  }

  /// 加载已安装应用及其启用状态
  Future<void> _loadApps() async {
    final apps = await ChatInputOptions.fetchInstalledApps();
    final status = await ChatInputOptions.getAppEnabledStatus();
    setState(() {
      _allApps = apps;
      _selectedApps = apps.where((app) => status[app.id] == true).toList();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // 获取当前模型配置
  Map<String, dynamic>? get _currentModelConfig =>
      ChatInputOptions.getModelConfig(_currentModel, _modelConfigs);

  // 获取特定功能的排除规则
  List<String> _getExclusions(String feature) {
    final config = _currentModelConfig;
    if (config == null) return [];

    final exclusiveRules = config['exclusiveRules'] as Map<String, dynamic>?;
    if (exclusiveRules == null) return [];

    final featureConfig = exclusiveRules[feature] as Map<String, dynamic>?;
    if (featureConfig == null) return [];

    final excludes = featureConfig['excludes'] as List?;
    return excludes?.map((e) => e.toString()).toList() ?? [];
  }

  // 检查功能是否启用
  bool _isFeatureEnabled(String feature) {
    // 在配置加载完成前，默认禁用功能
    if (_isLoadingConfigs || _modelConfigs.isEmpty) return false;

    final config = _currentModelConfig;
    if (config == null) return false;

    final exclusiveRules = config['exclusiveRules'] as Map<String, dynamic>?;
    if (exclusiveRules == null) return true;

    final featureConfig = exclusiveRules[feature] as Map<String, dynamic>?;
    if (featureConfig == null) return true;

    return featureConfig['enabled'] as bool? ?? true;
  }

  // 处理模型选择
  void _selectModel() {
    // 确保配置已加载
    if (_isLoadingConfigs || _modelConfigs.isEmpty) {
      ToastNotification.showError(
        message: AppLocalizations.of(context)!.loading,
        context: context,
      );
      return;
    }

    // 添加按钮触感反馈
    _animationController.forward().then((_) => _animationController.reverse());

    ChatInputOptions.showModelSelectionMenu(context, _currentModel, (
      selectedModel,
    ) {
      setState(() {
        _currentModel = selectedModel;
        // 检查新模型下的功能互斥规则
        _applyExclusionRules();
      });
    }, _modelConfigs);
  }

  // 应用互斥规则
  void _applyExclusionRules() {
    if (_isLoadingConfigs) return;

    // 深度思考开启时，检查并关闭冲突功能
    if (_isDeepThinking) {
      final exclusions = _getExclusions('deepThinking');
      if (exclusions.contains('mcpServices')) {
        _disableMcpServices();
      }
    }
  }

  // 禁用MCP服务
  Future<void> _disableMcpServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('mcp_global_enabled', false);
      await prefs.setBool('mcp_basic_enabled', false);
      log("基于排除规则禁用 MCP 服务", name: 'ChatInput');
    } catch (e) {
      log("禁用 MCP 服务失败: $e", name: 'ChatInput');
    }
  }

  // 处理深度思考按钮点击
  void _toggleDeepThinking() {
    if (_isLoadingConfigs) return;
    if (!_isFeatureEnabled('deepThinking')) return;

    // 添加按钮触感反馈
    _animationController.forward().then((_) => _animationController.reverse());

    setState(() {
      _isDeepThinking = !_isDeepThinking;
    });

    // 保存深度思考状态到SharedPreferences
    _saveDeepThinkingState(_isDeepThinking);
  }

  // 保存深度思考状态
  Future<void> _saveDeepThinkingState(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('deep_thinking_enabled', enabled);
      log("Saved deep thinking state: $enabled", name: 'ChatInput');
    } catch (e) {
      log("Failed to save deep thinking state: $e", name: 'ChatInput');
    }
  }

  // 获取深度思考状态
  Future<bool> getDeepThinkingState() async {
    return _isDeepThinking;
  }

  // 处理MCP服务按钮点击
  void _openMCPServices() {
    if (_isLoadingConfigs) return;

    // 检查功能是否启用
    if (!_isFeatureEnabled('mcpServices')) {
      ToastNotification.showError(
        message: "Current model does not support this feature",
        context: context,
      );
      return;
    }

    // 检查是否与当前开启的功能冲突
    if (_isDeepThinking &&
        _getExclusions('deepThinking').contains('mcpServices')) {
      ToastNotification.showError(
        message: "Cannot use apps in deep thinking mode",
        context: context,
      );
      return;
    }

    // 添加按钮触感反馈
    _animationController.forward().then((_) => _animationController.reverse());

    // 打开我的应用菜单（原MCP服务菜单）
    ChatInputOptions.showMyAppsMenu(context);
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    _textController.clear();
    setState(() {
      _isComposing = false;
    });

    // 从SharedPreferences获取MCP设置和温度设置
    _getMcpSettings().then((settings) {
      if (widget.onSendMessage != null) {
        // 打印请求详情，包括MCP设置、深度思考状态和温度
        log(
          "Send message request: text=${text.length} chars, model=$_currentModel, "
          "deep thinking=$_isDeepThinking, MCP enabled=${settings['mcpEnabled']}, "
          "base tools=${settings['baseToolsEnabled']}, temperature=${settings['temperature']}",
          name: 'ChatInput',
        );

        // 保存深度思考状态以便后续使用
        _saveDeepThinkingState(_isDeepThinking);

        // 调用回调函数，传递消息文本和深度思考状态
        widget.onSendMessage!(text, deepThinking: _isDeepThinking);
      }
    });
  }

  // 获取MCP设置和温度设置
  Future<Map<String, dynamic>> _getMcpSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mcpEnabled = prefs.getBool('mcp_global_enabled') ?? false;
      final baseToolsEnabled = prefs.getBool('mcp_basic_enabled') ?? false;
      final temperature = prefs.getDouble('temperature_setting') ?? 0.7;

      return {
        'mcpEnabled': mcpEnabled,
        'baseToolsEnabled': baseToolsEnabled,
        'temperature': temperature,
      };
    } catch (e) {
      log("Failed to get settings: $e", name: 'ChatInput', error: e);
      return {
        'mcpEnabled': false,
        'baseToolsEnabled': false,
        'temperature': 0.7,
      };
    }
  }

  // 处理文件上传
  Future<void> _handleFileUpload() async {
    // 检查用户是否已登录
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      if (!mounted) return;
      ToastNotification.showError(
        message: AppLocalizations.of(context)!.loginRequired,
        context: context,
      );
      return;
    }

    // 添加按钮触感反馈
    _animationController.forward().then((_) => _animationController.reverse());

    // 保存当前的国际化实例，避免异步间隔中使用context
    final localizations = AppLocalizations.of(context)!;

    try {
      // 直接调用文件选择器
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'markdown'],
        allowMultiple: false,
        dialogTitle: localizations.selectFileToUpload,
        lockParentWindow: true,
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.first.path == null) {
        if (!mounted) return;
        ToastNotification.showError(
          message: localizations.cannotGetFilePath,
          context: context,
        );
        return;
      }

      final file = File(result.files.first.path!);
      final fileName = result.files.first.name;
      log('File selected: ${file.path}', name: 'ChatInput');

      // 在解析文件前检查组件是否仍然挂载
      if (!mounted) return;

      // 使用文件解析器解析文件
      final parseResult = await FileParser.parseFile(file, context);

      // 再次检查组件是否仍然挂载
      if (!mounted) return;

      if (parseResult.success) {
        // 解析成功，将文件内容添加到消息中
        final formattedContent = FileParser.formatFileContentForMessage(
          fileName,
          parseResult.content!,
          context,
        );

        // 将格式化后的内容设置到输入框
        _textController.text = formattedContent;
        setState(() {
          _isComposing = true;
        });

        // 显示成功提示
        ToastNotification.showSuccess(
          message: "${localizations.success}: $fileName",
          context: context,
        );
      } else {
        // 解析失败，显示错误消息
        ToastNotification.showError(
          message: parseResult.errorMessage!,
          context: context,
        );
      }
    } catch (e) {
      // 显示错误信息
      if (!mounted) return;
      ToastNotification.showError(message: e.toString(), context: context);
    }
  }

  // 获取当前输入框提示文字
  String _getHintText() {
    return _isDeepThinking
        ? AppLocalizations.of(context)!.deepThinkingModeEnabled
        : AppLocalizations.of(context)!.askAnyQuestion;
  }

  // 根据当前选择的模型返回相应图标
  IconData _getModelIcon() {
    if (_isLoadingConfigs || _modelConfigs.isEmpty) {
      return Icons.hourglass_empty; // 加载中或失败时显示占位图标
    }
    // 从配置中获取图标名称字符串
    final config = _currentModelConfig;
    final iconName = config?['icon'] as String? ?? 'question_mark';
    return IconMapper.getIcon(iconName); // 使用映射器获取IconData
  }

  // 构建模型选择按钮
  Widget _buildModelButton(ColorScheme colorScheme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _modelConfigs.isNotEmpty ? _selectModel : null,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Tooltip(
            message:
                '${AppLocalizations.of(context)!.selectModel}: $_currentModel',
            child: Icon(
              _getModelIcon(),
              color:
                  _modelConfigs.isNotEmpty
                      ? colorScheme.onSurfaceVariant
                      // ignore: deprecated_member_use
                      : colorScheme.onSurface.withValues(alpha: 0.38),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  // 构建操作按钮
  Widget _buildActionButton({
    Key? key,
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    required Color color,
  }) {
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }

  // 处理MCP总开关切换
  Future<void> _toggleMcp() async {
    // 检查用户是否已登录
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      if (!mounted) return;

      // 显示提示
      ToastNotification.showInfo(
        message: AppLocalizations.of(context)!.loginRequired,
        context: context,
      );

      // 跳转到登录页面
      Navigator.of(context).pushNamed('/login');
      return;
    }

    // 添加按钮触感反馈
    _animationController.forward().then((_) => _animationController.reverse());

    try {
      final prefs = await SharedPreferences.getInstance();
      // 切换状态
      final newState = !_isMcpEnabled;
      await prefs.setBool('mcp_global_enabled', newState);

      // 如果关闭总开关，也要关闭基础工具
      if (!newState) {
        await prefs.setBool('mcp_basic_enabled', false);

        // 保存应用状态，但不更改它们的值，这样重新打开总开关时，应用状态能够恢复
        // 应用状态由用户在应用列表中设置并保存，这里不影响
      }

      setState(() {
        _isMcpEnabled = newState;
      });

      // 显示状态切换提示
      if (mounted) {
        ToastNotification.showSuccess(
          message:
              newState
                  ? AppLocalizations.of(context)!.mcpGlobalSwitch +
                      AppLocalizations.of(context)!.mcpEnabled
                  : AppLocalizations.of(context)!.mcpGlobalSwitch +
                      AppLocalizations.of(context)!.mcpDisabled,
          context: context,
        );
      }
    } catch (e) {
      log("Failed to toggle MCP state: $e", name: 'ChatInput');
      if (mounted) {
        ToastNotification.showError(
          message: "Failed to toggle MCP state: $e",
          context: context,
        );
      }
    }
  }

  // 显示温度设置菜单
  void _showTemperatureMenu() {
    // 检查用户是否已登录
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      if (!mounted) return;

      // 显示提示
      ToastNotification.showInfo(
        message: AppLocalizations.of(context)!.loginRequired,
        context: context,
      );

      // 跳转到登录页面
      Navigator.of(context).pushNamed('/login');
      return;
    }

    // 添加按钮触感反馈
    _animationController.forward().then((_) => _animationController.reverse());

    // 显示温度设置菜单
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 标题行
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          AppLocalizations.of(context)!.modelTemperature,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(40, 40),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 温度设置部分
                  _buildTemperatureSection(context, setState),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 构建温度设置部分
  Widget _buildTemperatureSection(BuildContext context, StateSetter setState) {
    final temperatureValue = _temperature.toStringAsFixed(2);
    final temperatureLevel = _getTemperatureLevel(context, _temperature);
    final temperatureColor = _getTemperatureColor(context, _temperature);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.thermostat_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${AppLocalizations.of(context)!.responseTemperature}: $temperatureValue',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: temperatureColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      temperatureLevel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Slider(
          value: _temperature,
          min: 0.0,
          max: 2.0,
          divisions: 40, // 0.05刻度
          activeColor: temperatureColor,
          onChanged: (value) {
            setState(() {
              _temperature = value;
            });
            _updateTemperature(value);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            AppLocalizations.of(context)!.temperatureDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // 更新温度值
  void _updateTemperature(double value) {
    setState(() {
      _temperature = value;
    });
    _saveTemperature(value);
  }

  // 获取温度等级描述
  String _getTemperatureLevel(BuildContext context, double temp) {
    if (temp < 0.3) return AppLocalizations.of(context)!.temperatureLow;
    if (temp < 0.7) return AppLocalizations.of(context)!.temperatureMedium;
    if (temp < 1.2) return AppLocalizations.of(context)!.temperatureHigh;
    return AppLocalizations.of(context)!.temperatureVeryHigh;
  }

  // 获取温度对应的颜色
  Color _getTemperatureColor(BuildContext context, double temp) {
    final theme = Theme.of(context).colorScheme;
    if (temp < 0.3) return Colors.blue;
    if (temp < 0.7) return theme.primary;
    if (temp < 1.2) return Colors.orange;
    return Colors.red;
  }

  // 保存温度设置
  Future<void> _saveTemperature(double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('temperature_setting', value);
      log("Saved temperature setting: $value", name: 'ChatInput');
    } catch (e) {
      log("Failed to save temperature setting: $e", name: 'ChatInput');
    }
  }

  /// 文本变化时处理 @ 触发和建议过滤
  Future<void> _onTextChanged(String text) async {
    final cursor = _textController.selection.baseOffset;
    // 避免 cursor 为0 时传递 -1 给 lastIndexOf
    final idx = cursor > 0 ? text.lastIndexOf('@', cursor - 1) : -1;
    if (idx >= 0) {
      final q = text.substring(idx + 1, cursor);
      if (q.isEmpty) {
        // 仅在刚输入 '@' 且未输入其他字符时，加载并显示建议
        await _loadApps();
        setState(() {
          _mentionIndex = idx;
          _filteredApps =
              _allApps.where((app) => !_selectedApps.contains(app)).toList();
          _showSuggestions = _filteredApps.isNotEmpty;
        });
      } else {
        // 输入了其他内容时，关闭建议
        setState(() {
          _showSuggestions = false;
        });
      }
    } else {
      // 未输入 '@'，重置建议列表
      setState(() {
        _showSuggestions = false;
        _filteredApps = [];
        _mentionIndex = -1;
      });
    }
  }

  /// 选中建议应用时的处理
  void _onAppSelected(AppModel app) {
    // 同步全局和应用开关
    ChatInputOptions.setGlobalMcpEnabled(true);
    ChatInputOptions.setAppEnabled(app.id, true);
    // 移除触发的 @ 及查询字符，增加边界检测
    final text = _textController.text;
    // 确保下标在有效范围内
    final mentionIdx =
        (_mentionIndex >= 0 && _mentionIndex <= text.length)
            ? _mentionIndex
            : 0;
    final cursorPos =
        (_textController.selection.baseOffset >= 0 &&
                _textController.selection.baseOffset <= text.length)
            ? _textController.selection.baseOffset
            : text.length;
    final before = text.substring(0, mentionIdx);
    final after = text.substring(cursorPos);
    _textController.text = before + after;
    _textController.selection = TextSelection.collapsed(offset: before.length);
    setState(() {
      _selectedApps.add(app);
      _showSuggestions = false;
      _isComposing = _textController.text.trim().isNotEmpty;
      _isMcpEnabled = true; // 同步总开关状态
    });
  }

  /// 点击已选应用气泡时触发，移除应用并同步 MCP 状态
  void _onAppTap(AppModel app) {
    ChatInputOptions.setAppEnabled(app.id, false);
    setState(() {
      _selectedApps.remove(app);
      if (_selectedApps.isEmpty) {
        ChatInputOptions.setGlobalMcpEnabled(false);
        _isMcpEnabled = false;
      }
    });
  }

  /// 切换 @ 建议菜单
  Future<void> _toggleMentionList() async {
    if (_showSuggestions) {
      setState(() {
        _showSuggestions = false;
      });
    } else {
      await _loadApps();
      setState(() {
        // 展示所有未选应用
        _filteredApps =
            _allApps.where((app) => !_selectedApps.contains(app)).toList();
        _mentionIndex = 0;
        _showSuggestions = _filteredApps.isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // 在加载时显示加载指示器
    if (_isLoadingConfigs) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // 如果加载出错
    if (_loadingError != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(child: Text(_loadingError!)),
      );
    }

    // 获取当前主题亮度
    final Brightness currentBrightness = Theme.of(context).brightness;

    // 定义一些常用的颜色，直接从主题获取
    final primaryColor = colorScheme.primary;
    final inactiveColor = colorScheme.onSurfaceVariant;
    // Material 3 标准禁用颜色
    // ignore: deprecated_member_use
    final disabledColor = colorScheme.onSurface.withValues(alpha: 0.38);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                color: colorScheme.surfaceContainerLow.withValues(
                  alpha: currentBrightness == Brightness.dark ? 0.8 : 0.7,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 建议列表和已选应用区域（带动画）
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 建议列表
                            if (_showSuggestions &&
                                _filteredApps.isNotEmpty &&
                                _mentionIndex >= 0)
                              Container(
                                margin: const EdgeInsets.only(bottom: 4.0),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children:
                                      _filteredApps.map((app) {
                                        return ListTile(
                                          title: Text(
                                            app.name,
                                            style: TextStyle(
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                          dense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                              ),
                                          onTap: () => _onAppSelected(app),
                                        );
                                      }).toList(),
                                ),
                              ),
                            // 已选应用列表
                            if (_selectedApps.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children:
                                    _selectedApps.map((app) {
                                      return Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(
                                          bottom: 4.0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              child: Text(
                                                app.name,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color:
                                                      colorScheme
                                                          .onPrimaryContainer,
                                                ),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () => _onAppTap(app),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 6,
                                                    ),
                                                child: Icon(
                                                  Icons.close,
                                                  size: 16,
                                                  color:
                                                      colorScheme
                                                          .onPrimaryContainer,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                              ),
                          ],
                        ),
                      ),
                      // 工具栏按钮
                      Row(
                        children: [
                          _buildModelButton(colorScheme),
                          // @ 切换应用建议菜单按钮
                          Material(
                            color: Colors.transparent,
                            child: IconButton(
                              icon: const Icon(Icons.alternate_email),
                              tooltip:
                                  AppLocalizations.of(context)!.quickActions,
                              onPressed: _toggleMentionList,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          _buildActionButtonsThemed(
                            colorScheme,
                            primaryColor,
                            inactiveColor,
                            disabledColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 输入框区域
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: SafeTextField(
                              controller: _textController,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(
                                  _isDeepThinking ? 300 : 1000,
                                ),
                              ],
                              decoration: InputDecoration(
                                hintText: _getHintText(),
                                hintStyle: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                  fontStyle: FontStyle.normal, // 固定为正体
                                ),
                                // 使用标准的主题颜色定义边框
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.5), // 略微透明
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.5), // 略微透明
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: primaryColor, // 聚焦时使用主色
                                    width: 1.5,
                                  ),
                                ),
                                filled: true,
                                // 使用 surfaceContainerHighest 作为填充色，适当透明
                                fillColor: colorScheme.surfaceContainerHighest
                                    .withValues(
                                      alpha:
                                          currentBrightness == Brightness.dark
                                              ? 0.5
                                              : 0.7,
                                    ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              // 使用主题文本样式
                              style: textTheme.bodyLarge?.copyWith(
                                fontSize: _isDeepThinking ? 14 : 16,
                                color: colorScheme.onSurface, // 标准前景色
                                letterSpacing: _isDeepThinking ? -0.3 : 0,
                                height: _isDeepThinking ? 1.3 : 1.5,
                              ),
                              minLines: 1,
                              maxLines: 5,
                              textInputAction: TextInputAction.send,
                              onChanged: (t) {
                                _onTextChanged(t);
                                setState(
                                  () => _isComposing = t.trim().isNotEmpty,
                                );
                              },
                              onSubmitted:
                                  _isComposing ? _handleSubmitted : null,
                            ),
                          ),
                          if (_isComposing)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: _buildActionButton(
                                key: const ValueKey('send_button'),
                                icon: Icons.send,
                                onPressed:
                                    () =>
                                        _handleSubmitted(_textController.text),
                                tooltip: AppLocalizations.of(context)!.send,
                                color: primaryColor,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build action buttons with theme colors
  Widget _buildActionButtonsThemed(
    ColorScheme colorScheme,
    Color primaryColor,
    Color inactiveColor,
    Color disabledColor,
  ) {
    // 获取当前MCP服务是否被禁用
    final isMCPDisabled =
        _isDeepThinking &&
        _getExclusions('deepThinking').contains('mcpServices');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 上传文件按钮
        _buildActionButton(
          icon: Icons.add,
          onPressed: _handleFileUpload,
          tooltip: AppLocalizations.of(context)!.uploadFile,
          color: inactiveColor, // 使用未激活色
        ),

        const SizedBox(width: 4),

        // 温度设置按钮
        _buildActionButton(
          icon: Icons.thermostat_outlined,
          onPressed: _showTemperatureMenu,
          tooltip: AppLocalizations.of(context)!.modelTemperature,
          color: inactiveColor, // 使用未激活色
        ),

        const SizedBox(width: 4),

        // 深度思考按钮
        _buildActionButton(
          icon: Icons.psychology_outlined,
          onPressed:
              _isFeatureEnabled('deepThinking') ? _toggleDeepThinking : null,
          tooltip: AppLocalizations.of(context)!.deepThinking,
          color:
              _isFeatureEnabled('deepThinking')
                  ? (_isDeepThinking
                      ? primaryColor
                      : inactiveColor) // 激活时用主色，否则用未激活色
                  : disabledColor, // 禁用时用标准禁用色
        ),

        const SizedBox(width: 4),

        // MCP总开关按钮
        _buildActionButton(
          icon: _isMcpEnabled ? Icons.bolt : Icons.bolt_outlined,
          onPressed: () => _toggleMcp(),
          tooltip: AppLocalizations.of(context)!.mcpGlobalSwitch,
          color: _isMcpEnabled ? primaryColor : inactiveColor, // 激活时用主色，否则用未激活色
        ),

        const SizedBox(width: 4),

        // 我的应用按钮（原MCP服务/插件按钮）
        _buildActionButton(
          icon: Icons.extension_outlined,
          onPressed:
              (isMCPDisabled || !_isMcpEnabled) ? null : _openMCPServices,
          tooltip: AppLocalizations.of(context)!.myApps,
          color:
              (isMCPDisabled || !_isMcpEnabled)
                  ? disabledColor // 禁用时用标准禁用色
                  : inactiveColor, // 未禁用时用未激活色
        ),
      ],
    );
  }
}
