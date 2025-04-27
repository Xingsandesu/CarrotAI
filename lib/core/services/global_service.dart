// 全局服务，用于在应用的任何地方访问关键服务和状态
// 这个服务提供了一个全局的访问点，用于获取导航器键和其他全局状态

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:carrot/shared/components/toast_notification.dart';
import 'package:carrot/core/providers/auth_provider.dart';

/// 全局服务单例，用于在应用的任何地方访问关键服务和状态
class GlobalService {
  // 单例实例
  static final GlobalService _instance = GlobalService._internal();

  // 工厂构造函数返回单例实例
  factory GlobalService() => _instance;

  // 私有构造函数
  GlobalService._internal();

  // 全局导航器键，用于在没有上下文的情况下进行导航
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // 获取当前上下文
  BuildContext? get currentContext => navigatorKey.currentContext;

  // 获取当前状态
  NavigatorState? get currentState => navigatorKey.currentState;

  // 导航到指定路由
  Future<T?> navigateTo<T>(String routeName, {Object? arguments}) {
    return currentState!.pushNamed<T>(routeName, arguments: arguments);
  }

  // 替换当前路由
  Future<T?> replaceTo<T>(String routeName, {Object? arguments}) {
    return currentState!.pushReplacementNamed<T, dynamic>(
      routeName,
      arguments: arguments,
    );
  }

  // 返回上一页
  void goBack<T>([T? result]) {
    return currentState!.pop<T>(result);
  }

  // 显示通用对话框
  Future<T?> showDialogWithContext<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: currentContext!,
      builder: builder,
      barrierDismissible: barrierDismissible,
    );
  }

  // 显示通用Snackbar（现在使用通知气泡）
  void showSnackBar(String message, {Duration? duration}) {
    if (currentContext != null) {
      AppLocalizations.of(currentContext!);
      ToastNotification.show(
        message: message,
        context: currentContext!,
        duration: duration ?? const Duration(seconds: 2),
      );
    }
  }

  /// 刷新认证状态
  ///
  /// 安全地刷新认证状态，避免在异步间隙使用BuildContext
  Future<void> refreshAuthState() async {
    try {
      // 获取当前上下文
      final context = navigatorKey.currentContext;
      if (context == null) {
        debugPrint('GlobalService: 刷新认证状态失败 - 无法获取上下文');
        return;
      }

      // 使用Provider.of而不是context.read，避免在异步间隙使用BuildContext
      AuthProvider authProvider;

      try {
        authProvider = Provider.of<AuthProvider>(context, listen: false);
      } catch (e) {
        debugPrint('GlobalService: 获取AuthProvider失败 - $e');
        return;
      }

      debugPrint('GlobalService: 开始刷新认证状态');

      // 刷新认证状态
      await authProvider.refreshAuthState();

      // 如果认证提供者未初始化，尝试重新初始化
      if (!authProvider.isInitialized) {
        debugPrint('GlobalService: 认证提供者未初始化，尝试重新初始化');
        await authProvider.reinitialize();
      }

      debugPrint('GlobalService: 认证状态刷新完成');
    } catch (e) {
      debugPrint('GlobalService: 刷新认证状态时出错 - $e');
    }
  }
}

// 全局服务实例，可以在应用的任何地方使用
final globalService = GlobalService();
