// 性能跟踪示例
// 展示如何在应用中使用性能跟踪功能

import 'package:flutter/material.dart';
import 'package:carrot/core/config/app_config.dart';
import 'package:carrot/core/utils/__export.dart';

/// 性能跟踪示例
///
/// 这个类展示了如何在应用中使用性能跟踪功能
class PerformanceExample {
  /// 初始化性能跟踪
  ///
  /// 在应用启动时调用此方法来初始化性能跟踪
  static void initializePerformanceTracking() {
    // 只有在调试模式且性能跟踪开关打开时才执行
    if (AppConfig.shouldTrackPerformance) {
      debugPrint('初始化性能跟踪...');

      // 启用性能调试标志
      PerformanceUtils.enablePerformanceOverlay();

      // 启动帧时间监控
      PerformanceUtils.startFrameMonitoring();

      // 启动内存监控
      MemoryUtils.startMemoryMonitor(interval: const Duration(seconds: 60));

      debugPrint('性能跟踪已初始化');
    }
  }

  /// 停止性能跟踪
  ///
  /// 在应用关闭时调用此方法来停止性能跟踪
  static void stopPerformanceTracking() {
    // 停止帧时间监控
    PerformanceUtils.stopFrameMonitoring();

    // 停止内存监控
    MemoryUtils.stopMemoryMonitor();

    // 禁用性能调试标志
    PerformanceUtils.disablePerformanceOverlay();

    // 清理资源
    MemoryUtils.cleanupAll();

    if (AppConfig.shouldTrackPerformance) {
      debugPrint('性能跟踪已停止');
    }
  }

  /// 记录性能事件
  ///
  /// 在关键操作前后调用此方法来记录性能事件
  static void logPerformanceEvent(String eventName, Function() action) {
    if (!AppConfig.shouldTrackPerformance) {
      // 如果性能跟踪关闭，直接执行操作
      action();
      return;
    }

    debugPrint('开始性能事件: $eventName');
    final stopwatch = Stopwatch()..start();

    // 执行操作
    action();

    stopwatch.stop();
    debugPrint('结束性能事件: $eventName, 耗时: ${stopwatch.elapsedMilliseconds}ms');
  }

  /// 记录异步性能事件
  ///
  /// 在关键异步操作前后调用此方法来记录性能事件
  static Future<T> logAsyncPerformanceEvent<T>(
    String eventName,
    Future<T> Function() asyncAction,
  ) async {
    if (!AppConfig.shouldTrackPerformance) {
      // 如果性能跟踪关闭，直接执行操作
      return await asyncAction();
    }

    debugPrint('开始异步性能事件: $eventName');
    final stopwatch = Stopwatch()..start();

    try {
      // 执行异步操作
      final result = await asyncAction();

      stopwatch.stop();
      debugPrint(
        '结束异步性能事件: $eventName, 耗时: ${stopwatch.elapsedMilliseconds}ms',
      );

      return result;
    } catch (e) {
      stopwatch.stop();
      debugPrint(
        '异步性能事件出错: $eventName, 耗时: ${stopwatch.elapsedMilliseconds}ms, 错误: $e',
      );
      rethrow;
    }
  }
}
