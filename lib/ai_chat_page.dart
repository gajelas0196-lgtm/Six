import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AiChatPage extends StatefulWidget {
  final String username;
  const AiChatPage({super.key, required this.username});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  static const _blue = Color(0xFF2F6FED);
  static const _cyan = Color(0xFF57A6FF);
  static const _bg = Color(0xFF05070C);
  static const _card = Color(0xFF0D121C);
  static const _border = Color(0xFF253A61);
  static const _endpoint = 'https://api.nexray.eu.cc/ai/copilot';

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  final List<_AiMessage> _messages = [];
  File? _attachment;
  String? _attachmentName;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messages.add(_AiMessage(
      text: 'Halo ${widget.username}! Saya SixEyesX AI. Kirim pertanyaan, foto, atau berkas untuk dianalisis.',
      fromUser: false,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (image == null) return;
    setState(() {
      _attachment = File(image.path);
      _attachmentName = image.name;
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _attachment = File(result.files.single.path!);
      _attachmentName = result.files.single.name;
    });
  }

  Future<http.Response> _postJson(String endpoint, String text) async {
    return http.post(
      Uri.parse(endpoint),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/plain, */*',
      },
      body: jsonEncode({
        'message': text,
        'prompt': text,
        'text': text,
        'username': widget.username,
      }),
    ).timeout(const Duration(minutes: 2));
  }

  Future<http.Response> _getText(String endpoint, String text) async {
    final base = Uri.parse(endpoint);
    final uri = base.replace(queryParameters: {
      ...base.queryParameters,
      'prompt': text,
      'message': text,
      'text': text,
      'username': widget.username,
    });
    return http.get(uri, headers: const {'Accept': 'application/json, text/plain, */*'})
        .timeout(const Duration(minutes: 2));
  }

  Future<http.Response> _postFile(String endpoint, File file, String text) async {
    final request = http.MultipartRequest('POST', Uri.parse(endpoint));
    request.headers['Accept'] = 'application/json, text/plain, */*';
    request.fields.addAll({
      'message': text,
      'prompt': text,
      'text': text,
      'username': widget.username,
    });
    final bytes = await file.readAsBytes();
    final name = _attachmentName ?? file.path.split(Platform.pathSeparator).last;
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: name));
    if (name.toLowerCase().endsWith('.jpg') || name.toLowerCase().endsWith('.jpeg') || name.toLowerCase().endsWith('.png') || name.toLowerCase().endsWith('.webp')) {
      request.files.add(http.MultipartFile.fromBytes('image', bytes, filename: name));
    }
    final streamed = await request.send().timeout(const Duration(minutes: 2));
    return http.Response.fromStream(streamed);
  }

  bool _isNotFound(http.Response response) => response.statusCode == 404;

  Future<http.Response> _requestAi({required String text, File? file}) async {
    // The supplied API has returned 404 for one HTTP method on some deployments.
    // Try the exact endpoint first, then the harmless trailing-slash variant.
    final endpoints = <String>[_endpoint, '$_endpoint/'];
    http.Response? last;

    if (file != null) {
      for (final endpoint in endpoints) {
        final response = await _postFile(endpoint, file, text);
        last = response;
        if (!_isNotFound(response)) return response;
      }
    } else {
      for (final endpoint in endpoints) {
        final response = await _postJson(endpoint, text);
        last = response;
        if (!_isNotFound(response)) return response;
      }
      // Some lightweight API routers expose chat as GET instead of POST.
      for (final endpoint in endpoints) {
        final response = await _getText(endpoint, text);
        last = response;
        if (!_isNotFound(response)) return response;
      }
    }

    return last ?? (throw const SocketException('Tidak ada respons dari server AI.'));
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachment == null) return;

    final localFile = _attachment;
    final localName = _attachmentName;
    _controller.clear();
    setState(() {
      _messages.add(_AiMessage(
        text: text.isEmpty ? 'Analisis berkas ini.' : text,
        fromUser: true,
        fileName: localName,
      ));
      _attachment = null;
      _attachmentName = null;
      _sending = true;
    });
    _scrollBottom();

    try {
      final response = await _requestAi(
        text: text.isEmpty ? 'Analisis berkas ini.' : text,
        file: localFile,
      );
      final body = response.body;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: ${_shorten(body)}');
      }
      final answer = _extractAnswer(body);
      if (answer.trim().isEmpty) throw Exception('Respons AI kosong.');
      if (!mounted) return;
      setState(() => _messages.add(_AiMessage(text: answer, fromUser: false)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_AiMessage(
        text: 'SixEyesX AI tidak dapat terhubung ke server.\n${_friendlyError(e)}',
        fromUser: false,
        error: true,
      )));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollBottom();
      }
    }
  }

  String _shorten(String value) {
    final v = value.trim();
    return v.length > 700 ? '${v.substring(0, 700)}…' : v;
  }

  String _friendlyError(Object error) {
    final s = error.toString();
    if (s.contains('SocketException')) return 'Server tidak dapat dijangkau. Coba lagi beberapa saat lagi.';
    if (s.contains('TimeoutException')) return 'Server terlalu lama merespons. Coba lagi.';
    return s.replaceFirst('Exception: ', '');
  }

  String _extractAnswer(String raw) {
    try {
      final data = jsonDecode(raw);
      String? find(dynamic value) {
        if (value is String && value.trim().isNotEmpty) return value.trim();
        if (value is List) {
          for (final item in value) {
            final found = find(item);
            if (found != null) return found;
          }
        }
        if (value is Map) {
          const keys = ['answer', 'response', 'message', 'text', 'content', 'result', 'output', 'reply'];
          for (final key in keys) {
            final found = find(value[key]);
            if (found != null) return found;
          }
          for (final key in ['data', 'choices', 'result']) {
            final found = find(value[key]);
            if (found != null) return found;
          }
        }
        return null;
      }
      return find(data) ?? raw;
    } catch (_) {
      return raw.trim();
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(children: [
          CircleAvatar(radius: 17, backgroundColor: _blue, child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 19)),
          SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SixEyesX AI', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.4)),
            Text('COPILOT', style: TextStyle(color: _cyan, fontSize: 9, letterSpacing: 2)),
          ]),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            itemCount: _messages.length,
            itemBuilder: (_, i) => _bubble(_messages[i]),
          ),
        ),
        _composer(),
      ]),
    );
  }

  Widget _bubble(_AiMessage m) => Align(
    alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .84),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: m.fromUser ? _blue.withOpacity(.22) : _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: m.error ? Colors.redAccent : (m.fromUser ? _blue : _border)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (m.fileName != null) ...[
          Row(children: [
            const Icon(Icons.attach_file_rounded, color: _cyan, size: 16),
            const SizedBox(width: 5),
            Expanded(child: Text(m.fileName!, style: const TextStyle(color: _cyan, fontSize: 11, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 7),
        ],
        Text(m.text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35)),
      ]),
    ),
  );

  Widget _composer() => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(color: _card, border: Border(top: BorderSide(color: _border))),
      child: Column(children: [
        if (_attachment != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: _blue.withOpacity(.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _blue)),
            child: Row(children: [
              const Icon(Icons.attach_file_rounded, color: _cyan, size: 18),
              const SizedBox(width: 7),
              Expanded(child: Text(_attachmentName ?? 'Attachment', style: const TextStyle(color: Colors.white, fontSize: 11))),
              IconButton(onPressed: () => setState(() { _attachment = null; _attachmentName = null; }), icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18)),
            ]),
          ),
        Row(children: [
          IconButton(onPressed: _sending ? null : _pickPhoto, icon: const Icon(Icons.photo_rounded, color: _cyan)),
          IconButton(onPressed: _sending ? null : _pickFile, icon: const Icon(Icons.attach_file_rounded, color: _cyan)),
          Expanded(child: Container(
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(22), border: Border.all(color: _border)),
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: 'Tulis ke SixEyesX AI...', hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10)),
              onSubmitted: (_) => _send(),
            ),
          )),
          const SizedBox(width: 7),
          GestureDetector(
            onTap: _sending ? null : _send,
            child: Container(width: 45, height: 45, decoration: BoxDecoration(shape: BoxShape.circle, color: _sending ? Colors.white12 : _blue, boxShadow: const [BoxShadow(color: Color(0x552F6FED), blurRadius: 12)]), child: _sending ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: _cyan)) : const Icon(Icons.arrow_upward_rounded, color: Colors.white)),
          ),
        ]),
      ]),
    ),
  );
}

class _AiMessage {
  final String text;
  final bool fromUser;
  final String? fileName;
  final bool error;
  const _AiMessage({required this.text, required this.fromUser, this.fileName, this.error = false});
}
