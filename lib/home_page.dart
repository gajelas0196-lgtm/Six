import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'widgets/custom_popup.dart';
import 'srv.dart';
import 'app_theme.dart';

class HomePage extends StatefulWidget {
  final String username;
  final String password;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final String role;
  final String expiredDate;

  const HomePage({
    super.key,
    required this.username,
    required this.password,
    required this.sessionKey,
    required this.listBug,
    required this.role,
    required this.expiredDate,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final targetController = TextEditingController();
  late AnimationController _pulseController;
  String selectedBugId = "";
  VideoPlayerController? _videoController;
  FixedExtentScrollController? _wheelController;

  String _selectedBugMode = "number";
  String _senderMode = "private";
  int _privateSenderCount = 0;
  int _globalSenderCount = 0;
  bool _isSending = false;

  // --- TEMA (alias dari Design System) ---
  static const Color bgMain = AppColors.bgMain;
  static const Color bgSurface = AppColors.bgSurface;
  static const Color bgCard = AppColors.bgCard;
  static const Color textMain = AppColors.textMain;
  static const Color textSub = AppColors.textSub;
  static const Color accentColor = AppColors.accent;
  static const Color borderLight = AppColors.accentSoft;
  static const Color selectGreen = AppColors.success;

  @override
  void initState() {
    super.initState();

    _initBannerVideo();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    if (widget.listBug.isNotEmpty) {
      final initialBugs = _getFilteredBugs();
      if (initialBugs.isNotEmpty) {
        selectedBugId = initialBugs[0]['bug_id'];
        _wheelController = FixedExtentScrollController(initialItem: 0);
      }
    }

    _fetchSenderStats();
  }

  Future<void> _initBannerVideo() async {
    try {
      final ctrl = VideoPlayerController.asset('assets/videos/bug.mp4');
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      await ctrl.setLooping(true);
      await ctrl.setVolume(1.0);
      await ctrl.seekTo(Duration.zero);
      await ctrl.play();
      setState(() => _videoController = ctrl);
    } catch (e) {
      debugPrint('home banner video: $e');
    }
  }

  List<Map<String, dynamic>> _getFilteredBugs() {
    if (_selectedBugMode == "group") {
      return widget.listBug
          .where((b) => b['bug_id'].contains('_group'))
          .toList();
    } else {
      return widget.listBug
          .where((b) => !b['bug_id'].contains('_group'))
          .toList();
    }
  }

  Future<void> _fetchSenderStats() async {
    try {
      final res = await http.get(Uri.parse(
          "${Srv.baseUrl}/getSenderStats?key=${widget.sessionKey}"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['valid'] == true) {
          setState(() {
            _privateSenderCount = data['private'] ?? 0;
            _globalSenderCount = data['global'] ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching sender stats: $e");
    }
  }

  @override
  void dispose() {
    try {
      _videoController?.pause();
    } catch (_) {}
    _videoController?.dispose();
    _videoController = null;
    _pulseController.dispose();
    _wheelController?.dispose();
    targetController.dispose();
    super.dispose();
  }

  String? formatPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleaned.startsWith('') || cleaned.length < 8) return null;
    return cleaned;
  }

  bool isValidGroupLink(String input) {
    return input.contains('chat.whatsapp.com') && input.contains('https://');
  }

  Future<void> _sendBug() async {
    final rawInput = targetController.text.trim();
    final key = widget.sessionKey;

    if (_selectedBugMode == "number") {
      final target = formatPhoneNumber(rawInput);
      if (target == null || key.isEmpty) {
        _showAlert("Invalid Number",
            "Gunakan nomor internasional (misal: +62, 1, 44), bukan 08xxx.");
        return;
      }
    } else {
      if (!isValidGroupLink(rawInput)) {
        _showAlert("Invalid Link",
            "Masukkan link group WA yang valid (contoh: https://chat.whatsapp.com/...).");
        return;
      }
    }

    final currentBugs = _getFilteredBugs();
    if (!currentBugs.any((b) => b['bug_id'] == selectedBugId)) {
      if (currentBugs.isNotEmpty) {
        setState(() {
          selectedBugId = currentBugs[0]['bug_id'];
        });
      } else {
        _showAlert("Error", "Tidak ada bug tersedia untuk mode ini.");
        return;
      }
    }

    setState(() => _isSending = true);

    final effectiveSenderMode = (widget.role == 'moderator')
        ? 'private'
        : ((widget.role == 'developer' ||
                widget.role == 'owner' ||
                widget.role == 'vip')
            ? _senderMode
            : 'private');

    try {
      final res = await http.get(Uri.parse(
          "${Srv.baseUrl}/sendBug?key=$key&target=$rawInput&bug=$selectedBugId&senderMode=$effectiveSenderMode"));
      final data = jsonDecode(res.body);

      if (data["cooldown"] == true) {
        _showAlert(
            "⏳ Cooldown", "Tunggu beberapa saat sebelum mengirim lagi.");
      } else if (data["valid"] == false) {
        _showAlert(
            "❌ Key Invalid", "Sesi Anda tidak valid. Silakan login ulang.");
      } else if (data["sended"] == false) {
        _showAlert(
            "⚠️ Gagal", "Server sedang maintenance atau terjadi kegagalan.");
      } else {
        _showAlert("✅ Berhasil", "Bug sukses dikirim ke target!");
        targetController.clear();
        _fetchSenderStats();
      }
    } catch (_) {
      _showAlert(
          "❌ Error", "Terjadi kesalahan pada sistem. Coba lagi nanti.");
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showAlert(String title, String msg) {
    if (!mounted) return;
    final isSuccess = title.contains("✅") ||
        title.toLowerCase().contains('berhasil') ||
        msg.toLowerCase().contains('sukses') ||
        msg.toLowerCase().contains('berhasil');

    if (isSuccess) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
              decoration: BoxDecoration(
                gradient: AppGradients.card,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: AppColors.success.withOpacity(0.55),
                  width: 1.5,
                ),
                boxShadow: AppShadows.glow(AppColors.success,
                    blur: 30, opacity: 0.35),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00E676), Color(0xFF00C853)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: AppShadows.glow(AppColors.success,
                          blur: 24, opacity: 0.55),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFF69F0AE)],
                    ).createShader(rect),
                    child: const Text(
                      'SUCCESS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    msg.replaceAll('✅', '').trim().isEmpty
                        ? 'Bug berhasil dikirim ke target!'
                        : msg.replaceAll('✅', '').trim(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSub,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  PressableScale(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E676), Color(0xFF00C853)],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: AppShadows.glow(AppColors.success,
                            blur: 14, opacity: 0.4),
                      ),
                      child: const Center(
                        child: Text(
                          'OK',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    CustomPopup.show(
      context,
      title: title,
      message: msg,
      icon: Icons.error_outline,
      iconColor: Colors.redAccent,
      confirmText: "Close",
    );
  }

  Widget _buildAccountOverlay() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.bgSurface, AppColors.bgMain],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.play_circle_outline,
              color: AppColors.textMuted, size: 40),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child: VideoPlayer(_videoController!),
        ),
      ),
    );
  }

  /// Widget info di atas video — Modern profile bar
  Widget _buildUserInfoBar() {
    final roleLower = widget.role.toLowerCase();
    final isDev = roleLower == 'developer' || roleLower == 'owner';
    final badgeColor = isDev ? const Color(0xFF40C4FF) : AppColors.accent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.softCard,
      ),
      child: Row(
        children: [
          // Avatar + badge centang
          SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        badgeColor.withOpacity(0.35),
                        badgeColor.withOpacity(0.10),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: badgeColor.withOpacity(0.75),
                      width: 1.6,
                    ),
                    boxShadow: AppShadows.glow(badgeColor,
                        blur: 12, opacity: 0.3),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: badgeColor,
                      border: Border.all(
                          color: AppColors.bgCard, width: 1.6),
                      boxShadow: AppShadows.glow(badgeColor, blur: 8),
                    ),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    widget.role.toUpperCase(),
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // EXP di kanan
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border:
                  Border.all(color: AppColors.accent.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'EXP',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.expiredDate.isEmpty ? '-' : widget.expiredDate,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _cleanBugName(String bugName) {
    return bugName
        .replaceAll(RegExp(r'^bug_|_group$'), '')
        .replaceAll('_', ' ')
        .toUpperCase();
  }

  Widget _buildSelectionButton({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: AppGradients.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.softCard,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.14),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border:
                    Border.all(color: AppColors.accent.withOpacity(0.35)),
              ),
              child: Icon(icon, color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.accent, size: 22),
          ],
        ),
      ),
    );
  }

  void _showTargetTypePopup() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppGradients.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 1.4),
            boxShadow: AppShadows.softCard,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded,
                        color: AppColors.accent, size: 20),
                    SizedBox(width: 10),
                    Text(
                      "PILIH MODE TARGET",
                      style: TextStyle(
                        color: AppColors.textMain,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              _buildPopupOption(
                label: "BUG NOMOR",
                isSelected: _selectedBugMode == "number",
                onTap: () {
                  setState(() {
                    _selectedBugMode = "number";
                    targetController.clear();
                    final newBugs = _getFilteredBugs();
                    if (newBugs.isNotEmpty) {
                      selectedBugId = newBugs[0]['bug_id'];
                    }
                  });
                  Navigator.pop(ctx);
                  _wheelController?.animateToItem(
                    0,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildPopupOption(
                label: "BUG GROUP",
                isSelected: _selectedBugMode == "group",
                onTap: () {
                  setState(() {
                    _selectedBugMode = "group";
                    targetController.clear();
                    final newBugs = _getFilteredBugs();
                    if (newBugs.isNotEmpty) {
                      selectedBugId = newBugs[0]['bug_id'];
                    }
                  });
                  Navigator.pop(ctx);
                  _wheelController?.animateToItem(
                    0,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [
                  AppColors.accent.withOpacity(0.22),
                  AppColors.accent.withOpacity(0.08),
                ])
              : null,
          color: isSelected ? null : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? AppShadows.glow(AppColors.accent,
                  blur: 12, opacity: 0.3)
              : null,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.accent : AppColors.textMain,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildModernWheelPicker(List<Map<String, dynamic>> availableBugs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            "SELECT PAYLOAD",
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
              letterSpacing: 1.6,
            ),
          ),
        ),
        Container(
          height: 116,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: AppGradients.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.softCard,
          ),
          child: Stack(
            children: [
              ListWheelScrollView.useDelegate(
                controller: _wheelController,
                itemExtent: 32,
                diameterRatio: 6.0,
                perspective: 0.001,
                offAxisFraction: 0,
                physics: const BouncingScrollPhysics(),
                useMagnifier: false,
                magnification: 1.0,
                onSelectedItemChanged: (index) {
                  setState(() {
                    selectedBugId = availableBugs[index]['bug_id'];
                  });
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: availableBugs.length,
                  builder: (context, index) {
                    final bug = availableBugs[index];
                    final isSelected = bug['bug_id'] == selectedBugId;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _cleanBugName(bug['bug_name'] ?? 'Unknown'),
                          textAlign: TextAlign.left,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.textSub.withOpacity(0.45),
                            fontSize: isSelected ? 14 : 11,
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.w400,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 26,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.bgCard.withOpacity(0.0),
                          AppColors.bgCard.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (widget.role == 'developer' ||
            widget.role == 'owner' ||
            widget.role == 'vip' ||
            widget.role == 'moderator') ...[
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              "SENDER MODE",
              style: TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
                letterSpacing: 1.6,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildSenderModeButton(
                  label: "PRIVATE",
                  icon: Icons.lock_person_rounded,
                  count: _privateSenderCount,
                  isSelected: _senderMode == 'private',
                  onTap: () => setState(() => _senderMode = 'private'),
                ),
              ),
              if (widget.role != 'moderator') ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSenderModeButton(
                    label: "GLOBAL",
                    icon: Icons.public_rounded,
                    count: _globalSenderCount,
                    isSelected: _senderMode == 'global',
                    onTap: () => setState(() => _senderMode = 'global'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSenderModeButton({
    required String label,
    required IconData icon,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final color = label == 'GLOBAL' ? AppColors.danger : AppColors.accent;

    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    color.withOpacity(0.28),
                    color.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : AppGradients.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? AppShadows.glow(color, blur: 14, opacity: 0.35)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isSelected
                      ? [color, color.withOpacity(0.7)]
                      : [
                          Colors.white.withOpacity(0.08),
                          Colors.white.withOpacity(0.03),
                        ],
                ),
                boxShadow: isSelected
                    ? AppShadows.glow(color, blur: 10, opacity: 0.45)
                    : null,
              ),
              child: Icon(icon,
                  color: isSelected ? Colors.white : AppColors.textSub,
                  size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? color : AppColors.textSub,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count sender aktif',
                    style: TextStyle(
                      color: isSelected
                          ? color.withOpacity(0.85)
                          : AppColors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildInputPanel() {
    final availableBugs = _getFilteredBugs();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTargetModeTabs(),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            _selectedBugMode == "number"
                ? "TARGET NUMBER"
                : "WHATSAPP GROUP LINK",
            style: const TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
              letterSpacing: 1.6,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgElevated.withOpacity(0.85),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.softCard,
          ),
          child: TextField(
            controller: targetController,
            style: const TextStyle(
                color: AppColors.textMain, fontSize: 15),
            cursorColor: AppColors.accent,
            keyboardType: _selectedBugMode == "number"
                ? TextInputType.phone
                : TextInputType.url,
            decoration: InputDecoration(
              hintText: _selectedBugMode == "number"
                  ? "e.g. +628xxxxxxxx"
                  : "e.g. https://chat.whatsapp.com/...",
              hintStyle: TextStyle(
                  color: AppColors.textMuted.withOpacity(0.7),
                  fontSize: 13.5),
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              prefixIcon: Icon(
                _selectedBugMode == "number"
                    ? Icons.phone_android_rounded
                    : Icons.link_rounded,
                color: AppColors.accent,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 18, horizontal: 16),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildPayloadList(availableBugs),
      ],
    );
  }

  Widget _buildTargetModeTabs() {
    return Row(
      children: [
        Expanded(
          child: _modeTab(
            label: 'Number',
            icon: Icons.person_rounded,
            selected: _selectedBugMode == 'number',
            onTap: () {
              setState(() {
                _selectedBugMode = 'number';
                targetController.clear();
                final bugs = _getFilteredBugs();
                if (bugs.isNotEmpty) selectedBugId = bugs[0]['bug_id'];
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _modeTab(
            label: 'Group',
            icon: Icons.groups_rounded,
            selected: _selectedBugMode == 'group',
            onTap: () {
              setState(() {
                _selectedBugMode = 'group';
                targetController.clear();
                final bugs = _getFilteredBugs();
                if (bugs.isNotEmpty) selectedBugId = bugs[0]['bug_id'];
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _modeTab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: selected ? AppGradients.accent : null,
          color: selected ? null : AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.border,
            width: 1,
          ),
          boxShadow: selected
              ? AppShadows.glow(AppColors.accent,
                  blur: 18, opacity: 0.4)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: selected ? Colors.white : AppColors.textSub,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSub,
                fontWeight:
                    selected ? FontWeight.w900 : FontWeight.w600,
                fontSize: 12.5,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayloadList(List<Map<String, dynamic>> availableBugs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            "BUG TYPE / PAYLOAD",
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
              letterSpacing: 1.6,
            ),
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            gradient: AppGradients.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.softCard,
          ),
          child: availableBugs.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Tidak ada payload',
                      style: TextStyle(color: AppColors.textSub),
                    ),
                  ),
                )
              : ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    physics: const BouncingScrollPhysics(
                      decelerationRate: ScrollDecelerationRate.normal,
                    ),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(10),
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: availableBugs.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final bug = availableBugs[index];
                      final id = bug['bug_id']?.toString() ?? '';
                      final name = _cleanBugName(
                          bug['bug_name']?.toString() ?? 'Unknown');
                      final selected = id == selectedBugId;
                      final isIos = id.toLowerCase().contains('ios') ||
                          name.toLowerCase().contains('ios');

                      return GestureDetector(
                        onTap: () =>
                            setState(() => selectedBugId = id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: selected
                                ? LinearGradient(colors: [
                                    AppColors.accent.withOpacity(0.22),
                                    AppColors.accent.withOpacity(0.08),
                                  ])
                                : null,
                            color: selected
                                ? null
                                : AppColors.bgElevated.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(
                                AppRadius.sm),
                            border: Border.all(
                              color: selected
                                  ? AppColors.accent
                                  : AppColors.border,
                              width: selected ? 1.5 : 1,
                            ),
                            boxShadow: selected
                                ? AppShadows.glow(AppColors.accent,
                                    blur: 12, opacity: 0.3)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isIos
                                    ? Icons.phone_iphone_rounded
                                    : Icons.android_rounded,
                                color: selected
                                    ? AppColors.accent
                                    : AppColors.textSub,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected
                                        ? AppColors.accent
                                        : AppColors.textMain,
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                color: selected
                                    ? AppColors.accent
                                    : AppColors.textMuted,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(height: 16),
        if (widget.role == 'developer' ||
            widget.role == 'owner' ||
            widget.role == 'vip' ||
            widget.role == 'moderator') ...[
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              "SENDER MODE",
              style: TextStyle(
                color: AppColors.textMain,
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
                letterSpacing: 1.6,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildSenderModeButton(
                  label: "PRIVATE",
                  icon: Icons.lock_person_rounded,
                  count: _privateSenderCount,
                  isSelected: _senderMode == 'private',
                  onTap: () => setState(() => _senderMode = 'private'),
                ),
              ),
              if (widget.role != 'moderator') ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSenderModeButton(
                    label: "GLOBAL",
                    icon: Icons.public_rounded,
                    count: _globalSenderCount,
                    isSelected: _senderMode == 'global',
                    onTap: () => setState(() => _senderMode = 'global'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSendButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return PressableScale(
          onTap: _isSending ? null : _sendBug,
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              gradient: AppGradients.accent,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.accentSoft.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(
                      0.30 + 0.30 * _pulseController.value),
                  blurRadius: 20 + 12 * _pulseController.value,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: _isSending
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.rocket_launch_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          "LAUNCH ATTACK",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 2.2,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info akun lonjong di atas video
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _buildUserInfoBar(),
                ),
                const SizedBox(height: 14),
                // Video dengan lengkungan + glow border
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppRadius.xl),
                      border: Border.all(
                        color: AppColors.accent.withOpacity(0.35),
                        width: 1.3,
                      ),
                      boxShadow: AppShadows.glow(AppColors.accent,
                          blur: 24, opacity: 0.22),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppRadius.xl),
                      child: SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: _buildAccountOverlay(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _buildInputPanel(),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _buildSendButton(),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}