import 'package:flutter/material.dart';

/// 统一的搜索框组件
class AppSearchBar extends StatelessWidget {
  /// 搜索控制器
  final TextEditingController controller;

  /// 搜索提示文本
  final String hintText;

  /// 焦点节点
  final FocusNode? focusNode;

  /// 是否自动获取焦点
  final bool autofocus;

  /// 搜索内容变化回调
  final Function(String)? onChanged;

  /// 清除搜索内容回调
  final VoidCallback? onClear;

  /// 提交搜索回调
  final Function(String)? onSubmitted;

  /// 构造函数
  const AppSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.focusNode,
    this.autofocus = false,
    this.onChanged,
    this.onClear,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool hasText = controller.text.isNotEmpty;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
        suffixIcon:
            hasText
                ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onClear?.call();
                  },
                  tooltip: 'Clear',
                )
                : null,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: EdgeInsets.zero,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.2),
            width: 1.0,
          ),
        ),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
    );
  }
}
