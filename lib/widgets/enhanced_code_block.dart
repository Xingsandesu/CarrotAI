import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class EnhancedCodeBlock extends StatefulWidget {
  final String code;
  final String? language;
  final TextStyle? textStyle;

  const EnhancedCodeBlock({
    super.key,
    required this.code,
    this.language,
    this.textStyle,
  });

  @override
  State<EnhancedCodeBlock> createState() => _EnhancedCodeBlockState();
}

class _EnhancedCodeBlockState extends State<EnhancedCodeBlock> {
  bool _showCopyButton = false;
  bool _isCopied = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Determine if language is supported for syntax highlighting
    final String? language = widget.language;

    return MouseRegion(
      onEnter: (_) => setState(() => _showCopyButton = true),
      onExit: (_) => setState(() => _showCopyButton = false),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: const Color(0xFF282C34), // Dark background for code blocks
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: colorScheme.outline.withValues(
              alpha: (255 * 0.3).round().toDouble(),
            ),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language indicator and copy button bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 6.0,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(
                  alpha: (255 * 0.3).round().toDouble(),
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8.0),
                  topRight: Radius.circular(8.0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Language indicator with improved visibility
                  if (language != null && language.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 2.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(
                          alpha: (255 * 0.5).round().toDouble(),
                        ),
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: 51.0,
                          ), // 0.2 * 255 = 51
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        language,
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  // Copy button
                  AnimatedOpacity(
                    opacity: _showCopyButton ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child:
                        _isCopied
                            ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check,
                                  size: 16.0,
                                  color: Colors.green[300],
                                ),
                                const SizedBox(width: 4.0),
                                Text(
                                  AppLocalizations.of(context)!.copied,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: Colors.green[300],
                                  ),
                                ),
                              ],
                            )
                            : IconButton(
                              icon: const Icon(
                                Icons.copy,
                                size: 16.0,
                                color: Colors.white70,
                              ),
                              tooltip: AppLocalizations.of(context)!.copyCode,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              splashRadius: 16.0,
                              onPressed: () => _copyToClipboard(widget.code),
                            ),
                  ),
                ],
              ),
            ),

            // 简化实现，移除行号显示
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: HighlightView(
                widget.code,
                language: widget.language ?? 'plaintext',
                theme: atomOneDarkTheme,
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14.0,
                  height: 1.5,
                  color: Colors.white,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() {
      _isCopied = true;
    });

    // Reset the copied state after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }
}

// Custom Markdown element builder for code blocks
class CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    String language = '';
    String textContent = '';

    // 处理代码块
    if (element.tag == 'pre') {
      final codeBlocks =
          element.children
              ?.whereType<md.Element>()
              .where((e) => e.tag == 'code')
              .toList() ??
          [];

      if (codeBlocks.isNotEmpty) {
        final codeElement = codeBlocks.first;
        // 从子元素获取语言
        final String? className = codeElement.attributes['class'];
        if (className != null) {
          final Match? match = RegExp(r'language-(\w+)').firstMatch(className);
          if (match != null && match.groupCount >= 1) {
            language = match.group(1) ?? '';
          }
        }

        // 从子元素获取内容
        textContent = codeElement.textContent;
      } else {
        // 如果没有code子元素，使用pre标签的内容
        textContent = element.textContent;
      }

      // 如果代码内容为空，不应用自定义渲染
      if (textContent.trim().isEmpty) {
        return null;
      }

      // 如果语言仍然为空，尝试从内容的第一行推断
      if (language.isEmpty) {
        final firstLine = textContent.split('\n').first.trim();
        if (firstLine.startsWith('```') && firstLine.length > 3) {
          language = firstLine.substring(3).trim();
          // 移除第一行的语言标记
          final lines = textContent.split('\n');
          if (lines.length > 1) {
            textContent = lines.sublist(1).join('\n');
          }
        }
      }

      // 如果内容以```结尾，移除它
      if (textContent.trim().endsWith('```')) {
        final lines = textContent.split('\n');
        if (lines.isNotEmpty) {
          final lastLine = lines.last.trim();
          if (lastLine == '```') {
            textContent = lines.sublist(0, lines.length - 1).join('\n');
          }
        }
      }

      // 使用 ValueKey 确保每个代码块都有唯一标识
      return EnhancedCodeBlock(
        key: ValueKey('code_${textContent.hashCode}'),
        code: textContent,
        language: language,
        textStyle: preferredStyle,
      );
    }

    // 处理内联代码
    if (element.tag == 'code') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 51),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          element.textContent,
          style: preferredStyle?.copyWith(
            fontFamily: 'monospace',
            fontSize: preferredStyle.fontSize,
          ),
        ),
      );
    }

    return null;
  }
}
