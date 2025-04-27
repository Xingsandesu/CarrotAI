import 'package:flutter/material.dart';
import 'package:carrot/core/providers/__export.dart';
import 'package:provider/provider.dart';
import 'package:carrot/features/home/screens/home_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:carrot/shared/components/toast_notification.dart';

// AuthWrapper 现在始终显示 HomeScreen，但在需要时会要求登录
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // 等待 AuthProvider 初始化完成
    if (!authProvider.isInitialized) {
      // 显示加载指示器
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 无论是否登录，都显示 HomeScreen
    // HomeScreen 将负责检查用户交互时是否需要登录
    return const HomeScreen();
  }

  // 静态方法，检查用户是否已登录，如果未登录则导航到登录页面
  // 返回值表示用户是否已登录
  static bool checkAuthAndRedirect(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated) {
      // 显示提示
      ToastNotification.showInfo(
        message: AppLocalizations.of(context)!.loginRequired,
        context: context,
      );

      // 导航到登录页面
      Navigator.pushNamed(context, '/login');
      return false;
    }

    return true;
  }
}
