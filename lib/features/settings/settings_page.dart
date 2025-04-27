// 设置页面，显示应用的设置选项

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// 用于格式化数字
import 'package:carrot/core/providers/theme_provider.dart';
import 'package:carrot/core/providers/auth_provider.dart';
import 'package:carrot/core/providers/locale_provider.dart'; // 导入 LocaleProvider
import 'package:carrot/core/config/theme/app_theme.dart'; // 导入 AppTheme 获取默认种子颜色
import 'package:carrot/core/config/app_config.dart'; // 导入 AppConfig 获取版本信息
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // 导入生成的本地化文件
import 'package:intl/intl.dart'; // 导入数字格式化工具
import 'package:carrot/features/settings/open_source_licenses_page.dart'; // 导入开源组件许可页面
import 'package:carrot/core/api/api_client_factory.dart'; // 导入 API 客户端

/// 设置页面
class SettingsPage extends StatefulWidget {
  // 添加关闭回调
  final VoidCallback? onClose;

  const SettingsPage({super.key, this.onClose});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

// 预设的自定义种子颜色
final List<Map<String, Color>> customSeedColors = [
  {'Default': AppTheme.defaultSeedColor}, // 默认蓝色
  {'M3 Baseline': const Color(0xff6750a4)}, // Material 3 Baseline 紫色
  {'Green': Colors.green},
  {'Teal': Colors.teal},
  {'Orange': Colors.deepOrange},
];

class _SettingsPageState extends State<SettingsPage> {
  // 字体大小
  String _selectedFontSize = '中'; // 默认值为中文的"中"，会在initState中更新为当前语言的值

  // 记录字体缩放比例
  final Map<String, double> _fontSizeScales = {};

  // 用户Token使用数据和格式化器
  late final Future<Map<String, dynamic>?> _tokenUsageFuture;
  final NumberFormat _numberFormatter = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    // 获取用户Token使用数据
    _tokenUsageFuture = apiClientFactory.userApiClient.getCurrentUser().then(
      (response) =>
          response.success && response.data != null
              ? response.data!['token_usage'] as Map<String, dynamic>?
              : null,
    );
    // 加载当前应用的字体大小设置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final currentScale = themeProvider.fontSizeScale;
      final appLocalizations = AppLocalizations.of(context)!;

      // 根据当前语言设置字体大小选项，但保持固定的值
      Map<String, double> fontSizeMap = {
        appLocalizations.small: 0.85, // 小
        appLocalizations.medium: 1.0, // 中
        appLocalizations.large: 1.15, // 大
      };

      // 更新字体大小比例映射
      _fontSizeScales.clear();
      _fontSizeScales.addAll(fontSizeMap);

      // 默认使用中号字体，除非用户之前选择了其他大小
      String selectedSize = appLocalizations.medium; // 默认中号

      // 如果当前缩放因子不是1.0（中号），则查找最接近的大小
      if ((currentScale - 1.0).abs() > 0.01) {
        // 使用小数点比较需要容差
        double minDifference = double.infinity;
        for (final entry in _fontSizeScales.entries) {
          final difference = (entry.value - currentScale).abs();
          if (difference < minDifference) {
            minDifference = difference;
            selectedSize = entry.key;
          }
        }
      }

      setState(() {
        _selectedFontSize = selectedSize;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final bool isWideScreen = MediaQuery.of(context).size.width >= 800.0;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final appLocalizations = AppLocalizations.of(context)!;

    // 获取当前颜色来源对应的文本
    String currentColorSourceText() {
      switch (themeProvider.colorSource) {
        case ColorSource.defaultSeed:
          return appLocalizations.defaultColor;
        case ColorSource.system:
          return appLocalizations.followSystem;
        case ColorSource.customSeed:
          // 尝试查找当前自定义颜色是否在预设列表中
          final currentCustom = customSeedColors.firstWhere(
            (map) => map.values.first == themeProvider.customSeedColor,
            orElse:
                () => {
                  'Custom': themeProvider.customSeedColor,
                }, // 找不到则显示 Custom
          );
          return '${AppLocalizations.of(context)!.customColor} (${currentCustom.keys.first})';
      }
    }

    // 更新字体大小的方法
    void updateFontSize(String size) {
      if (_selectedFontSize != size) {
        setState(() {
          _selectedFontSize = size;
        });

        // 更新应用的字体大小
        final newScale = _fontSizeScales[size] ?? 1.0;

        // 使用ThemeProvider更新字体缩放比例
        themeProvider.setFontSizeScale(newScale);
      }
    }

    // 定义AppBar的leading widget
    Widget? leadingWidget;
    if (isWideScreen && widget.onClose != null) {
      // 宽屏模式下，如果提供了onClose回调，显示关闭按钮
      leadingWidget = IconButton(
        icon: const Icon(Icons.close),
        onPressed: widget.onClose,
        tooltip: AppLocalizations.of(context)!.closeSettings,
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
        title: Text(appLocalizations.settings),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: SafeArea(
        child: ListView(
          children: [
            // 账户信息部分
            ListTile(
              title: Text(
                appLocalizations.userInfo,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            // 用户信息行
            ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  user?.name.isNotEmpty == true
                      ? user!.name[0].toUpperCase()
                      : AppLocalizations.of(context)!.userInitial,
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                user?.name ?? AppLocalizations.of(context)!.unknownUser,
              ),
              subtitle: Text(user?.email ?? ''),
            ),

            // Token使用情况简化展示
            ListTile(
              leading: const Icon(Icons.watch_later_outlined),
              title: Text(appLocalizations.tokenUsage),
            ),
            FutureBuilder<Map<String, dynamic>?>(
              future: _tokenUsageFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final usage = snapshot.data;
                if (usage == null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(appLocalizations.errorGettingUserInfo),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${appLocalizations.usedTokens}: ${_numberFormatter.format(usage['token_used'] ?? 0)}',
                      ),
                      Text(
                        '${appLocalizations.inputTokens}: ${_numberFormatter.format(usage['prompt_tokens_used'] ?? 0)}',
                      ),
                      Text(
                        '${appLocalizations.outputTokens}: ${_numberFormatter.format(usage['completion_tokens_used'] ?? 0)}',
                      ),
                    ],
                  ),
                );
              },
            ),

            // 外观设置部分
            ListTile(
              title: Text(
                appLocalizations.theme,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              contentPadding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            ),

            // 主题切换
            ListTile(
              leading: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.dark_mode
                    : Icons.light_mode,
              ),
              title: Text(appLocalizations.theme),
              subtitle: Text(
                themeProvider.themeMode == ThemeMode.system
                    ? appLocalizations.systemMode
                    : (Theme.of(context).brightness == Brightness.dark
                        ? appLocalizations.darkMode
                        : appLocalizations.lightMode),
              ),
              onTap: () {
                // 显示主题模式选择菜单
                _showThemeModeSelectionDialog(context, themeProvider);
              },
            ),

            // 主题色选择
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(appLocalizations.colorTheme),
              subtitle: Text(currentColorSourceText()),
              onTap: () {
                // 显示主题色选择菜单
                _showColorThemeDialog(context, themeProvider);
              },
            ),

            // 字体大小选择
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: Text(appLocalizations.fontSize),
              subtitle: Text(_selectedFontSize),
              trailing: SizedBox(
                width: MediaQuery.of(context).size.width * 0.5,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: appLocalizations.small,
                      label: Text(appLocalizations.small),
                    ),
                    ButtonSegment(
                      value: appLocalizations.medium,
                      label: Text(appLocalizations.medium),
                    ),
                    ButtonSegment(
                      value: appLocalizations.large,
                      label: Text(appLocalizations.large),
                    ),
                  ],
                  selected: {_selectedFontSize},
                  onSelectionChanged: (Set<String> selected) {
                    updateFontSize(selected.first);
                  },
                  style: ButtonStyle(visualDensity: VisualDensity.compact),
                ),
              ),
            ),

            // 语言选择
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(appLocalizations.language),
              subtitle: Text(
                localeProvider.getCurrentLocaleSourceDisplayName(),
              ),
              onTap: () {
                // 显示语言选择菜单
                _showLanguageSelectionDialog(context, localeProvider);
              },
            ),

            // 关于部分
            ListTile(
              title: Text(
                appLocalizations.about,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              contentPadding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            ),

            // 版本信息
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(appLocalizations.version),
              subtitle: FutureBuilder(
                future: Future.wait([
                  AppConfig.appVersion,
                  AppConfig.appBuildNumber,
                ]),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final version = snapshot.data![0];
                    final buildNumber = snapshot.data![1];
                    return Text('$version (build $buildNumber)');
                  }
                  return const Text('Loading...');
                },
              ),
            ),

            // 开源组件许可
            ListTile(
              leading: const Icon(Icons.code_outlined),
              title: Text(appLocalizations.openSourceLicenses),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const OpenSourceLicensesPage(),
                  ),
                );
              },
            ),

            // 底部间距
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Helper: 显示主题色选择对话框
  void _showColorThemeDialog(
    BuildContext context,
    ThemeProvider themeProvider,
  ) {
    final appLocalizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(appLocalizations.colorTheme),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                // 跟随系统选项
                RadioListTile<ColorSource>(
                  title: Text(appLocalizations.systemColor),
                  subtitle: Text(appLocalizations.useSystemDefaultColor),
                  value: ColorSource.system,
                  groupValue: themeProvider.colorSource,
                  onChanged: (value) {
                    themeProvider.setColorSource(value!);
                    Navigator.pop(context);
                  },
                ),
                // 默认配色选项
                RadioListTile<ColorSource>(
                  title: Text(appLocalizations.defaultColor),
                  subtitle: Text(appLocalizations.useAppDefaultColor),
                  value: ColorSource.defaultSeed,
                  groupValue: themeProvider.colorSource,
                  onChanged: (value) {
                    themeProvider.setColorSource(value!);
                    Navigator.pop(context);
                  },
                ),
                // 自定义颜色选项
                ...customSeedColors.map((colorMap) {
                  final String name = colorMap.keys.first;
                  final Color color = colorMap.values.first;
                  final bool isSelected =
                      themeProvider.colorSource == ColorSource.customSeed &&
                      themeProvider.customSeedColor == color;
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: color, radius: 16),
                    title: Text(name),
                    trailing: isSelected ? const Icon(Icons.check) : null,
                    onTap: () {
                      themeProvider.setCustomSeedColor(color);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(appLocalizations.cancel),
            ),
          ],
        );
      },
    );
  }

  // Helper: 显示语言选择对话框
  void _showLanguageSelectionDialog(
    BuildContext context,
    LocaleProvider localeProvider,
  ) {
    final appLocalizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(appLocalizations.language),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                // 跟随系统选项
                ListTile(
                  title: Text(appLocalizations.followSystem),
                  subtitle: Text(appLocalizations.useSystemDefaultLanguage),
                  trailing:
                      localeProvider.localeSource == LocaleSource.system
                          ? const Icon(Icons.check)
                          : null,
                  onTap: () {
                    localeProvider.setSystemLocale();
                    Navigator.pop(context);
                  },
                ),
                // 中文选项
                ListTile(
                  title: Text(appLocalizations.chinese),
                  trailing:
                      localeProvider.localeSource == LocaleSource.custom &&
                              localeProvider.customLocale?.languageCode == 'zh'
                          ? const Icon(Icons.check)
                          : null,
                  onTap: () {
                    localeProvider.setChineseLocale();
                    Navigator.pop(context);
                  },
                ),
                // 英文选项
                ListTile(
                  title: Text(appLocalizations.english),
                  trailing:
                      localeProvider.localeSource == LocaleSource.custom &&
                              localeProvider.customLocale?.languageCode == 'en'
                          ? const Icon(Icons.check)
                          : null,
                  onTap: () {
                    localeProvider.setEnglishLocale();
                    Navigator.pop(context);
                  },
                ),
                // 日文选项
                ListTile(
                  title: Text(appLocalizations.japanese),
                  trailing:
                      localeProvider.localeSource == LocaleSource.custom &&
                              localeProvider.customLocale?.languageCode == 'ja'
                          ? const Icon(Icons.check)
                          : null,
                  onTap: () {
                    localeProvider.setJapaneseLocale();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(appLocalizations.cancel),
            ),
          ],
        );
      },
    );
  }

  // Helper: 显示主题模式选择对话框
  void _showThemeModeSelectionDialog(
    BuildContext context,
    ThemeProvider themeProvider,
  ) {
    final appLocalizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(appLocalizations.theme),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                // 浅色模式
                RadioListTile<ThemeMode>(
                  title: Text(appLocalizations.lightMode),
                  value: ThemeMode.light,
                  groupValue: themeProvider.themeMode,
                  onChanged: (value) {
                    themeProvider.setLightMode();
                    Navigator.pop(context);
                  },
                ),
                // 深色模式
                RadioListTile<ThemeMode>(
                  title: Text(appLocalizations.darkMode),
                  value: ThemeMode.dark,
                  groupValue: themeProvider.themeMode,
                  onChanged: (value) {
                    themeProvider.setDarkMode();
                    Navigator.pop(context);
                  },
                ),
                // 跟随系统
                RadioListTile<ThemeMode>(
                  title: Text(appLocalizations.systemMode),
                  subtitle: Text(appLocalizations.followSystem),
                  value: ThemeMode.system,
                  groupValue: themeProvider.themeMode,
                  onChanged: (value) {
                    themeProvider.setSystemMode();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(appLocalizations.cancel),
            ),
          ],
        );
      },
    );
  }
}
