// 开源组件许可证页面，显示项目使用的开源组件信息

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 开源组件许可证页面
class OpenSourceLicensesPage extends StatelessWidget {
  const OpenSourceLicensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appLocalizations = AppLocalizations.of(context)!;

    // 开源组件列表，仅包含仓库和许可证URL
    final List<Map<String, String>> openSourceComponents = [
      {
        'name': 'Flutter',
        'repoUrl': 'https://github.com/flutter/flutter',
        'licenseUrl':
            'https://raw.githubusercontent.com/flutter/flutter/master/LICENSE',
      },
      {
        'name': 'Fluent UI Emoji',
        'repoUrl': 'https://github.com/microsoft/fluentui-emoji',
        'licenseUrl':
            'https://raw.githubusercontent.com/microsoft/fluentui-emoji/refs/heads/main/LICENSE',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(appLocalizations.openSourceLicenses),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView.builder(
          itemCount: openSourceComponents.length,
          itemBuilder: (context, index) {
            final component = openSourceComponents[index];
            return Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              color: colorScheme.surfaceContainerLowest,
              child: ListTile(
                title: Text(component['name']!),
                subtitle: Text(component['repoUrl']!),
                onTap: () => _showLicenseDetails(context, component),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 显示许可证详情对话框并从网络获取内容
  void _showLicenseDetails(
    BuildContext context,
    Map<String, String> component,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final appLocalizations = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(component['name']!),
          content: FutureBuilder<http.Response>(
            future: http.get(Uri.parse(component['licenseUrl']!)),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || snapshot.data?.statusCode != 200) {
                return Text(appLocalizations.error);
              }
              final licenseText = snapshot.data!.body;
              return SingleChildScrollView(
                child: SelectableText(licenseText, style: textTheme.bodyMedium),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(appLocalizations.close),
            ),
            TextButton(
              onPressed: () async {
                // 在异步操作前捕获 ScaffoldMessengerState
                final messenger = ScaffoldMessenger.of(context);
                final url = Uri.parse(component['repoUrl']!);
                final canLaunchResult = await canLaunchUrl(url);
                if (canLaunchResult) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  messenger.showSnackBar(
                    SnackBar(content: Text(appLocalizations.cannotOpenLink)),
                  );
                }
              },
              child: Text(appLocalizations.visitWebsite),
            ),
          ],
        );
      },
    );
  }
}
