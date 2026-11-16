import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class IphoneQuoteGenerator extends StatefulWidget {
  final String username;
  final String role;

  const IphoneQuoteGenerator({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<IphoneQuoteGenerator> createState() => _IphoneQuoteGeneratorState();
}

class _IphoneQuoteGeneratorState extends State<IphoneQuoteGenerator> {
  final TextEditingController _timeController = TextEditingController(text: "18:00");
  final TextEditingController _batteryController = TextEditingController(text: "40");
  final TextEditingController _messageController = TextEditingController(text: "Halo bang");
  
  String _selectedOperator = "Telkomsel";
  String _generatedQuote = "";
  bool _isGenerating = false;
  bool _showPreview = false;
  
  final List<String> _operators = [
    "Telkomsel", "Indosat", "XL Axiata", "Tri (3)",
    "Smartfren", "By.U", "Axis", "Biznet",
  ];
  
  final Color _primaryBlue = const Color(0xFF2196F3);
  final Color _darkBlue = const Color(0xFF0D47A1);
  final Color _softBlue = const Color(0xFF64B5F6);
  final Color _bgDark = const Color(0xFF0A1929);
  final Color _cardBg = const Color(0xFF0F1D2F);
  final Color _quoteBg = const Color(0xFF1C1C1E);
  final Color _quoteBubble = const Color(0xFF2C2C2E);
  final Color _quoteText = const Color(0xFFE5E5EA);
  final Color _quoteTime = const Color(0xFF8E8E93);
  final Color _quoteSignal = const Color(0xFF34C759);

  @override
  void initState() {
    super.initState();
    _generatePreview();
  }

  @override
  void dispose() {
    _timeController.dispose();
    _batteryController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _generatePreview() {
    setState(() {
      _generatedQuote = _messageController.text.trim();
      if (_generatedQuote.isEmpty) {
        _generatedQuote = "Pesan akan muncul di sini";
      }
      _showPreview = true;
    });
  }

  Future<void> _generateQuote() async {
    final time = _timeController.text.trim();
    final battery = _batteryController.text.trim();
    final message = _messageController.text.trim();
    
    if (time.isEmpty) {
      _showSnackbar("Masukkan waktu terlebih dahulu!", isError: true);
      return;
    }
    
    if (battery.isEmpty) {
      _showSnackbar("Masukkan persentase baterai!", isError: true);
      return;
    }
    
    int? batteryInt = int.tryParse(battery);
    if (batteryInt == null || batteryInt < 0 || batteryInt > 100) {
      _showSnackbar("Baterai harus angka antara 0-100!", isError: true);
      return;
    }
    
    if (message.isEmpty) {
      _showSnackbar("Masukkan pesan terlebih dahulu!", isError: true);
      return;
    }
    
    setState(() {
      _isGenerating = true;
      _showPreview = true;
    });
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      _generatedQuote = message;
      _isGenerating = false;
    });
    
    _showSnackbar("Quote Chat berhasil dibuat!", isError: false);
  }

  Future<void> _saveAndShare() async {
    if (!_showPreview || _generatedQuote.isEmpty) {
      _showSnackbar("Buat quote terlebih dahulu!", isError: true);
      return;
    }
    
    setState(() => _isGenerating = true);
    
    try {
      await Share.share(
        "📱 Quote Chat\n\n"
        "Waktu: ${_timeController.text}\n"
        "Baterai: ${_batteryController.text}%\n"
        "Operator: $_selectedOperator\n"
        "Pesan: ${_messageController.text}\n\n"
        "✨ Dibuat dengan Prime Vision",
        subject: "Quote Chat",
      );
      _showSnackbar("Berhasil dibagikan!", isError: false);
    } catch (e) {
      _showSnackbar("Gagal membagikan: $e", isError: true);
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  void _resetForm() {
    setState(() {
      _timeController.text = "18:00";
      _batteryController.text = "40";
      _selectedOperator = "Telkomsel";
      _messageController.text = "Halo bang";
      _generatedQuote = "Halo bang";
      _showPreview = true;
    });
    _showSnackbar("Form telah direset!", isError: false);
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red : _primaryBlue,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _darkBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Quote Chat",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _resetForm,
            tooltip: "Reset Form",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPreviewSection(),
            const SizedBox(height: 20),
            _buildFormSection(),
            const SizedBox(height: 20),
            _buildButtonSection(),
            const SizedBox(height: 20),
            _buildGuideSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _quoteBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Container(
              height: 50,
              color: Colors.black,
              child: Stack(
                children: [
                  Positioned(
                    left: 20,
                    top: 15,
                    child: Text(
                      _timeController.text.isEmpty ? "18:00" : _timeController.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 110,
                      height: 35,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 20,
                    top: 15,
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 10,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: (_batteryController.text.isEmpty ? 40 : int.tryParse(_batteryController.text) ?? 40) / 100,
                              backgroundColor: Colors.transparent,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34C759)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${_batteryController.text.isEmpty ? "40" : _batteryController.text}%",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _quoteBubble,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.signal_cellular_alt, color: _quoteSignal, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _selectedOperator,
                          style: TextStyle(color: _quoteTime, fontSize: 11),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.wifi, color: _quoteSignal, size: 14),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_showPreview)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _quoteBubble,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _generatedQuote.isEmpty ? "Pesan akan muncul di sini" : _generatedQuote,
                              style: TextStyle(
                                color: _quoteText,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _timeController.text.isEmpty ? "18:00" : _timeController.text,
                              style: TextStyle(
                                color: _quoteTime,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      alignment: Alignment.center,
                      child: Text(
                        "Isi form untuk membuat pratinjau",
                        style: TextStyle(
                          color: _quoteTime,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              height: 34,
              alignment: Alignment.topCenter,
              child: Container(
                width: 140,
                height: 5,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.edit_note_rounded, color: _primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              // ✅ FIX: HAPUS "const" DI SINI (TAPI INI UDAH BENER, PAKAI const Text)
              const Text(
                "BUAT QUOTE CHAT",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFormField(
            label: "Waktu",
            hint: "Contoh: 18:00",
            icon: Icons.access_time_rounded,
            controller: _timeController,
            keyboardType: TextInputType.datetime,
            onChanged: (_) => _generatePreview(),
          ),
          const SizedBox(height: 12),
          _buildFormField(
            label: "Baterai (%)",
            hint: "0-100",
            icon: Icons.battery_alert_rounded,
            controller: _batteryController,
            keyboardType: TextInputType.number,
            onChanged: (_) => _generatePreview(),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: _bgDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primaryBlue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      Icon(Icons.signal_cellular_alt, color: _softBlue, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        "Operator",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedOperator,
                    dropdownColor: _cardBg,
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    icon: Icon(Icons.arrow_drop_down, color: _primaryBlue),
                    items: _operators.map((op) {
                      return DropdownMenuItem(
                        value: op,
                        child: Text(op),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedOperator = value);
                        _generatePreview();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildFormField(
            label: "Pesan",
            hint: "Tulis pesan di sini...",
            icon: Icons.message_rounded,
            controller: _messageController,
            maxLines: 3,
            onChanged: (_) => _generatePreview(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    required Function(String) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Icon(icon, color: _softBlue, size: 16),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white38),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildButtonSection() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _isGenerating ? null : _generateQuote,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryBlue, _darkBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "BUAT QUOTE CHAT",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _isGenerating ? null : _saveAndShare,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _primaryBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primaryBlue),
              ),
              child: Center(
                child: Text(
                  "SHARE",
                  style: TextStyle(
                    color: _softBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded, color: _softBlue, size: 18),
              const SizedBox(width: 8),
              const Text(
                "Panduan Penggunaan",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGuideBullet("Masukkan waktu (contoh: 18:00)"),
          _buildGuideBullet("Masukkan persentase baterai (0-100)"),
          _buildGuideBullet("Pilih operator seluler"),
          _buildGuideBullet("Tulis pesan yang ingin ditampilkan"),
          _buildGuideBullet("Klik Buat Quote Chat"),
          _buildGuideBullet("Simpan atau bagikan hasilnya"),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primaryBlue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Contoh format lengkap:",
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Text(
                  "Waktu = 18:00,\nBaterai = 40%,\nOperator = Indosat,\nPesan = Halo bang",
                  style: TextStyle(color: _softBlue, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text("• ", style: TextStyle(color: _softBlue, fontSize: 12)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}