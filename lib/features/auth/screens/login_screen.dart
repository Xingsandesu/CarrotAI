import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carrot/core/providers/__export.dart';
import 'package:carrot/features/home/providers/chat_provider.dart'; // 导入ChatProvider
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:carrot/shared/components/toast_notification.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
  }

  Future<void> _login(AuthProvider authProvider) async {
    // 清除之前的错误信息
    authProvider.clearError();

    if (_formKey.currentState!.validate()) {
      final email = _emailController.text;
      final password = _passwordController.text;

      // 获取ChatProvider实例，用于同步会话
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      // 登录时传入登录成功回调，触发会话同步
      final success = await authProvider.login(
        email,
        password,
        onLoginSuccess: () => chatProvider.onLoginSuccess(),
      );

      if (success && mounted) {
        // 登录成功，跳转到主页
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (route) => false, // 清除所有路由堆栈
        );
      } else if (!success && mounted) {
        // 登录失败，显示错误信息
        ToastNotification.showError(
          message:
              authProvider.errorMessage ?? AppLocalizations.of(context)!.error,
          context: context,
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 16),

                      // 欢迎标题和图标
                      Row(
                        children: [
                          Hero(
                            tag: 'appIcon',
                            child: Material(
                              type: MaterialType.transparency,
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: theme.colorScheme.primary
                                    .withValues(alpha: 0.1),
                                child: Icon(
                                  Icons.smart_toy_outlined,
                                  size: 32,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            AppLocalizations.of(context)!.login,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 欢迎副标题
                      Text(
                        AppLocalizations.of(context)!.welcomeBack,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 32),

                      // 邮箱输入框
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.email,
                          hintText: AppLocalizations.of(context)!.enterEmail,
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '${AppLocalizations.of(context)!.email} ${AppLocalizations.of(context)!.required}';
                          }
                          if (!value.contains('@')) {
                            return '${AppLocalizations.of(context)!.email} ${AppLocalizations.of(context)!.invalid}';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 密码输入框
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.password,
                          hintText: AppLocalizations.of(context)!.enterPassword,
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        obscureText: _obscurePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '${AppLocalizations.of(context)!.password} ${AppLocalizations.of(context)!.required}';
                          }
                          return null;
                        },
                      ),

                      // 登录按钮
                      Consumer<AuthProvider>(
                        builder: (context, provider, child) {
                          return ElevatedButton(
                            onPressed:
                                provider.isLoading
                                    ? null
                                    : () => _login(provider),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                            ),
                            child:
                                provider.isLoading
                                    ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(),
                                    )
                                    : Text(AppLocalizations.of(context)!.login),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
