// 环境变量编辑对话框
// 用于在应用安装前或安装后编辑应用的环境变量

import 'package:flutter/material.dart';
import 'package:carrot/shared/models/app_model.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 环境变量编辑对话框
///
/// 用于编辑应用的环境变量配置
class EnvEditorDialog extends StatefulWidget {
  /// 应用模型
  final AppModel app;

  /// 是否是安装过程中的编辑
  final bool isInstalling;

  /// 确认回调，返回更新后的应用模型
  final Function(AppModel updatedApp) onConfirm;

  const EnvEditorDialog({
    super.key,
    required this.app,
    this.isInstalling = true,
    required this.onConfirm,
  });

  @override
  State<EnvEditorDialog> createState() => _EnvEditorDialogState();
}

class _EnvEditorDialogState extends State<EnvEditorDialog> {
  /// 环境变量列表
  late Map<String, String> envVariables;

  /// URL控制器
  late TextEditingController _urlController;

  /// 当前编辑后的URL
  String _currentUrl = '';

  /// 控制器映射表，用于管理每个环境变量的输入控制器
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();

    // 初始化 URL 控制器
    final String url = widget.app.mcpServer['url']?.toString() ?? '';
    _currentUrl = url;
    _urlController = TextEditingController(text: url);

    // 添加监听器，当URL变化时更新预览
    _urlController.addListener(_updateUrlPreview);

    // 初始化环境变量
    final Map<dynamic, dynamic> rawEnv =
        (widget.app.mcpServer['env'] as Map<dynamic, dynamic>?) ?? {};
    envVariables = {};

    // 转换为 Map<String, String>
    for (final entry in rawEnv.entries) {
      final key = entry.key.toString();
      final value = entry.value?.toString() ?? '';
      envVariables[key] = value;
      _controllers[key] = TextEditingController(text: value);
    }

    // 如果没有环境变量，添加一个空的
    if (envVariables.isEmpty) {
      _addNewVariable();
    }
  }

  /// 更新URL预览
  void _updateUrlPreview() {
    setState(() {
      _currentUrl = _urlController.text;
    });
  }

  @override
  void dispose() {
    // 移除监听器
    _urlController.removeListener(_updateUrlPreview);

    // 释放 URL 控制器
    _urlController.dispose();

    // 释放所有环境变量控制器
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 添加新的环境变量
  void _addNewVariable() {
    final newKey = '';
    setState(() {
      envVariables[newKey] = '';
      _controllers[newKey] = TextEditingController();
    });
  }

  /// 删除环境变量
  void _removeVariable(String key) {
    setState(() {
      envVariables.remove(key);
      _controllers[key]?.dispose();
      _controllers.remove(key);
    });
  }

  /// 更新环境变量键
  void _updateKey(String oldKey, String newKey) {
    if (oldKey == newKey) return;

    setState(() {
      final value = envVariables[oldKey] ?? '';
      envVariables.remove(oldKey);
      envVariables[newKey] = value;

      // 更新控制器映射
      final controller = _controllers[oldKey];
      if (controller != null) {
        _controllers[newKey] = controller;
        _controllers.remove(oldKey);
      }
    });
  }

  /// 更新环境变量值
  void _updateValue(String key, String value) {
    setState(() {
      envVariables[key] = value;
    });
  }

  /// 保存环境变量和 URL
  void _saveEnvVariables() {
    // 更新控制器中的最新值
    for (final entry in _controllers.entries) {
      envVariables[entry.key] = entry.value.text;
    }

    // 过滤掉空键的环境变量
    final filteredEnvVariables = <String, String>{};
    for (final entry in envVariables.entries) {
      if (entry.key.trim().isNotEmpty) {
        filteredEnvVariables[entry.key] = entry.value;
      }
    }

    // 创建更新后的应用模型
    final updatedMcpServer = Map<String, dynamic>.from(widget.app.mcpServer);
    updatedMcpServer['env'] =
        filteredEnvVariables.isEmpty
            ? <String, String>{}
            : Map<String, String>.from(filteredEnvVariables);

    // 更新 URL
    updatedMcpServer['url'] = _urlController.text;

    final updatedApp = widget.app.copyWith(mcpServer: updatedMcpServer);

    // 调用确认回调
    widget.onConfirm(updatedApp);
  }

  /// 构建使用方法部分
  Widget _buildUsageGuide() {
    final colorScheme = Theme.of(context).colorScheme;
    final usageGuide = widget.app.usageGuide;
    final appLocalizations = AppLocalizations.of(context)!;

    if (usageGuide.isEmpty) {
      return const SizedBox.shrink(); // 如果没有使用方法，则不显示此部分
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appLocalizations.usageGuideLabel,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Text(usageGuide, style: TextStyle(fontSize: 14)),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appLocalizations = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(
        widget.isInstalling
            ? appLocalizations.appInstallation
            : appLocalizations.appEdit,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 应用名称
              Text(
                widget.app.name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // 使用方法部分
              _buildUsageGuide(),

              // URL 输入框
              Text(
                'MCP Server URL:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: 'https://mcp.example.com/sse?key=your_api_key',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),

              // URL 预览
              if (_currentUrl.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'URL Preview:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentUrl,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // 环境变量说明
              Text(
                '${appLocalizations.appStorage}: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(appLocalizations.environmentVariablesDescription),
              const SizedBox(height: 8),

              // 环境变量列表
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: envVariables.length,
                itemBuilder: (context, index) {
                  final key = envVariables.keys.elementAt(index);
                  final controller = _controllers[key]!;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        // 键输入框
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: appLocalizations.key,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            initialValue: key,
                            onChanged: (value) => _updateKey(key, value),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 值输入框
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              labelText: appLocalizations.value,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (value) => _updateValue(key, value),
                          ),
                        ),

                        // 删除按钮
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: colorScheme.error,
                          onPressed: () => _removeVariable(key),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // 添加新变量按钮
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(appLocalizations.addEnvironmentVariable),
                onPressed: _addNewVariable,
              ),
            ],
          ),
        ),
      ),
      actions: [
        // 取消按钮
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),

        // 确认按钮
        ElevatedButton(
          onPressed: () {
            _saveEnvVariables();
            Navigator.of(context).pop();
          },
          child: Text(
            widget.isInstalling
                ? appLocalizations.install
                : appLocalizations.save,
          ),
        ),
      ],
    );
  }
}

/// 显示环境变量编辑对话框的辅助方法
Future<AppModel?> showEnvEditorDialog({
  required BuildContext context,
  required AppModel app,
  bool isInstalling = true,
}) async {
  AppModel? result;

  await showDialog(
    context: context,
    builder:
        (context) => EnvEditorDialog(
          app: app,
          isInstalling: isInstalling,
          onConfirm: (updatedApp) {
            result = updatedApp;
          },
        ),
  );

  return result;
}
