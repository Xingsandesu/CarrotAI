import 'package:flutter/material.dart';
import 'package:carrot/features/auth/screens/login_screen.dart';
import 'package:carrot/features/home/screens/home_screen.dart';

class AppRouter {
  // 定义静态路由表
  static final Map<String, WidgetBuilder> routes = {
    '/login': (context) => const LoginScreen(),
    '/home': (context) => const HomeScreen(),
  };

  // 定义页面生成器，用于处理动态路由或未找到的路由
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    return null;
  }
}
