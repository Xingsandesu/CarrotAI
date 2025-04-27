// 性能优化工具类
// 提供常用的性能优化方法和工具

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:carrot/core/config/app_config.dart';

/// 性能优化工具类
class PerformanceUtils {
  /// 启用性能调试标志
  static void enablePerformanceOverlay() {
    // 只在调试模式且性能跟踪开关打开时执行
    if (AppConfig.shouldTrackPerformance) {
      debugPrintRebuildDirtyWidgets = true;
      debugPrintLayouts = true;
      // 使用正确的标志名称
      debugPrint('===== FRAME START ====='); // 替代debugPrintBeginFrameBanner
      debugPrint('===== FRAME END ====='); // 替代debugPrintEndFrameBanner
      debugProfileBuildsEnabled = true;
      debugProfileLayoutsEnabled = true;
      debugProfilePaintsEnabled = true;
      // 添加其他有用的性能标志
      debugPaintLayerBordersEnabled = true; // 显示层边界
      debugRepaintRainbowEnabled = true; // 显示重绘区域
    }
  }

  /// 禁用性能调试标志
  static void disablePerformanceOverlay() {
    // 只在调试模式下执行，正式版本中这些代码不会影响性能
    if (kDebugMode) {
      debugPrintRebuildDirtyWidgets = false;
      debugPrintLayouts = false;
      // 不需要禁用不存在的标志
      // debugPrintBeginFrameBanner = false;
      // debugPrintEndFrameBanner = false;
      debugProfileBuildsEnabled = false;
      debugProfileLayoutsEnabled = false;
      debugProfilePaintsEnabled = false;
      // 禁用其他标志
      debugPaintLayerBordersEnabled = false;
      debugRepaintRainbowEnabled = false;
    }
  }

  /// 使用RepaintBoundary包装小部件以防止重绘传播
  static Widget wrapWithRepaintBoundary(Widget child) {
    return RepaintBoundary(child: child);
  }

  /// 使用缓存键包装ListView以优化滚动性能
  static Widget optimizedListView({
    required String cacheKey,
    required IndexedWidgetBuilder itemBuilder,
    required int itemCount,
    ScrollController? controller,
    bool reverse = false,
    EdgeInsetsGeometry? padding,
    ScrollPhysics? physics,
    bool shrinkWrap = false,
    double? cacheExtent,
  }) {
    return ListView.builder(
      key: PageStorageKey(cacheKey),
      controller: controller,
      reverse: reverse,
      padding: padding,
      physics:
          physics ??
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      shrinkWrap: shrinkWrap,
      cacheExtent: cacheExtent ?? 500, // 默认缓存500像素
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return RepaintBoundary(child: itemBuilder(context, index));
      },
    );
  }

  /// 使用缓存键包装GridView以优化滚动性能
  static Widget optimizedGridView({
    required String cacheKey,
    required IndexedWidgetBuilder itemBuilder,
    required int itemCount,
    required SliverGridDelegate gridDelegate,
    ScrollController? controller,
    EdgeInsetsGeometry? padding,
    ScrollPhysics? physics,
    bool shrinkWrap = false,
    double? cacheExtent,
  }) {
    return GridView.builder(
      key: PageStorageKey(cacheKey),
      controller: controller,
      padding: padding,
      physics:
          physics ??
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      shrinkWrap: shrinkWrap,
      cacheExtent: cacheExtent ?? 500, // 默认缓存500像素
      gridDelegate: gridDelegate,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return RepaintBoundary(child: itemBuilder(context, index));
      },
    );
  }

  /// 优化动画构建器，避免每帧重建子部件
  static Widget optimizedAnimationBuilder<T>({
    required Animation<T> animation,
    required Widget Function(BuildContext context, T value, Widget? child)
    builder,
    required Widget child,
  }) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) => builder(context, animation.value, child),
        child: child,
      ),
    );
  }

  /// 延迟加载小部件，用于优化初始渲染性能
  static Widget lazyWidget({
    required WidgetBuilder builder,
    Duration delay = const Duration(milliseconds: 200),
  }) {
    return _LazyWidget(builder: builder, delay: delay);
  }

  /// 帧时间监控
  // 这些变量只在调试模式下使用
  static bool _isMonitoringFrames = false;
  static int _frameCount = 0;
  static int _slowFrameCount = 0;
  static Stopwatch? _frameStopwatch;
  static Duration _totalFrameTime = Duration.zero;
  static Duration _maxFrameTime = Duration.zero;

  /// 开始监控帧时间
  static void startFrameMonitoring() {
    // 只在调试模式且性能跟踪开关打开时执行
    if (AppConfig.shouldTrackPerformance && !_isMonitoringFrames) {
      _isMonitoringFrames = true;
      _frameCount = 0;
      _slowFrameCount = 0;
      _totalFrameTime = Duration.zero;
      _maxFrameTime = Duration.zero;
      _frameStopwatch = Stopwatch();

      // 添加帧回调
      WidgetsBinding.instance.addPostFrameCallback(_onFrameEnd);
      debugPrint('开始监控帧时间');
    }
  }

  /// 帧结束回调
  static void _onFrameEnd(Duration timeStamp) {
    // 只在调试模式且性能跟踪开关打开时执行
    if (!AppConfig.shouldTrackPerformance ||
        !_isMonitoringFrames ||
        _frameStopwatch == null) {
      return;
    }

    final frameDuration = _frameStopwatch!.elapsed;
    _frameStopwatch!.reset();

    _frameCount++;
    _totalFrameTime += frameDuration;

    // 更新最大帧时间
    if (frameDuration > _maxFrameTime) {
      _maxFrameTime = frameDuration;
    }

    // 检测慢帧 (> 16ms 意味着低于 60fps)
    if (frameDuration > const Duration(milliseconds: 16)) {
      _slowFrameCount++;
      debugPrint('检测到慢帧: ${frameDuration.inMilliseconds}ms');
    }

    // 每 60 帧打印一次统计信息
    if (_frameCount % 60 == 0) {
      final avgFrameTime = _totalFrameTime.inMicroseconds / _frameCount;
      final fps = 1000000 / avgFrameTime;
      final slowFramePercentage = (_slowFrameCount / _frameCount) * 100;

      debugPrint('===== 帧统计 =====');
      debugPrint('平均帧时间: ${avgFrameTime / 1000}ms');
      debugPrint('估计 FPS: ${fps.toStringAsFixed(1)}');
      debugPrint('最大帧时间: ${_maxFrameTime.inMilliseconds}ms');
      debugPrint('慢帧百分比: ${slowFramePercentage.toStringAsFixed(1)}%');
    }

    // 继续监控下一帧
    if (_isMonitoringFrames) {
      _frameStopwatch!.start();
      WidgetsBinding.instance.addPostFrameCallback(_onFrameEnd);
    }
  }

  /// 停止监控帧时间
  static void stopFrameMonitoring() {
    // 只在调试模式且性能跟踪开关打开时执行
    if (AppConfig.shouldTrackPerformance && _isMonitoringFrames) {
      _isMonitoringFrames = false;
      _frameStopwatch?.stop();

      // 打印最终统计信息
      if (_frameCount > 0) {
        final avgFrameTime = _totalFrameTime.inMicroseconds / _frameCount;
        final fps = 1000000 / avgFrameTime;
        final slowFramePercentage = (_slowFrameCount / _frameCount) * 100;

        debugPrint('===== 帧监控统计汇总 =====');
        debugPrint('总帧数: $_frameCount');
        debugPrint('平均帧时间: ${avgFrameTime / 1000}ms');
        debugPrint('平均 FPS: ${fps.toStringAsFixed(1)}');
        debugPrint('最大帧时间: ${_maxFrameTime.inMilliseconds}ms');
        debugPrint('慢帧数: $_slowFrameCount');
        debugPrint('慢帧百分比: ${slowFramePercentage.toStringAsFixed(1)}%');
      }

      debugPrint('帧时间监控已停止');
    }
  }
}

/// 延迟加载小部件
class _LazyWidget extends StatefulWidget {
  final WidgetBuilder builder;
  final Duration delay;

  const _LazyWidget({required this.builder, required this.delay});

  @override
  State<_LazyWidget> createState() => _LazyWidgetState();
}

class _LazyWidgetState extends State<_LazyWidget> {
  bool _isLoaded = false;
  Widget? _child;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) {
        setState(() {
          _isLoaded = true;
          _child = widget.builder(context);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const SizedBox.shrink();
    }
    return _child!;
  }
}
