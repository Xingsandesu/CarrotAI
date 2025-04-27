// 这个文件实现聊天消息区域组件，显示聊天消息并管理聊天状态

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import 'package:carrot/features/home/providers/chat_provider.dart';
import 'package:carrot/shared/models/__export.dart';
import 'package:carrot/widgets/enhanced_code_block.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:carrot/shared/components/toast_notification.dart';

/// 聊天消息区域组件
///
/// 显示聊天消息列表并管理聊天状态
class ChatMessageArea extends StatelessWidget {
  /// 当前会话
  final Conversation? conversation;

  /// 是否正在加载中
  final bool isLoading;

  /// 用户信息
  final String? username;

  /// 创建聊天消息区域组件
  const ChatMessageArea({
    super.key,
    this.conversation,
    this.isLoading = false,
    this.username,
  });

  @override
  Widget build(BuildContext context) {
    // 获取Material 3的颜色方案
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // 如果没有会话或消息列表为空，显示提示
    if (conversation == null || conversation!.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: colorScheme.primary.withValues(alpha: 128),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noChats,
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 179),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.startChat,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // 显示消息列表
    return ListView.builder(
      reverse: true, // 倒序显示，最新消息在底部
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      itemCount: conversation!.messages.length,
      // 添加缓存键以优化重建
      key: PageStorageKey('chat_messages_${conversation!.conversationId}'),
      // 添加物理滚动行为优化
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      // 添加缓存范围
      cacheExtent: 1000, // 预缓存更多项目以减少重建
      itemBuilder: (context, index) {
        // 计算正确的索引，不需要考虑loading情况
        final messageIndex = index;
        final message =
            conversation!.messages[conversation!.messages.length -
                1 -
                messageIndex];

        // 使用RepaintBoundary包装每个消息项以优化渲染
        return RepaintBoundary(child: _buildMessageItem(context, message));
      },
    );
  }

  /// 构建消息项
  Widget _buildMessageItem(BuildContext context, ChatMessage message) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isUser = message.role == 'user';
    // 获取当前主题亮度
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    // 根据是否为用户和模式确定颜色
    final bubbleColor =
        isUser
            ? (isDarkMode ? colorScheme.primaryContainer : colorScheme.primary)
            : (isDarkMode
                ? colorScheme.surfaceContainerLow
                : colorScheme.surfaceContainerLow);
    final textColor =
        isUser
            ? (isDarkMode ? colorScheme.onPrimaryContainer : Colors.white)
            : (isDarkMode ? colorScheme.onSurface : colorScheme.onSurface);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // 显示工具调用气泡（如果有）
                if (!isUser &&
                    message.toolCalls != null &&
                    message.toolCalls!.isNotEmpty)
                  _buildToolCallsBubble(context, message.toolCalls!),

                // 显示深度思考内容（如果有）- 移到消息内容上方
                if (!isUser &&
                    message.reasoningContent != null &&
                    message.reasoningContent!.isNotEmpty)
                  _buildReasoningContent(context, message.reasoningContent!),

                // 主要消息内容
                Column(
                  crossAxisAlignment:
                      isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                  children: [
                    Container(
                      // 移除width: double.infinity，让容器宽度自适应内容
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: bubbleColor, // 使用计算出的气泡颜色
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft:
                              isUser
                                  ? const Radius.circular(20)
                                  : const Radius.circular(4),
                          bottomRight:
                              isUser
                                  ? const Radius.circular(4)
                                  : const Radius.circular(20),
                        ),
                        border: Border.all(color: Colors.transparent, width: 0),
                      ),
                      child:
                          isUser
                              ? Text(
                                message.content,
                                style: textTheme.bodyLarge?.copyWith(
                                  color: textColor, // 使用计算出的文字颜色
                                ),
                              )
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MarkdownBody(
                                    data: message.content,
                                    selectable: true,
                                    builders: {
                                      'pre': CodeElementBuilder(),
                                      'code': CodeElementBuilder(),
                                    },
                                    // 添加自定义语法处理
                                    extensionSet: md.ExtensionSet.gitHubWeb,
                                    // 添加自定义内联语法
                                    inlineSyntaxes: [md.InlineHtmlSyntax()],
                                    // 使用 hashCode 作为唯一标识符
                                    key: ValueKey(
                                      'markdown_${message.hashCode}',
                                    ),
                                    // 添加防抖动处理
                                    softLineBreak: true,
                                    fitContent: true,
                                    shrinkWrap: true,
                                    styleSheet: MarkdownStyleSheet(
                                      p: textTheme.bodyLarge?.copyWith(
                                        color: textColor,
                                        height: 1.5,
                                      ),
                                      // 减小标题字体大小差距
                                      h1: textTheme.titleLarge?.copyWith(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                        height: 1.5,
                                      ),
                                      h2: textTheme.titleMedium?.copyWith(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                        height: 1.5,
                                      ),
                                      h3: textTheme.titleSmall?.copyWith(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                        height: 1.5,
                                      ),
                                      h4: textTheme.bodyLarge?.copyWith(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                        height: 1.5,
                                      ),
                                      h5: textTheme.bodyLarge?.copyWith(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                        height: 1.5,
                                      ),
                                      h6: textTheme.bodyMedium?.copyWith(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                        height: 1.5,
                                      ),
                                      strong: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                      em: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: textColor,
                                      ),
                                      blockquote: textTheme.bodyMedium
                                          ?.copyWith(
                                            color: textColor.withValues(
                                              alpha: 204,
                                            ),
                                            fontStyle: FontStyle.italic,
                                            height: 1.5,
                                          ),
                                      code: TextStyle(
                                        backgroundColor:
                                            isDarkMode
                                                ? Colors.black.withValues(
                                                  alpha: 51,
                                                )
                                                : Colors.white.withValues(
                                                  alpha: 51,
                                                ),
                                        fontFamily: 'monospace',
                                        fontSize:
                                            textTheme.bodyMedium?.fontSize,
                                        color: textColor,
                                      ),
                                      listBullet: textTheme.bodyLarge?.copyWith(
                                        color: textColor,
                                      ),
                                      a: TextStyle(
                                        color: colorScheme.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                      listIndent: 24.0,
                                      blockSpacing: 12.0,
                                    ),
                                    onTapLink: (text, href, title) async {
                                      if (href != null) {
                                        try {
                                          await launchUrl(
                                            Uri.parse(href),
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        } catch (e) {
                                          if (context.mounted) {
                                            ToastNotification.showError(
                                              message: '无法打开链接: $e',
                                              context: context,
                                            );
                                          }
                                        }
                                      }
                                    },
                                  ),
                                  // 在文字后方添加操作按钮
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: _buildMessageActions(
                                        context,
                                        message,
                                      ),
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
        ],
      ),
    );
  }

  /// 构建消息操作按钮
  Widget _buildMessageActions(BuildContext context, ChatMessage message) {
    final colorScheme = Theme.of(context).colorScheme;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    // 在气泡内部使用半透明按钮，以便更好地融入
    final buttonColor =
        isDarkMode
            ? colorScheme.onSurface.withValues(
              alpha: (255 * 0.7).round().toDouble(),
            )
            : colorScheme.onSurface.withValues(
              alpha: (255 * 0.6).round().toDouble(),
            );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 复制按钮 - 仅显示图标，更小更紧凑
        IconButton(
          icon: Icon(Icons.copy_outlined, size: 16, color: buttonColor),
          tooltip: AppLocalizations.of(context)!.copy,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: const EdgeInsets.all(4),
          style: IconButton.styleFrom(
            foregroundColor: buttonColor,
            backgroundColor: Colors.transparent,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: message.content));
            ToastNotification.showSuccess(
              message: AppLocalizations.of(context)!.copied,
              context: context,
              duration: const Duration(seconds: 2),
            );
          },
        ),
        const SizedBox(width: 0), // 减小间距
        // 重新生成按钮 - 仅显示图标，更小更紧凑
        IconButton(
          icon: Icon(Icons.refresh_outlined, size: 16, color: buttonColor),
          tooltip: AppLocalizations.of(context)!.regenerate,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: const EdgeInsets.all(4),
          style: IconButton.styleFrom(
            foregroundColor: buttonColor,
            backgroundColor: Colors.transparent,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () {
            // 获取当前会话中最后一条用户消息
            if (conversation != null && conversation!.messages.isNotEmpty) {
              // 找到最后一条用户消息
              ChatMessage? lastUserMessage;
              for (int i = conversation!.messages.length - 1; i >= 0; i--) {
                if (conversation!.messages[i].role == 'user') {
                  lastUserMessage = conversation!.messages[i];
                  break;
                }
              }

              if (lastUserMessage != null) {
                // 移除最后一条助手消息
                chatProvider.regenerateLastResponse();
              }
            }
          },
        ),
      ],
    );
  }

  /// 构建深度思考内容的可折叠组件
  Widget _buildReasoningContent(BuildContext context, String reasoningContent) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    // 为深色模式使用不同的颜色以确保正确的对比度
    // 在Android上，深色模式需要使用更明确的颜色
    final containerColor =
        isDarkMode
            ? colorScheme
                .surfaceContainerHigh // 使用更高对比度的容器颜色
            : colorScheme.surfaceContainerLow.withValues(alpha: 128);

    // 完全移除边框，解决安卓上的白色边框问题

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(12),
        // 完全移除边框定义，确保在所有平台上都没有边框
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Icon(Icons.psychology, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.deepThinking,
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // 内容区域 - 使用Markdown渲染
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
            child: MarkdownBody(
              data: reasoningContent,
              selectable: true,
              builders: {'pre': CodeElementBuilder()},
              styleSheet: MarkdownStyleSheet(
                p: textTheme.bodyMedium?.copyWith(
                  color:
                      isDarkMode
                          ? colorScheme
                              .onSurface // 深色模式下使用更高对比度的颜色
                          : colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                h1: textTheme.titleLarge?.copyWith(
                  color:
                      isDarkMode
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
                h2: textTheme.titleMedium?.copyWith(
                  color:
                      isDarkMode
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
                h3: textTheme.titleSmall?.copyWith(
                  color:
                      isDarkMode
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
                h4: textTheme.bodyLarge?.copyWith(
                  color:
                      isDarkMode
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
                h5: textTheme.bodyLarge?.copyWith(
                  color:
                      isDarkMode
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
                h6: textTheme.bodyMedium?.copyWith(
                  color:
                      isDarkMode
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
                strong: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      isDarkMode
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                ),
                em: TextStyle(
                  fontStyle: FontStyle.italic,
                  color:
                      isDarkMode
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                ),
                code: TextStyle(
                  backgroundColor:
                      isDarkMode
                          ? Colors.black.withValues(alpha: 77) // 0.3 * 255 = 77
                          : Colors.white.withValues(alpha: 51),
                  fontFamily: 'monospace',
                  fontSize: textTheme.bodyMedium?.fontSize,
                  color:
                      isDarkMode
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                ),
                // 代码块样式由自定义构建器处理
                a: TextStyle(
                  color:
                      isDarkMode
                          ? colorScheme.primary.withValues(alpha: 230)
                          : colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
                listIndent: 24.0, // 增加列表缩进
                blockSpacing: 12.0, // 增加块间距
                tableHead: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      isDarkMode
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                ),
                tableBody: TextStyle(
                  color:
                      isDarkMode
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                ),
                tableBorder: TableBorder.all(
                  color:
                      isDarkMode
                          ? colorScheme.outline.withValues(
                            alpha: 153,
                          ) // 0.6 * 255 = 153
                          : colorScheme.outline.withValues(
                            alpha: 102,
                          ), // 0.4 * 255 = 102
                  width: 0.5,
                ),
                tableCellsPadding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化工具调用信息
  String _formatToolCalls(
    BuildContext context,
    List<Map<String, dynamic>> toolCalls,
  ) {
    if (toolCalls.isEmpty) return '';

    // 正确解析工具名称和参数
    final firstTool = toolCalls.first;
    // 从function对象中获取名称
    final name =
        firstTool['function']?['name'] ??
        AppLocalizations.of(context)!.unknownTool;

    // 格式化显示
    String formattedInfo = name;

    // 如果有多个工具调用，显示总数
    if (toolCalls.length > 1) {
      return '$formattedInfo ${AppLocalizations.of(context)!.andOtherTools(toolCalls.length)}';
    }

    return formattedInfo;
  }

  /// 构建工具调用气泡
  Widget _buildToolCallsBubble(
    BuildContext context,
    List<Map<String, dynamic>> toolCalls,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    // 获取工具名称和参数

    // 显示的文本
    String displayText =
        '${AppLocalizations.of(context)!.usingTool}: ${_formatToolCalls(context, toolCalls)}';

    // 为深色模式使用适当的颜色
    // 在Android上，需要使用更高对比度的颜色
    final containerColor =
        isDarkMode
            ? colorScheme.tertiary.withValues(alpha: 77) // 使用主色的深色变体，增加透明度
            : colorScheme.tertiaryContainer;

    // 完全移除边框，确保在所有平台上都没有边框

    // 文本颜色需要在深色模式下更加明显
    final textColor =
        isDarkMode
            ? colorScheme
                .onTertiary // 使用更高对比度的文本颜色
            : colorScheme.onTertiaryContainer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(16),
          // 完全移除边框定义，确保在所有平台上都没有边框
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.build_circle, size: 16, color: textColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                displayText,
                style: textTheme.labelMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
