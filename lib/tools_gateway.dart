// ignore_for_file: deprecated_member_use
import 'dart:ui';
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════
// 📦 ALL IMPORTS — CAMPUR SEMUA
// ═══════════════════════════════════════════════════════════
import 'manage_server.dart';
import 'wifi_internal.dart';
import 'wifi_external.dart';
import 'ddos_panel.dart';
import 'nik_check.dart';
import 'tiktok_page.dart';
import 'instagram_page.dart';
import 'qr_gen.dart';
import 'domain_page.dart';
import 'spam_ngl.dart';
import 'riwayat_page.dart';
import 'breach_checker.dart';
import 'web_scanner.dart';
import 'ip_geo.dart';
import 'password_generator.dart';
import 'encoder_tools.dart';
import 'phone_lookup.dart';
import 'snake_game.dart';
import 'game_2048.dart';
import 'text_tools.dart';
import 'fake_identity.dart';
import 'plat_nomor.dart';
import 'converter_page.dart';
import 'url_shortener.dart';
import 'typosquat_checker.dart';
import 'speed_test.dart';
import 'whois_page.dart';
import 'tes_func_page.dart';
import 'deface_page.dart';
import 'amprem_page.dart';
import 'spamotp.dart';        // ← SPAM OTP
import 'iqcxuy.dart';         // ← QUOTE CHAT (IQC)  🔥
import 'ai_chat_page.dart';   // ← SixEyesX AI CHAT

class ToolsPage extends StatefulWidget {
  final String sessionKey;
  final String userRole;
  final List<Map<String, dynamic>> listDoos;

  const ToolsPage({
    super.key,
    required this.sessionKey,
    required this.userRole,
    required this.listDoos,
  });

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  // Ocean blue palette
  static const Color primaryDark = Color(0xFF0A0A0F);
  static const Color cardDark = Color(0xFF14141A);
  static const Color cardDark2 = Color(0xFF12253A);
  static const Color accentBlue = Color(0xFFE53935);
  static const Color lightBlue = Color(0xFFFF8A80);
  static const Color primaryWhite = Colors.white;

  static const Map<String, int> _toolCounts = {
    'DDoS Tools': 2,
    'Network': 4,
    'OSINT': 6,
    'Downloader': 2,
    'Utilities': 6,
    'Security': 7,
    'Games': 2,
    'Converter': 10,
    'Quick Access': 4,
    'Tester': 2,
    'Premium': 1,
  };

  // ═══════════════════════════════════════════════════════════
  // 🎯 HELPER NAVIGATION
  // ═══════════════════════════════════════════════════════════

  /// Buka SixEyesX AI Chat
  void _openAiChat(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiChatPage(username: widget.userRole),
      ),
    );
  }

  /// 🔥 Buka iPhone Quote Chat (IQC)
  void _openIqc(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const IqcPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalTools = _toolCounts.values.fold(0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            // ═════════════════════════════════════════════════
            // TOOLS DASHBOARD HEADER
            // ═════════════════════════════════════════════════
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121218),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.12)),
                      ),
                      child: const Icon(Icons.handyman_rounded,
                          color: Colors.white70, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tools Dashboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Security & OSINT Suite',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ─── TOMBOL PINTASAN IQC ───
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const IqcPage(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF2196F3)
                                  .withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chat_bubble_rounded,
                                color: Color(0xFF2196F3), size: 14),
                            const SizedBox(width: 5),
                            Text(
                              'IQC',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // ─── TOMBOL PINTASAN AI ───
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AiChatPage(username: widget.userRole),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF57A6FF)
                                  .withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.smart_toy_rounded,
                                color: Color(0xFF57A6FF), size: 14),
                            const SizedBox(width: 5),
                            Text(
                              'AI',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$totalTools',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ═════════════════════════════════════════════════
            // CATEGORY GRID
            // ═════════════════════════════════════════════════
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.95,
                children: [
                  _buildToolCard(
                    icon: Icons.flash_on_rounded,
                    title: "DDoS Tools",
                    subtitle: "Attack & Server",
                    colors: const [Color(0xFFB71C1C), Color(0xFFFF1744)],
                    onTap: () => _showDDoSTools(context),
                  ),
                  _buildToolCard(
                    icon: Icons.wifi_tethering_rounded,
                    title: "Network",
                    subtitle: "WiFi & Spam",
                    colors: const [Color(0xFFE65100), Color(0xFFFFAB00)],
                    onTap: () => _showNetworkTools(context),
                  ),
                  _buildToolCard(
                    icon: Icons.manage_search_rounded,
                    title: "OSINT",
                    subtitle: "Investigation",
                    colors: const [Color(0xFFB71C1C), Color(0xFFFF8A80)],
                    onTap: () => _showOSINTTools(context),
                  ),
                  _buildToolCard(
                    icon: Icons.cloud_download_rounded,
                    title: "Downloader",
                    subtitle: "Social Media",
                    colors: const [Color(0xFF006064), Color(0xFFFF5252)],
                    onTap: () => _showDownloaderTools(context),
                  ),
                  _buildToolCard(
                    icon: Icons.handyman_rounded,
                    title: "Utilities",
                    subtitle: "Extra Tools",
                    colors: const [Color(0xFF1B5E20), Color(0xFF69FF47)],
                    onTap: () => _showUtilityTools(context),
                  ),
                  _buildToolCard(
                    icon: Icons.shield_rounded,
                    title: "Security",
                    subtitle: "Breach & Scan",
                    colors: const [Color(0xFFE65100), Color(0xFFFF6D00)],
                    onTap: () => _showSecurityTools(context),
                  ),
                  _buildToolCard(
                    icon: Icons.sports_esports_rounded,
                    title: "Games",
                    subtitle: "Mini Games",
                    colors: const [Color(0xFFF57F17), Color(0xFFFFD600)],
                    onTap: () => _showGames(context),
                  ),
                  _buildToolCard(
                    icon: Icons.transform_rounded,
                    title: "Converter",
                    subtitle: "Text & Units",
                    colors: const [Color(0xFFC62828), Color(0xFFFFAB91)],
                    onTap: () => _showConverterTools(context),
                  ),
                  _buildToolCard(
                    icon: Icons.rocket_launch_rounded,
                    title: "Quick Access",
                    subtitle: "Favorites & History",
                    colors: const [Color(0xFF0D47A1), Color(0xFFFF8A80)],
                    onTap: () => _showQuickAccess(context),
                  ),
                  _buildToolCard(
                    icon: Icons.science_rounded,
                    title: "Tester",
                    subtitle: "TesFunc & Auto Deface",
                    colors: const [Color(0xFFB71C1C), Color(0xFFFFAB91)],
                    onTap: () => _showTesterMenu(context),
                  ),
                  _buildToolCard(
                    icon: Icons.workspace_premium_rounded,
                    title: "Premium",
                    subtitle: "Alight Motion",
                    colors: const [Color(0xFF1A73E8), Color(0xFF4FC3F7)],
                    onTap: () => _openAmpremPage(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎬 PREMIUM PAGE OPENER
  // ═══════════════════════════════════════════════════════════

  void _openAmpremPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AmpremPage()),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 TOOL CARD BUILDER
  // ═══════════════════════════════════════════════════════════

  Widget _buildToolCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.first.withOpacity(0.85),
              colors.last.withOpacity(0.55),
              cardDark.withOpacity(0.95),
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
          border:
              Border.all(color: colors.last.withOpacity(0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: colors.last.withOpacity(0.28),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              top: -18,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.last.withOpacity(0.18),
                ),
              ),
            ),
            Positioned(
              left: -10,
              bottom: -20,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.first.withOpacity(0.12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.last.withOpacity(0.35),
                          colors.first.withOpacity(0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2), width: 1),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'BUKA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 BOTTOM SHEETS MENU
  // ═══════════════════════════════════════════════════════════

  void _showTesterMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _sheetShell(
        context,
        title: "Tester",
        icon: Icons.science_rounded,
        heightFactor: 0.45,
        child: Column(
          children: [
            _buildToolOption(
              icon: Icons.science_outlined,
              label: "TesFunc",
              color: const Color(0xFFFFAB91),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TesFuncPage(
                      username: widget.userRole,
                      sessionKey: widget.sessionKey,
                      role: widget.userRole,
                    ),
                  ),
                );
              },
            ),
            _buildToolOption(
              icon: Icons.code_rounded,
              label: "Auto Deface",
              color: const Color(0xFFFF7043),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DefacePage(
                      sessionKey: widget.sessionKey,
                      userRole: widget.userRole,
                      username: widget.userRole,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickAccess(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _sheetShell(
        context,
        title: "Quick Access",
        icon: Icons.rocket_launch,
        heightFactor: 0.75,
        child: Column(
          children: [
            _buildToolOption(
              icon: Icons.history_rounded,
              label: "Riwayat Aktivitas",
              color: lightBlue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RiwayatPage(
                        sessionKey: widget.sessionKey, role: widget.userRole),
                  ),
                );
              },
            ),
            // 🔥 IQC di Quick Access
            _buildToolOption(
              icon: Icons.chat_bubble_rounded,
              label: "Quote Chat (iPhone)",
              color: const Color(0xFF2196F3),
              onTap: () => _openIqc(context),
            ),
            // 🔥 AI CHAT di Quick Access
            _buildToolOption(
              icon: Icons.smart_toy_rounded,
              label: "SixEyesX AI Chat",
              color: const Color(0xFF57A6FF),
              onTap: () => _openAiChat(context),
            ),
            _buildToolOption(
              icon: Icons.star,
              label: "Favorites (Coming Soon)",
              color: lightBlue,
              onTap: () => _showComingSoon(context),
            ),
            _buildToolOption(
              icon: Icons.settings,
              label: "Settings (Coming Soon)",
              color: lightBlue,
              onTap: () => _showComingSoon(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showDDoSTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _sheetShell(
        context,
        title: "DDoS Tools",
        icon: Icons.flash_on,
        child: Column(
          children: [
            _buildToolOption(
              icon: Icons.flash_on,
              label: "Attack Panel",
              color: const Color(0xFFFF5252),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AttackPanel(
                        sessionKey: widget.sessionKey,
                        listDoos: widget.listDoos),
                  ),
                );
              },
            ),
            _buildToolOption(
              icon: Icons.dns,
              label: "Manage Server",
              color: lightBlue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ManageServerPage(keyToken: widget.sessionKey),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNetworkTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _sheetShell(
        context,
        title: "Network Tools",
        icon: Icons.wifi,
        heightFactor: 0.75,
        child: Column(
          children: [
            _buildToolOption(
              icon: Icons.newspaper_outlined,
              label: "Spam NGL",
              color: lightBlue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NglPage()));
              },
            ),
            // 🔥 SPAM OTP
            _buildToolOption(
              icon: Icons.sms_failed_rounded,
              label: "Spam OTP",
              color: const Color(0xFFFF5252),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SpamOTPApp(),
                  ),
                );
              },
            ),
            _buildToolOption(
              icon: Icons.wifi_off,
              label: "WiFi Killer (Internal)",
              color: lightBlue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WifiKillerPage()));
              },
            ),
            if (widget.userRole == "vip" || widget.userRole == "owner")
              _buildToolOption(
                icon: Icons.router,
                label: "WiFi Killer (External)",
                color: lightBlue,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          WifiInternalPage(sessionKey: widget.sessionKey),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showOSINTTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _sheetShell(
        context,
        title: "OSINT Tools",
        icon: Icons.search,
        heightFactor: 0.85,
        child: Column(
          children: [
            _buildToolOption(
              icon: Icons.badge,
              label: "NIK Detail",
              color: lightBlue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NikCheckerPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.domain,
              label: "Domain OSINT",
              color: lightBlue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DomainOsintPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.phone_android,
              label: "Phone Lookup",
              color: lightBlue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PhoneLookupPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.manage_search,
              label: "WHOIS Lookup",
              color: lightBlue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WhoisPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.find_replace,
              label: "Typosquat Checker",
              color: lightBlue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TyposquatPage()));
              },
            ),
            // 🔥 AI CHAT di OSINT
            _buildToolOption(
              icon: Icons.smart_toy_rounded,
              label: "AI Chat",
              color: const Color(0xFF57A6FF),
              onTap: () => _openAiChat(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showDownloaderTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _sheetShell(
        context,
        title: "Media Downloader",
        icon: Icons.download,
        heightFactor: 0.55,
        child: Column(
          children: [
            _buildToolOption(
              icon: Icons.video_library,
              label: "TikTok Downloader",
              color: lightBlue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TiktokDownloaderPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.camera_alt,
              label: "Instagram Downloader",
              color: lightBlue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const InstagramDownloaderPage()));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUtilityTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _sheetShell(
        context,
        title: "Utility Tools",
        icon: Icons.build,
        heightFactor: 0.85,
        child: Column(
          children: [
            _buildToolOption(
              icon: Icons.qr_code,
              label: "QR Generator",
              color: lightBlue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const QrGeneratorPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.public,
              label: "IP Geolocation",
              color: lightBlue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const IpGeoPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.speed,
              label: "Speed Test",
              color: lightBlue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SpeedTestPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.password,
              label: "Password Generator",
              color: lightBlue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PasswordGeneratorPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.link,
              label: "URL Shortener",
              color: lightBlue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const UrlShortenerPage()));
              },
            ),
            // 🔥 AI CHAT di Utilities
            _buildToolOption(
              icon: Icons.smart_toy_rounded,
              label: "AI Chat",
              color: const Color(0xFF57A6FF),
              onTap: () => _openAiChat(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showSecurityTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _sheetShell(
        ctx,
        title: "Security Tools",
        icon: Icons.shield,
        heightFactor: 0.85,
        child: Column(
          children: [
            _buildToolOption(
              icon: Icons.radar,
              label: "Breach Checker",
              color: lightBlue,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                    ctx,
                    MaterialPageRoute(
                        builder: (_) => const BreachCheckerPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.scanner,
              label: "Web Scanner",
              color: lightBlue,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const WebScannerPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.public,
              label: "IP Geolocation",
              color: lightBlue,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const IpGeoPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.find_replace,
              label: "Typosquat Checker",
              color: const Color(0xFFFFD600),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const TyposquatPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.manage_search,
              label: "WHOIS Lookup",
              color: const Color(0xFF00FF41),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const WhoisPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.speed,
              label: "Speed Test",
              color: lightBlue,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const SpeedTestPage()));
              },
            ),
            // 🔥 AI CHAT di Security
            _buildToolOption(
              icon: Icons.smart_toy_rounded,
              label: "AI Chat",
              color: const Color(0xFF57A6FF),
              onTap: () => _openAiChat(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showGames(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _sheetShell(
        ctx,
        title: "Mini Games",
        icon: Icons.sports_esports,
        heightFactor: 0.5,
        child: Column(
          children: [
            _buildToolOption(
              icon: Icons.sports_esports,
              label: "Snake Game",
              color: accentBlue,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const SnakeGamePage()));
              },
            ),
            _buildToolOption(
              icon: Icons.grid_4x4,
              label: "2048 Game",
              color: const Color(0xFFFFD700),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const Game2048Page()));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showConverterTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _sheetShell(
        ctx,
        title: "Converter & Tools",
        icon: Icons.transform,
        heightFactor: 0.9,
        child: Column(
          children: [
            _buildToolOption(
              icon: Icons.currency_exchange,
              label: "Mata Uang & Satuan",
              color: lightBlue,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const ConverterPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.text_fields,
              label: "Text Tools",
              color: lightBlue,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const TextToolsPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.lock,
              label: "Encoder / Hash",
              color: const Color(0xFF00FF41),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const EncoderToolsPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.password,
              label: "Password Generator",
              color: lightBlue,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                    ctx,
                    MaterialPageRoute(
                        builder: (_) => const PasswordGeneratorPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.link,
              label: "URL Shortener",
              color: lightBlue,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const UrlShortenerPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.person_add,
              label: "Fake Identity Generator",
              color: lightBlue,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const FakeIdentityPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.phone_android,
              label: "Phone Lookup",
              color: lightBlue,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const PhoneLookupPage()));
              },
            ),
            _buildToolOption(
              icon: Icons.directions_car,
              label: "Cek Plat Nomor",
              color: Colors.amber,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const PlatNomorPage()));
              },
            ),
            // 🔥 QUOTE CHAT (IQC) DI CONVERTER
            _buildToolOption(
              icon: Icons.chat_bubble_rounded,
              label: "Quote Chat (iPhone)",
              color: const Color(0xFF2196F3),
              onTap: () => _openIqc(ctx),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 UI COMPONENTS
  // ═══════════════════════════════════════════════════════════

  Widget _sheetShell(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
    double heightFactor = 0.7,
  }) {
    return Container(
      height: MediaQuery.of(context).size.height * heightFactor,
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border.all(color: accentBlue.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: accentBlue.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFC62828), Color(0xFFE53935)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.12),
            cardDark,
          ],
        ),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          label,
          style: const TextStyle(
            color: primaryWhite,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.arrow_forward_ios, color: color, size: 12),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.hourglass_top, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Feature Coming Soon!',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: accentBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}