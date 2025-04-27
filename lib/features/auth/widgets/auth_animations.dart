import 'package:flutter/material.dart';

/// Auth screens animation utilities
class AuthAnimations {
  /// Creates a fade-in and slide-up animation for form elements
  static Widget fadeSlideIn({
    required Widget child,
    required int index,
    required bool animate,
    double offset = 30.0,
  }) {
    // Calculate delay based on index
    final int delayMs = 100 * index;
    final duration = Duration(milliseconds: 500 + delayMs);

    // 使用RepaintBoundary包装动画内容，防止重绘传播
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: animate ? 1.0 : 0.0),
        duration: duration,
        curve: Curves.easeOutQuart,
        // 使用child参数避免重建
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1.0 - value) * offset),
              child: child!,
            ),
          );
        },
        child: child, // 传入child参数避免重建
      ),
    );
  }

  /// Creates a scale animation for buttons
  static Widget scaleButton({
    required Widget child,
    required VoidCallback? onPressed,
  }) {
    // 使用RepaintBoundary包装动画内容，防止重绘传播
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1.0, end: onPressed == null ? 1.0 : 1.0),
        duration: const Duration(milliseconds: 150),
        builder: (context, value, child) {
          return Transform.scale(scale: value, child: child);
        },
        child: child,
      ),
    );
  }

  /// Creates a pulse animation for the verification code countdown
  static Widget pulseAnimation({required Widget child, required bool animate}) {
    // 使用RepaintBoundary包装动画内容，防止重绘传播
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1.0, end: animate ? 1.1 : 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Transform.scale(scale: value, child: child);
        },
        child: child,
      ),
    );
  }

  /// Creates a success checkmark animation
  static Widget successCheckmark({
    required bool show,
    double size = 100.0,
    Color color = Colors.green,
  }) {
    // 使用RepaintBoundary包装动画内容，防止重绘传播
    return RepaintBoundary(
      child: AnimatedOpacity(
        opacity: show ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 500),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          height: show ? size : 0,
          width: show ? size : 0,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          // 预先构建图标以避免重建
          child: Icon(Icons.check, color: Colors.white, size: size * 0.6),
        ),
      ),
    );
  }
}

/// Animated text field with enhanced styling
class AnimatedAuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool enabled;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  const AnimatedAuthTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.suffix,
    this.enabled = true,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffix: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 128),
          ), // 0.5 opacity
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 128,
        ), // 0.5 opacity
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      style: TextStyle(color: colorScheme.onSurface),
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      enabled: enabled,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}

/// Enhanced button for auth screens
class AuthButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final double width;
  final double height;
  final Color? backgroundColor;
  final bool useGradient;

  const AuthButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.width = double.infinity,
    this.height = 50,
    this.backgroundColor,
    this.useGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final buttonColor = backgroundColor ?? colorScheme.primary;

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 3,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient:
                useGradient
                    ? LinearGradient(
                      colors: [
                        buttonColor,
                        buttonColor.withValues(
                          alpha: (buttonColor.a * 0.8).toDouble(),
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                    : null,
            color: useGradient ? null : buttonColor,
          ),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.center,
            child:
                isLoading
                    ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.onPrimary,
                        ),
                      ),
                    )
                    : child,
          ),
        ),
      ),
    );
  }
}

/// Decorative wave background for auth screens
class WaveBackground extends StatelessWidget {
  final Color color;
  final double height;

  const WaveBackground({super.key, required this.color, this.height = 0.2});

  @override
  Widget build(BuildContext context) {
    // 使用RepaintBoundary包装波浪背景，防止重绘传播
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: RepaintBoundary(
        child: ClipPath(
          clipper: WaveClipper(),
          child: Container(
            height: MediaQuery.of(context).size.height * height,
            decoration: BoxDecoration(
              color: color,
              // 优化阴影渲染，减少模糊范围
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 26), // 0.1 opacity
                  blurRadius: 8, // 减小模糊半径
                  spreadRadius: 2, // 减小扩散半径
                  offset: const Offset(0, 2), // 添加偏移使阴影更自然
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wave clipper for decorative background
class WaveClipper extends CustomClipper<Path> {
  // 缓存路径对象以提高性能
  Path? _cachedPath;
  Size? _cachedSize;

  @override
  Path getClip(Size size) {
    // 如果尺寸相同，返回缓存的路径
    if (_cachedPath != null && _cachedSize == size) {
      return _cachedPath!;
    }

    final path = Path();
    path.lineTo(0, size.height * 0.8);

    // 使用更简单的贝塞尔曲线减少计算量
    final firstControlPoint = Offset(size.width * 0.25, size.height);
    final firstEndPoint = Offset(size.width * 0.5, size.height * 0.8);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    final secondControlPoint = Offset(size.width * 0.75, size.height * 0.6);
    final secondEndPoint = Offset(size.width, size.height * 0.8);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();

    // 缓存路径和尺寸
    _cachedPath = path;
    _cachedSize = size;

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    // 始终返回false，因为我们的波浪形状不会改变
    // 这样可以避免不必要的重新剪裁和重绘
    return false;
  }
}

/// Card container for auth forms
class AuthCard extends StatelessWidget {
  final Widget child;
  final double width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double elevation;

  const AuthCard({
    super.key,
    required this.child,
    this.width = double.infinity,
    this.height,
    this.padding = const EdgeInsets.all(24.0),
    this.elevation = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: elevation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: colorScheme.surface.withValues(alpha: 230), // 0.9 opacity
      child: Container(
        width: width,
        height: height,
        padding: padding,
        child: child,
      ),
    );
  }
}
