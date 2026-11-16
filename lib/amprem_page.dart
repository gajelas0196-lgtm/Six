import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'srv.dart';
// ==================== CUSTOM BLUE THEME COLORS ====================
class AppColors {
  static const Color primaryBlue = Color(0xFF1A73E8);
  static const Color primaryLight = Color(0xFFE8F0FE);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color secondaryBlue = Color(0xFF4FC3F7);
  static const Color accentBlue = Color(0xFF00BCD4);
  static const Color successGreen = Color(0xFF34A853);
  static const Color warningYellow = Color(0xFFFBBC04);
  static const Color errorRed = Color(0xFFEA4335);
  
  static const Color grey950 = Color(0xFF0A1628);
  static const Color grey900 = Color(0xFF0F1E3A);
  static const Color grey800 = Color(0xFF1A2D4A);
  static const Color grey700 = Color(0xFF2A3F5A);
  static const Color grey600 = Color(0xFF4A5F7A);
  static const Color grey500 = Color(0xFF7A8FA0);
  static const Color grey400 = Color(0xFFA0B5C8);
  static const Color grey300 = Color(0xFFC8D8E8);
  static const Color grey200 = Color(0xFFE0ECF8);
  static const Color grey100 = Color(0xFFF0F6FE);
  static const Color grey50 = Color(0xFFF8FAFF);
}

// ==================== MAIN APP ====================
class AmpremPage extends StatefulWidget {
  const AmpremPage({super.key});

  @override
  State<AmpremPage> createState() => _AmpremPageState();
}

class _AmpremPageState extends State<AmpremPage> with SingleTickerProviderStateMixin {
  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _magicLinkController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  // States
  bool _isLoading = false;
  bool _isVerified = false;
  bool _isEmailSent = false;
  bool _isDarkMode = false;
  bool _isOpeningAlight = false;
  String _statusMessage = '';
  Color _statusColor = AppColors.primaryBlue;
  int _retryCount = 0;
  String _deviceId = '';
  String _appVersion = '19.0.0';
  
  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  
  // Premium Data
  Map<String, dynamic> _premiumData = {};
  
  // Base URL
  final String baseUrl = 'https://satriam.satriadeveloperz.workers.dev';
  
  Timer? _autoRefreshTimer;
  Timer? _countdownTimer;
  int _countdown = 0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initDeviceInfo();
    _checkSavedSession();
    _checkThemePreference();
    _startPeriodicCheck();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _animationController.forward();
  }

  Future<void> _initDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Theme.of(context).platform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        setState(() {
          _deviceId = androidInfo.id ?? 'unknown_android';
        });
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        setState(() {
          _deviceId = iosInfo.identifierForVendor ?? 'unknown_ios';
        });
      } else {
        setState(() {
          _deviceId = 'unknown_device';
        });
      }
    } catch (e) {
      setState(() {
        _deviceId = 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
      });
    }
  }

  Future<void> _checkThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _toggleTheme() async {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _checkSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString('premium_data');
      
      if (savedData != null) {
        final data = json.decode(savedData);
        final expiry = DateTime.tryParse(data['validUntil'] ?? '');
        
        if (expiry != null && expiry.isAfter(DateTime.now())) {
          setState(() {
            _isVerified = true;
            _premiumData = data;
          });
        } else {
          await prefs.remove('premium_data');
          await prefs.remove('premium_email');
        }
      }
    } catch (e) {
      // Handle error
    }
  }

  void _startPeriodicCheck() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted && _isVerified) {
        _checkSessionValidity();
      }
    });
  }

  Future<void> _checkSessionValidity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString('premium_data');
      
      if (savedData != null) {
        final data = json.decode(savedData);
        final expiry = DateTime.tryParse(data['validUntil'] ?? '');
        
        if (expiry != null && expiry.isBefore(DateTime.now())) {
          await prefs.remove('premium_data');
          if (mounted) {
            setState(() {
              _isVerified = false;
              _premiumData = {};
              _statusMessage = '⚠️ Sesi premium telah berakhir';
              _statusColor = AppColors.warningYellow;
            });
          }
        }
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _magicLinkController.dispose();
    _animationController.dispose();
    _autoRefreshTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ==================== API FUNCTIONS ====================
  
  Future<void> _requestMagicLink() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _statusMessage = '';
      _retryCount = 0;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/satriam/send-link'),
        headers: _getHeaders(),
        body: json.encode({
          'email': _emailController.text.trim(),
          'deviceId': _deviceId,
          'appVersion': _appVersion,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        setState(() {
          _isEmailSent = true;
          _statusMessage = '✅ Magic link berhasil dikirim! Cek email Anda';
          _statusColor = AppColors.successGreen;
          _isLoading = false;
          _countdown = 60;
        });
        
        _showNotification('Magic link terkirim! 📨', AppColors.primaryBlue);
        _startAutoRefresh();
        _startCountdown();
      } else {
        _handleError(data['message'] ?? 'Gagal mengirim magic link');
      }
    } on TimeoutException {
      _handleError('Timeout - Server tidak merespons');
    } catch (e) {
      _handleError(e.toString());
    }
  }

  Future<void> _verifyMagicLink() async {
    if (_emailController.text.isEmpty || _magicLinkController.text.isEmpty) {
      _showNotification('Email dan Magic Link harus diisi!', AppColors.warningYellow);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/satriam/verify-link'),
        headers: _getHeaders(),
        body: json.encode({
          'email': _emailController.text.trim(),
          'magicLink': _magicLinkController.text.trim(),
          'deviceId': _deviceId,
          'appVersion': _appVersion,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        _handleVerificationSuccess(data);
      } else {
        _handleError(data['message'] ?? 'Gagal verifikasi magic link');
      }
    } on TimeoutException {
      _handleError('Timeout - Server tidak merespons');
    } catch (e) {
      _handleError(e.toString());
    }
  }

  // ==================== ALIGHT MOTION FUNCTIONS ====================
  
  Future<void> _openAlightMotion() async {
    setState(() {
      _isOpeningAlight = true;
    });

    try {
      // Coba buka Alight Motion dengan URL Scheme
      final alightUrl = Uri.parse('alightmotion://');
      
      if (await canLaunchUrl(alightUrl)) {
        await launchUrl(alightUrl, mode: LaunchMode.externalApplication);
        _showNotification('Membuka Alight Motion... 🎬', AppColors.primaryBlue);
      } else {
        // Jika tidak terinstall, buka Play Store
        final playStoreUrl = Uri.parse(
          'https://play.google.com/store/apps/details?id=com.alightcreative.motion'
        );
        if (await canLaunchUrl(playStoreUrl)) {
          await launchUrl(playStoreUrl, mode: LaunchMode.externalApplication);
          _showNotification('Download Alight Motion di Play Store', AppColors.warningYellow);
        } else {
          _showNotification('Gagal membuka Alight Motion', AppColors.errorRed);
        }
      }
    } catch (e) {
      // Fallback: Buka Play Store
      try {
        final playStoreUrl = Uri.parse(
          'https://play.google.com/store/apps/details?id=com.alightcreative.motion'
        );
        if (await canLaunchUrl(playStoreUrl)) {
          await launchUrl(playStoreUrl, mode: LaunchMode.externalApplication);
          _showNotification('Download Alight Motion di Play Store', AppColors.warningYellow);
        }
      } catch (e2) {
        _showNotification('Gagal membuka Alight Motion', AppColors.errorRed);
      }
    }

    setState(() {
      _isOpeningAlight = false;
    });
  }

  // ==================== HELPER FUNCTIONS ====================
  
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'User-Agent': 'SixEyesX/$_appVersion (${Theme.of(context).platform.name}; ${_deviceId.substring(0, 8)})',
      'Accept': 'application/json, text/plain, */*',
      'X-Device-ID': _deviceId,
      'X-App-Version': _appVersion,
      'X-Platform': Theme.of(context).platform.name,
    };
  }

  void _handleVerificationSuccess(Map<String, dynamic> data) {
    final premiumData = {
      'email': data['email'] ?? _emailController.text.trim(),
      'uid': data['uid'] ?? _generateUID(),
      'displayName': data['displayName'] ?? 'SixEyesX User',
      'membershipStatus': data['membershipStatus'] ?? 'PREMIUM_ACTIVE',
      'planName': data['planName'] ?? 'Alight Motion Premium Pro',
      'orderId': data['orderId'] ?? 'AM-${DateTime.now().millisecondsSinceEpoch}',
      'validUntil': data['validUntil'] ?? _getLifetimeDate(),
      'features': data['features'] ?? _getDefaultFeatures(),
      'premium': true,
      'activatedAt': DateTime.now().toIso8601String(),
      'deviceId': _deviceId,
      'appVersion': _appVersion,
    };

    setState(() {
      _isVerified = true;
      _isEmailSent = false;
      _statusMessage = '🎉 Premium berhasil diaktifkan!';
      _statusColor = AppColors.successGreen;
      _isLoading = false;
      _premiumData = premiumData;
      _countdown = 0;
    });
    
    _savePremiumData(premiumData);
    _showNotification('🎉 Selamat! Premium aktif!', AppColors.successGreen);
    
    _animationController.reset();
    _animationController.forward();
    _autoRefreshTimer?.cancel();
    _countdownTimer?.cancel();

    // LANGSUNG BUKA ALIGHT MOTION
    Future.delayed(const Duration(seconds: 1), () {
      _openAlightMotion();
    });
  }

  Future<void> _savePremiumData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('premium_data', json.encode(data));
      await prefs.setString('premium_email', data['email']);
      await prefs.setString('premium_uid', data['uid']);
    } catch (e) {
      // Handle error
    }
  }

  void _handleError(String error) {
    setState(() {
      _statusMessage = '❌ $error';
      _statusColor = AppColors.errorRed;
      _isLoading = false;
      if (_retryCount < 3) _retryCount++;
    });
    
    _showNotification(_statusMessage, AppColors.errorRed);
  }

  void _showNotification(String message, Color color) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == AppColors.errorRed 
                  ? Icons.error_outline 
                  : color == AppColors.warningYellow 
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 6,
      ),
    );
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted && _isEmailSent && !_isVerified) {
        // Auto check status
      }
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_countdown > 0) {
            _countdown--;
          } else {
            _countdownTimer?.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _generateUID() {
    return 'SixEyesX_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _getLifetimeDate() {
    final now = DateTime.now();
    final lifetime = now.add(const Duration(days: 365 * 10));
    return DateFormat('yyyy-MM-dd').format(lifetime);
  }

  List<String> _getDefaultFeatures() {
    return [
      'All Effects Unlocked',
      'No Watermark',
      '4K Export',
      '60 FPS Support',
      'Premium Fonts',
      'Advanced Color Grading',
      'Motion Blur',
      'Keyframe Animation',
      'Green Screen',
      'Audio Editing',
      'Chroma Key',
      'Speed Control',
      'Unlimited Layers',
      'Custom Transitions',
      'AI Effects',
      'Cloud Sync',
      'Team Collaboration',
      'Priority Support',
    ];
  }

  void _resetForm() {
    setState(() {
      _emailController.clear();
      _magicLinkController.clear();
      _isVerified = false;
      _isEmailSent = false;
      _premiumData = {};
      _statusMessage = '';
      _retryCount = 0;
      _countdown = 0;
    });
    
    _autoRefreshTimer?.cancel();
    _countdownTimer?.cancel();
    _clearSavedData();
  }

  Future<void> _clearSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('premium_data');
      await prefs.remove('premium_email');
      await prefs.remove('premium_uid');
    } catch (e) {
      // Handle error
    }
  }

  // ==================== WIDGET BUILDERS ====================
  
  Widget _buildLogo() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue,
            AppColors.secondaryBlue,
            AppColors.accentBlue,
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/am.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryBlue,
                    AppColors.secondaryBlue,
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome_motion,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode
              ? [
                  AppColors.grey900,
                  AppColors.primaryDark,
                  AppColors.grey800,
                ]
              : [
                  AppColors.primaryBlue,
                  AppColors.primaryDark,
                  AppColors.secondaryBlue,
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value * 0.1,
                child: _buildLogo(),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'SixEyesX',
            style: TextStyle(
              fontFamily: 'Orbitron',
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          Text(
            'Alight Motion Premium',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isVerified ? AppColors.successGreen : AppColors.warningYellow,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isVerified ? 'PREMIUM ACTIVE' : 'UNLOCK PREMIUM',
                  style: TextStyle(
                    color: _isVerified ? AppColors.successGreen : AppColors.warningYellow,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: _isDarkMode ? AppColors.grey900 : Colors.white,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isDarkMode ? AppColors.grey700 : AppColors.primaryLight,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Email Field
                _buildTextField(
                  controller: _emailController,
                  label: 'EMAIL ADDRESS',
                  hint: 'Masukkan email kamu',
                  icon: Icons.email_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email harus diisi';
                    }
                    if (!EmailValidator.validate(value)) {
                      return 'Format email tidak valid';
                    }
                    return null;
                  },
                  enabled: !_isVerified,
                ),
                
                const SizedBox(height: 16),
                
                // Send Button
                _buildActionButton(
                  onPressed: _isLoading ? null : _requestMagicLink,
                  label: 'KIRIM MAGIC LINK',
                  icon: Icons.send_outlined,
                  color: AppColors.primaryBlue,
                  isLoading: _isLoading && !_isVerified,
                  enabled: !_isVerified,
                ),
                
                if (_isEmailSent && !_isVerified) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isDarkMode
                            ? [AppColors.grey800, AppColors.grey700]
                            : [AppColors.primaryLight, AppColors.grey100],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isDarkMode ? AppColors.grey600 : AppColors.primaryBlue.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: _isDarkMode ? AppColors.secondaryBlue : AppColors.primaryBlue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Link telah dikirim!',
                                style: TextStyle(
                                  color: _isDarkMode ? Colors.white70 : AppColors.primaryDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_countdown > 0)
                                Text(
                                  'Kirim ulang dalam $_countdown detik',
                                  style: TextStyle(
                                    color: _isDarkMode ? AppColors.grey400 : AppColors.grey600,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                Container(
                  height: 1,
                  color: _isDarkMode ? AppColors.grey700 : AppColors.grey200,
                ),
                const SizedBox(height: 16),
                
                // Magic Link Field
                _buildTextField(
                  controller: _magicLinkController,
                  label: 'MAGIC LINK',
                  hint: 'Tempel magic link dari email',
                  icon: Icons.link_outlined,
                  enabled: !_isVerified && _isEmailSent,
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.paste,
                      color: (!_isVerified && _isEmailSent) 
                          ? (_isDarkMode ? AppColors.secondaryBlue : AppColors.primaryBlue)
                          : AppColors.grey400,
                    ),
                    onPressed: (!_isVerified && _isEmailSent) 
                        ? _pasteFromClipboard 
                        : null,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Verify Button
                _buildActionButton(
                  onPressed: _isLoading ? null : _verifyMagicLink,
                  label: 'VERIFIKASI & AKTIFKAN',
                  icon: Icons.verified_outlined,
                  color: AppColors.accentBlue,
                  isLoading: _isLoading && _isEmailSent,
                  enabled: !_isVerified && _isEmailSent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    bool enabled = true,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? AppColors.grey400 : AppColors.grey600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.emailAddress,
          validator: validator,
          style: TextStyle(
            color: enabled ? (_isDarkMode ? Colors.white : AppColors.grey900) : AppColors.grey500,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.grey400,
              fontSize: 13,
            ),
            prefixIcon: Icon(
              icon, 
              color: enabled 
                  ? (_isDarkMode ? AppColors.secondaryBlue : AppColors.primaryBlue)
                  : AppColors.grey400,
            ),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _isDarkMode ? AppColors.grey700 : AppColors.grey300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _isDarkMode ? AppColors.grey700 : AppColors.grey300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _isDarkMode ? AppColors.secondaryBlue : AppColors.primaryBlue,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: enabled 
                ? (_isDarkMode ? AppColors.grey800 : Colors.white)
                : (_isDarkMode ? AppColors.grey900 : AppColors.grey50),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required String label,
    required IconData icon,
    required Color color,
    bool isLoading = false,
    bool enabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: enabled && !isLoading ? _pulseAnimation.value : 1.0,
            child: ElevatedButton.icon(
              onPressed: enabled ? onPressed : null,
              icon: isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(icon, size: 20),
              label: Text(
                isLoading ? 'PROCESSING...' : label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
                shadowColor: color.withOpacity(0.4),
                disabledBackgroundColor: _isDarkMode ? AppColors.grey700 : AppColors.grey300,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumCard() {
    if (!_isVerified || _premiumData.isEmpty) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Card(
          elevation: 12,
          margin: const EdgeInsets.only(top: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isDarkMode
                    ? [
                        AppColors.grey900,
                        AppColors.primaryDark,
                        AppColors.grey800,
                      ]
                    : [
                        AppColors.primaryDark,
                        AppColors.primaryBlue,
                        AppColors.accentBlue,
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'PREMIUM ACTIVE',
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white70),
                      onPressed: _copyPremiumData,
                      tooltip: 'Copy Data',
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white70),
                      onPressed: _sharePremiumData,
                      tooltip: 'Share Data',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.play_arrow,
                        color: Colors.white70,
                      ),
                      onPressed: _isOpeningAlight ? null : _openAlightMotion,
                      tooltip: 'Buka Alight Motion',
                    ),
                  ],
                ),
                
                const Divider(color: Colors.white24, height: 24),
                
                _buildInfoRow('EMAIL', _premiumData['email'] ?? '-'),
                _buildInfoRow('NAME', _premiumData['displayName'] ?? 'SixEyesX User'),
                _buildInfoRow('PLAN', _premiumData['planName'] ?? 'Alight Motion Premium Pro'),
                _buildInfoRow('ORDER ID', _premiumData['orderId'] ?? '-'),
                _buildInfoRow('VALID UNTIL', _premiumData['validUntil'] ?? 'Lifetime'),
                _buildInfoRow('DEVICE ID', _premiumData['deviceId']?.substring(0, 12) ?? '-'),
                
                const SizedBox(height: 16),
                
                // Features
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PREMIUM FEATURES UNLOCKED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (_premiumData['features'] as List<dynamic>? ?? [])
                            .take(10)
                            .map((feature) => Chip(
                                  label: Text(
                                    feature.toString(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  backgroundColor: AppColors.secondaryBlue.withOpacity(0.4),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                ))
                            .toList(),
                      ),
                      if ((_premiumData['features'] as List<dynamic>? ?? []).length > 10)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '+${(_premiumData['features'] as List).length - 10} more features',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Activated: ${_formatDate(_premiumData['activatedAt'])}',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.successGreen),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: AppColors.successGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.logout, color: Colors.white70, size: 18),
                          onPressed: _resetForm,
                          tooltip: 'Logout',
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                
                // Tombol Buka Alight Motion
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isOpeningAlight ? null : _openAlightMotion,
                    icon: _isOpeningAlight
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(
                      _isOpeningAlight ? 'MEMBUKA...' : 'BUKA ALIGHT MOTION',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTips() {
    if (_isVerified) return const SizedBox.shrink();
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDarkMode
              ? [AppColors.grey800, AppColors.grey700]
              : [AppColors.primaryLight, AppColors.grey100],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDarkMode ? AppColors.grey600 : AppColors.primaryBlue.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: _isDarkMode ? AppColors.secondaryBlue : AppColors.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'CARA AKTIVASI',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white70 : AppColors.primaryDark,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStep('1', 'Masukkan email yang terdaftar'),
          _buildStep('2', 'Klik "KIRIM MAGIC LINK"'),
          _buildStep('3', 'Cek email (termasuk folder spam)'),
          _buildStep('4', 'Salin magic link dari email'),
          _buildStep('5', 'Tempel dan klik "VERIFIKASI"'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: _isDarkMode ? AppColors.secondaryBlue : AppColors.primaryBlue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Magic link hanya berlaku 15 menit',
                    style: TextStyle(
                      fontSize: 11,
                      color: _isDarkMode ? Colors.white60 : AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryBlue,
                  AppColors.accentBlue,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: _isDarkMode ? Colors.white70 : AppColors.grey700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== UTILITY FUNCTIONS ====================
  
  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData != null && clipboardData.text != null) {
        setState(() {
          _magicLinkController.text = clipboardData.text!;
        });
        _showNotification('Magic link ditempel dari clipboard 📋', AppColors.primaryBlue);
      }
    } catch (e) {
      _showNotification('Gagal menempel dari clipboard', AppColors.warningYellow);
    }
  }

  Future<void> _copyPremiumData() async {
    if (_premiumData.isEmpty) return;
    
    final data = _formatPremiumData();
    
    try {
      await Clipboard.setData(ClipboardData(text: data));
      _showNotification('Data premium disalin! 📋', AppColors.successGreen);
    } catch (e) {
      _showNotification('Gagal menyalin data', AppColors.errorRed);
    }
  }

  Future<void> _sharePremiumData() async {
    if (_premiumData.isEmpty) return;
    
    final data = _formatPremiumData();
    
    try {
      await Share.share(data);
    } catch (e) {
      _showNotification('Gagal share data', AppColors.errorRed);
    }
  }

  String _formatPremiumData() {
    return '''
╔═══════════════════════════════════════════════════╗
║              SixEyesX - PREMIUM DATA                ║
╠═══════════════════════════════════════════════════╣
║ 📧 Email    : ${_premiumData['email']}
║ 👤 Name     : ${_premiumData['displayName']}
║ 📋 Plan     : ${_premiumData['planName']}
║ 🆔 Order    : ${_premiumData['orderId']}
║ 📅 Valid    : ${_premiumData['validUntil']}
║ ✅ Status   : PREMIUM ACTIVE
║ 🔑 Device   : ${_premiumData['deviceId']?.substring(0, 12) ?? '-'}
║ 📱 Version  : $_appVersion
║ 🕐 Activated: ${_formatDate(_premiumData['activatedAt'])}
╠═══════════════════════════════════════════════════╣
║ FEATURES:                                        ║
${(_premiumData['features'] as List<dynamic>? ?? []).map((f) => '║  ✅ $f').join('\n')}
╚═══════════════════════════════════════════════════╝
''';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Just now';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateString;
    }
  }

  // ==================== MAIN BUILD ====================
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? AppColors.grey950 : AppColors.grey50,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isDarkMode
                  ? [AppColors.grey900, AppColors.primaryDark]
                  : [AppColors.primaryBlue, AppColors.primaryDark],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.2),
                blurRadius: 10,
              ),
            ],
          ),
          child: AppBar(
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      'X',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'SixEyesX PREMIUM',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                if (_isVerified)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.successGreen),
                    ),
                    child: Text(
                      'VIP',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        color: AppColors.successGreen,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              ],
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: Icon(
                  _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                  color: Colors.white,
                ),
                onPressed: _toggleTheme,
                tooltip: 'Toggle Theme',
              ),
              if (_isVerified)
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: _sharePremiumData,
                  tooltip: 'Share Premium Data',
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _resetForm,
                tooltip: 'Reset',
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildForm(),
            
            // Status Message
            if (_statusMessage.isNotEmpty && !_isVerified)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _statusColor, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusColor == AppColors.successGreen 
                          ? Icons.check_circle_outline 
                          : _statusColor == AppColors.errorRed
                              ? Icons.error_outline
                              : Icons.warning_amber_rounded,
                      color: _statusColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            _buildPremiumCard(),
            _buildTips(),
            
            const SizedBox(height: 16),
            
            // Retry warning
            if (_retryCount >= 3 && !_isVerified)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.errorRed.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.errorRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Gagal beberapa kali. Periksa koneksi dan coba lagi.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.errorRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 8),
            
            // Footer
            Column(
              children: [
                Text(
                  '© 2026 SixEyesX - Alight Motion Premium',
                  style: TextStyle(
                    color: _isDarkMode ? AppColors.grey600 : AppColors.grey400,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version $_appVersion',
                  style: TextStyle(
                    color: _isDarkMode ? AppColors.grey700 : AppColors.grey400,
                    fontSize: 8,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}