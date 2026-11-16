import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'set.dart';
import 'tap.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SPLASH — Phase 1: verifikasi sidik jari (1.5s)
//            Phase 2: loading SixEyesX (logo + progress 1s)
// ─────────────────────────────────────────────────────────────────────────────
class SplashVideoPage extends StatefulWidget {
  final Widget nextPage;
  final String username;

  const SplashVideoPage({
    super.key,
    required this.nextPage,
    required this.username,
  });

  @override
  State<SplashVideoPage> createState() => _SplashVideoPageState();
}

class _SplashVideoPageState extends State<SplashVideoPage>
    with TickerProviderStateMixin {
  static const Color bgMain = Color(0xFF050508);
  static const Duration _holdDuration = Duration(milliseconds: 1500);
  static const Duration _loadDuration = Duration(milliseconds: 1000);

  /// false = fingerprint, true = loading
  bool _showLoading = false;
  bool _navigated = false;
  bool _holding = false;

  late final AnimationController _holdCtrl;
  late final AnimationController _progressCtrl;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _holdCtrl = AnimationController(
      vsync: this,
      duration: _holdDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _goToLoading();
        }
      });

    _progressCtrl = AnimationController(
      vsync: this,
      duration: _loadDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _goNext();
        }
      });
  }

  @override
  void dispose() {
    _holdCtrl.dispose();
    _progressCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onHoldStart() {
    if (_showLoading || _navigated) return;
    setState(() => _holding = true);
    HapticFeedback.selectionClick();
    _holdCtrl.forward(from: 0);
  }

  void _onHoldEnd() {
    if (_showLoading || _navigated) return;
    if (_holdCtrl.status != AnimationStatus.completed) {
      _holdCtrl.stop();
      _holdCtrl.value = 0;
      setState(() => _holding = false);
    }
  }

  void _goToLoading() {
    if (_showLoading || _navigated) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _showLoading = true;
      _holding = false;
    });
    // Mulai progress loading setelah frame pertama phase 2
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showLoading) _progressCtrl.forward(from: 0);
    });
  }

  void _goNext() {
    if (_navigated) return;
    _navigated = true;
    HapticFeedback.lightImpact();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => widget.nextPage,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlobalTouchWrapper(
      child: Scaffold(
        backgroundColor: bgMain,
        body: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _GridPainter(),
              size: Size.infinite,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.95,
                  colors: [
                    const Color(0xFF12121A).withOpacity(0.9),
                    bgMain,
                  ],
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _showLoading ? _buildLoadingPhase() : _buildFingerprintPhase(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Phase 1: Sidik jari ──────────────────────────────────────────────────
  Widget _buildFingerprintPhase() {
    final dateStr = _formatDate(DateTime.now());

    return SafeArea(
      key: const ValueKey('fp'),
      child: Column(
        children: [
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.asset(
                  'assets/images/banner.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF121218),
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_outlined,
                        color: Colors.white24, size: 40),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            dateStr,
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'ABOUT THIS APPLICATION',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              children: [
                Text(
                  'SixEyesX Project adalah platform premium yang dirancang untuk '
                  'pengalaman eksekusi modern, cepat, dan stabil.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 13.5,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Dengan antarmuka yang elegan, modul payload mutakhir, '
                  'sender pool global, serta proteksi berlapis, SixEyesX menjaga '
                  'privasi dan kenyamananmu di setiap sesi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 13.5,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Bangun untuk performa. Siap untuk skala. Dirancang untukmu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 13.5,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded,
                    size: 14, color: Colors.amber.withOpacity(0.9)),
                const SizedBox(width: 6),
                Text(
                  'Multi-Payload  ·  Fast  ·  Anti-Ampas',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Version 19.0.0  ·  SixEyesX',
            style: TextStyle(
              color: Colors.white.withOpacity(0.28),
              fontSize: 11,
              letterSpacing: 0.6,
            ),
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: _holdCtrl,
            builder: (context, _) {
              final p = _holdCtrl.value;
              final pct = (p * 100).round();
              return Column(
                children: [
                  GestureDetector(
                    onTapDown: (_) => _onHoldStart(),
                    onTapUp: (_) => _onHoldEnd(),
                    onTapCancel: _onHoldEnd,
                    child: SizedBox(
                      width: 92,
                      height: 92,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 92,
                            height: 92,
                            child: CircularProgressIndicator(
                              value: p > 0 ? p : null,
                              strokeWidth: 2.4,
                              backgroundColor: Colors.white.withOpacity(0.08),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _holding
                                    ? const Color(0xFFE53935)
                                    : Colors.white.withOpacity(0.35),
                              ),
                            ),
                          ),
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.04),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: Icon(
                              Icons.fingerprint_rounded,
                              size: 36,
                              color: _holding
                                  ? const Color(0xFFE53935)
                                  : Colors.white.withOpacity(0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tahan sidik jari untuk masuk',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _holding ? '$pct%  ·  Tahan 1.5 detik' : 'Tahan 1.5 detik',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  // ── Phase 2: Loading Hoxten ──────────────────────────────────────────────
  Widget _buildLoadingPhase() {
    return SafeArea(
      key: const ValueKey('load'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Spacer(flex: 3),
            SizedBox(
              width: 160,
              height: 160,
              child: Image.asset(
                'assets/images/logo.jpg',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF1A1A22),
                  alignment: Alignment.center,
                  child: const Text(
                    'SixEyesX Project',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'SixEyesX Project',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Text(
                'Powered by @xyzyanzzi',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const Spacer(flex: 2),
            AnimatedBuilder(
              animation: _progressCtrl,
              builder: (context, _) {
                final p = _progressCtrl.value.clamp(0.0, 1.0);
                final pct = (p * 100).round();
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) {
                        final active =
                            (p * 3).floor() % 3 == i || (p > 0.95 && i == 2);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                Colors.white.withOpacity(active ? 0.9 : 0.25),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 180,
                        height: 3,
                        child: LinearProgressIndicator(
                          value: p,
                          backgroundColor: Colors.white.withOpacity(0.12),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$pct%  loading bosqu',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;

    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final dot = Paint()..color = Colors.white.withOpacity(0.06);
    for (double x = step / 2; x < size.width; x += step * 2) {
      for (double y = step / 2; y < size.height; y += step * 2) {
        canvas.drawCircle(Offset(x, y), 1.2, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
