// 内存管理工具类
// 提供内存优化和资源管理的工具方法

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:carrot/core/config/app_config.dart';

/// 内存管理工具类
class MemoryUtils {
  /// 图片缓存实例
  static final Map<String, ui.Image> _imageCache = {};

  /// 定时器缓存，用于跟踪和清理
  static final Map<String, Timer> _timerCache = {};

  /// 流订阅缓存，用于跟踪和清理
  static final Map<String, StreamSubscription> _streamCache = {};

  /// 清理所有缓存的图片
  static void clearImageCache() {
    _imageCache.clear();
  }

  /// 缓存图片
  static void cacheImage(String key, ui.Image image) {
    _imageCache[key] = image;
  }

  /// 获取缓存的图片
  static ui.Image? getCachedImage(String key) {
    return _imageCache[key];
  }

  /// 移除缓存的图片
  static void removeCachedImage(String key) {
    _imageCache.remove(key);
  }

  /// 注册定时器以便后续清理
  static void registerTimer(String key, Timer timer) {
    // 如果已存在同名定时器，先取消它
    cancelTimer(key);
    _timerCache[key] = timer;
  }

  /// 取消并移除定时器
  static void cancelTimer(String key) {
    final timer = _timerCache[key];
    if (timer != null) {
      timer.cancel();
      _timerCache.remove(key);
    }
  }

  /// 取消所有定时器
  static void cancelAllTimers() {
    for (final timer in _timerCache.values) {
      timer.cancel();
    }
    _timerCache.clear();
  }

  /// 注册流订阅以便后续清理
  static void registerStreamSubscription(
    String key,
    StreamSubscription subscription,
  ) {
    // 如果已存在同名订阅，先取消它
    cancelStreamSubscription(key);
    _streamCache[key] = subscription;
  }

  /// 取消并移除流订阅
  static void cancelStreamSubscription(String key) {
    final subscription = _streamCache[key];
    if (subscription != null) {
      subscription.cancel();
      _streamCache.remove(key);
    }
  }

  /// 取消所有流订阅
  static void cancelAllStreamSubscriptions() {
    for (final subscription in _streamCache.values) {
      subscription.cancel();
    }
    _streamCache.clear();
  }

  /// 清理所有资源
  static void cleanupAll() {
    clearImageCache();
    cancelAllTimers();
    cancelAllStreamSubscriptions();
  }

  /// 强制垃圾回收（仅在调试模式且性能跟踪开关打开时有效）
  static void forceGC() {
    if (AppConfig.shouldTrackPerformance) {
      debugPrint('强制垃圾回收...');
      // 这只是一个提示，实际GC由Dart VM决定何时执行
      // 但这可以帮助触发更频繁的GC
      Future.microtask(() {
        // 创建并丢弃大对象以触发GC
        // ignore: unused_local_variable
        final temp = List.filled(1000000, 0);
        // 不需要显式设置为空，变量会自动离开作用域
      });
    }
  }

  /// 打印当前内存使用情况（仅在调试模式且性能跟踪开关打开时有效）
  static void printMemoryUsage() {
    if (AppConfig.shouldTrackPerformance) {
      debugPrint('当前缓存的图片数量: ${_imageCache.length}');
      debugPrint('当前活跃的定时器数量: ${_timerCache.length}');
      debugPrint('当前活跃的流订阅数量: ${_streamCache.values.length}');
    }
  }

  /// 开始定期监控内存使用情况
  static Timer? _monitorTimer;
  static void startMemoryMonitor({
    Duration interval = const Duration(seconds: 30),
  }) {
    if (AppConfig.shouldTrackPerformance) {
      stopMemoryMonitor(); // 先停止现有的监控
      _monitorTimer = Timer.periodic(interval, (_) {
        printMemoryUsage();
      });
      debugPrint('内存监控已启动，间隔: ${interval.inSeconds}秒');
    }
  }

  /// 停止内存监控
  static void stopMemoryMonitor() {
    // 取消定时器不需要性能跟踪开关，这是清理操作
    _monitorTimer?.cancel();
    _monitorTimer = null;
    if (AppConfig.shouldTrackPerformance) {
      debugPrint('内存监控已停止');
    }
  }
}
