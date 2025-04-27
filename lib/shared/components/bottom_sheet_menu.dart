// 通用底部弹出菜单组件，统一应用中所有底部弹出样式

import 'package:flutter/material.dart';

/// 底部弹出菜单选项项
class MenuOption {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final String? subtitle;
  final bool? isHighlighted;
  final Widget? trailing;

  MenuOption({
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.isHighlighted = false,
    this.trailing,
  });
}

/// 菜单分区，用于分组显示菜单选项
class MenuSection {
  final String title;
  final List<MenuOption> options;

  MenuSection({required this.title, required this.options});
}

/// 通用底部弹出菜单，用于统一应用中所有底部弹出样式
class AppBottomSheetMenu {
  /// 显示标准底部弹出菜单
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<MenuOption> options,
    EdgeInsetsGeometry? padding,
    bool showDividers = true,
    Widget? headerTrailing,
  }) {
    final theme = Theme.of(context);

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: padding ?? const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (headerTrailing != null)
                      headerTrailing
                    else
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

              const SizedBox(height: 4),

              // 选项列表
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: options.length,
                separatorBuilder:
                    (_, __) =>
                        showDividers
                            ? const Divider(height: 1)
                            : const SizedBox(height: 0),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final textColor =
                      option.isHighlighted == true
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface;

                  return ListTile(
                    leading: Icon(
                      option.icon,
                      color:
                          option.isHighlighted == true
                              ? theme.colorScheme.primary
                              : null,
                    ),
                    title: Text(
                      option.title,
                      style: TextStyle(
                        color: textColor,
                        fontWeight:
                            option.isHighlighted == true
                                ? FontWeight.bold
                                : null,
                      ),
                    ),
                    subtitle:
                        option.subtitle != null ? Text(option.subtitle!) : null,
                    trailing: option.trailing,
                    onTap: () {
                      Navigator.pop(context);
                      option.onTap();
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 显示带分区的底部弹出菜单
  static Future<T?> showWithSections<T>({
    required BuildContext context,
    required String title,
    required List<MenuSection> sections,
    EdgeInsetsGeometry? padding,
    Widget? footer,
  }) {
    final theme = Theme.of(context);

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true, // 允许更大的高度
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: padding ?? const EdgeInsets.symmetric(vertical: 16),
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
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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

                const SizedBox(height: 4),

                // 分区列表
                ...sections.map((section) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 分区标题
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          section.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),

                      // 分区选项
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: section.options.length,
                        itemBuilder: (context, index) {
                          final option = section.options[index];
                          final textColor =
                              option.isHighlighted == true
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface;

                          return ListTile(
                            leading: Icon(
                              option.icon,
                              color:
                                  option.isHighlighted == true
                                      ? theme.colorScheme.primary
                                      : null,
                            ),
                            title: Text(
                              option.title,
                              style: TextStyle(
                                color: textColor,
                                fontWeight:
                                    option.isHighlighted == true
                                        ? FontWeight.bold
                                        : null,
                              ),
                            ),
                            subtitle:
                                option.subtitle != null
                                    ? Text(option.subtitle!)
                                    : null,
                            trailing: option.trailing,
                            onTap: option.onTap,
                          );
                        },
                      ),

                      if (section != sections.last)
                        const Divider(thickness: 1, height: 24),
                    ],
                  );
                }),

                // 底部内容
                if (footer != null) footer,
              ],
            ),
          ),
        );
      },
    );
  }

  /// 显示简单的选项列表底部弹出菜单（无标题，适合文件上传等简单选择）
  static Future<T?> showSimpleOptions<T>({
    required BuildContext context,
    required List<MenuOption> options,
    EdgeInsetsGeometry? padding,
  }) {
    final theme = Theme.of(context);

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖动条
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withAlpha(
                    (255 * 0.1).round(),
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 选项列表
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];

                  return ListTile(
                    leading: Icon(option.icon),
                    title: Text(option.title),
                    onTap: () {
                      Navigator.pop(context);
                      option.onTap();
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 显示自定义内容的底部弹出菜单
  static Future<T?> showCustomContent<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    Color? backgroundColor,
    BorderRadius? borderRadius,
  }) {
    final theme = Theme.of(context);

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: backgroundColor ?? theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius:
            borderRadius ??
            const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
              const Divider(height: 1),
            ],

            child,
          ],
        );
      },
    );
  }
}
