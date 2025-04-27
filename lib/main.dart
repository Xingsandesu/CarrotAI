// 这个文件是主文件，用于启动应用程序
// 它使用 Provider 提供 App状态 (Auth, Theme)
// 它使用 MaterialApp 提供应用程序的外观
// 它使用 AuthWrapper 根据认证状态决定显示哪个页面
// 它使用 routes 定义应用程序的路由
// 它使用 dynamic_color 支持 Material 3 动态颜色
//

import 'package:dynamic_color/dynamic_color.dart'; // 导入 dynamic_color
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 导入foundation包，用于kReleaseMode
import 'package:provider/provider.dart';
import 'package:carrot/core/providers/__export.dart';
import 'package:carrot/core/config/routes/app_router.dart';
import 'package:carrot/features/auth/widgets/auth_wrapper.dart';
import 'package:carrot/core/config/theme/app_theme.dart';
import 'package:carrot/features/home/providers/chat_provider.dart'; // 导入ChatProvider
import 'package:carrot/core/config/app_config.dart';
import 'package:carrot/core/services/global_service.dart'; // 导入全局服务
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // 导入生成的本地化文件
import 'package:carrot/core/utils/__export.dart'; // 导入工具类

void main() {
  // 确保 WidgetsBinding 已初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 在发布模式下禁用debugPrint
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {
      // 发布模式下的空实现，不输出任何调试信息
    };
  }

  // 初始化性能跟踪（只在调试模式且性能跟踪开关打开时生效）
  PerformanceExample.initializePerformanceTracking();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // 添加应用生命周期观察者
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // 移除观察者
    WidgetsBinding.instance.removeObserver(this);
    // 停止性能跟踪
    PerformanceExample.stopPerformanceTracking();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('应用生命周期状态变化: $state');

    // 当应用进入后台时暂停性能跟踪，返回前台时恢复
    if (state == AppLifecycleState.paused) {
      // 应用进入后台
      debugPrint('应用进入后台');
      PerformanceExample.stopPerformanceTracking();
    } else if (state == AppLifecycleState.resumed) {
      // 应用返回前台
      debugPrint('应用返回前台');
      PerformanceExample.initializePerformanceTracking();

      // 应用返回前台时，刷新认证状态
      _refreshAuthState();
    } else if (state == AppLifecycleState.detached) {
      // 应用被终止
      debugPrint('应用被终止');
    }
  }

  /// 刷新认证状态
  ///
  /// 当应用从后台返回前台时调用，确保认证状态是最新的
  void _refreshAuthState() {
    // 使用延迟执行，确保应用已完全恢复
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) {
        debugPrint('刷新认证状态: 组件已卸载');
        return;
      }

      // 使用全局服务的方法刷新认证状态
      // 这样避免在异步间隙使用BuildContext
      debugPrint('应用返回前台，请求刷新认证状态');
      globalService.refreshAuthState();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 使用 MultiProvider 提供 AuthProvider 和 ThemeProvider
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create:
              (context) => ChatProvider(
                Provider.of<AuthProvider>(context, listen: false),
              ),
          update:
              (context, auth, previousChat) =>
                  previousChat ?? ChatProvider(auth),
        ),
      ],
      // 使用 DynamicColorBuilder 来获取动态颜色
      child: DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          // 使用 Consumer 来监听 ThemeProvider 和 LocaleProvider 的变化
          return Consumer2<ThemeProvider, LocaleProvider>(
            builder: (context, themeProvider, localeProvider, child) {
              ColorScheme? lightColorScheme;
              ColorScheme? darkColorScheme;
              Color lightSeedColor = AppTheme.defaultSeedColor;
              Color darkSeedColor = AppTheme.defaultSeedColor;

              // 根据 ThemeProvider 的状态决定颜色方案
              switch (themeProvider.colorSource) {
                case ColorSource.system:
                  // 优先使用系统动态颜色
                  lightColorScheme = lightDynamic;
                  darkColorScheme = darkDynamic;
                  // 如果系统动态颜色不可用，则回退到默认种子颜色
                  if (lightColorScheme == null || darkColorScheme == null) {
                    lightSeedColor = AppTheme.defaultSeedColor;
                    darkSeedColor = AppTheme.defaultSeedColor;
                    lightColorScheme = null; // 确保使用 seed color 生成
                    darkColorScheme = null; // 确保使用 seed color 生成
                  } else {
                    // 如果动态颜色可用，不需要种子颜色
                    lightSeedColor = lightColorScheme.primary; // 可以用动态主色作为种子
                    darkSeedColor = darkColorScheme.primary;
                  }
                  break;
                case ColorSource.customSeed:
                  // 使用用户选择的自定义种子颜色
                  lightSeedColor = themeProvider.customSeedColor;
                  darkSeedColor = themeProvider.customSeedColor;
                  lightColorScheme = null; // 强制使用 seed color 生成
                  darkColorScheme = null; // 强制使用 seed color 生成
                  break;
                case ColorSource.defaultSeed:
                  // 使用 AppTheme 中定义的默认种子颜色
                  lightSeedColor = AppTheme.defaultSeedColor;
                  darkSeedColor = AppTheme.defaultSeedColor;
                  lightColorScheme = null; // 强制使用 seed color 生成
                  darkColorScheme = null; // 强制使用 seed color 生成
                  break;
              }

              // 使用 Builder 来获取正确的 context 以应用 MediaQuery override
              return Builder(
                builder: (context) {
                  return MaterialApp(
                    title: AppConfig.appName,
                    // 使用全局导航器键，允许在没有上下文的情况下进行导航
                    navigatorKey: globalService.navigatorKey,
                    // 应用字体缩放
                    builder: (context, child) {
                      final scale = themeProvider.fontSizeScale;
                      return MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(scale), // 使用 textScaler
                        ),
                        child: child!,
                      );
                    },
                    theme: AppTheme.lightTheme(
                      seedColor: lightSeedColor,
                      dynamicColorScheme: lightColorScheme,
                    ),
                    darkTheme: AppTheme.darkTheme(
                      seedColor: darkSeedColor,
                      dynamicColorScheme: darkColorScheme,
                    ),
                    themeMode: themeProvider.themeMode, // 直接使用 themeMode
                    // 本地化配置
                    locale:
                        localeProvider
                            .currentLocale, // 使用 LocaleProvider 中的当前语言
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales:
                        LocaleProvider.supportedLocales, // 支持的语言列表

                    home: const AuthWrapper(),
                    routes: AppRouter.routes,
                    onGenerateRoute: AppRouter.onGenerateRoute,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// AuthWrapper 根据认证状态决定显示哪个页面
// class AuthWrapper extends StatelessWidget {
//   const AuthWrapper({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context);
//
//     // 等待 AuthProvider 初始化完成
//     if (!authProvider.isInitialized) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }
//
//     // 根据认证状态显示页面
//     if (authProvider.isAuthenticated) {
//       return const HomeScreen();
//     } else {
//       return const LoginScreen();
//     }
//   }
// }
