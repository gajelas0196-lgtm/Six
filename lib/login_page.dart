import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:video_player/video_player.dart';
import 'dashboard_page.dart';
import 'splash_video_page.dart';
import 'widgets/custom_popup.dart';
import 'srv.dart';
import 'app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final userController = TextEditingController();
  final passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool _obscurePassword = true;
  String? androidId;

  VideoPlayerController? _videoController;
  bool _videoReady = false;

  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _initAnim();
    _initVideo();
    initLogin();
  }

  void _initAnim() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  Future<void> _initVideo() async {
    try {
      final c = VideoPlayerController.asset('assets/videos/bg_landing.mp4');
      await c.initialize();
      c
        ..setLooping(true)
        ..setVolume(10)
        ..play();
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _videoController = c;
        _videoReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => _videoReady = false);
    }
  }

  Future<void> initLogin() async {
    androidId = await getAndroidId();
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString("username");
    final savedPass = prefs.getString("password");
    final savedKey = prefs.getString("key");

    if (savedUser != null && savedPass != null && savedKey != null) {
      final uri = Uri.parse(
          "${Srv.baseUrl}/myInfo?username=$savedUser&password=$savedPass&androidId=$androidId&key=$savedKey");
      try {
        final res = await http.get(uri);
        final data = jsonDecode(res.body);
        if (data['valid'] == true) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => SplashVideoPage(
                  username: savedUser,
                  nextPage: DashboardPage(
                    username: savedUser,
                    password: savedPass,
                    role: data['role'],
                    sessionKey: data['key'],
                    expiredDate: data['expiredDate'],
                    listBug: (data['listBug'] as List? ?? [])
                        .map((e) => Map<String, dynamic>.from(e as Map))
                        .toList(),
                    listDoos: (data['listDDoS'] as List? ?? [])
                        .map((e) => Map<String, dynamic>.from(e as Map))
                        .toList(),
                    news: (data['news'] as List? ?? [])
                        .map((e) => Map<String, dynamic>.from(e as Map))
                        .toList(),
                  ),
                ),
              ),
            );
          }
        }
      } catch (_) {}
    }
  }

  Future<String> getAndroidId() async {
    final deviceInfo = DeviceInfoPlugin();
    final android = await deviceInfo.androidInfo;
    return android.id ?? "unknown_device";
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;
    final username = userController.text.trim();
    final password = passController.text.trim();
    setState(() => isLoading = true);

    try {
      final validate = await http.post(
        Uri.parse("${Srv.baseUrl}/validate"),
        body: {
          "username": username,
          "password": password,
          "androidId": androidId ?? "unknown_device",
        },
      );
      final validData = jsonDecode(validate.body);

      if (validData['expired'] == true) {
        _showPopup(
          title: "Access Expired",
          message: "Masa akses Anda telah habis.\nSilakan perpanjang akses.",
          showContact: true,
        );
      } else if (validData['valid'] != true) {
        final String errorMsg = (validData['message'] ?? "").toLowerCase();
        if (errorMsg.contains("perangkat") ||
            errorMsg.contains("device") ||
            errorMsg.contains("another")) {
          _showPopup(
            title: "Sesi Aktif",
            message:
                "Akun ini sedang login di perangkat lain.\nSilakan logout di perangkat lama.",
          );
        } else {
          _showPopup(
            title: "Login Gagal",
            message: "Username atau password salah.",
          );
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString("username", username);
        prefs.setString("password", password);
        prefs.setString("key", validData['key']);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SplashVideoPage(
                username: username,
                nextPage: DashboardPage(
                  username: username,
                  password: password,
                  role: validData['role'],
                  sessionKey: validData['key'],
                  expiredDate: validData['expiredDate'],
                  listBug: (validData['listBug'] as List? ?? [])
                      .map((e) => Map<String, dynamic>.from(e as Map))
                      .toList(),
                  listDoos: (validData['listDDoS'] as List? ?? [])
                      .map((e) => Map<String, dynamic>.from(e as Map))
                      .toList(),
                  news: (validData['news'] as List? ?? [])
                      .map((e) => Map<String, dynamic>.from(e as Map))
                      .toList(),
                ),
              ),
            ),
          );
        }
      }
    } catch (e) {
      _showPopup(
        title: "Connection Error",
        message: "Gagal terhubung ke server.",
      );
    }
    setState(() => isLoading = false);
  }

  void _showPopup({
    required String title,
    required String message,
    bool showContact = false,
  }) {
    final bool isError = title.toLowerCase().contains("gagal") ||
        title.toLowerCase().contains("expired") ||
        title.toLowerCase().contains("error");

    CustomPopup.show(
      context,
      title: title,
      message: message,
      icon: isError ? Icons.error_outline : Icons.info_outline,
      iconColor: isError ? AppColors.danger : AppColors.accent,
      cancelText: showContact ? "Contact Admin" : null,
      onCancel: showContact
          ? () async {
              await launchUrl(Uri.parse("https://t.me/xyzyanzzi"),
                  mode: LaunchMode.externalApplication);
            }
          : null,
      confirmText: "Close",
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _videoController?.dispose();
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_videoReady && _videoController != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            )
          else
            Container(color: AppColors.bgDeep),

          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.50),
                    Colors.black.withOpacity(0.75),
                    Colors.black.withOpacity(0.92),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Title
                          ShaderMask(
                            shaderCallback: (rect) => const LinearGradient(
                              colors: [Color(0xFFFFFFFF), Color(0xFFFF8A8A)],
                            ).createShader(rect),
                            child: const Text(
                              'SixEyesX',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.15),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                  color:
                                      AppColors.accent.withOpacity(0.45)),
                            ),
                            child: const Text(
                              'PROJECT',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Banner
                          Container(
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.xl),
                              border: Border.all(
                                  color:
                                      AppColors.accent.withOpacity(0.4),
                                  width: 1.4),
                              boxShadow: AppShadows.glow(AppColors.accent,
                                  blur: 28, opacity: 0.22),
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.xl),
                              child: AspectRatio(
                                aspectRatio: 16 / 10,
                                child: Image.asset(
                                  'assets/images/anjay.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppColors.bgSurface,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.image,
                                        color: AppColors.textMuted, size: 48),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                _buildTextField(
                                  controller: userController,
                                  hint: 'USERNAME',
                                  icon: Icons.person_outline_rounded,
                                ),
                                const SizedBox(height: 14),
                                _buildTextField(
                                  controller: passController,
                                  hint: 'PASSWORD',
                                  icon: Icons.lock_outline_rounded,
                                  isPassword: true,
                                ),
                                const SizedBox(height: 28),
                                _buildLoginButton(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated.withOpacity(0.85),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.softCard,
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        style: const TextStyle(color: AppColors.textMain, fontSize: 15),
        cursorColor: AppColors.accent,
        validator: (v) {
          if (v == null || v.trim().isEmpty) {
            return isPassword ? 'Password wajib diisi' : 'Username wajib diisi';
          }
          return null;
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: Icon(icon, color: AppColors.accent, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textSub,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          errorStyle: const TextStyle(color: AppColors.danger, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return PressableScale(
      onTap: isLoading ? null : login,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppGradients.accent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.glow(AppColors.accent,
              blur: 24, opacity: 0.5),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'LOGIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
        ),
      ),
    );
  }
}