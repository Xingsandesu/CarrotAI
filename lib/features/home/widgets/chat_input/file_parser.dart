// 文件解析组件，用于处理上传的文件

import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 文件解析结果
class FileParseResult {
  final bool success;
  final String? content;
  final String? errorMessage;

  FileParseResult({required this.success, this.content, this.errorMessage});

  /// 创建成功结果
  factory FileParseResult.success(String content) {
    return FileParseResult(success: true, content: content);
  }

  /// 创建失败结果
  factory FileParseResult.error(String errorMessage) {
    return FileParseResult(success: false, errorMessage: errorMessage);
  }
}

/// 文件解析器
class FileParser {
  /// 支持的文件扩展名
  static const List<String> supportedExtensions = ['txt', 'md', 'markdown'];

  /// 检查文件是否支持
  static bool isFileSupported(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    return supportedExtensions.contains(extension);
  }

  /// 获取文件扩展名
  static String getFileExtension(File file) {
    return file.path.split('.').last.toLowerCase();
  }

  /// 解析文件内容
  static Future<FileParseResult> parseFile(
    File file,
    BuildContext context,
  ) async {
    // 保存国际化实例和错误消息，避免异步间隔中使用context
    final localizations = AppLocalizations.of(context);

    try {
      // 检查文件是否支持
      if (!isFileSupported(file)) {
        final extension = getFileExtension(file);
        // 手动构造错误消息，因为没有unsupportedFileFormat方法
        return FileParseResult.error("${localizations!.error}: $extension");
      }

      // 读取文件内容
      final content = await file.readAsString();

      // 如果内容为空，返回错误
      if (content.trim().isEmpty) {
        // 手动构造错误消息，因为没有fileIsEmpty字段
        return FileParseResult.error(
          "${localizations!.error}: ${localizations.noMessages}",
        );
      }

      // 返回成功结果
      return FileParseResult.success(content);
    } catch (e, stackTrace) {
      log(
        'Error parsing file: $e',
        error: e,
        stackTrace: stackTrace,
        name: 'FileParser',
      );
      // 手动构造错误消息，因为没有fileParsingError字段
      return FileParseResult.error(
        "${localizations!.error}: ${localizations.fileSelectionFailed}",
      );
    }
  }

  /// 格式化文件内容以附加到消息中
  static String formatFileContentForMessage(
    String fileName,
    String content,
    BuildContext context,
  ) {
    // 添加文件名和分隔线
    return '''
${AppLocalizations.of(context)!.uploadFile}: $fileName
---
$content
''';
  }
}
