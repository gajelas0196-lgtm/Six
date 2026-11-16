// app_theme.dart
import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
///  SixEyesX — Unified Design System
/// ═══════════════════════════════════════════════════════════════
class AppColors {
  // Background layers
  static const Color bgDeep = Color(0xFF05060A);
  static const Color bgMain = Color(0xFF0A0B12);
  static const Color bgSurface = Color(0xFF12141C);
  static const Color bgCard = Color(0xFF161822);
  static const Color bgElevated = Color(0xFF1C1F2B);

  // Text
  static const Color textMain = Color(0xFFF2F3F7);
  static const Color textSub = Color(0xFF9CA0B0);
  static const Color textMuted = Color(0xFF5A5F70);

  // Accents — Merah neon theme
  static const Color accent = Color(0xFFFF3B3B);
  static const Color accentSoft = Color(0xFFFF6B6B);
  static const Color accentGlow = Color(0xFFFF1744);
  static const Color accentDeep = Color(0xFFB71C1C);

  // Status
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFB74D);
  static const Color danger = Color(0xFFFF5252);
  static const Color info = Color(0xFF40C4FF);

  // Borders
  static const Color border = Color(0xFF23263A);
  static const Color borderSoft = Color(0xFF1A1D2A);
  static const Color borderGlow = Color(0x33FF3B3B);
}

class AppGradients {
  static const LinearGradient accent = LinearGradient(
    colors: [Color(0xFFFF3B3B), Color(0xFFB71C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient card = LinearGradient(
    colors: [Color(0xFF1A1D2A), Color(0xFF12141C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glass = LinearGradient(
    colors: [Color(0x1AFFFFFF), Color(0x08FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient redGlow = LinearGradient(
    colors: [Color(0x33FF3B3B), Color(0x00FF3B3B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppShadows {
  static List<BoxShadow> glow(Color c,
          {double blur = 20, double opacity = 0.35}) =>
      [
        BoxShadow(
          color: c.withOpacity(opacity),
          blurRadius: blur,
          spreadRadius: 0,
          offset: const Offset(0, 6),
        ),
      ];

  static const List<BoxShadow> softCard = [
    BoxShadow(color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> hardNeo = [
    BoxShadow(color: Color(0xFF000000), blurRadius: 0, offset: Offset(3, 3)),
  ];
}

class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;
}

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgMain,
        primaryColor: AppColors.accent,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.accentSoft,
          surface: AppColors.bgSurface,
          error: AppColors.danger,
        ),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.bgElevated,
          contentTextStyle: const TextStyle(color: AppColors.textMain),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      );
}

/// ═══════════════════════════════════════════════════════════════
///  Reusable Widgets
/// ═══════════════════════════════════════════════════════════════

/// Grid background global (subtle dot pattern + gradient)
class GridBackground extends StatelessWidget {
  final Widget child;
  const GridBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.4,
          colors: [Color(0xFF141824), Color(0xFF05060A)],
        ),
      ),
      child: CustomPaint(
        painter: _DotPainter(),
        child: child,
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x0DFFFFFF);
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Glass card wrapper
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? borderColor;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = AppRadius.lg,
    this.borderColor,
    this.gradient,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient ?? AppGradients.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? AppColors.border,
          width: 1,
        ),
        boxShadow: shadows ?? AppShadows.softCard,
      ),
      child: child,
    );
  }
}

/// Pressable scale wrapper (dipakai berulang)
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleTo;
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scaleTo = 0.95,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  double _scale = 1.0;
  void _set(bool p) {
    if (!mounted) return;
    setState(() => _scale = p ? widget.scaleTo : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}