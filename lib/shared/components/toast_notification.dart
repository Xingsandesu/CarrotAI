import 'package:flutter/material.dart';

/// 通知气泡服务，用于显示顶部通知气泡
class ToastNotification {
  /// 显示通知气泡
  ///
  /// [message] 消息内容
  /// [context] 上下文
  /// [duration] 显示时长，默认2秒
  /// [backgroundColor] 背景色，默认从主题中获取
  /// [textColor] 文本颜色，默认从主题中获取
  /// [icon] 图标，默认为null
  /// [position] 显示位置，默认为顶部
  static void show({
    required String message,
    required BuildContext context,
    Duration? duration,
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
    ToastPosition position = ToastPosition.top,
  }) {
    final overlay = Overlay.of(context);
    final theme = Theme.of(context);

    final entry = OverlayEntry(
      builder: (context) {
        return _ToastNotificationWidget(
          message: message,
          duration: duration ?? const Duration(seconds: 2),
          backgroundColor: backgroundColor ?? theme.colorScheme.secondary,
          textColor: textColor ?? theme.colorScheme.onSecondary,
          icon: icon,
          position: position,
        );
      },
    );

    overlay.insert(entry);

    // 在指定时间后移除通知
    Future.delayed(duration ?? const Duration(seconds: 2), () {
      entry.remove();
    });
  }

  /// 显示成功通知
  static void showSuccess({
    required String message,
    required BuildContext context,
    Duration? duration,
  }) {
    Theme.of(context);

    show(
      message: message,
      context: context,
      duration: duration,
      backgroundColor: Colors.green.shade700,
      textColor: Colors.white,
      icon: Icons.check_circle,
    );
  }

  /// 显示错误通知
  static void showError({
    required String message,
    required BuildContext context,
    Duration? duration,
  }) {
    show(
      message: message,
      context: context,
      backgroundColor: Colors.red.shade700,
      textColor: Colors.white,
      duration: duration,
      icon: Icons.error,
    );
  }

  /// 显示警告通知
  static void showWarning({
    required String message,
    required BuildContext context,
    Duration? duration,
  }) {
    show(
      message: message,
      context: context,
      backgroundColor: Colors.orange.shade700,
      textColor: Colors.white,
      duration: duration,
      icon: Icons.warning,
    );
  }

  /// 显示信息通知
  static void showInfo({
    required String message,
    required BuildContext context,
    Duration? duration,
  }) {
    final theme = Theme.of(context);

    show(
      message: message,
      context: context,
      backgroundColor: theme.colorScheme.primary,
      textColor: theme.colorScheme.onPrimary,
      duration: duration,
      icon: Icons.info,
    );
  }
}

/// 通知气泡位置
enum ToastPosition { top, bottom }

/// 通知气泡小部件
class _ToastNotificationWidget extends StatefulWidget {
  final String message;
  final Duration duration;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;
  final ToastPosition position;

  const _ToastNotificationWidget({
    required this.message,
    required this.duration,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
    required this.position,
  });

  @override
  State<_ToastNotificationWidget> createState() =>
      _ToastNotificationWidgetState();
}

class _ToastNotificationWidgetState extends State<_ToastNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    // 进入动画
    _controller.forward();

    // 在退出前300ms开始退出动画
    Future.delayed(widget.duration - const Duration(milliseconds: 300), () {
      if (mounted) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top:
          widget.position == ToastPosition.top
              ? MediaQuery.of(context).viewPadding.top + 16
              : null,
      bottom:
          widget.position == ToastPosition.bottom
              ? MediaQuery.of(context).viewPadding.bottom + 16
              : null,
      left: 16,
      right: 16,
      child: SafeArea(
        child: FadeTransition(
          opacity: _animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, widget.position == ToastPosition.top ? -1 : 1),
              end: const Offset(0, 0),
            ).animate(_animation),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: widget.backgroundColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: widget.textColor),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(color: widget.textColor, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
