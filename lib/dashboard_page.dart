import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:video_player/video_player.dart';
import 'package:glaze_nav_bar/glaze_nav_bar.dart';

// Import halaman lain
import 'nik_check.dart';
import 'home_page.dart';
import 'change_password_page.dart';
import 'tools_gateway.dart';
import 'login_page.dart';
import 'landing_page.dart';
import 'bug_sender.dart';
import 'contact_page.dart';
import 'profile_page.dart';
import 'riwayat_page.dart';
import 'info_page.dart';
import 'device_dashboard.dart';
import 'set.dart';
import 'tap.dart';
import 'widgets/custom_popup.dart';
import 'chat_page.dart';
import 'ordernokos.dart';
import 'srv.dart';
import 'story_section.dart';
import 'spotify_page.dart';
import 'youtube_tools.dart';
import 'amprem_page.dart';

class DashboardPage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;
  final List<dynamic> news;

  const DashboardPage({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.listBug,
    required this.listDoos,
    required this.sessionKey,
    required this.news,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late WebSocketChannel channel;

  late String sessionKey;
  late String username;
  late String password;
  late String role;
  late String expiredDate;
  late List<Map<String, dynamic>> listBug;
  late List<Map<String, dynamic>> listDoos;
  late List<dynamic> newsList;

  String androidId = "unknown";
  File? _profileImage;

  int _bottomNavIndex = 0;
  Widget _selectedPage = const Placeholder();

  int onlineUsers = 0;
  int activeConnections = 0;

  // Jadwal Sholat
  String _prayerCity = 'Jombang';
  Map<String, String> _prayerTimes = {};
  String _nextPrayerLabel = '-';
  String _nextPrayerTime = '--:--';
  bool _prayerLoading = false;
  Timer? _prayerTimer;
  final Set<String> _notifiedPrayers = {};

  // Cuaca
  bool _weatherLoading = false;
  String _weatherCity = 'Lokasi...';
  String _weatherCountry = 'Indonesia';
  String _weatherDesc = '-';
  double? _weatherTemp;
  double? _weatherFeels;
  int? _weatherHumidity;
  double? _weatherWind;
  double? _weatherPressure;
  String _weatherUpdated = '--:--';
  IconData _weatherIcon = Icons.cloud_rounded;

  static const List<String> _indoCities = [
    'Jakarta', 'Surabaya', 'Bandung', 'Medan', 'Semarang', 'Makassar',
    'Palembang', 'Tangerang', 'Depok', 'Bekasi', 'Bogor', 'Malang',
    'Yogyakarta', 'Jombang', 'Kediri', 'Solo', 'Denpasar', 'Balikpapan',
    'Pontianak', 'Banjarmasin', 'Manado', 'Padang', 'Pekanbaru', 'Aceh',
    'Lampung', 'Cirebon', 'Tasikmalaya', 'Sukabumi', 'Purwokerto', 'Magelang',
    'Madiun', 'Sidoarjo', 'Gresik', 'Probolinggo', 'Banyuwangi', 'Jember',
    'Cianjur', 'Garut', 'Kuningan', 'Tegal', 'Pekalongan', 'Salatiga',
  ];

  late PageController _newsPageController;
  double _currentNewsPage = 0.0;
  Timer? _newsTimer;
  VideoPlayerController? _videoController;
  final FlutterLocalNotificationsPlugin _notifPlugin =
      FlutterLocalNotificationsPlugin();

  // ═══════════════════════════════════════════════════════════
  // THEME — OBSIDIAN CRIMSON
  // ═══════════════════════════════════════════════════════════
  static const Color bgMain       = Color(0xFF0B0D12);
  static const Color bgSurface    = Color(0xFF13161D);
  static const Color bgCard       = Color(0xFF161A22);
  static const Color bgElevated   = Color(0xFF1C212B);
  static const Color textMain     = Color(0xFFEDEEF2);
  static const Color textSub      = Color(0xFF8A8F9A);
  static const Color textMuted    = Color(0xFF5C6270);
  static const Color accentWhite  = Color(0xFFE63946);
  static const Color accentDeep   = Color(0xFFB3242E);
  static const Color accentSoft   = Color(0xFFF26B76);
  static const Color borderLight  = Color(0xFF2A303C);
  static const Color borderGlass  = Color(0xFF2A303C);
  static const Color successGreen = Color(0xFF4ADE80);
  static const Color warnAmber    = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();

    sessionKey = widget.sessionKey;
    username = widget.username;
    password = widget.password;
    role = widget.role;
    expiredDate = widget.expiredDate;
    listBug = widget.listBug;
    listDoos = widget.listDoos;
    newsList = widget.news;

    _initBannerVideo();
    _initNewsBanner();
    _selectedPage = _buildNewsPage();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    _initAndroidIdAndConnect();
    _loadProfileImage();
    _initPrayerSchedule();
    _initWeather();
  }

  Future<void> _initBannerVideo() async {
    try {
      final ctrl = VideoPlayerController.asset('assets/videos/banner.mp4');
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(20);
      await ctrl.seekTo(Duration.zero);
      if (_bottomNavIndex == 0) {
        await ctrl.play();
      } else {
        await ctrl.pause();
      }
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _videoController = ctrl;
      });
    } catch (_) {}
  }

  Future<void> _setHeroVideoActive(bool active) async {
    final ctrl = _videoController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    try {
      if (active) {
        await ctrl.seekTo(Duration.zero);
        await ctrl.play();
      } else {
        await ctrl.pause();
      }
    } catch (_) {}
  }

  void _initNewsBanner() {
    _newsPageController = PageController(
      initialPage: 0,
      viewportFraction: 0.9,
    );

    _newsPageController.addListener(() {
      if (_newsPageController.hasClients && _newsPageController.page != null) {
        _currentNewsPage = _newsPageController.page!;
      }
    });

    if (newsList.isNotEmpty) {
      _newsTimer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
        if (_newsPageController.hasClients) {
          int targetIndex = (_currentNewsPage + 1).round() % newsList.length;
          _newsPageController.animateToPage(
            targetIndex,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_$username');
    if (imagePath != null && imagePath.isNotEmpty) {
      setState(() {
        _profileImage = File(imagePath);
      });
    }
  }

  Future<void> _initAndroidIdAndConnect() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    androidId = deviceInfo.id;
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    channel = WebSocketChannel.connect(
      Uri.parse(Srv.wsUrl),
    );
    channel.sink.add(
      jsonEncode({
        "type": "validate",
        "key": sessionKey,
        "androidId": androidId,
      }),
    );
    channel.sink.add(jsonEncode({"type": "stats"}));

    channel.stream.listen((event) {
      final data = jsonDecode(event);
      if (data['type'] == 'myInfo') {
        if (data['valid'] == false) {
          if (data['reason'] == 'androidIdMismatch') {
            _handleInvalidSession("Your account has logged on another device.");
          } else if (data['reason'] == 'keyInvalid') {
            _handleInvalidSession("Key is not valid. Please login again.");
          }
        }
      }
      if (data['type'] == 'stats') {
        setState(() {
          onlineUsers = data['onlineUsers'] ?? 0;
          activeConnections = data['activeConnections'] ?? 0;
        });
      }
    });
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $uri");
    }
  }

  void _openAmpremPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AmpremPage(),
      ),
    );
  }

  void _handleInvalidSession(String message) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    CustomPopup.show(
      context,
      title: "Session Expired",
      message: message,
      icon: Icons.error_outline,
      iconColor: Colors.redAccent,
      confirmText: "OK",
      onConfirm: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      },
    );
  }

  void _onBottomNavTapped(int index) {
    _setHeroVideoActive(index == 0);
    setState(() {
      _bottomNavIndex = index;
      if (index == 0) {
        _selectedPage = _buildNewsPage();
      } else if (index == 1) {
        _selectedPage = HomePage(
          username: username,
          password: password,
          listBug: listBug,
          role: role,
          expiredDate: expiredDate,
          sessionKey: sessionKey,
        );
      } else if (index == 2) {
        _selectedPage = InfoPage(
          sessionKey: sessionKey,
          username: username,
          role: role,
          expiredDate: expiredDate,
        );
      } else if (index == 3) {
        _selectedPage = ToolsPage(
          sessionKey: sessionKey,
          userRole: role,
          listDoos: listDoos,
        );
      }
    });
  }

  void _showWhatsAppMenu() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF25D366).withOpacity(0.35),
                      ),
                    ),
                    child: const Icon(
                      FaFaIcon(FontAwesomeIcons.whatsapp),
                      size: 34,
                      color: Color(0xFF25D366),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "WHATSAPP TOOLS",
                    style: TextStyle(
                      color: textMain,
                      fontFamily: 'Orbitron',
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Choose an action to perform",
                    style: TextStyle(
                      color: textSub.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildWhatsAppOption(
                    icon: Icons.bug_report_rounded,
                    color: const Color(0xFFE63946),
                    title: "WhatsApp Crash",
                    subtitle: "Send payloads & crash codes",
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _bottomNavIndex = 1;
                        _selectedPage = HomePage(
                          username: username,
                          password: password,
                          listBug: listBug,
                          role: role,
                          expiredDate: expiredDate,
                          sessionKey: sessionKey,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildWhatsAppOption(
                    icon: Icons.devices_rounded,
                    color: const Color(0xFF4ADE80),
                    title: "Manage Sender",
                    subtitle: "Pair devices & manage sessions",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BugSenderPage(
                            sessionKey: sessionKey,
                            username: username,
                            role: role,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: textMain,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWhatsAppOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: textMain,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textSub.withOpacity(0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: textMuted.withOpacity(0.7), size: 13),
          ],
        ),
      ),
    );
  }

  String _getGreetingPeriod() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 6) return "Subuh";
    if (hour >= 6 && hour < 11) return "Pagi";
    if (hour >= 11 && hour < 15) return "Siang";
    if (hour >= 15 && hour < 18) return "Sore";
    return "Malam";
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case "developer":
        return const Color(0xFFE63946);
      case "owner":
        return const Color(0xFFEF4444);
      case "admin":
        return const Color(0xFFF26B76);
      case "reseller":
        return const Color(0xFFF59E0B);
      case "partner":
        return const Color(0xFF4ADE80);
      case "moderator":
        return const Color(0xFF60A5FA);
      case "vip":
        return const Color(0xFFEAB308);
      default:
        return textSub;
    }
  }

  Widget _appBarBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: bgCard.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Tooltip(
              message: tooltip,
              child: Icon(icon, color: textMain, size: 17),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHoxtenHeroCard() {
    final bugCount = listBug.length;
    final ddosCount = listDoos.length;
    final expText =
        expiredDate.toString().isEmpty ? '-' : expiredDate.toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: accentDeep.withOpacity(0.10),
              blurRadius: 32,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: (_videoController != null &&
                        _videoController!.value.isInitialized)
                    ? FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: _videoController!.value.size.width,
                          height: _videoController!.value.size.height,
                          child: VideoPlayer(_videoController!),
                        ),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF151922), Color(0xFF0B0D12)],
                          ),
                        ),
                      ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withOpacity(0.55),
                        accentDeep.withOpacity(0.20),
                        Colors.black.withOpacity(0.80),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.14),
                                Colors.white.withOpacity(0.04),
                              ],
                            ),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.14),
                                width: 1.2),
                          ),
                          child: const Icon(Icons.person_rounded,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.55),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                username.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                  fontFamily: 'Orbitron',
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _getRoleColor(role)
                                          .withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _getRoleColor(role)
                                            .withOpacity(0.35),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      role.toUpperCase(),
                                      style: TextStyle(
                                        color: _getRoleColor(role),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: successGreen,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              successGreen.withOpacity(0.6),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'ONLINE',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentDeep.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: accentSoft.withOpacity(0.35),
                                width: 1),
                          ),
                          child: const Text(
                            'SESSION',
                            style: TextStyle(
                              color: Color(0xFFEDEEF2),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _statChip(
                            icon: Icons.groups_rounded,
                            label: 'Online Users',
                            value: '$onlineUsers',
                            accent: const Color(0xFFE63946),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statChip(
                            icon: Icons.hub_outlined,
                            label: 'Sender Aktif',
                            value: '$activeConnections',
                            accent: const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _miniStat(
                            icon: Icons.bug_report_rounded,
                            label: 'BUG',
                            value: '$bugCount',
                            color: const Color(0xFFE63946),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _miniStat(
                            icon: Icons.bolt_rounded,
                            label: 'DDOS',
                            value: '$ddosCount',
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _miniStat(
                            icon: Icons.timer_outlined,
                            label: 'EXP',
                            value: expText,
                            color: const Color(0xFF4ADE80),
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

  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.22), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 12, color: accent),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.20), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureDuo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _featureBigCard(
              title: 'Manage\nSender',
              subtitle: 'Kelola Sender',
              badge: 'SENDER',
              icon: Icons.wifi_tethering_rounded,
              colors: const [Color(0xFF6B0F1A), Color(0xFFB3242E)],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BugSenderPage(
                    sessionKey: sessionKey,
                    username: username,
                    role: role,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _featureBigCard(
              title: 'Remote\nAccess',
              subtitle: 'RAT Control',
              badge: 'CONTROL',
              icon: Icons.dashboard_customize_rounded,
              colors: const [Color(0xFF1E2A4A), Color(0xFF3B4F7E)],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DeviceDashboardPage(sessionKey: sessionKey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureBigCard({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 145,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          boxShadow: [
            BoxShadow(
              color: colors.last.withOpacity(0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.14), width: 1),
                  ),
                  child: Icon(icon,
                      color: Colors.white.withOpacity(0.95), size: 18),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.28),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.12), width: 0.8),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                height: 1.15,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalChatPreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  color: accentWhite,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.groups_2_rounded, color: textMain, size: 19),
              const SizedBox(width: 8),
              const Text(
                "GLOBAL CHAT",
                style: TextStyle(
                  color: textMain,
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                  fontFamily: 'Orbitron',
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Ngobrol langsung dengan semua pengguna SixEyesX project di satu ruangan.",
            style: TextStyle(
              color: textSub.withOpacity(0.8),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  currentUsername: username,
                  currentRole: role,
                  sessionKey: sessionKey,
                ),
              ),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accentWhite.withOpacity(0.10),
                      shape: BoxShape.circle,
                      border: Border.all(color: accentWhite.withOpacity(0.28)),
                    ),
                    child: const Icon(
                      Icons.groups_2_rounded,
                      size: 22,
                      color: accentWhite,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Community Room",
                          style: TextStyle(
                            color: textMain,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: successGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              "Tap untuk masuk ke ruang chat",
                              style: TextStyle(
                                color: textSub.withOpacity(0.85),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentWhite.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: accentWhite,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Jadwal Sholat ────────────────────────────────────────────────────────
  Future<void> _initPrayerSchedule() async {
    await _initLocalNotifications();
    final prefs = await SharedPreferences.getInstance();
    _prayerCity = prefs.getString('prayer_city') ?? 'Jombang';
    await _fetchPrayerTimes();
    _prayerTimer?.cancel();
    _prayerTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _updateNextPrayer();
      _checkPrayerNotification();
    });
  }

  Future<void> _initLocalNotifications() async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _notifPlugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
      );
      final android = _notifPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      const channel = AndroidNotificationChannel(
        'prayer_channel',
        'Jadwal Sholat',
        description: 'Notifikasi waktu sholat',
        importance: Importance.high,
      );
      await android?.createNotificationChannel(channel);
    } catch (e) {
      debugPrint('notif init: $e');
    }
  }

  Future<void> _schedulePrayerNotifications() async {
    if (_prayerTimes.isEmpty) return;
    try {
      final android = _notifPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      try {
        await android?.requestExactAlarmsPermission();
      } catch (_) {}

      await _notifPlugin.cancelAll();
      final now = tz.TZDateTime.now(tz.local);
      final order = ['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya'];
      int id = 100;
      for (final name in order) {
        final t = _prayerTimes[name];
        if (t == null || !t.contains(':')) continue;
        final parts = t.split(':');
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
        if (!when.isAfter(now)) {
          when = when.add(const Duration(days: 1));
        }
        const details = NotificationDetails(
          android: AndroidNotificationDetails(
            'prayer_channel',
            'Jadwal Sholat',
            channelDescription: 'Notifikasi waktu sholat',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
          ),
        );
        try {
          await _notifPlugin.zonedSchedule(
            id,
            'Waktu Sholat $name',
            'Sudah waktunya sholat $name ($t). Semoga ibadahmu khusyuk.',
            when,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
          );
        } catch (_) {
          await _notifPlugin.zonedSchedule(
            id,
            'Waktu Sholat $name',
            'Sudah waktunya sholat $name ($t). Semoga ibadahmu khusyuk.',
            when,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
          );
        }
        id++;
      }
      debugPrint('prayer notifs scheduled');
    } catch (e) {
      debugPrint('schedule prayer notif: $e');
    }
  }

  Future<void> _fetchPrayerTimes() async {
    if (!mounted) return;
    setState(() => _prayerLoading = true);
    try {
      final city = Uri.encodeComponent(_prayerCity);
      final uri = Uri.parse(
        'https://api.aladhan.com/v1/timingsByCity?city=$city&country=Indonesia&method=20',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final t = data['data']?['timings'] as Map<String, dynamic>?;
        if (t != null) {
          String clean(String? v) =>
              (v ?? '--:--').toString().split(' ').first.trim();
          _prayerTimes = {
            'Subuh': clean(t['Fajr']?.toString()),
            'Dzuhur': clean(t['Dhuhr']?.toString()),
            'Ashar': clean(t['Asr']?.toString()),
            'Maghrib': clean(t['Maghrib']?.toString()),
            'Isya': clean(t['Isha']?.toString()),
          };
          _notifiedPrayers.clear();
          _updateNextPrayer();
          await _schedulePrayerNotifications();
        }
      }
    } catch (e) {
      debugPrint('prayer fetch error: $e');
    }
    if (mounted) setState(() => _prayerLoading = false);
  }

  int _toMinutes(String hhmm) {
    final p = hhmm.split(':');
    if (p.length < 2) return -1;
    final h = int.tryParse(p[0]) ?? -1;
    final m = int.tryParse(p[1]) ?? -1;
    if (h < 0 || m < 0) return -1;
    return h * 60 + m;
  }

  void _updateNextPrayer() {
    if (_prayerTimes.isEmpty) return;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final order = ['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya'];
    String label = order.first;
    String time = _prayerTimes[label] ?? '--:--';
    for (final name in order) {
      final t = _prayerTimes[name] ?? '--:--';
      final mins = _toMinutes(t);
      if (mins >= nowMin) {
        label = name;
        time = t;
        break;
      }
      if (name == order.last) {
        label = 'Subuh';
        time = _prayerTimes['Subuh'] ?? '--:--';
      }
    }
    if (!mounted) return;
    if (label != _nextPrayerLabel || time != _nextPrayerTime) {
      setState(() {
        _nextPrayerLabel = label;
        _nextPrayerTime = time;
      });
    }
  }

  void _checkPrayerNotification() {
    if (_prayerTimes.isEmpty || !mounted) return;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final today = '${now.year}-${now.month}-${now.day}';
    for (final e in _prayerTimes.entries) {
      final mins = _toMinutes(e.value);
      if (mins < 0) continue;
      final key = '$today-${e.key}';
      if (mins == nowMin && !_notifiedPrayers.contains(key)) {
        _notifiedPrayers.add(key);
        _showPrayerNotification(e.key, e.value);
      }
    }
  }

  void _showPrayerNotification(String name, String time) {
    try {
      _notifPlugin.show(
        200 + name.hashCode % 50,
        'Waktu Sholat $name',
        'Sudah waktunya sholat $name ($time). Semoga ibadahmu khusyuk.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'prayer_channel',
            'Jadwal Sholat',
            channelDescription: 'Notifikasi waktu sholat',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('show prayer notif: $e');
    }
    if (!mounted) return;
    try {
      CustomPopup.show(
        context,
        title: 'Waktu Sholat',
        message: 'Sudah waktunya sholat $name ($time).\nSemoga ibadahmu khusyuk.',
        icon: Icons.mosque_rounded,
        iconColor: const Color(0xFFE63946),
        confirmText: 'OK',
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sudah waktunya sholat $name ($time)'),
          backgroundColor: const Color(0xFFB3242E),
        ),
      );
    }
  }

  Future<void> _pickPrayerCity() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String q = '';
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final filtered = _indoCities
                .where((c) => c.toLowerCase().contains(q.toLowerCase()))
                .toList();
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Color(0xFF0B0D12),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Pilih Kota',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Orbitron',
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Cari kota...',
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.35)),
                        prefixIcon:
                            const Icon(Icons.search, color: Color(0xFFF26B76)),
                        filled: true,
                        fillColor: const Color(0xFF161A22),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => setModal(() => q = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final city = filtered[i];
                        final active = city == _prayerCity;
                        return ListTile(
                          title: Text(
                            city,
                            style: TextStyle(
                              color: active
                                  ? const Color(0xFFF26B76)
                                  : Colors.white,
                              fontWeight:
                                  active ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                          trailing: active
                              ? const Icon(Icons.check_circle,
                                  color: Color(0xFFE63946))
                              : null,
                          onTap: () => Navigator.pop(ctx, city),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (selected != null && selected.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('prayer_city', selected);
      setState(() => _prayerCity = selected);
      await _fetchPrayerTimes();
    }
  }

  // ── Cuaca ────────────────────────────────────────────────────────────────
  Future<void> _initWeather() async {
    await _fetchWeatherByGps();
  }

  String _weatherCodeToId(int code) {
    if (code == 0) return 'Cerah';
    if (code == 1) return 'Cerah berawan';
    if (code == 2) return 'Berawan sebagian';
    if (code == 3) return 'Berawan';
    if (code == 45 || code == 48) return 'Berkabut';
    if (code >= 51 && code <= 57) return 'Gerimis';
    if (code >= 61 && code <= 67) return 'Hujan';
    if (code >= 71 && code <= 77) return 'Salju';
    if (code >= 80 && code <= 82) return 'Hujan lokal';
    if (code >= 85 && code <= 86) return 'Salju lokal';
    if (code >= 95) return 'Badai petir';
    return 'Awan pecah';
  }

  IconData _weatherCodeToIcon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code <= 2) return Icons.cloud_queue_rounded;
    if (code == 3) return Icons.cloud_rounded;
    if (code == 45 || code == 48) return Icons.cloud_rounded;
    if (code >= 51 && code <= 67) return Icons.water_drop_rounded;
    if (code >= 80 && code <= 82) return Icons.grain_rounded;
    if (code >= 95) return Icons.thunderstorm_rounded;
    return Icons.cloud_rounded;
  }

  Future<bool> _ensureLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isGranted) return true;
    status = await Permission.locationWhenInUse.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Izin lokasi ditolak. Buka pengaturan aplikasi.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
      }
      return false;
    }
    return false;
  }

  Future<void> _fetchWeatherByGps() async {
    if (!mounted) return;
    setState(() => _weatherLoading = true);
    try {
      final ok = await _ensureLocationPermission();
      if (!ok) {
        setState(() {
          _weatherLoading = false;
          _weatherCity = 'Izin lokasi dibutuhkan';
          _weatherDesc = 'Ketuk refresh untuk mencoba lagi';
        });
        return;
      }

      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        setState(() {
          _weatherLoading = false;
          _weatherCity = 'GPS mati';
          _weatherDesc = 'Aktifkan lokasi perangkat';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 15),
      );

      try {
        final geoUri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=${pos.latitude}&lon=${pos.longitude}&format=json&zoom=10&addressdetails=1',
        );
        final geoRes = await http.get(
          geoUri,
          headers: {'User-Agent': 'XeronApp/1.0'},
        ).timeout(const Duration(seconds: 10));
        if (geoRes.statusCode == 200) {
          final g = jsonDecode(geoRes.body) as Map<String, dynamic>;
          final addr = (g['address'] as Map?) ?? {};
          _weatherCity = (addr['city'] ??
                  addr['town'] ??
                  addr['county'] ??
                  addr['state'] ??
                  g['name'] ??
                  'Lokasi')
              .toString();
          _weatherCountry = (addr['country'] ?? 'Indonesia').toString();
        }
      } catch (_) {
        _weatherCity = 'Lokasi Anda';
        _weatherCountry = 'Indonesia';
      }

      final wUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${pos.latitude}&longitude=${pos.longitude}'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,'
        'weather_code,wind_speed_10m,surface_pressure'
        '&timezone=Asia%2FJakarta',
      );
      final wRes = await http.get(wUri).timeout(const Duration(seconds: 12));
      if (wRes.statusCode == 200) {
        final data = jsonDecode(wRes.body) as Map<String, dynamic>;
        final cur = (data['current'] as Map?) ?? {};
        final code = int.tryParse('${cur['weather_code']}') ?? 0;
        final now = DateTime.now();
        _weatherTemp = (cur['temperature_2m'] as num?)?.toDouble();
        _weatherFeels = (cur['apparent_temperature'] as num?)?.toDouble();
        _weatherHumidity = (cur['relative_humidity_2m'] as num?)?.toInt();
        _weatherWind = (cur['wind_speed_10m'] as num?)?.toDouble();
        _weatherPressure = (cur['surface_pressure'] as num?)?.toDouble();
        _weatherDesc = _weatherCodeToId(code);
        _weatherIcon = _weatherCodeToIcon(code);
        _weatherUpdated =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      debugPrint('weather error: $e');
      if (mounted) {
        setState(() {
          _weatherCity = 'Gagal memuat';
          _weatherDesc = 'Coba lagi';
        });
      }
    }
    if (mounted) setState(() => _weatherLoading = false);
  }

  Widget _buildWeatherCard() {
    final tempStr = _weatherTemp != null
        ? '${_weatherTemp!.toStringAsFixed(1)}°C'
        : '--°C';
    final feelsStr = _weatherFeels != null
        ? '${_weatherFeels!.toStringAsFixed(1)}°C'
        : '--';
    final humStr = _weatherHumidity != null ? '$_weatherHumidity%' : '--';
    final windStr =
        _weatherWind != null ? '${_weatherWind!.toStringAsFixed(1)} m/s' : '--';
    final pressStr = _weatherPressure != null
        ? '${_weatherPressure!.toStringAsFixed(0)} hPa'
        : '--';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF161A22), Color(0xFF101319)],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentWhite.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentWhite.withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      color: Color(0xFFF26B76), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _weatherCity,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _weatherCountry.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _weatherLoading ? null : _fetchWeatherByGps,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: accentWhite.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentWhite.withOpacity(0.32)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _weatherLoading
                              ? Icons.hourglass_top_rounded
                              : Icons.my_location_rounded,
                          color: const Color(0xFFF26B76),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _weatherLoading ? '...' : 'GPS',
                          style: const TextStyle(
                            color: Color(0xFFF26B76),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accentWhite.withOpacity(0.10),
                    shape: BoxShape.circle,
                    border: Border.all(color: accentWhite.withOpacity(0.22)),
                  ),
                  child: Icon(_weatherIcon,
                      color: const Color(0xFFF26B76), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tempStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _weatherLoading ? 'Memuat cuaca...' : _weatherDesc,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Terasa $feelsStr  ·  $humStr',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.42),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child:
                        _weatherMini(Icons.air_rounded, windStr, 'Angin')),
                const SizedBox(width: 8),
                Expanded(
                    child: _weatherMini(
                        Icons.speed_rounded, pressStr, 'Tekanan')),
                const SizedBox(width: 8),
                Expanded(
                    child: _weatherMini(Icons.access_time_rounded,
                        _weatherUpdated, 'Update')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _weatherMini(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 15, color: const Color(0xFFF26B76)),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerScheduleCard() {
    final items = [
      ('Subuh', Icons.nightlight_round, _prayerTimes['Subuh'] ?? '--:--'),
      ('Dzuhur', Icons.wb_sunny_rounded, _prayerTimes['Dzuhur'] ?? '--:--'),
      ('Ashar', Icons.cloud_rounded, _prayerTimes['Ashar'] ?? '--:--'),
      ('Maghrib', Icons.wb_twilight, _prayerTimes['Maghrib'] ?? '--:--'),
      ('Isya', Icons.brightness_2_rounded, _prayerTimes['Isya'] ?? '--:--'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF161A22), Color(0xFF101319)],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accentWhite.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentWhite.withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.mosque_rounded,
                      color: Color(0xFFF26B76), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'JADWAL SHOLAT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 12, color: Color(0xFFF26B76)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _prayerCity,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 11.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _pickPrayerCity,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE63946), Color(0xFFB3242E)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: accentDeep.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz,
                            color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'GANTI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: accentDeep.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentSoft.withOpacity(0.22)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accentSoft,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentSoft.withOpacity(0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _prayerLoading
                          ? 'Memuat jadwal...'
                          : 'Menuju $_nextPrayerLabel : $_nextPrayerTime',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentDeep,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'NOW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: items[i].$1 == _nextPrayerLabel
                            ? accentDeep.withOpacity(0.25)
                            : Colors.white.withOpacity(0.035),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: items[i].$1 == _nextPrayerLabel
                              ? accentSoft.withOpacity(0.6)
                              : Colors.white.withOpacity(0.06),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(items[i].$2,
                              size: 15, color: const Color(0xFFF26B76)),
                          const SizedBox(height: 5),
                          Text(
                            items[i].$1.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.68),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            items[i].$3,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsPage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          StorySection(
            username: username,
            sessionKey: sessionKey,
            serverUrl: Srv.baseUrl,
          ),
          const SizedBox(height: 8),

          _buildHoxtenHeroCard(),
          _buildFeatureDuo(),
          const SizedBox(height: 20),

          // QUICK ACTIONS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: accentWhite,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'QUICK ACTIONS',
                      style: TextStyle(
                        color: textMain,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        fontFamily: 'Orbitron',
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Akses cepat fitur favorit kamu',
                  style: TextStyle(
                    color: textSub.withOpacity(0.75),
                    fontSize: 12,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _JustinActionTile(
                        title: 'Order Nokos',
                        subtitle: 'Beli nomor OTP',
                        icon: Icons.phone_android_rounded,
                        color: const Color(0xFFE63946),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderNokosPage(
                              sessionKey: sessionKey,
                              username: username,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _JustinActionTile(
                        title: 'Chat',
                        subtitle: 'Global chat room',
                        icon: Icons.chat_bubble_rounded,
                        color: const Color(0xFF7E57C2),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                currentUsername: username,
                                currentRole: role,
                                sessionKey: sessionKey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _JustinWideTile(
                  title: 'Join Channel Telegram',
                  subtitle: 'Channel resmi SixEyesX Community',
                  icon: FaFaIcon(FontAwesomeIcons.telegram),
                  color: const Color(0xFF29B6F6),
                  onTap: () => _openUrl('https://t.me/InformasiSyX'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _JustinActionTile(
                        title: 'Riwayat',
                        subtitle: 'Histori aktivitas',
                        icon: Icons.history_rounded,
                        color: const Color(0xFFF26B76),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RiwayatPage(
                              sessionKey: sessionKey,
                              role: role,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _JustinActionTile(
                        title: 'Profile',
                        subtitle: 'Kelola akun',
                        icon: Icons.person_rounded,
                        color: const Color(0xFF4ADE80),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfilePage(
                              username: username,
                              password: password,
                              role: role,
                              expiredDate: expiredDate,
                              sessionKey: sessionKey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _JustinWideTile(
                  title: 'RangersMusic',
                  subtitle: 'Streaming musik gratis 30 detik',
                  icon: Icons.music_note_rounded,
                  color: const Color(0xFF7B1FA2),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SpotifyPage()),
                  ),
                ),
                const SizedBox(height: 10),
                _JustinWideTile(
                  title: 'YouTube Browser',
                  subtitle: 'Streaming YouTube tanpa iklan ribet',
                  icon: Icons.play_circle_fill_rounded,
                  color: const Color(0xFFFF0000),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const YouTubeToolPage()),
                  ),
                ),
                const SizedBox(height: 10),
                _JustinWideTile(
                  title: 'Alight Motion Premium',
                  subtitle: 'alight premium gratis 1 tahun',
                  icon: Icons.auto_awesome_motion_rounded,
                  color: const Color(0xFF1A73E8),
                  onTap: _openAmpremPage,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _JustinActionTile(
                        title: 'Contact',
                        subtitle: 'Hubungi support',
                        icon: Icons.contact_support_rounded,
                        color: const Color(0xFFF59E0B),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ContactPage()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _JustinActionTile(
                        title: 'Info',
                        subtitle: 'Bantuan & panduan',
                        icon: Icons.info_rounded,
                        color: const Color(0xFF60A5FA),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InfoPage(
                              sessionKey: sessionKey,
                              username: username,
                              role: role,
                              expiredDate: expiredDate,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _JustinWideTile(
                  title: 'Contact Developer',
                  subtitle: 'Telegram @xyzyanzzi',
                  icon: FaFaIcon(FontAwesomeIcons.telegram),
                  color: const Color(0xFF0088CC),
                  onTap: () => _openUrl('https://t.me/xyzyanzzi'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // LATEST UPDATE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: accentWhite,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.calendar_month_rounded,
                        color: textMain, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      "LATEST UPDATE",
                      style: TextStyle(
                        color: textMain,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        fontFamily: 'Orbitron',
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "Keep yourself informed about recent system maintenance, newly added tools, and important announcements from the administration.",
                  style: TextStyle(
                    color: textSub.withOpacity(0.8),
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            height: 180,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Stack(
              children: [
                PageView.builder(
                  controller: _newsPageController,
                  itemCount: newsList.isEmpty ? 1 : newsList.length,
                  itemBuilder: (context, index) {
                    if (newsList.isEmpty) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: bgCard,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.06)),
                        ),
                        child: const Center(
                          child: Text(
                            "No updates yet",
                            style: TextStyle(color: textSub),
                          ),
                        ),
                      );
                    }
                    final item = newsList[index];
                    final String mediaUrl = (item is Map)
                        ? (item['image'] ?? item['media'] ?? '').toString()
                        : '';
                    final String title = (item is Map)
                        ? (item['title'] ?? 'Update').toString()
                        : 'Update';
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: bgCard,
                        border:
                            Border.all(color: Colors.white.withOpacity(0.07)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (mediaUrl.isNotEmpty)
                            NewsMedia(url: mediaUrl)
                          else
                            Container(color: bgSurface),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.78),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 14,
                            right: 14,
                            bottom: 14,
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _newsPageController,
                    builder: (context, child) {
                      double currentNewsPage = 0.0;
                      if (_newsPageController.hasClients &&
                          _newsPageController.page != null) {
                        currentNewsPage = _newsPageController.page!;
                      } else {
                        currentNewsPage = _currentNewsPage;
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          newsList.isEmpty ? 1 : newsList.length,
                          (index) {
                            double diff = (index - currentNewsPage).abs();
                            double width = 5.0;
                            double opacity = 0.3;

                            if (diff < 1) {
                              width = 25.0 - (diff * 20.0);
                              opacity = 1.0 - (diff * 0.7);
                            }

                            return Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 2.5),
                              width: width,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(opacity),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _buildPrayerScheduleCard(),
          _buildWeatherCard(),

          const SizedBox(height: 110),
        ],
      ),
    );
  }

  Widget _buildCustomDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      width: MediaQuery.of(context).size.width * 0.55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 180,
            decoration: const BoxDecoration(color: bgMain),
            child: SafeArea(
              child: Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.transparent,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  _buildDrawerMenuItem(
                    icon: Icons.history_rounded,
                    label: "Riwayat Aktivitas",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RiwayatPage(
                            sessionKey: sessionKey,
                            role: role,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildDrawerMenuItem(
                    icon: Icons.logout,
                    label: "Log Out",
                    isLogout: true,
                    onTap: () async {
                      Navigator.pop(context);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isLogout ? accentDeep : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isLogout
            ? [
                BoxShadow(
                  color: accentDeep.withOpacity(0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isLogout ? Colors.white : textSub,
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isLogout ? Colors.white : textMain,
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: isLogout ? Colors.white70 : textSub,
          size: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlobalTouchWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: bgCard.withOpacity(0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accentWhite,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentWhite.withOpacity(0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "SixEyesX",
                  style: TextStyle(
                    color: textMain,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    fontFamily: 'Orbitron',
                    letterSpacing: 2.2,
                  ),
                ),
              ],
            ),
          ),
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: textMain),
          actions: [
            _appBarBtn(
              icon: Icons.logout_rounded,
              tooltip: 'Log Out',
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LandingPage()),
                  (route) => false,
                );
              },
            ),
            _appBarBtn(
              icon: Icons.headset_mic_outlined,
              tooltip: 'Customer Service',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactPage()),
              ),
            ),
            _appBarBtn(
              icon: FaFaIcon(FontAwesomeIcons.userCircle),
              tooltip: 'My Profile',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfilePage(
                    username: username,
                    password: password,
                    role: role,
                    expiredDate: expiredDate,
                    sessionKey: sessionKey,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.transparent,
          child: SafeArea(
            child: FadeTransition(
              opacity: _animation,
              child: _selectedPage,
            ),
          ),
        ),
        extendBody: true,
        bottomNavigationBar: _buildGlazeNavBar(),
      ),
    );
  }

  GlazeNavBarItem _glazeItem({
    required IconData icon,
    required String label,
    required bool active,
    double size = 23,
  }) {
    const activeRed = Color(0xFFE63946);
    return GlazeNavBarItem(
      child: Icon(
        icon,
        color: active ? Colors.white : Colors.white.withOpacity(0.62),
        size: size,
      ),
      label: label,
      labelStyle: TextStyle(
        color: active ? activeRed : Colors.white.withOpacity(0.62),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildGlazeNavBar() {
    const activeRed = Color(0xFFE63946);
    return GlazeNavBar(
      index: _bottomNavIndex,
      backgroundColor: bgMain,
      color: bgElevated,
      glassBlur: 22,
      glassOpacity: 0.28,
      glassBorderRadius: 0,
      glassBorderWidth: 1.2,
      glassBorderColor: Colors.white.withOpacity(0.10),
      buttonBackgroundColor: activeRed,
      buttonBorderColor: Colors.white.withOpacity(0.9),
      buttonBorderWidth: 3.0,
      buttonGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE63946), Color(0xFFB3242E)],
      ),
      animationDuration: const Duration(milliseconds: 600),
      animationCurve: Curves.easeOut,
      onTap: _onBottomNavTapped,
      items: [
        _glazeItem(
          icon: Icons.home_rounded,
          label: 'Home',
          active: _bottomNavIndex == 0,
        ),
        _glazeItem(
          icon: FaFaIcon(FontAwesomeIcons.whatsapp),
          label: 'WA',
          active: _bottomNavIndex == 1,
          size: 20,
        ),
        _glazeItem(
          icon: Icons.notifications_rounded,
          label: 'Info',
          active: _bottomNavIndex == 2,
        ),
        _glazeItem(
          icon: Icons.build_circle,
          label: 'Tools',
          active: _bottomNavIndex == 3,
        ),
      ],
    );
  }

  @override
  void dispose() {
    try {
      _videoController?.pause();
    } catch (_) {}
    _videoController?.dispose();
    _videoController = null;
    _newsTimer?.cancel();
    _prayerTimer?.cancel();
    _newsPageController.dispose();
    channel.sink.close(status.goingAway);
    _controller.dispose();
    super.dispose();
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 168,
        margin: const EdgeInsets.only(right: 12, bottom: 4, top: 2),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161A22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withOpacity(0.28)),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 12, color: Colors.white.withOpacity(0.35)),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Path _buildNotchedNavBarPath(Size size) {
  const double radius = 30;
  const double notchRadius = 34;
  final double centerX = size.width / 2;

  final path = Path();
  path.moveTo(0, radius);
  path.quadraticBezierTo(0, 0, radius, 0);
  path.lineTo(centerX - notchRadius - 6, 0);
  path.arcToPoint(
    Offset(centerX + notchRadius + 6, 0),
    radius: const Radius.circular(notchRadius),
    clockwise: false,
  );
  path.lineTo(size.width - radius, 0);
  path.quadraticBezierTo(size.width, 0, size.width, radius);
  path.lineTo(size.width, size.height - radius);
  path.quadraticBezierTo(
    size.width,
    size.height,
    size.width - radius,
    size.height,
  );
  path.lineTo(radius, size.height);
  path.quadraticBezierTo(0, size.height, 0, size.height - radius);
  path.close();
  return path;
}

class _NotchedNavBarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _buildNotchedNavBarPath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _NotchedNavBarPainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;

  _NotchedNavBarPainter({
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildNotchedNavBarPath(size);

    final shadowPath = path.shift(const Offset(4, 4));
    canvas.drawPath(shadowPath, Paint()..color = Colors.black);

    canvas.drawShadow(
      path.shift(const Offset(0, 6)),
      Colors.black.withOpacity(0.15),
      16,
      false,
    );

    canvas.drawPath(path, Paint()..color = backgroundColor);

    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _NotchedNavBarPainter oldDelegate) =>
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.borderColor != borderColor;
}

class NewsMedia extends StatelessWidget {
  final String url;
  const NewsMedia({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.endsWith(".mp4") ||
        url.endsWith(".webm") ||
        url.endsWith(".mov")) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.videocam_off, color: Colors.grey, size: 50),
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF1C212B),
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      ),
    );
  }
}

class _JustinActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _JustinActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF161A22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.28), width: 1),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFEDEEF2),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF8A8F9A).withOpacity(0.85),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: const Color(0xFF5C6270).withOpacity(0.9), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _JustinWideTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _JustinWideTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0xFF161A22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: color.withOpacity(0.28), width: 1),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFEDEEF2),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: const Color(0xFF8A8F9A).withOpacity(0.85),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: const Color(0xFF5C6270).withOpacity(0.9), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _XeonNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _XeonNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return SizedBox(
      height: 72 + bottom,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 8 + bottom * 0.25),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/nav.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFF13161D)),
              ),
              Container(color: Colors.black.withOpacity(0.42)),
              Row(
                children: [
                  _item(0, Icons.home_rounded, 'Home'),
                  _item(1, FaFaIcon(FontAwesomeIcons.whatsapp), 'WA'),
                  _item(2, Icons.notifications_rounded, 'Info'),
                  _item(3, Icons.build_circle, 'Tools'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int index, IconData icon, String label) {
    final selected = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: selected ? 24 : 22,
              color: selected
                  ? const Color(0xFFE63946)
                  : Colors.white.withOpacity(0.75),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFFE63946)
                    : Colors.white.withOpacity(0.65),
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}