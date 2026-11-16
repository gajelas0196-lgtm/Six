// intro_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'landing_page.dart';

// ── Design Tokens ──────────────────────────────────────────
class _C {
  static const blue = Color(0xFF4FA8FF);
  static const blueDeep = Color(0xFF1E4FA8);
  static const white = Color(0xFFFFFFFF);
  static const greyText = Color(0xFFB9C2CE);
  static const dotInactive = Color(0xFF4A5568);
  static const overlayDark = Color(0xCC05070C);
}

class _T {
  static const font = 'Rajdhani';

  static TextStyle jp(double size) => TextStyle(
        fontFamily: font,
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: _C.greyText,
        letterSpacing: 2,
      );

  static TextStyle title(double size) => TextStyle(
        fontFamily: font,
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: _C.white,
        letterSpacing: 1.5,
      );

  static TextStyle subtitle(double size) => TextStyle(
        fontFamily: font,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: _C.blue,
        letterSpacing: 2,
      );

  static TextStyle body(double size) => TextStyle(
        fontFamily: font,
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: _C.greyText,
        height: 1.5,
      );

  static TextStyle button(double size) => TextStyle(
        fontFamily: font,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: _C.white,
        letterSpacing: 1.2,
      );
}

// ── Slide data model ───────────────────────────────────────
class _Slide {
  final IconData icon;
  final String tag;
  final String jpLabel;
  final String titleId;
  final String subtitle;
  final String descLine1;
  final String descLine2;
  final String descLine3;

  const _Slide({
    required this.icon,
    required this.tag,
    required this.jpLabel,
    required this.titleId,
    required this.subtitle,
    required this.descLine1,
    required this.descLine2,
    required this.descLine3,
  });
}

const List<_Slide> _kSlides = [
  _Slide(
    icon: Icons.star_rounded,
    tag: 'STYLE',
    jpLabel: 'スタイルを持って',
    titleId: 'BERGAYA',
    subtitle: 'STYLE WITH ATTITUDE',
    descLine1: 'Tampil dengan gaya khasmu',
    descLine2: 'Jadilah dirimu sendiri',
    descLine3: 'Tanpa batasan!',
  ),
  _Slide(
    icon: Icons.bolt_rounded,
    tag: 'POWER',
    jpLabel: 'パワーを解き放て',
    titleId: 'BERTENAGA',
    subtitle: 'POWER WITHOUT LIMITS',
    descLine1: 'Rasakan performa maksimal',
    descLine2: 'Setiap detik penuh energi',
    descLine3: 'Tanpa kompromi!',
  ),
  _Slide(
    icon: Icons.shield_rounded,
    tag: 'SECURE',
    jpLabel: '安全を守れ',
    titleId: 'TERLINDUNGI',
    subtitle: 'SAFETY FIRST ALWAYS',
    descLine1: 'Keamanan tingkat tinggi',
    descLine2: 'Setiap langkahmu terjaga',
    descLine3: 'Selalu tenang!',
  ),
  _Slide(
    icon: Icons.flash_on_rounded,
    tag: 'SPEED',
    jpLabel: 'スピードを感じろ',
    titleId: 'SECEPAT KILAT',
    subtitle: 'FAST AND FURIOUS',
    descLine1: 'Respons instan setiap saat',
    descLine2: 'Tanpa jeda tanpa lag',
    descLine3: 'Selalu terdepan!',
  ),
];

// ── Intro Page ─────────────────────────────────────────────
class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage>
    with TickerProviderStateMixin {
  late final PageController _pageCtrl;
  late final AnimationController _iconPulseCtrl;
  late VideoPlayerController _videoCtrl;

  int _currentPage = 0;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _iconPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _videoCtrl = VideoPlayerController.asset('assets/videos/bg.mp4')
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _videoReady = true);
        _videoCtrl.play();
      });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _iconPulseCtrl.dispose();
    _videoCtrl.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _kSlides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    } else {
      _goToLanding();
    }
  }

  void _skip() => _goToLanding();

  void _goToLanding() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, anim, __) => const LandingPage(),
        transitionsBuilder: (_, anim, __, child) {
          final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
          return FadeTransition(opacity: fade, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Video background ──────────────────────────────
          if (_videoReady)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoCtrl.value.size.width,
                  height: _videoCtrl.value.size.height,
                  child: VideoPlayer(_videoCtrl),
                ),
              ),
            )
          else
            Container(color: Colors.black),

          // ── Dark gradient overlay for readability ─────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xB3000000),
                  Color(0x33000000),
                  Color(0x33000000),
                  Color(0xE6000000),
                ],
                stops: [0.0, 0.25, 0.6, 1.0],
              ),
            ),
          ),

          // ── Foreground content ─────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Skip button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: _skip,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          child: Text(
                            'LEWATI',
                            style: _T.button(13).copyWith(
                                  color: Colors.white70,
                                  letterSpacing: 1,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Swipeable slides
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: _kSlides.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, index) {
                      return _buildSlide(_kSlides[index], size);
                    },
                  ),
                ),

                // Page indicator dots
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_kSlides.length, (i) {
                      final active = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active ? _C.blue : _C.dotInactive,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),
                ),

                // Bottom "LANJUT" button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: GestureDetector(
                    onTap: _onNext,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            _currentPage == _kSlides.length - 1
                                ? 'MULAI'
                                : 'LANJUT',
                            style: _T.button(16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Home indicator bar (visual only, like screenshot)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  width: 120,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Single slide content ───────────────────────────────────
  Widget _buildSlide(_Slide slide, Size size) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: size.height * 0.55),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing icon ring
            AnimatedBuilder(
              animation: _iconPulseCtrl,
              builder: (context, child) {
                final glow = 0.35 + (_iconPulseCtrl.value * 0.35);
                return Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _C.blue, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: _C.blue.withOpacity(glow),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _C.blue.withOpacity(0.9),
                            _C.blueDeep.withOpacity(0.6),
                          ],
                        ),
                      ),
                      child: Icon(slide.icon, color: Colors.white, size: 30),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),

            // Tag pill (e.g. "STYLE")
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _C.blue.withOpacity(0.6)),
                color: _C.blue.withOpacity(0.08),
              ),
              child: Text(
                slide.tag,
                style: _T.subtitle(14).copyWith(letterSpacing: 3),
              ),
            ),
            const SizedBox(height: 18),

            // Japanese label
            Text(slide.jpLabel, style: _T.jp(16)),
            const SizedBox(height: 6),

            // Big Indonesian title
            Text(
              slide.titleId,
              style: _T.title(38),
            ),
            const SizedBox(height: 6),

            // English subtitle
            Text(slide.subtitle, style: _T.subtitle(15)),
            const SizedBox(height: 18),

            // Thin divider
            Container(
              width: 40,
              height: 2,
              color: _C.blue.withOpacity(0.5),
            ),
            const SizedBox(height: 18),

            // Description lines
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  Text(slide.descLine1,
                      textAlign: TextAlign.center, style: _T.body(15)),
                  const SizedBox(height: 4),
                  Text(slide.descLine2,
                      textAlign: TextAlign.center, style: _T.body(15)),
                  const SizedBox(height: 4),
                  Text(slide.descLine3,
                      textAlign: TextAlign.center, style: _T.body(15)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Page counter "1/4"
            Text(
              '${_kSlides.indexOf(slide) + 1}/${_kSlides.length}',
              style: _T.body(13).copyWith(color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}