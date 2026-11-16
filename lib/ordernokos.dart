import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// ═══════════════════════════════════════════════════════════════════════════
//  DIGITALPEDIA NOKOS + MARKUP UNTUNG
//  Docs: https://digitalpedia.web.id/dokumentasi
//
//  Alur untung:
//    hargaJual  = hargaModal + markup  →  ditampilkan & "dipotong" ke user
//    hargaModal = harga Digitalpedia   →  dikirim sebagai price_original
//    selisih    = UNTUNG kamu
// ═══════════════════════════════════════════════════════════════════════════

const String _baseUrl = 'https://digitalpedia.web.id/api/v1';

/// GANTI dengan API key Digitalpedia (lebih aman di backend)
const String _apiKey = 'dp_ea5df7a3e469e14396d691cc753268458281758e9627c400';

/// Default server (bisa diganti di UI)
const String _defaultServer = 's1';
const List<String> _serverOptions = ['s1', 's2', 's3', 's4'];

// ─── PENGATURAN UNTUNG (UBAH SESUKA KAMU) ─────────────────────────────────
/// Markup tetap per order (Rupiah). Contoh: 1000 = untung Rp 1.000 / nomor
const int markupNokosFlat = 500;

/// Markup persen dari harga modal (0.0 – 1.0). Contoh: 0.20 = +20%
const double markupNokosPercent = 0.20;

/// true = pakai yang LEBIH BESAR antara flat & persen
/// false = flat + persen digabung
const bool markupAmbilYangLebihBesar = true;

/// Fee deposit (jika nanti terhubung modul deposit di halaman ini)
const int feeDepositFlat = 500; // Rp
const double feeDepositPercent = 0.05; // 5%

int hitungHargaJual(int hargaModal) {
  if (hargaModal <= 0) return markupNokosFlat;
  final dariPersen = (hargaModal * markupNokosPercent).round();
  if (markupAmbilYangLebihBesar) {
    final m = dariPersen > markupNokosFlat ? dariPersen : markupNokosFlat;
    return hargaModal + m;
  }
  return hargaModal + markupNokosFlat + dariPersen;
}

int hitungUntung(int hargaModal) {
  final jual = hitungHargaJual(hargaModal);
  return jual - hargaModal;
}

int hitungKreditDeposit(int jumlahTransfer) {
  final feeP = (jumlahTransfer * feeDepositPercent).round();
  final fee = feeP > feeDepositFlat ? feeP : feeDepositFlat;
  final kredit = jumlahTransfer - fee;
  return kredit < 0 ? 0 : kredit;
}

// ═══════════════════════════════════════════════════════════════════════════

class OrderNokosPage extends StatefulWidget {
  /// Opsional: session user (untuk integrasi saldo backend kamu nanti)
  final String? sessionKey;
  final String? username;

  const OrderNokosPage({
    super.key,
    this.sessionKey,
    this.username,
  });

  @override
  State<OrderNokosPage> createState() => _OrderNokosPageState();
}

class _OrderNokosPageState extends State<OrderNokosPage>
    with TickerProviderStateMixin {
  static const Color bgMain = Color(0xFF050505);
  static const Color cardColor = Color(0xFF1E1E1E);
  static const Color primary = Color(0xFFE53935);
  static const Color profitGreen = Color(0xFF00E676);

  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _operators = [];

  Map<String, dynamic>? _selectedService;
  Map<String, dynamic>? _selectedCountry;
  Map<String, dynamic>? _selectedOperator;

  bool _loadingServices = true;
  bool _loadingCountries = false;
  bool _loadingOperators = false;

  bool _isLoading = false;
  bool _isWaitingOtp = false;
  String _currentOrderId = '';
  String _phoneNumberDisplay = '-';
  String _statusMessage = 'Pilih layanan & negara, lalu order';
  String _otpCode = '';

  int? _hargaModal;
  int? _hargaJual;
  int? _untungPerOrder;
  double? _balanceDp; // saldo Digitalpedia (modal kamu)
  int _totalUntungSesi = 0; // akumulasi untung order sukses di sesi ini

  // Server & Deposit
  String _server = _defaultServer;
  final _depositAmountCtrl = TextEditingController();
  bool _depositLoading = false;
  String? _depositId;
  String? _depositQrUrl;
  int? _depositAmount;
  int? _depositTotalPay;
  String _depositStatus = ''; // pending / success / cancelled
  Timer? _depositPollTimer;

  Timer? _pollTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
      };

  String get _s => _server;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _bootstrap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _depositPollTimer?.cancel();
    _depositAmountCtrl.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_fetchBalance(), _fetchServices()]);
  }

  void _recalcHarga() {
    int modal = 0;
    if (_selectedOperator != null) {
      modal = _asInt(_selectedOperator!['price']) ??
          _asInt(_selectedOperator!['price_with_markup']) ??
          0;
      // prefer harga asli (tanpa markup DP) jika ada
      modal = _asInt(_selectedOperator!['price']) ?? modal;
    } else if (_selectedCountry != null) {
      modal = _asInt(_selectedCountry!['original_price']) ??
          _asInt(_selectedCountry!['price']) ??
          0;
      if (modal == 0 && _selectedCountry!['pricelist'] is List) {
        final pl = _selectedCountry!['pricelist'] as List;
        if (pl.isNotEmpty) {
          modal = _asInt(pl.first['price']) ?? 0;
        }
      }
    }
    setState(() {
      _hargaModal = modal > 0 ? modal : null;
      if (_hargaModal != null) {
        _hargaJual = hitungHargaJual(_hargaModal!);
        _untungPerOrder = hitungUntung(_hargaModal!);
      } else {
        _hargaJual = null;
        _untungPerOrder = null;
      }
    });
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  // ── API helpers ────────────────────────────────────────────────────────

  Future<void> _fetchBalance() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/balance'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        setState(() => _balanceDp = (data['balance'] as num?)?.toDouble());
      }
    } catch (_) {}
  }

  Future<void> _fetchServices() async {
    setState(() => _loadingServices = true);
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/$_s/nokos/services'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        final list = (data['data'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        setState(() {
          _services = list;
          _loadingServices = false;
          _selectedService = list.cast<Map<String, dynamic>?>().firstWhere(
                (s) {
                  final name =
                      '${s?['service_name'] ?? s?['name'] ?? ''}'.toLowerCase();
                  return name.contains('whatsapp');
                },
                orElse: () => list.isNotEmpty ? list.first : null,
              );
        });
        if (_selectedService != null) await _fetchCountries();
      } else {
        setState(() => _loadingServices = false);
        _handleError(data['message']?.toString() ?? 'Gagal memuat layanan');
      }
    } catch (_) {
      setState(() => _loadingServices = false);
      _handleError('Gagal memuat layanan. Cek API key & internet.');
    }
  }

  Future<void> _fetchCountries() async {
    if (_selectedService == null) return;
    setState(() {
      _loadingCountries = true;
      _countries = [];
      _operators = [];
      _selectedCountry = null;
      _selectedOperator = null;
      _hargaModal = null;
      _hargaJual = null;
      _untungPerOrder = null;
    });

    try {
      final serviceId = _serviceId(_selectedService!);
      final uri = _s == 's1'
          ? Uri.parse(
              '$_baseUrl/$_s/nokos/countries?service_id=$serviceId')
          : Uri.parse('$_baseUrl/$_s/nokos/countries');

      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        final list = (data['data'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        setState(() {
          _countries = list;
          _loadingCountries = false;
          _selectedCountry = list.cast<Map<String, dynamic>?>().firstWhere(
                (c) => '${c?['name'] ?? ''}'
                    .toLowerCase()
                    .contains('indonesia'),
                orElse: () => list.isNotEmpty ? list.first : null,
              );
        });
        if (_selectedCountry != null) await _fetchOperators();
      } else {
        setState(() => _loadingCountries = false);
        _handleError(data['message']?.toString() ?? 'Gagal memuat negara');
      }
    } catch (_) {
      setState(() => _loadingCountries = false);
      _handleError('Gagal memuat negara.');
    }
  }

  Future<void> _fetchOperators() async {
    if (_selectedService == null || _selectedCountry == null) return;
    setState(() {
      _loadingOperators = true;
      _operators = [];
      _selectedOperator = null;
    });

    try {
      final serviceId = _serviceId(_selectedService!);
      final countryId = _countryId(_selectedCountry!);

      Uri uri;
      if (_s == 's1') {
        String? providerId;
        final pl = _selectedCountry!['pricelist'];
        if (pl is List && pl.isNotEmpty) {
          providerId = '${pl.first['provider_id']}';
        }
        uri = Uri.parse('$_baseUrl/$_s/nokos/numbers').replace(
          queryParameters: {
            'country_id': '$countryId',
            'service_id': '$serviceId',
            if (providerId != null) 'provider_id': providerId,
          },
        );
      } else {
        uri = Uri.parse('$_baseUrl/$_s/nokos/numbers').replace(
          queryParameters: {
            'service_code': '$serviceId',
            'country_id': '$countryId',
          },
        );
      }

      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        final list = (data['data'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        setState(() {
          _operators = list;
          _loadingOperators = false;
          if (list.isNotEmpty) _selectedOperator = list.first;
        });
      } else {
        setState(() => _loadingOperators = false);
      }
      _recalcHarga();
    } catch (_) {
      setState(() => _loadingOperators = false);
      _recalcHarga();
    }
  }

  String _serviceId(Map<String, dynamic> s) =>
      '${s['service_code'] ?? s['id'] ?? ''}';

  String _serviceName(Map<String, dynamic> s) =>
      '${s['service_name'] ?? s['name'] ?? 'Service'}';

  int _countryId(Map<String, dynamic> c) =>
      (c['number_id'] as num?)?.toInt() ??
      int.tryParse('${c['number_id'] ?? 0}') ??
      0;

  String _countryName(Map<String, dynamic> c) => '${c['name'] ?? 'Country'}';

  // ── ORDER (kirim harga MODAL ke DP, user "bayar" harga JUAL) ───────────

  Future<void> _submitOrder() async {
    FocusScope.of(context).unfocus();
    if (_selectedService == null || _selectedCountry == null) {
      _handleError('Pilih layanan dan negara dulu.');
      return;
    }
    if (_apiKey.contains('GANTI')) {
      _handleError('Isi API key Digitalpedia di konstanta _apiKey.');
      return;
    }
    if (_hargaModal == null || _hargaJual == null) {
      _handleError('Harga belum tersedia. Pilih operator/negara.');
      return;
    }

    // TODO (backend kamu):
    // 1. Cek saldo USER (bukan saldo DP) >= _hargaJual
    // 2. Potong saldo user sebesar _hargaJual
    // 3. Baru order ke Digitalpedia
    // 4. Jika order gagal → refund saldo user

    setState(() {
      _isLoading = true;
      _statusMessage = 'Memproses order...';
      _isWaitingOtp = false;
      _otpCode = '';
      _phoneNumberDisplay = '-';
      _currentOrderId = '';
    });

    try {
      final serviceId = _serviceId(_selectedService!);
      final serviceName = _serviceName(_selectedService!);
      final countryId = _countryId(_selectedCountry!);
      final countryName = _countryName(_selectedCountry!);

      String providerId = '';
      String operatorId = '1';
      final int priceOriginal = _hargaModal!; // MODAL ke Digitalpedia

      if (_selectedOperator != null) {
        providerId = '${_selectedOperator!['provider_id'] ?? ''}';
        operatorId =
            '${_selectedOperator!['operator_id'] ?? _selectedOperator!['provider_id'] ?? '1'}';
      } else if (_selectedCountry!['pricelist'] is List &&
          (_selectedCountry!['pricelist'] as List).isNotEmpty) {
        final first = (_selectedCountry!['pricelist'] as List).first;
        providerId = '${first['provider_id']}';
      }

      final body = <String, dynamic>{
        'service_code': serviceId,
        'service_name': serviceName,
        'country_id': countryId,
        'country_name': countryName,
        'provider_id': providerId,
        'price_original': priceOriginal, // harga MODAL
      };
      if (_s == 's1') body['operator_id'] = operatorId;

      final res = await http
          .post(
            Uri.parse('$_baseUrl/$_s/nokos/order'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        final order = data['order'] is Map
            ? Map<String, dynamic>.from(data['order'] as Map)
            : data;
        final id = '${order['id'] ?? data['id'] ?? ''}';
        final phone =
            '${order['phone_number'] ?? order['number'] ?? data['phone_number'] ?? '-'}';

        setState(() {
          _isLoading = false;
          _isWaitingOtp = true;
          _currentOrderId = id;
          _phoneNumberDisplay = phone;
          _statusMessage =
              'Menunggu OTP... (user: Rp $_hargaJual · modal: Rp $_hargaModal)';
        });
        _pulseController.repeat(reverse: true);
        _showSuccessSnackBar(
          'Order OK! Jual Rp $_hargaJual · Untung Rp $_untungPerOrder',
        );
        _startPolling();
        _fetchBalance();
      } else {
        // TODO: refund saldo user jika sudah dipotong
        _handleError(
            data['message']?.toString() ?? 'Gagal order nomor virtual.');
      }
    } catch (_) {
      _handleError('Koneksi gagal / timeout. Coba lagi.');
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _checkOtp());
    _checkOtp();
  }

  Future<void> _checkOtp() async {
    if (_currentOrderId.isEmpty || !_isWaitingOtp) return;
    try {
      final uri = Uri.parse('$_baseUrl/$_s/nokos/status')
          .replace(queryParameters: {'order_id': _currentOrderId});
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 12));
      final data = jsonDecode(res.body);
      if (res.statusCode != 200 || data['success'] != true) return;

      final payload = data['data'] is Map
          ? Map<String, dynamic>.from(data['data'] as Map)
          : data;
      final status = '${payload['status'] ?? ''}'.toLowerCase();
      final otp = '${payload['otp_code'] ?? payload['otp'] ?? ''}';

      if (status == 'received' || (otp.isNotEmpty && otp != 'null')) {
        _pollTimer?.cancel();
        setState(() {
          _isWaitingOtp = false;
          _statusMessage = 'OTP Diterima!';
          _otpCode = otp.isNotEmpty ? otp : 'Kode tidak terbaca';
          // Catat untung saat OTP sukses
          if (_untungPerOrder != null) {
            _totalUntungSesi += _untungPerOrder!;
          }
        });
        _pulseController.stop();
        _pulseController.reset();
        HapticFeedback.mediumImpact();
      } else if (status == 'cancel' || status == 'cancelled') {
        _pollTimer?.cancel();
        setState(() {
          _isWaitingOtp = false;
          _statusMessage = 'Order dibatalkan';
        });
        _pulseController.stop();
      } else {
        setState(() {
          _statusMessage =
              'Menunggu SMS... (${status.isEmpty ? 'pending' : status})';
        });
      }
    } catch (_) {}
  }

  Future<void> _cancelOrder() async {
    if (_currentOrderId.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/$_s/nokos/cancel'),
            headers: _headers,
            body: jsonEncode({'order_id': _currentOrderId}),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      _pollTimer?.cancel();
      setState(() {
        _isLoading = false;
        _isWaitingOtp = false;
        _statusMessage = data['message']?.toString() ??
            (data['success'] == true
                ? 'Order dibatalkan'
                : 'Gagal membatalkan');
      });
      _pulseController.stop();
      // TODO: refund saldo user (harga jual) jika sudah dipotong
      _fetchBalance();
    } catch (_) {
      setState(() => _isLoading = false);
      _handleError('Gagal membatalkan order.');
    }
  }

  void _handleError(String message) {
    setState(() {
      _isLoading = false;
      _statusMessage = message;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red.shade700, content: Text(message)),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.green.shade700, content: Text(message)),
    );
  }

  String _rp(int? v) => v == null ? '-' : 'Rp ${v.toString()}';


  // ═══════════════════════════════════════════════════════════════════════
  //  DEPOSIT QRIS (Digitalpedia)
  //  POST /deposit/create  GET /deposit/status/:id  POST /deposit/cancel
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _createDeposit() async {
    final raw = _depositAmountCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(raw) ?? 0;
    if (amount < 500) {
      _toast('Minimal deposit Rp 500');
      return;
    }
    setState(() {
      _depositLoading = true;
      _depositStatus = '';
      _depositId = null;
      _depositQrUrl = null;
    });
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/deposit/create'),
        headers: _headers,
        body: jsonEncode({'amount': amount}),
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true && data['deposit'] is Map) {
        final d = Map<String, dynamic>.from(data['deposit'] as Map);
        setState(() {
          _depositId = d['id']?.toString();
          _depositAmount = _asInt(d['amount']);
          _depositTotalPay = _asInt(d['total_payment']) ?? _depositAmount;
          _depositQrUrl = d['qr_image']?.toString();
          _depositStatus = d['status']?.toString() ?? 'pending';
        });
        _startDepositPoll();
        _toast('QRIS dibuat. Bayar dalam 5 menit.');
      } else {
        _toast(data['message']?.toString() ?? 'Gagal buat deposit');
      }
    } catch (e) {
      _toast('Error deposit: $e');
    } finally {
      if (mounted) setState(() => _depositLoading = false);
    }
  }

  void _startDepositPoll() {
    _depositPollTimer?.cancel();
    _depositPollTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      if (_depositId == null) return;
      try {
        final res = await http.get(
          Uri.parse('$_baseUrl/deposit/status/$_depositId'),
          headers: _headers,
        );
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final st = data['status']?.toString() ?? '';
          if (st == 'success') {
            _depositPollTimer?.cancel();
            setState(() => _depositStatus = 'success');
            await _fetchBalance();
            _toast('Deposit berhasil!');
          } else if (st == 'cancelled' || st == 'expired' || st == 'failed') {
            _depositPollTimer?.cancel();
            setState(() => _depositStatus = st);
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _cancelDeposit() async {
    if (_depositId == null) return;
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/deposit/cancel'),
        headers: _headers,
        body: jsonEncode({'deposit_id': _depositId}),
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _depositPollTimer?.cancel();
        setState(() {
          _depositStatus = 'cancelled';
          _depositQrUrl = null;
        });
        _toast('Deposit dibatalkan');
      } else {
        _toast(data['message']?.toString() ?? 'Gagal batalkan');
      }
    } catch (e) {
      _toast('Error: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildServerSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('SERVER NOKOS'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _server,
              dropdownColor: const Color(0xFF1A1A1A),
              icon: const Icon(Icons.dns_rounded, color: Colors.white54),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: _serverOptions
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        'Server ${s.toUpperCase()}  ·  /${s}/nokos/...',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                setState(() {
                  _server = v;
                  _selectedService = null;
                  _selectedCountry = null;
                  _selectedOperator = null;
                  _countries = [];
                  _operators = [];
                  _services = [];
                  _loadingServices = true;
                });
                await _fetchServices();
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Panduan: digitalpedia.web.id/dokumentasi — tiap server endpoint berbeda (s1–s4).',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildDepositSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: primary, size: 20),
              SizedBox(width: 8),
              Text(
                'DEPOSIT SALDO (QRIS)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Minimal Rp 500 · QR aktif 5 menit · saldo masuk otomatis setelah bayar',
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _depositAmountCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: 'Nominal (contoh: 50000)',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: const Color(0xFF121212),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primary),
              ),
              prefixText: 'Rp ',
              prefixStyle: const TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _depositLoading ? null : _createDeposit,
              icon: _depositLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.qr_code_2_rounded),
              label: Text(
                _depositLoading ? 'Membuat QRIS...' : 'Buat Deposit QRIS',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_depositQrUrl != null && _depositStatus == 'pending') ...[
            const SizedBox(height: 16),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _depositQrUrl!,
                  width: 220,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 220,
                    height: 220,
                    color: Colors.black26,
                    alignment: Alignment.center,
                    child: const Text('Gagal muat QR',
                        style: TextStyle(color: Colors.white54)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'ID: ${_depositId ?? '-'} · Tagihan: Rp ${_depositTotalPay ?? _depositAmount ?? 0}',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelDeposit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    child: const Text('Batalkan'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      // manual refresh status
                      if (_depositId == null) return;
                      final res = await http.get(
                        Uri.parse('$_baseUrl/deposit/status/$_depositId'),
                        headers: _headers,
                      );
                      final data = jsonDecode(res.body);
                      if (data['success'] == true) {
                        final st = data['status']?.toString() ?? '';
                        setState(() => _depositStatus = st);
                        if (st == 'success') {
                          _depositPollTimer?.cancel();
                          await _fetchBalance();
                          _toast('Deposit berhasil!');
                        }
                      }
                    },
                    child: const Text('Cek Status'),
                  ),
                ),
              ],
            ),
          ],
          if (_depositStatus == 'success') ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: profitGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: profitGreen.withOpacity(0.5)),
              ),
              child: const Text(
                '✓ Deposit berhasil. Saldo Digitalpedia sudah di-update.',
                style: TextStyle(color: profitGreen, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  UI
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        title: const Text(
          'ORDER NOKOS',
          style: TextStyle(
            fontFamily: 'Rajdhani',
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_balanceDp != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  'DP: Rp ${_balanceDp!.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchBalance();
              _fetchServices();
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Kartu untung ──────────────────────────────────────
                _buildProfitBanner(),
                const SizedBox(height: 16),

                _buildServerSelector(),
                const SizedBox(height: 16),

                _buildDepositSection(),
                const SizedBox(height: 16),

                _buildStatusCard(),
                const SizedBox(height: 22),

                _label('LAYANAN'),
                const SizedBox(height: 8),
                _loadingServices
                    ? const LinearProgressIndicator(color: primary)
                    : _dropdown<Map<String, dynamic>>(
                        value: _selectedService,
                        items: _services,
                        labelBuilder: _serviceName,
                        onChanged: (v) async {
                          setState(() => _selectedService = v);
                          await _fetchCountries();
                        },
                        hint: 'Pilih layanan',
                      ),

                const SizedBox(height: 16),
                _label('NEGARA'),
                const SizedBox(height: 8),
                _loadingCountries
                    ? const LinearProgressIndicator(color: primary)
                    : _dropdown<Map<String, dynamic>>(
                        value: _selectedCountry,
                        items: _countries,
                        labelBuilder: (c) {
                          final stock = c['stock_total'];
                          return stock != null
                              ? '${_countryName(c)} · stok $stock'
                              : _countryName(c);
                        },
                        onChanged: (v) async {
                          setState(() => _selectedCountry = v);
                          await _fetchOperators();
                        },
                        hint: 'Pilih negara',
                      ),

                if (_operators.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _label('OPERATOR'),
                  const SizedBox(height: 8),
                  _loadingOperators
                      ? const LinearProgressIndicator(color: primary)
                      : _dropdown<Map<String, dynamic>>(
                          value: _selectedOperator,
                          items: _operators,
                          labelBuilder: (op) {
                            final name =
                                '${op['operator_name'] ?? op['label'] ?? 'any'}';
                            final modal = _asInt(op['price']) ?? 0;
                            final jual = hitungHargaJual(modal);
                            return '$name · ${_rp(jual)}';
                          },
                          onChanged: (v) {
                            setState(() => _selectedOperator = v);
                            _recalcHarga();
                          },
                          hint: 'Pilih operator',
                        ),
                ],

                const SizedBox(height: 16),
                _buildPriceBreakdown(),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed:
                        (_isLoading || _isWaitingOtp) ? null : _submitOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      disabledBackgroundColor: primary.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 6,
                      shadowColor: primary.withOpacity(0.35),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 3,
                            ),
                          )
                        : Text(
                            _hargaJual != null
                                ? 'ORDER · ${_rp(_hargaJual)}'
                                : 'ORDER SEKARANG',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Rajdhani',
                              letterSpacing: 1.1,
                            ),
                          ),
                  ),
                ),

                if (_isWaitingOtp) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _cancelOrder,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'BATALKAN ORDER',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                Center(
                  child: Text(
                    'User membayar harga JUAL. Modal ke Digitalpedia lebih rendah.\n'
                    'Selisih = untungmu. OTP dicek otomatis tiap 10 detik.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 24),
                _buildDepositInfoCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfitBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            profitGreen.withOpacity(0.15),
            primary.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: profitGreen.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: profitGreen, size: 18),
              const SizedBox(width: 8),
              const Text(
                'MODE RESELLER AKTIF',
                style: TextStyle(
                  color: profitGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (_totalUntungSesi > 0)
                Text(
                  'Sesi +${_rp(_totalUntungSesi)}',
                  style: const TextStyle(
                    color: profitGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Markup: Rp $markupNokosFlat atau ${(markupNokosPercent * 100).toStringAsFixed(0)}%'
            '${markupAmbilYangLebihBesar ? ' (ambil lebih besar)' : ' (digabung)'}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          _priceRow('Harga modal (Digitalpedia)', _rp(_hargaModal),
              Colors.white70),
          const SizedBox(height: 8),
          _priceRow('Markup / untung kamu', _rp(_untungPerOrder), profitGreen),
          const Divider(height: 20, color: Colors.white12),
          _priceRow(
            'Harga jual ke user',
            _rp(_hargaJual),
            primary,
            bold: true,
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, Color color,
      {bool bold = false, double size = 14}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDepositInfoCard() {
    // Contoh hitungan fee deposit (untuk modul deposit kamu)
    const contohTransfer = 50000;
    final kredit = hitungKreditDeposit(contohTransfer);
    final fee = contohTransfer - kredit;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'UNTUNG DEPOSIT (referensi)',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fee: Rp $feeDepositFlat atau ${(feeDepositPercent * 100).toStringAsFixed(0)}% (ambil lebih besar)\n'
            'Contoh transfer Rp $contohTransfer → kredit user Rp $kredit · fee Rp $fee',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 11,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Integrasikan fungsi hitungKreditDeposit() di backend/deposit page.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isWaitingOtp ? primary : Colors.white10,
          width: 1.4,
        ),
        boxShadow: [
          if (_isWaitingOtp)
            BoxShadow(
              color: primary.withOpacity(0.2),
              blurRadius: 16,
            ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STATUS AKTIVASI',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              if (_isWaitingOtp)
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: const Icon(Icons.sync, color: primary, size: 20),
                )
              else
                Icon(
                  _otpCode.isNotEmpty
                      ? Icons.check_circle
                      : Icons.info_outline,
                  color:
                      _otpCode.isNotEmpty ? primary : Colors.grey.shade500,
                  size: 20,
                ),
            ],
          ),
          const Divider(height: 18, color: Colors.white10),
          if (_phoneNumberDisplay != '-' && _phoneNumberDisplay.isNotEmpty) ...[
            Text('NOMOR',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            const SizedBox(height: 4),
            SelectableText(
              _phoneNumberDisplay,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Rajdhani',
              ),
            ),
            if (_currentOrderId.isNotEmpty)
              Text(
                'ID: $_currentOrderId',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
            const SizedBox(height: 10),
          ],
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _isWaitingOtp ? primary : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_otpCode.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary),
              ),
              child: Column(
                children: [
                  const Text(
                    'KODE OTP',
                    style: TextStyle(
                      color: primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _otpCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      fontFamily: 'Rajdhani',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(String t) => Text(
        t,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      );

  Widget _dropdown<T>({
    required T? value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T?> onChanged,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          dropdownColor: const Color(0xFF1A1A1A),
          hint: Text(hint, style: TextStyle(color: Colors.grey.shade600)),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text(
                    labelBuilder(e),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
