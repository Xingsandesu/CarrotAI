// 动画优化工具类
// 提供优化的动画组件和工具方法

import 'package:flutter/material.dart';

/// 动画优化工具类
class AnimationUtils {
  /// 创建优化的淡入淡出动画
  static Widget optimizedFade({
    required Widget child,
    required bool visible,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) {
    return RepaintBoundary(
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: duration,
        curve: curve,
        child: child,
      ),
    );
  }

  /// 创建优化的缩放动画
  static Widget optimizedScale({
    required Widget child,
    required bool visible,
    double begin = 0.8,
    double end = 1.0,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) {
    return RepaintBoundary(
      child: AnimatedScale(
        scale: visible ? end : begin,
        duration: duration,
        curve: curve,
        child: child,
      ),
    );
  }

  /// 创建优化的滑动动画
  static Widget optimizedSlide({
    required Widget child,
    required bool visible,
    Offset begin = const Offset(0.0, 0.2),
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) {
    return RepaintBoundary(
      child: AnimatedSlide(
        offset: visible ? Offset.zero : begin,
        duration: duration,
        curve: curve,
        child: child,
      ),
    );
  }

  /// 创建优化的组合动画（淡入+缩放+滑动）
  static Widget optimizedEntrance({
    required Widget child,
    required bool visible,
    Duration duration = const Duration(milliseconds: 400),
    Curve curve = Curves.easeOutQuart,
    Offset slideBegin = const Offset(0.0, 0.1),
    double scaleBegin = 0.95,
  }) {
    return RepaintBoundary(
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: duration,
        curve: curve,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : slideBegin,
          duration: duration,
          curve: curve,
          child: AnimatedScale(
            scale: visible ? 1.0 : scaleBegin,
            duration: duration,
            curve: curve,
            child: child,
          ),
        ),
      ),
    );
  }

  /// 创建优化的交错动画
  static Widget staggeredItem({
    required Widget child,
    required bool animate,
    required int index,
    Duration baseDuration = const Duration(milliseconds: 300),
    Duration staggerDuration = const Duration(milliseconds: 50),
    Curve curve = Curves.easeOutQuart,
    double slideOffset = 20.0,
  }) {
    // 计算延迟
    final delay = Duration(
      milliseconds: index * staggerDuration.inMilliseconds,
    );
    final totalDuration = Duration(
      milliseconds: baseDuration.inMilliseconds + delay.inMilliseconds,
    );

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: animate ? 1.0 : 0.0),
        duration: totalDuration,
        curve: curve,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1.0 - value) * slideOffset),
              child: child,
            ),
          );
        },
        child: child,
      ),
    );
  }

  /// 创建脉冲动画
  static Widget pulse({
    required Widget child,
    required bool animate,
    Duration duration = const Duration(milliseconds: 600),
    Curve curve = Curves.easeInOut,
    double minScale = 1.0,
    double maxScale = 1.05,
  }) {
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: minScale,
          end: animate ? maxScale : minScale,
        ),
        duration: duration,
        curve: curve,
        builder: (context, value, child) {
          return Transform.scale(scale: value, child: child);
        },
        child: child,
      ),
    );
  }

  /// 创建闪烁动画
  static Widget blink({
    required Widget child,
    required bool animate,
    Duration duration = const Duration(milliseconds: 800),
    double minOpacity = 0.6,
    double maxOpacity = 1.0,
  }) {
    if (!animate) {
      return child;
    }

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: minOpacity, end: maxOpacity),
        duration: duration,
        curve: Curves.easeInOut,
        onEnd: () {
          // 动画结束时反转动画
          // 注意：这里不能直接修改状态，因为TweenAnimationBuilder是无状态的
          // 需要在外部控制animate状态
        },
        builder: (context, value, child) {
          return Opacity(opacity: value, child: child);
        },
        child: child,
      ),
    );
  }
}
