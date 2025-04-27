// 用户操作菜单组件，显示用户相关操作

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carrot/core/providers/auth_provider.dart';
import 'package:carrot/core/api/__export.dart';
import 'package:carrot/shared/components/bottom_sheet_menu.dart';
import 'package:carrot/features/home/providers/chat_provider.dart'; // 导入ChatProvider
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:carrot/shared/components/toast_notification.dart';

class UserOptionsMenu {
  // 显示用户选项底部菜单
  static void showUserOptionsBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 获取认证提供者
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    // 用户操作选项
    final options = [
      MenuOption(
        title: AppLocalizations.of(context)!.changePassword,
        icon: Icons.lock_reset_outlined,
        onTap: () {
          _showChangePasswordDialog(context);
        },
      ),
      MenuOption(
        title: AppLocalizations.of(context)!.forgotPassword,
        icon: Icons.help_outline,
        onTap: () {
          _showPasswordResetRequestDialog(context);
        },
      ),
      // 删除设置选项，因为设置按钮已经在侧边栏中显示
      MenuOption(
        title: AppLocalizations.of(context)!.logout,
        icon: Icons.logout,
        onTap: () {
          // 显示确认对话框
          _showLogoutConfirmationDialog(context);
        },
        isHighlighted: true,
      ),
    ];

    // 使用原生BottomSheet以支持更大高度和滚动
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 允许控制滚动
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 用户信息头部
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: colorScheme.secondaryContainer,
                          radius: 24,
                          child: Text(
                            user?.name.isNotEmpty == true
                                ? user!.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: colorScheme.onSecondaryContainer,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? '未登录',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 菜单选项
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final bool isLogout = index == options.length - 1;

                  return ListTile(
                    leading: Icon(
                      option.icon,
                      color: isLogout ? colorScheme.error : colorScheme.primary,
                    ),
                    title: Text(
                      option.title,
                      style: TextStyle(
                        color:
                            isLogout
                                ? colorScheme.error
                                : colorScheme.onSurface,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      option.onTap();
                    },
                  );
                },
              ),
              // 确保在底部有足够空间
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  // 显示修改密码对话框
  static void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final formKey = GlobalKey<FormState>();
    final userApiClient = apiClientFactory.userApiClient;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(AppLocalizations.of(context)!.changePassword),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPasswordController,
                      decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(context)!.currentPassword,
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(
                            context,
                          )!.pleaseEnterCurrentPassword;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.newPassword,
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(
                            context,
                          )!.pleaseEnterNewPassword;
                        }
                        if (value.length < 6) {
                          return AppLocalizations.of(
                            context,
                          )!.passwordMinLength;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(context)!.confirmNewPassword,
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return AppLocalizations.of(
                            context,
                          )!.pleaseConfirmNewPassword;
                        }
                        if (value != newPasswordController.text) {
                          return AppLocalizations.of(
                            context,
                          )!.passwordsDoNotMatch;
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                if (isLoading)
                  const CircularProgressIndicator()
                else
                  TextButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        setState(() {
                          isLoading = true;
                        });

                        final response = await userApiClient.updatePassword(
                          currentPassword: currentPasswordController.text,
                          newPassword: newPasswordController.text,
                        );

                        setState(() {
                          isLoading = false;
                        });

                        if (!context.mounted) return;

                        if (response.success) {
                          Navigator.pop(context);
                          ToastNotification.showSuccess(
                            message: '密码修改成功',
                            context: context,
                          );
                        } else {
                          ToastNotification.showInfo(
                            message: response.message,
                            context: context,
                          );
                        }
                      }
                    },
                    child: Text(AppLocalizations.of(context)!.confirm),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // 显示请求密码重置对话框
  static void _showPasswordResetRequestDialog(BuildContext context) {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final authApiClient = apiClientFactory.authApiClient;
    bool isLoading = false;

    // 获取认证提供者中的用户邮箱作为默认值
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user?.email != null) {
      emailController.text = authProvider.user!.email;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(AppLocalizations.of(context)!.requestPasswordReset),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppLocalizations.of(context)!.resetLinkWillBeSent),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.email,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '${AppLocalizations.of(context)!.email} ${AppLocalizations.of(context)!.required}';
                        }
                        if (!RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(value)) {
                          return AppLocalizations.of(context)!.enterValidEmail;
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                if (isLoading)
                  const CircularProgressIndicator()
                else
                  TextButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        setState(() {
                          isLoading = true;
                        });

                        final response = await authApiClient
                            .requestPasswordReset(emailController.text);

                        setState(() {
                          isLoading = false;
                        });

                        if (!context.mounted) return;

                        Navigator.pop(context);
                        ToastNotification.showSuccess(
                          message: response.message,
                          context: context,
                        );
                      }
                    },
                    child: Text(AppLocalizations.of(context)!.send),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // 显示注销确认对话框
  static void _showLogoutConfirmationDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.confirmLogout),
          content: Text(
            AppLocalizations.of(context)!.logoutConfirmationMessage,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // 执行注销操作，并传入回调清除会话数据
                authProvider.logout(
                  onLogoutCallback: () => chatProvider.clearAllData(),
                );

                // 跳转到主页
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false, // 清除所有路由堆栈
                );
              },
              child: Text(
                AppLocalizations.of(context)!.confirm,
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }
}
