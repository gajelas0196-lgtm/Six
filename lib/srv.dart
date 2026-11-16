import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Srv {
  // ====== URL RAW GITHUB KONFIGURASI ======
  // Ganti dengan URL raw GitHub kamu, contoh:
  // https://raw.githubusercontent.com/USERNAME/REPO/main/config.json
  static const String _configUrl =
      'https://raw.githubusercontent.com/gajelas0196-lgtm/Zijii/refs/heads/main/Kurumi/config.json';

  // ====== DEFAULT (fallback) ======
  static const String _defaultBaseUrl = 'http://alya-digital-id.pteroq.biz.id:2528';
  static const String _defaultManageUrl = 'http://alya-digital-id.pteroq.biz.id:2528';
  static const String _defaultTesFuncUrl = 'http://alya-digital-id.pteroq.biz.id:2528';

  // ====== VARIABEL AKTIF ======
  // Ubah dari 'const' ke 'static String' agar bisa diubah saat runtime
  static String baseUrl = _defaultBaseUrl;
  static String manageServerUrl = _defaultManageUrl;
  static String tesFuncUrl = _defaultTesFuncUrl;

  static const String _prefBaseKey = 'cfg_srv_base';
  static const String _prefManageKey = 'cfg_srv_manage';
  static const String _prefTesKey = 'cfg_srv_tes';

  /// Panggil sekali di main() sebelum runApp()
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Pakai cache dulu
    baseUrl = prefs.getString(_prefBaseKey) ?? _defaultBaseUrl;
    manageServerUrl = prefs.getString(_prefManageKey) ?? _defaultManageUrl;
    tesFuncUrl = prefs.getString(_prefTesKey) ?? _defaultTesFuncUrl;

    // 2. Coba ambil dari GitHub Raw
    try {
      final res = await http
          .get(Uri.parse(_configUrl))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;

        final newBase = (data['baseUrl'] as String?)?.trim();
        final newManage = (data['manageServerUrl'] as String?)?.trim();
        final newTes = (data['tesFuncUrl'] as String?)?.trim();

        if (newBase != null && newBase.isNotEmpty) {
          baseUrl = newBase;
          await prefs.setString(_prefBaseKey, newBase);
        }
        if (newManage != null && newManage.isNotEmpty) {
          manageServerUrl = newManage;
          await prefs.setString(_prefManageKey, newManage);
        }
        if (newTes != null && newTes.isNotEmpty) {
          tesFuncUrl = newTes;
          await prefs.setString(_prefTesKey, newTes);
        }
      }
    } catch (_) {
      // Gagal ambil remote → tetap pakai cache/default.
    }
  }

  /// WebSocket base (otomatis dari baseUrl: http→ws, https→wss)
  static String get wsUrl {
    final u = Uri.parse(baseUrl);
    final scheme = (u.scheme == 'https') ? 'wss' : 'ws';
    final port = u.hasPort ? ':${u.port}' : '';
    return '$scheme://${u.host}$port';
  }

  /// WebSocket chat
  static String get chatWsUrl => '$wsUrl/chat';
}