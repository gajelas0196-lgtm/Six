import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'srv.dart';

class InfoPage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;
  final String expiredDate;

  const InfoPage({
    super.key,
    required this.sessionKey,
    this.username = '',
    this.role = '',
    this.expiredDate = '',
  });

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> with TickerProviderStateMixin {
  bool isLoading = true;

  bool isApiOnline = false;
  int apiPingMs = 0;
  Color apiStatusColor = const Color(0xFFB0A8C0);
  String apiStatusText = "Checking...";
  Timer? _pingTimer;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  VideoPlayerController? _videoController;
  bool _videoReady = false;

  // ─── TEMA: Hitam Ungu + Grid Putih ─────────────────────────────────────
  static const Color bgMain     = Color(0xFF0A0A0F); // hitam agak ungu
  static const Color bgCard     = Color(0xFF14141A); // card gelap ungu
  static const Color bgSurface  = Color(0xFF1A1A22); // surface ungu gelap
  static const Color accentBlue = Color(0xFFFF5252); // ocean purple terang
  static const Color accentMid  = Color(0xFFC62828); // ocean purple medium
  static const Color accentLight= Color(0xFFFF8A80); // ocean purple soft
  static const Color textMain   = Color(0xFFEDE7F6); // teks putih keunguan
  static const Color textSub    = Color(0xFFB0A8C0); // teks secondary
  static const Color gridColor  = Color(0x22FFFFFF); // garis grid putih soft

  // ─── FITUR ─────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> featuresList = [
    {
      "title": "WhatsApp Crash",
      "icon": Icons.bug_report_rounded,
      "color": const Color(0xFFC62828),
      "desc":
          "Kemampuan mengirimkan payload secara masif ke target Private (Nomor) maupun Global (Grup) dengan hit rate tinggi dan efisiensi waktu.",
    },
    {
      "title": "Bug Sender",
      "icon": Icons.devices_rounded,
      "color": const Color(0xFFFF5252),
      "desc":
          "Pairing & konfigurasi perangkat sender untuk manajemen sesi pengiriman payload yang lebih terstruktur dan efisien.",
    },
    {
      "title": "Riwayat Aktivitas",
      "icon": Icons.history_rounded,
      "color": const Color(0xFFC62828),
      "desc":
          "Rekam dan pantau seluruh histori aktivitas akun kamu secara real-time, lengkap dengan log pengiriman dan status operasi.",
    },
    {
      "title": "Profile & Akun",
      "icon": Icons.person_rounded,
      "color": const Color(0xFFFF5252),
      "desc":
          "Kelola data profil, ubah password, dan pantau status akun serta masa aktif langganan kamu dengan mudah.",
    },
    {
      "title": "Global Chat",
      "icon": Icons.groups_2_rounded,
      "color": const Color(0xFF5E35B1),
      "desc":
          "Ruang komunitas eksklusif untuk berdiskusi, berbagi pengalaman, dan berinteraksi langsung dengan seluruh pengguna SixEyesX Project.",
    },
  ];

  // ─── KEBIJAKAN ──────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> rulesList = [
    {
      "title": "NO ACCOUNT BARTERING",
      "icon": Icons.swap_horizontal_circle_outlined,
      "desc":
          "Akun eksklusif SixEyesX tidak boleh ditukar dengan barang, jasa, atau akun lain dalam bentuk apa pun. Pelanggaran log akan terpantau.",
    },
    {
      "title": "STRICTLY PERSONAL USE",
      "icon": Icons.person_off_outlined,
      "desc":
          "Setiap akun terenkripsi untuk satu pengguna dan hanya boleh diakses oleh pemilik perangkat yang mendaftar (terikat Device ID).",
    },
    {
      "title": "RESELLING PROHIBITED",
      "icon": Icons.money_off_csred_outlined,
      "desc":
          "Member reguler dilarang memperjualbelikan akun. Akses penjualan eksklusif milik role berwenang (Partner, Owner, atau Reseller).",
    },
    {
      "title": "ILLEGAL DURATION SALES",
      "icon": Icons.timer_off_outlined,
      "desc":
          "Sangat dilarang membagi atau menjual akses eceran (harian, mingguan, trial) yang mengelabui skema periode resmi.",
    },
    {
      "title": "PRICE DUMPING BAN",
      "icon": Icons.trending_down_rounded,
      "desc":
          "Dilarang keras merusak standar harga pasar (banting harga) di bawah kesepakatan jaminan keamanan platform kami.",
    },
  ];

  // ───────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));
    _fetchServerInfo();
    _startApiPingLoop();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final c = VideoPlayerController.asset('assets/videos/banner.mp4');
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.setLooping(true);
      await c.setVolume(0);
      await c.seekTo(Duration.zero);
      await c.play();
      setState(() {
        _videoController = c;
        _videoReady = true;
      });
    } catch (e) {
      debugPrint('info video: $e');
    }
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _glowController.dispose();
    try {
      _videoController?.pause();
    } catch (_) {}
    _videoController?.dispose();
    _videoController = null;
    super.dispose();
  }

  Future<void> _fetchServerInfo() async {
    try {
      await http.get(Uri.parse(
          '${Srv.baseUrl}/getServerInfo?key=${widget.sessionKey}'));
      if (mounted) setState(() => isLoading = false);
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _startApiPingLoop() {
    _checkApiPing();
    _pingTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _checkApiPing());
  }

  Future<void> _checkApiPing() async {
    final start = DateTime.now();
    try {
      final res = await http
          .get(Uri.parse(
              '${Srv.baseUrl}/ping?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 3));
      final duration = DateTime.now().difference(start).inMilliseconds;
      if (res.statusCode == 200 && mounted) {
        setState(() {
          isApiOnline = true;
          apiPingMs   = duration;
          if (duration < 200) {
            apiStatusColor = const Color(0xFF00E676);
          } else if (duration < 500) {
            apiStatusColor = const Color(0xFFFFD54F);
          } else {
            apiStatusColor = const Color(0xFFFF8A65);
          }
          apiStatusText = "Sys.Online :: ${duration}ms";
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          isApiOnline    = false;
          apiPingMs      = 0;
          apiStatusColor = const Color(0xFFD32F2F);
          apiStatusText  = "Sys.Offline :: DEST";
        });
      }
    }
  }

  // ─── BANNER VIDEO + info user (gaya Mauldev) ───────────────────────────
  Widget _buildBanner() {
    final uname = widget.username.isEmpty ? 'User' : widget.username;
    final role = widget.role.isEmpty ? '-' : widget.role;
    final exp = widget.expiredDate.isEmpty ? '-' : widget.expiredDate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video background
              if (_videoReady && _videoController != null)
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                )
              else
                Container(color: const Color(0xFF0A0A0F)),
              // Soft dark gradient agar teks terbaca
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.55),
                    ],
                  ),
                ),
              ),
              // Info user di tengah (gaya Mauldev)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.45),
                        border: Border.all(
                          color: const Color(0xFFFF5252).withOpacity(0.85),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5252).withOpacity(0.35),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Color(0xFFFF5252),
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      uname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Orbitron',
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.25)),
                          ),
                          child: Text(
                            role,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC62828).withOpacity(0.75),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFFF5252).withOpacity(0.7),
                            ),
                          ),
                          child: Text(
                            'Exp:$exp',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── STATUS HEADER ─────────────────────────────────────────────────────
  Widget _buildStatusHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4)),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (_, __) => Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: apiStatusColor,
                boxShadow: [
                  BoxShadow(
                    color: apiStatusColor.withOpacity(_glowAnimation.value * 0.6),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              apiStatusText.toUpperCase(),
              style: TextStyle(
                color: apiStatusColor,
                fontFamily: 'ShareTechMono',
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Icon(Icons.memory, color: accentLight.withOpacity(0.5), size: 20),
        ],
      ),
    );
  }

  // ─── SECTION HEADER ────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(left: 10),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.black, width: 3.5),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: textMain, size: 20),
              const SizedBox(width: 8),
              Text(
                "!! $title",
                style: TextStyle(
                  color: textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'Orbitron',
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 60,
          height: 4,
          decoration: BoxDecoration(
            color: textMain,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  // ─── TENTANG Xeron ──────────────────────────────────────────────────────
  Widget _buildTentangSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Tentang SixEyesX Project", Icons.info_outline_rounded),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black, blurRadius: 0, offset: Offset(4, 4),
              ),
            ],
          ),
          child: Text(
            "SixEyesX Project adalah sebuah sistem utilitas tingkat lanjut yang dirancang khusus untuk memfasilitasi pengujian stabilitas dan pengiriman payload (Bug Testing). Dibangun dengan arsitektur berkinerja tinggi, sistem ini menjamin kecepatan eksekusi, keamanan enkripsi sesi, dan presisi dalam pengiriman data baik secara personal maupun publik. Kami menyediakan infrastruktur server yang kuat untuk kelancaran tugas Anda.",
            style: TextStyle(
              color: textMain,
              fontSize: 13,
              height: 1.75,
              fontFamily: 'ShareTechMono',
            ),
            textAlign: TextAlign.justify,
          ),
        ),
      ],
    );
  }

  // ─── FEATURE CARD ──────────────────────────────────────────────────────
  Widget _buildFeatureCard(Map<String, dynamic> feature) {
    final Color c = feature['color'] as Color;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.withOpacity(0.25), width: 1),
            ),
            child: Icon(feature['icon'] as IconData, color: c, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature['title'] as String,
                  style: TextStyle(
                    color: textMain,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    fontFamily: 'Orbitron',
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  feature['desc'] as String,
                  style: TextStyle(
                    color: textSub,
                    fontSize: 12,
                    height: 1.55,
                    fontFamily: 'ShareTechMono',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── FITUR SECTION ─────────────────────────────────────────────────────
  Widget _buildFiturSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Fitur-fitur Utama", Icons.rocket_launch_rounded),
        const SizedBox(height: 14),
        ...featuresList.map(_buildFeatureCard).toList(),
      ],
    );
  }

  // ─── RULE CARD — ocean purple accent ───────────────────────────────────
  Widget _buildRuleCard(int index, Map<String, dynamic> rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4)),
        ],
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          // Ocean purple untuk ikon panah expand/collapse
          iconColor: accentMid,
          collapsedIconColor: accentLight,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              // Background ikon: ocean purple sangat pucat
              color: accentBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentMid.withOpacity(0.3)),
            ),
            child: Icon(
              rule['icon'] as IconData,
              // Icon berwarna ocean purple
              color: accentMid,
              size: 22,
            ),
          ),
          title: Text(
            rule['title'] as String,
            style: TextStyle(
              // Judul rule berwarna ocean purple gelap
              color: accentBlue,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFamily: 'Orbitron',
              letterSpacing: 0.8,
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.only(
                left: 20, right: 20, bottom: 18, top: 2,
              ),
              width: double.infinity,
              // Garis bawah ocean purple tipis sebagai aksen
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: accentLight.withOpacity(0.2), width: 1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  rule['desc'] as String,
                  style: TextStyle(
                    color: textSub,
                    fontSize: 12,
                    height: 1.55,
                    fontFamily: 'ShareTechMono',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── PENALTY BOX ───────────────────────────────────────────────────────
  Widget _buildPenaltyBox() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 28),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD32F2F), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFEF5350), size: 26),
              SizedBox(width: 10),
              Text(
                "VIOLATION PENALTY",
                style: TextStyle(
                  color: Color(0xFFEF5350),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Orbitron',
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "Jika pengguna terdeteksi melanggar salah satu protokol kerahasiaan & aturan di atas secara sengaja:",
            style: TextStyle(
              color: textMain,
              fontSize: 12,
              fontFamily: 'ShareTechMono',
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFEF5350).withOpacity(0.5),
              ),
            ),
            child: Text(
              "AKUN AKAN DIHAPUS PERMANEN",
              style: TextStyle(
                color: textMain,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "TIDAK ADA PENGEMBALIAN SALDO ATAU KOMPENSASI.",
            style: TextStyle(
              color: Color(0xFFEF5350),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'ShareTechMono',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(color: accentMid),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background grid putih (fixed)
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(gridColor: gridColor),
            ),
          ),
          // Konten
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildBanner()),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildStatusHeader(),
                      _buildTentangSection(),
                      const SizedBox(height: 28),
                      _buildFiturSection(),
                      const SizedBox(height: 28),
                      _buildSectionHeader(
                        "Kebijakan Pengguna", Icons.shield_outlined,
                      ),
                      const SizedBox(height: 14),
                      ...rulesList
                          .asMap()
                          .entries
                          .map((e) => _buildRuleCard(e.key, e.value))
                          .toList(),
                      _buildPenaltyBox(),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.shield_moon_rounded,
                                color: accentLight.withOpacity(0.35), size: 28),
                            const SizedBox(height: 12),
                            Text(
                              "Peraturan ini dibuat semata-mata untuk menjaga keamanan, kenyamanan, dan kestabilan ekosistem server SixEyesX. Dengan mengakses aplikasi, Anda secara otomatis menyetujui seluruh protokol di atas.",
                              style: TextStyle(
                                color: textSub.withOpacity(0.7),
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                fontFamily: 'ShareTechMono',
                                height: 1.55,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 3,
                              width: 40,
                              decoration: BoxDecoration(
                                color: accentLight.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Grid Painter (garis kotak putih seperti foto) ───────────────────────
class _GridPainter extends CustomPainter {
  final Color gridColor;
  final double step;

  const _GridPainter({required this.gridColor, this.step = 28.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.gridColor != gridColor || oldDelegate.step != step;
}
