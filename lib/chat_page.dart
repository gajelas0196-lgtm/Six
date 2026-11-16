import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'srv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

// ══════════════════════════════════════════════════
//  PALETTE — WhatsApp iPhone
// ══════════════════════════════════════════════════

class _P {
  // List screen — WhatsApp iPhone DARK MODE
  static const bg            = Color(0xFF000000);  // pure black
  static const card          = Color(0xFF1C1C1E);  // elevated dark surface (app bars/tiles/sheets)
  static const divider       = Color(0xFF2C2C2E);
  static const textPrimary   = Color(0xFFFFFFFF);  // screen-level text (white)
  static const textSecondary = Color(0xFF8E8E93);  // screen-level secondary text (iOS gray)
  static const iosBlue       = Color(0xFF0A84FF);  // iOS dark-mode accent blue

  // Chat room
  static const chatWall      = Color(0xFF000000);  // black wallpaper
  static const meBubble      = Color(0xFFDCF8C6);  // sent — green
  static const otherBubble   = Color(0xFFFFFFFF);  // received — white
  static const green         = Color(0xFF25D366);
  static const greenDark     = Color(0xFF128C3F);

  // Text drawn directly on the light bubbles above — always dark, regardless of theme
  static const bubbleText          = Color(0xFF0B141A);
  static const bubbleTextSecondary = Color(0xFF667781);

  // Input bar
  static const inputBg       = Color(0xFF1C1C1E);
}

// ══════════════════════════════════════════════════
//  MODELS
// ══════════════════════════════════════════════════

class ChatMessage {
  final String id;
  final String from;
  final String? to;
  final String role;
  final String? text;
  final String? mediaUrl;
  final String mediaType;
  final String time;
  final bool fromMe;
  final String? replyToId;
  final String? replyToText;
  final String? replyToFrom;
  final Map<String, List<String>> reactions;
  final PollData? poll;
  final String? fileName;

  ChatMessage({
    required this.id,
    required this.from,
    this.to,
    this.role = 'member',
    this.text,
    this.mediaUrl,
    this.mediaType = 'text',
    required this.time,
    this.fromMe = false,
    this.replyToId,
    this.replyToText,
    this.replyToFrom,
    Map<String, List<String>>? reactions,
    this.poll,
    this.fileName,
  }) : reactions = reactions ?? {};

  factory ChatMessage.fromJson(Map<String, dynamic> j, String myUsername) {
    Map<String, List<String>> rxn = {};
    if (j['reactions'] is Map) {
      (j['reactions'] as Map).forEach((k, v) {
        rxn[k.toString()] = List<String>.from(v ?? []);
      });
    }
    return ChatMessage(
      id: j['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      from: j['from'] ?? '',
      to: j['to'],
      role: j['role'] ?? 'member',
      text: j['message'] ?? j['text'],
      mediaUrl: j['mediaUrl'],
      mediaType: j['mediaType'] ?? 'text',
      time: j['time'] ?? DateTime.now().toIso8601String(),
      fromMe: j['from'] == myUsername,
      replyToId: j['replyToId'],
      replyToText: j['replyToText'],
      replyToFrom: j['replyToFrom'],
      reactions: rxn,
      poll: j['poll'] != null ? PollData.fromJson(j['poll']) : null,
      fileName: j['fileName'],
    );
  }

  ChatMessage copyWithReactions(Map<String, List<String>> newReactions) {
    return ChatMessage(
      id: id, from: from, to: to, role: role, text: text,
      mediaUrl: mediaUrl, mediaType: mediaType, time: time,
      fromMe: fromMe, replyToId: replyToId, replyToText: replyToText,
      replyToFrom: replyToFrom, reactions: newReactions, poll: poll, fileName: fileName,
    );
  }
}

class PollData {
  final String question;
  final List<String> options;
  final Map<String, String> votes;

  PollData({required this.question, required this.options, Map<String, String>? votes})
      : votes = votes ?? {};

  factory PollData.fromJson(Map<String, dynamic> j) => PollData(
        question: j['question'] ?? '',
        options: List<String>.from(j['options'] ?? []),
        votes: Map<String, String>.from(j['votes'] ?? {}),
      );

  Map<String, dynamic> toJson() => {'question': question, 'options': options, 'votes': votes};
  int voteCount(String option) => votes.values.where((v) => v == option).length;
  int get totalVotes => votes.length;
}

class StatusItem {
  final String username;
  final String role;
  final String? mediaUrl;
  final String mediaType;
  final String? text;
  final String time;
  final String? profilePhoto;
  bool seen;

  StatusItem({
    required this.username,
    required this.role,
    this.mediaUrl,
    this.mediaType = 'text',
    this.text,
    required this.time,
    this.profilePhoto,
    this.seen = false,
  });

  factory StatusItem.fromJson(Map<String, dynamic> j) => StatusItem(
        username: j['username'] ?? '',
        role: j['role'] ?? 'member',
        mediaUrl: j['mediaUrl'],
        mediaType: j['mediaType'] ?? 'text',
        text: j['text'],
        time: j['time'] ?? DateTime.now().toIso8601String(),
        profilePhoto: j['profilePhoto'],
      );
}

class ChatUser {
  final String username;
  final String role;
  final bool online;
  final String? profilePhoto;

  ChatUser({required this.username, required this.role, this.online = false, this.profilePhoto});

  factory ChatUser.fromJson(Map<String, dynamic> j) => ChatUser(
        username: j['username'] ?? '',
        role: j['role'] ?? 'member',
        online: j['online'] ?? false,
        profilePhoto: j['profilePhoto'],
      );
}

// ══════════════════════════════════════════════════
//  HELPERS
// ══════════════════════════════════════════════════

Color _roleColor(String role) {
  switch (role.toLowerCase()) {
    case 'owner':    return Colors.red;
    case 'admin':    return Colors.orange;
    case 'reseller': return _P.green;
    case 'vip':      return Colors.purple;
    case 'dev':      return _P.iosBlue;
    default:         return Colors.grey;
  }
}

// ── Warna & label per tipe pesan — biar cepat kebaca tipe pesannya ──
Color _mediaTypeColor(String type) {
  switch (type) {
    case 'image': return const Color(0xFF2F9BFF); // biru
    case 'video': return const Color(0xFFB14EFF); // ungu
    case 'file':  return const Color(0xFFFF9F2F); // oranye
    case 'poll':  return const Color(0xFF26C6DA); // teal
    default:      return _P.green;
  }
}

String _mediaTypeLabel(String type) {
  switch (type) {
    case 'image': return 'PHOTO';
    case 'video': return 'VIDEO';
    case 'file':  return 'FILE';
    case 'poll':  return 'POLL';
    default:      return '';
  }
}

IconData _mediaTypeIcon(String type) {
  switch (type) {
    case 'image': return Icons.photo_camera_rounded;
    case 'video': return Icons.videocam_rounded;
    case 'file':  return Icons.insert_drive_file_rounded;
    case 'poll':  return Icons.bar_chart_rounded;
    default:      return Icons.chat_bubble_rounded;
  }
}

Widget _buildAvatar(String username, String? photoUrl, {double radius = 22}) {
  if (photoUrl != null && photoUrl.isNotEmpty) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: NetworkImage(photoUrl),
      backgroundColor: Colors.transparent,
    );
  }
  final col = _roleColor(username);
  return CircleAvatar(
    radius: radius,
    backgroundColor: col.withOpacity(0.18),
    child: Text(
      username.isNotEmpty ? username[0].toUpperCase() : '?',
      style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: radius * 0.75),
    ),
  );
}

String _shortTime(String iso) {
  try {
    final t = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    if (now.day == t.day && now.month == t.month && now.year == t.year) {
      return DateFormat('HH:mm').format(t);
    }
    if (now.difference(t).inDays < 7) return DateFormat('EEE').format(t);
    return DateFormat('dd/MM/yy').format(t);
  } catch (_) {
    return '';
  }
}

String _timeAgo(String iso) {
  try {
    final t = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return DateFormat('HH:mm').format(t);
    return DateFormat('dd/MM').format(t);
  } catch (_) {
    return '';
  }
}

String _previewText(ChatMessage m) {
  final prefix = m.fromMe ? 'You: ' : '';
  switch (m.mediaType) {
    case 'image': return '${prefix}📷 Photo';
    case 'video': return '${prefix}🎥 Video';
    case 'file':  return '${prefix}📎 ${m.fileName ?? 'Document'}';
    case 'poll':  return '${prefix}📊 ${m.poll?.question ?? 'Poll'}';
    default:      return '$prefix${m.text ?? ''}';
  }
}

// ══════════════════════════════════════════════════
//  CHAT PAGE (Main entry)
// ══════════════════════════════════════════════════

class ChatPage extends StatefulWidget {
  final String currentUsername;
  final String currentRole;
  final String sessionKey;
  final String? profilePhotoUrl;

  const ChatPage({
    super.key,
    required this.currentUsername,
    required this.currentRole,
    required this.sessionKey,
    this.profilePhotoUrl,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // WebSocket
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  bool _wsConnected = false;
  bool _wsReconnecting = false;
  Timer? _reconnectTimer;

  // Messages
  final List<String> _dmUserList = [];
  final Map<String, List<ChatMessage>> _dmMessages = {};
  final Set<String> _publicMsgIds = {};
  final List<ChatMessage> _publicMessages = [];
  int _publicOnline = 0;

  // ValueNotifiers — _ChatRoomPage listen ke ini untuk update real-time tanpa delay
  final _publicNotifier = ValueNotifier<int>(0);
  final Map<String, ValueNotifier<int>> _dmNotifiers = {};

  // Group
  String _groupName = 'Public Group';
  String _groupDesc = 'Official group';
  String? _groupPhotoUrl;

  // Status
  final List<StatusItem> _statusList = [];
  List<ChatUser> _allUsers = [];

  // Active chat
  String? _activeDmUser;
  bool _inPublicRoom = false;

  // Scroll — satu per room agar tidak conflict
  final _publicScrollCtrl = ScrollController();
  final Map<String, ScrollController> _dmScrollCtrls = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _connectWS();
    _fetchAllUsers();
    _fetchStatuses();
    _fetchGroupSettings();
  }

  // ── WebSocket ────────────────────────────────────

  void _connectWS() {
    if (_wsReconnecting) return;
    try {
      // Domain dari srv.dart (Srv.chatWsUrl)
      _channel = WebSocketChannel.connect(Uri.parse(Srv.chatWsUrl));
      _wsSub = _channel!.stream.listen(
        _onWsMessage,
        onDone: _onWsDone,
        onError: _onWsError,
        cancelOnError: false,
      );
      _sendWs({'type': 'auth', 'key': widget.sessionKey});
      // ── Re-join room/DM yang sedang aktif tiap kali WS reconnect ──
      // Server simpan keanggotaan grup (publicRoomClients) cuma di memory,
      // jadi kalau server restart/koneksi putus-sambung, kita HARUS join ulang
      // manual. Tanpa ini, user yang masih di dalam halaman grup bakal
      // berhenti nerima pesan baru tanpa sadar.
      if (_inPublicRoom) {
        _sendWs({'type': 'joinPublicRoom', 'key': widget.sessionKey});
      }
      if (_activeDmUser != null) {
        _sendWs({'type': 'getMessages', 'with': _activeDmUser});
      }
      if (mounted) setState(() { _wsConnected = true; _wsReconnecting = false; });
    } catch (e) {
      debugPrint('WS connect error: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_wsReconnecting) return;
    _wsReconnecting = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), () {
      _wsReconnecting = false;
      if (mounted) _connectWS();
    });
  }

  void _sendWs(Map<String, dynamic> data) {
    try { _channel?.sink.add(jsonEncode(data)); } catch (_) {}
  }

  void _onWsDone() {
    if (mounted) setState(() => _wsConnected = false);
    _scheduleReconnect();
  }

  void _onWsError(Object e) {
    if (mounted) setState(() => _wsConnected = false);
    _scheduleReconnect();
  }

  void _onWsMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final type = data['type'];

      if (type == 'chatList') {
        final users = List<String>.from(data['users'] ?? []);
        if (mounted) setState(() {
          for (final u in users) {
            if (!_dmUserList.contains(u)) _dmUserList.add(u);
          }
        });
      } else if (type == 'messages') {
        final withUser = data['with'] as String;
        final seen = <String>{};
        final deduped = <ChatMessage>[];
        for (final m in (data['messages'] as List? ?? [])) {
          final msg = ChatMessage.fromJson(m, widget.currentUsername);
          if (seen.add(msg.id)) deduped.add(msg);
        }
        if (mounted) setState(() => _dmMessages[withUser] = deduped);
        _getDmNotifier(withUser).value++;
        _scrollBottom(_getDmScrollCtrl(withUser));
      } else if (type == 'chat') {
        // Server kadang kirim format nested ({'message': {...}}), kadang flat
        // (field langsung di top-level kayak waktu kita kirim ke server).
        // Sebelumnya cuma nerima yang nested → kalau server relay flat,
        // parsing gagal diam-diam (ke-catch) dan pesan ke lawan chat ga pernah nongol.
        final rawMsg = data['message'];
        final Map<String, dynamic> msgJson = rawMsg is Map
            ? Map<String, dynamic>.from(rawMsg)
            : {...data, 'message': rawMsg};
        final msg = ChatMessage.fromJson(msgJson, widget.currentUsername);
        // If I sent it: key = recipient (msg.to). If I received it: key = sender (msg.from).
        // Guard against empty/null to avoid messages landing in a ghost bucket.
        final key = msg.fromMe
            ? (msg.to?.isNotEmpty == true ? msg.to! : '')
            : (msg.from.isNotEmpty ? msg.from : '');
        if (key.isEmpty) return; // drop malformed messages
        if (mounted) setState(() {
          _dmMessages.putIfAbsent(key, () => []);
          if (!_dmMessages[key]!.any((m) => m.id == msg.id)) {
            _dmMessages[key]!.add(msg);
          }
          if (!_dmUserList.contains(key)) _dmUserList.add(key);
        });
        _getDmNotifier(key).value++;
        if (_activeDmUser == key) _scrollBottom(_getDmScrollCtrl(key));
      } else if (type == 'publicHistory') {
        final msgs = (data['messages'] as List? ?? [])
            .map((m) => ChatMessage.fromJson(m, widget.currentUsername))
            .toList();
        if (mounted) setState(() {
          _publicMsgIds.clear();
          _publicMessages.clear();
          for (final m in msgs) {
            if (_publicMsgIds.add(m.id)) _publicMessages.add(m);
          }
        });
        _publicNotifier.value++;
        _scrollBottom(_publicScrollCtrl);
      } else if (type == 'publicMessage') {
        final msg = ChatMessage.fromJson(data, widget.currentUsername);
        if (!_publicMsgIds.contains(msg.id)) {
          if (mounted) setState(() {
            _publicMsgIds.add(msg.id);
            _publicMessages.add(msg);
          });
          _publicNotifier.value++;
          if (_inPublicRoom) _scrollBottom(_publicScrollCtrl);
        }
      } else if (type == 'publicOnlineCount') {
        if (mounted) setState(() => _publicOnline = data['count'] ?? 0);
      } else if (type == 'reaction') {
        _handleReactionUpdate(data);
      } else if (type == 'pollVote') {
        _handlePollVoteUpdate(data);
      } else if (type == 'newStatus') {
        final status = StatusItem.fromJson(data['status']);
        if (mounted) setState(() => _statusList.insert(0, status));
      } else if (type == 'groupSettings') {
        final settings = data['settings'] as Map<String, dynamic>?;
        if (settings != null && mounted) {
          setState(() {
            _groupName = settings['name'] ?? _groupName;
            _groupDesc = settings['description'] ?? _groupDesc;
            _groupPhotoUrl = settings['photoUrl'];
          });
        }
      }
    } catch (e) {
      debugPrint('WS parse error: $e');
    }
  }

  void _handleReactionUpdate(Map<String, dynamic> data) {
    final msgId = data['messageId'] as String?;
    final emoji  = data['emoji']     as String?;
    final user   = data['user']      as String?;
    if (msgId == null || emoji == null || user == null || !mounted) return;
    setState(() {
      // public
      final pi = _publicMessages.indexWhere((m) => m.id == msgId);
      if (pi != -1) {
        final rxn = Map<String, List<String>>.from(_publicMessages[pi].reactions);
        rxn.putIfAbsent(emoji, () => []);
        if (!rxn[emoji]!.contains(user)) rxn[emoji]!.add(user);
        _publicMessages[pi] = _publicMessages[pi].copyWithReactions(rxn);
      }
      // dm
      for (final key in _dmMessages.keys) {
        final di = _dmMessages[key]!.indexWhere((m) => m.id == msgId);
        if (di != -1) {
          final rxn = Map<String, List<String>>.from(_dmMessages[key]![di].reactions);
          rxn.putIfAbsent(emoji, () => []);
          if (!rxn[emoji]!.contains(user)) rxn[emoji]!.add(user);
          _dmMessages[key]![di] = _dmMessages[key]![di].copyWithReactions(rxn);
        }
      }
    });
  }

  void _handlePollVoteUpdate(Map<String, dynamic> data) {
    final msgId  = data['messageId'] as String?;
    final voter  = data['voter']     as String?;
    final option = data['option']    as String?;
    if (msgId == null || voter == null || option == null || !mounted) return;
    setState(() {
      for (final m in _publicMessages) {
        if (m.id == msgId && m.poll != null) m.poll!.votes[voter] = option;
      }
      for (final msgs in _dmMessages.values) {
        for (final m in msgs) {
          if (m.id == msgId && m.poll != null) m.poll!.votes[voter] = option;
        }
      }
    });
  }

  // ── API ──────────────────────────────────────────

  Future<void> _fetchAllUsers() async {
    try {
      final res = await http
          .get(Uri.parse('${Srv.baseUrl}/listUsers?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        if (data['users'] != null) {
          setState(() {
            _allUsers = (data['users'] as List)
                .map((u) => ChatUser.fromJson(u))
                .where((u) => u.username != widget.currentUsername)
                .toList();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchStatuses() async {
    try {
      final res = await http
          .get(Uri.parse('${Srv.baseUrl}/api/chat/statuses?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        if (data['statuses'] != null) {
          setState(() {
            _statusList
              ..clear()
              ..addAll((data['statuses'] as List).map((s) => StatusItem.fromJson(s)));
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchGroupSettings() async {
    try {
      final res = await http
          .get(Uri.parse('${Srv.baseUrl}/api/chat/group/settings?key=${widget.sessionKey}'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final s = data['settings'];
        if (s != null) {
          setState(() {
            _groupName    = s['name']        ?? _groupName;
            _groupDesc    = s['description'] ?? _groupDesc;
            _groupPhotoUrl = s['photoUrl'];
          });
        }
      }
    } catch (_) {}
  }

  // ── Scroll ───────────────────────────────────────

  ScrollController _getDmScrollCtrl(String user) {
    return _dmScrollCtrls.putIfAbsent(user, () => ScrollController());
  }

  ValueNotifier<int> _getDmNotifier(String user) {
    return _dmNotifiers.putIfAbsent(user, () => ValueNotifier<int>(0));
  }

  void _scrollBottom(ScrollController ctrl) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ctrl.hasClients && ctrl.position.maxScrollExtent > 0) {
        ctrl.animateTo(
          ctrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Navigation ───────────────────────────────────

  void _openPublicRoom() {
    setState(() { _activeDmUser = null; _inPublicRoom = true; });
    _sendWs({'type': 'joinPublicRoom', 'key': widget.sessionKey});
    Navigator.push(context, _slideRoute(_ChatRoomPage(
      title: _groupName,
      subtitle: '$_publicOnline online',
      groupPhotoUrl: _groupPhotoUrl,
      isPublic: true,
      isAdmin: widget.currentRole == 'owner' || widget.currentRole == 'admin',
      messagesGetter: () => _publicMessages,
      notifier: _publicNotifier,
      currentUsername: widget.currentUsername,
      currentRole: widget.currentRole,
      profilePhotoUrl: widget.profilePhotoUrl,
      sessionKey: widget.sessionKey,
      onSendText:  (t, r) => _sendPublicText(t, r),
      onSendMedia: (f, t) => _sendMedia(null, f, t),
      onSendPoll:  (q, o) => _sendPoll(null, q, o),
      onReact:     (id, e) => _sendReaction(id, e),
      onVotePoll:  (id, o) => _sendPollVote(id, o),
      onGroupSettingsUpdated: (name, desc, photo) {
        if (mounted) setState(() { _groupName = name; _groupDesc = desc; _groupPhotoUrl = photo; });
      },
      scrollCtrl: _publicScrollCtrl,
    ))).then((_) { if (mounted) setState(() => _inPublicRoom = false); });
  }

  void _openDm(String targetUser) {
    setState(() => _activeDmUser = targetUser);
    _sendWs({'type': 'getMessages', 'with': targetUser});
    final sc = _getDmScrollCtrl(targetUser);
    Navigator.push(context, _slideRoute(_ChatRoomPage(
      title: targetUser,
      subtitle: null,
      groupPhotoUrl: null,
      isPublic: false,
      isAdmin: false,
      messagesGetter: () => _dmMessages[targetUser] ?? [],
      notifier: _getDmNotifier(targetUser),
      currentUsername: widget.currentUsername,
      currentRole: widget.currentRole,
      profilePhotoUrl: widget.profilePhotoUrl,
      sessionKey: widget.sessionKey,
      onSendText:  (t, r) => _sendDmText(targetUser, t, r),
      onSendMedia: (f, t) => _sendMedia(targetUser, f, t),
      onSendPoll:  (q, o) => _sendPoll(targetUser, q, o),
      onReact:     (id, e) => _sendReaction(id, e),
      onVotePoll:  (id, o) => _sendPollVote(id, o),
      onGroupSettingsUpdated: null,
      scrollCtrl: sc,
    ))).then((_) { if (mounted) setState(() => _activeDmUser = null); });
  }

  PageRoute _slideRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 280),
  );

  // ── Send ─────────────────────────────────────────

  void _sendPublicText(String text, ChatMessage? replyTo) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final localMsg = ChatMessage(
      id: id,
      from: widget.currentUsername,
      role: widget.currentRole,
      text: text,
      time: DateTime.now().toIso8601String(),
      fromMe: true,
      replyToId: replyTo?.id,
      replyToText: replyTo?.text,
      replyToFrom: replyTo?.from,
    );
    if (mounted) setState(() {
      if (_publicMsgIds.add(id)) _publicMessages.add(localMsg);
    });
    _publicNotifier.value++;
    if (_inPublicRoom) _scrollBottom(_publicScrollCtrl);

    _sendWs({
      'type': 'publicChat',
      'key': widget.sessionKey,
      'message': text,
      'id': id,
      if (replyTo != null) 'replyToId': replyTo.id,
      if (replyTo != null) 'replyToText': replyTo.text ?? '',
      if (replyTo != null) 'replyToFrom': replyTo.from,
    });
  }

  void _sendDmText(String to, String text, ChatMessage? replyTo) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final localMsg = ChatMessage(
      id: id,
      from: widget.currentUsername,
      to: to,
      role: widget.currentRole,
      text: text,
      time: DateTime.now().toIso8601String(),
      fromMe: true,
      replyToId: replyTo?.id,
      replyToText: replyTo?.text,
      replyToFrom: replyTo?.from,
    );
    if (mounted) setState(() {
      _dmMessages.putIfAbsent(to, () => []);
      if (!_dmMessages[to]!.any((m) => m.id == id)) _dmMessages[to]!.add(localMsg);
      if (!_dmUserList.contains(to)) _dmUserList.add(to);
    });
    _getDmNotifier(to).value++;
    if (_activeDmUser == to) _scrollBottom(_getDmScrollCtrl(to));

    _sendWs({
      'type': 'chat',
      'key': widget.sessionKey,
      'to': to,
      'message': text,
      'id': id,
      if (replyTo != null) 'replyToId': replyTo.id,
      if (replyTo != null) 'replyToText': replyTo.text ?? '',
      if (replyTo != null) 'replyToFrom': replyTo.from,
    });
  }

  Future<void> _sendMedia(String? to, File file, String type) async {
    try {
      final mime = lookupMimeType(file.path) ?? 'application/octet-stream';
      final req = http.MultipartRequest('POST', Uri.parse('${Srv.baseUrl}/api/chat/upload'));
      req.fields['key'] = widget.sessionKey;
      if (to != null) req.fields['to'] = to;
      req.fields['mediaType'] = type;
      req.files.add(await http.MultipartFile.fromPath(
        'file', file.path, contentType: MediaType.parse(mime),
      ));
      final res = await req.send().timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) {
        final body = jsonDecode(await res.stream.bytesToString());
        final mediaUrl = body['url'] as String?;
        if (mediaUrl == null) return;
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        final fileName = file.path.split('/').last;

        final localMsg = ChatMessage(
          id: id,
          from: widget.currentUsername,
          to: to,
          role: widget.currentRole,
          text: '',
          mediaUrl: mediaUrl,
          mediaType: type,
          fileName: fileName,
          time: DateTime.now().toIso8601String(),
          fromMe: true,
        );
        if (mounted) setState(() {
          if (to == null) {
            if (_publicMsgIds.add(id)) _publicMessages.add(localMsg);
          } else {
            _dmMessages.putIfAbsent(to, () => []);
            if (!_dmMessages[to]!.any((m) => m.id == id)) _dmMessages[to]!.add(localMsg);
            if (!_dmUserList.contains(to)) _dmUserList.add(to);
          }
        });
        if (to == null) {
          _publicNotifier.value++;
          if (_inPublicRoom) _scrollBottom(_publicScrollCtrl);
        } else {
          _getDmNotifier(to).value++;
          if (_activeDmUser == to) _scrollBottom(_getDmScrollCtrl(to));
        }

        final payload = {
          'type': to == null ? 'publicChat' : 'chat',
          'key': widget.sessionKey,
          if (to != null) 'to': to,
          'message': '',
          'mediaUrl': mediaUrl,
          'mediaType': type,
          'fileName': fileName,
          'id': id,
        };
        _sendWs(payload);
      }
    } catch (e) {
      debugPrint('Upload error: $e');
    }
  }

  void _sendPoll(String? to, String question, List<String> options) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final localMsg = ChatMessage(
      id: id,
      from: widget.currentUsername,
      to: to,
      role: widget.currentRole,
      text: '',
      mediaType: 'poll',
      poll: PollData(question: question, options: options, votes: {}),
      time: DateTime.now().toIso8601String(),
      fromMe: true,
    );
    if (mounted) setState(() {
      if (to == null) {
        if (_publicMsgIds.add(id)) _publicMessages.add(localMsg);
      } else {
        _dmMessages.putIfAbsent(to, () => []);
        if (!_dmMessages[to]!.any((m) => m.id == id)) _dmMessages[to]!.add(localMsg);
        if (!_dmUserList.contains(to)) _dmUserList.add(to);
      }
    });
    if (to == null) {
      _publicNotifier.value++;
      if (_inPublicRoom) _scrollBottom(_publicScrollCtrl);
    } else {
      _getDmNotifier(to).value++;
      if (_activeDmUser == to) _scrollBottom(_getDmScrollCtrl(to));
    }

    _sendWs({
      'type': to == null ? 'publicChat' : 'chat',
      'key': widget.sessionKey,
      if (to != null) 'to': to,
      'message': '',
      'mediaType': 'poll',
      'poll': {'question': question, 'options': options, 'votes': {}},
      'id': id,
    });
  }

  void _sendReaction(String msgId, String emoji) {
    _sendWs({'type': 'reaction', 'key': widget.sessionKey, 'messageId': msgId, 'emoji': emoji});
  }

  void _sendPollVote(String msgId, String option) {
    _sendWs({'type': 'pollVote', 'key': widget.sessionKey, 'messageId': msgId, 'option': option});
  }

  // ── Status ───────────────────────────────────────

  Future<void> _postStatus(File file, String type, String? text) async {
    try {
      final mime = lookupMimeType(file.path) ?? 'application/octet-stream';
      final req = http.MultipartRequest('POST', Uri.parse('${Srv.baseUrl}/api/chat/status'));
      req.fields['key'] = widget.sessionKey;
      req.fields['mediaType'] = type;
      if (text != null) req.fields['text'] = text;
      req.files.add(await http.MultipartFile.fromPath(
        'file', file.path, contentType: MediaType.parse(mime),
      ));
      await req.send();
      await _fetchStatuses();
    } catch (e) {
      debugPrint('Status upload error: $e');
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _wsSub?.cancel();
    _channel?.sink.close();
    _tabController.dispose();
    _publicScrollCtrl.dispose();
    for (final sc in _dmScrollCtrls.values) sc.dispose();
    _publicNotifier.dispose();
    for (final n in _dmNotifiers.values) n.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // prevent accidental swipe
        children: [_buildChatsTab(), _buildStatusTab()],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _P.card,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleSpacing: 20,
      title: const Text(
        'Chats',
        style: TextStyle(color: _P.textPrimary, fontWeight: FontWeight.w700, fontSize: 22,
            fontFamily: '.SF Pro Display'),
      ),
      actions: [
        // WS indicator
        if (!_wsConnected)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Tooltip(
              message: 'Reconnecting...',
              child: SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.orange.shade400,
                ),
              ),
            ),
          ),
        // Online badge
        Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _P.green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _P.green.withOpacity(0.35)),
          ),
          child: Row(children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: _P.green, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            const Text('Online', style: TextStyle(color: _P.green, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ]),
        ),
        // Compose
        GestureDetector(
          onTap: _showSelectUser,
          child: Container(
            margin: const EdgeInsets.only(right: 14),
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: _P.iosBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit_square, color: _P.iosBlue, size: 17),
          ),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: _P.iosBlue,
        indicatorWeight: 2.5,
        labelColor: _P.iosBlue,
        unselectedLabelColor: _P.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
        tabs: const [Tab(text: 'Chats'), Tab(text: 'Status')],
      ),
    );
  }

  // ── Chats Tab ────────────────────────────────────

  Widget _buildChatsTab() {
    final publicLast = _publicMessages.isNotEmpty ? _publicMessages.last : null;
    final groupAvatar = _groupPhotoUrl != null && _groupPhotoUrl!.isNotEmpty
        ? CircleAvatar(radius: 26, backgroundImage: NetworkImage(_groupPhotoUrl!), backgroundColor: Colors.transparent)
        : Container(
            width: 52, height: 52,
            decoration: const BoxDecoration(color: _P.green, shape: BoxShape.circle),
            child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 26),
          );

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _ChatTile(
          avatar: groupAvatar,
          title: _groupName,
          subtitle: publicLast != null ? _previewText(publicLast) : '$_publicOnline online',
          time: publicLast != null ? _shortTime(publicLast.time) : null,
          pinned: true,
          onTap: _openPublicRoom,
        ),
        const _Divider(),
        if (_dmUserList.isEmpty)
          _buildEmptyDms()
        else
          ..._dmUserList.map((u) {
            final msgs = _dmMessages[u] ?? [];
            final last = msgs.isNotEmpty ? msgs.last : null;
            return Column(children: [
              _ChatTile(
                avatar: _buildAvatar(u, null, radius: 26),
                title: u,
                subtitle: last != null ? _previewText(last) : '',
                time: last != null ? _shortTime(last.time) : null,
                onTap: () => _openDm(u),
              ),
              const _Divider(),
            ]);
          }),
      ],
    );
  }

  Widget _buildEmptyDms() {
    return Padding(
      padding: const EdgeInsets.only(top: 72),
      child: Column(children: [
        Icon(Icons.chat_bubble_outline_rounded, color: Colors.white.withOpacity(0.10), size: 72),
        const SizedBox(height: 14),
        const Text('No direct chats yet', style: TextStyle(color: _P.textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        const Text('Tap ✏️ above to start a conversation', style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13)),
      ]),
    );
  }

  // ── Status Tab ───────────────────────────────────

  Widget _buildStatusTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      children: [
        _buildMyStatusTile(),
        if (_statusList.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Recent updates', style: TextStyle(color: _P.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          ),
          ..._statusList.map(_buildStatusTile),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: Text('No status updates', style: TextStyle(color: Color(0xFFAAAAAA)))),
          ),
      ],
    );
  }

  Widget _buildMyStatusTile() {
    return InkWell(
      onTap: _showAddStatus,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _P.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _P.divider),
        ),
        child: Row(children: [
          Stack(children: [
            _buildAvatar(widget.currentUsername, widget.profilePhotoUrl, radius: 26),
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                    color: _P.green, shape: BoxShape.circle,
                    border: Border.all(color: _P.card, width: 2)),
                child: const Icon(Icons.add, color: Colors.white, size: 13),
              ),
            ),
          ]),
          const SizedBox(width: 14),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('My Status', style: TextStyle(color: _P.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
            SizedBox(height: 2),
            Text('Tap to add status update', style: TextStyle(color: _P.textSecondary, fontSize: 12.5)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildStatusTile(StatusItem s) {
    final unseen = !s.seen;
    return InkWell(
      onTap: () => _openStatusViewer(s),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _P.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _P.divider),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: unseen
                  ? const LinearGradient(colors: [_P.green, Color(0xFF128C3F)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                  : null,
              border: unseen ? null : Border.all(color: _P.divider, width: 2),
            ),
            child: _buildAvatar(s.username, s.profilePhoto, radius: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.username, style: const TextStyle(color: _P.textPrimary, fontWeight: FontWeight.w600, fontSize: 14.5)),
            const SizedBox(height: 2),
            Text(_timeAgo(s.time), style: const TextStyle(color: _P.textSecondary, fontSize: 12)),
          ])),
          if (unseen)
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: _P.green, shape: BoxShape.circle),
            ),
        ]),
      ),
    );
  }

  // ── Select User ──────────────────────────────────

  void _showSelectUser() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _SelectUserPage(
        users: _allUsers,
        onSelect: (user) { Navigator.pop(context); _openDm(user.username); },
        currentUsername: widget.currentUsername,
      ),
    ));
  }

  // ── Add Status ───────────────────────────────────

  void _showAddStatus() async {
    final picker = ImagePicker();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: _P.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 36, height: 4, decoration: BoxDecoration(color: _P.divider, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text('Add Status', style: TextStyle(color: _P.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        ListTile(
          leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: _P.iosBlue.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.image_rounded, color: _P.iosBlue, size: 20)),
          title: const Text('Photo', style: TextStyle(color: _P.textPrimary, fontWeight: FontWeight.w500)),
          onTap: () async {
            Navigator.pop(context);
            final img = await picker.pickImage(source: ImageSource.gallery);
            if (img != null) await _postStatus(File(img.path), 'image', null);
          },
        ),
        ListTile(
          leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.videocam_rounded, color: Colors.red, size: 20)),
          title: const Text('Video', style: TextStyle(color: _P.textPrimary, fontWeight: FontWeight.w500)),
          onTap: () async {
            Navigator.pop(context);
            final vid = await picker.pickVideo(source: ImageSource.gallery);
            if (vid != null) await _postStatus(File(vid.path), 'video', null);
          },
        ),
        ListTile(
          leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: _P.green.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.text_fields_rounded, color: _P.green, size: 20)),
          title: const Text('Text', style: TextStyle(color: _P.textPrimary, fontWeight: FontWeight.w500)),
          onTap: () { Navigator.pop(context); _showTextStatusDialog(); },
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  void _showTextStatusDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _P.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Post Text Status', style: TextStyle(color: _P.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: _P.textPrimary),
          decoration: const InputDecoration(
            hintText: "What's on your mind?",
            hintStyle: TextStyle(color: _P.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _P.green)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _P.green, width: 2)),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: _P.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _P.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                Navigator.pop(context);
                _sendWs({'type': 'newStatus', 'key': widget.sessionKey, 'mediaType': 'text', 'text': ctrl.text.trim()});
                _fetchStatuses();
              }
            },
            child: const Text('Post', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _openStatusViewer(StatusItem s) {
    setState(() => s.seen = true);
    Navigator.push(context, MaterialPageRoute(builder: (_) => _StatusViewerPage(status: s)));
  }
}

// ══════════════════════════════════════════════════
//  REUSABLE WIDGETS
// ══════════════════════════════════════════════════

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Divider(height: 1, color: _P.divider, indent: 82);
}

class _ChatTile extends StatelessWidget {
  final Widget avatar;
  final String title;
  final String subtitle;
  final String? time;
  final bool pinned;
  final VoidCallback onTap;

  const _ChatTile({
    required this.avatar,
    required this.title,
    required this.subtitle,
    this.time,
    this.pinned = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: _P.card,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          avatar,
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(title,
                    style: const TextStyle(color: _P.textPrimary, fontWeight: FontWeight.w600, fontSize: 15.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (pinned) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _P.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('📌 Pinned', style: TextStyle(color: _P.green, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                  style: const TextStyle(color: _P.textSecondary, fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
            ]),
          ),
          if (time != null) ...[
            const SizedBox(width: 10),
            Text(time!, style: const TextStyle(color: _P.textSecondary, fontSize: 11.5)),
          ],
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
//  SELECT USER PAGE
// ══════════════════════════════════════════════════

class _SelectUserPage extends StatefulWidget {
  final List<ChatUser> users;
  final ValueChanged<ChatUser> onSelect;
  final String currentUsername;

  const _SelectUserPage({required this.users, required this.onSelect, required this.currentUsername});

  @override
  State<_SelectUserPage> createState() => _SelectUserPageState();
}

class _SelectUserPageState extends State<_SelectUserPage> {
  String _search = '';

  List<ChatUser> get _filtered => widget.users
      .where((u) => u.username.toLowerCase().contains(_search.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.card,
        elevation: 0.5,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _P.iosBlue, size: 19),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New Message', style: TextStyle(color: _P.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(color: _P.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search',
              hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF8E8E93), size: 20),
              filled: true,
              fillColor: _P.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? const Center(child: Text('No users found', style: TextStyle(color: _P.textSecondary)))
              : ListView.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: _P.divider, indent: 72),
                  itemBuilder: (_, i) {
                    final u = _filtered[i];
                    final col = _roleColor(u.role);
                    return ListTile(
                      onTap: () => widget.onSelect(u),
                      leading: Stack(children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: u.profilePhoto != null ? NetworkImage(u.profilePhoto!) : null,
                          backgroundColor: col.withOpacity(0.15),
                          child: u.profilePhoto == null
                              ? Text(u.username[0].toUpperCase(), style: TextStyle(color: col, fontWeight: FontWeight.bold))
                              : null,
                        ),
                        if (u.online)
                          Positioned(
                            bottom: 1, right: 1,
                            child: Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(
                                color: _P.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: _P.card, width: 1.5),
                              ),
                            ),
                          ),
                      ]),
                      title: Text(u.username, style: const TextStyle(color: _P.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                      subtitle: Text(u.role, style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w500)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFC7C7CC)),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════
//  CHAT ROOM PAGE
// ══════════════════════════════════════════════════

class _ChatRoomPage extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? groupPhotoUrl;
  final bool isPublic;
  final bool isAdmin;
  // Getter so room page always reads live data from parent state
  final List<ChatMessage> Function() messagesGetter;
  final ValueNotifier<int> notifier; // triggers rebuild when new messages arrive
  final String currentUsername;
  final String currentRole;
  final String? profilePhotoUrl;
  final String sessionKey;
  final void Function(String text, ChatMessage? replyTo) onSendText;
  final void Function(File file, String type) onSendMedia;
  final void Function(String question, List<String> options) onSendPoll;
  final void Function(String msgId, String emoji) onReact;
  final void Function(String msgId, String option) onVotePoll;
  final void Function(String name, String desc, String? photoUrl)? onGroupSettingsUpdated;
  final ScrollController scrollCtrl;

  const _ChatRoomPage({
    required this.title,
    required this.subtitle,
    this.groupPhotoUrl,
    required this.isPublic,
    required this.isAdmin,
    required this.messagesGetter,
    required this.notifier,
    required this.currentUsername,
    required this.currentRole,
    this.profilePhotoUrl,
    required this.sessionKey,
    required this.onSendText,
    required this.onSendMedia,
    required this.onSendPoll,
    required this.onReact,
    required this.onVotePoll,
    this.onGroupSettingsUpdated,
    required this.scrollCtrl,
  });

  @override
  State<_ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<_ChatRoomPage> {
  final _textCtrl    = TextEditingController();
  final _focusNode   = FocusNode();
  ChatMessage? _replyingTo;

  OverlayEntry? _emojiOverlay;

  static const _emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥', '👀', '💯'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void didUpdateWidget(_ChatRoomPage old) {
    super.didUpdateWidget(old);
    // Scroll to bottom jika ada pesan baru (notifier sudah handle rebuild)
    final newLen = widget.messagesGetter().length;
    final oldLen = old.messagesGetter().length;
    if (newLen != oldLen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _animateToBottom());
    }
  }

  @override
  void dispose() {
    _removeEmojiOverlay();
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    final ctrl = widget.scrollCtrl;
    if (ctrl.hasClients) ctrl.jumpTo(ctrl.position.maxScrollExtent);
  }

  void _animateToBottom() {
    final ctrl = widget.scrollCtrl;
    if (ctrl.hasClients) {
      ctrl.animateTo(ctrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    widget.onSendText(text, _replyingTo);
    _textCtrl.clear();
    if (mounted) setState(() => _replyingTo = null);
  }

  Future<void> _pickMedia(String type) async {
    try {
      if (type == 'file') {
        final result = await FilePicker.platform.pickFiles();
        if (result?.files.single.path != null) {
          widget.onSendMedia(File(result!.files.single.path!), 'file');
        }
        return;
      }
      final picker = ImagePicker();
      final XFile? picked = type == 'image'
          ? await picker.pickImage(source: ImageSource.gallery, imageQuality: 75)
          : await picker.pickVideo(source: ImageSource.gallery);
      if (picked != null) widget.onSendMedia(File(picked.path), type);
    } catch (e) {
      debugPrint('Pick error: $e');
    }
  }

  // ── Emoji / Action Overlay ────────────────────────

  void _removeEmojiOverlay() {
    _emojiOverlay?.remove();
    _emojiOverlay = null;
  }

  void _showEmojiOverlay(ChatMessage msg, Offset globalPos) {
    _removeEmojiOverlay();
    final size = MediaQuery.of(context).size;
    final bool above = globalPos.dy > size.height * 0.55;

    _emojiOverlay = OverlayEntry(
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _removeEmojiOverlay,
        child: Stack(children: [
          // Dim backdrop
          Container(color: Colors.black.withOpacity(0.38)),
          // Emoji row
          Positioned(
            left: globalPos.dx.clamp(8, size.width - 310),
            top: above ? globalPos.dy - 108 : globalPos.dy - 14,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 20, offset: const Offset(0, 6))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _emojis.map((e) => GestureDetector(
                    onTap: () { _removeEmojiOverlay(); widget.onReact(msg.id, e); },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text(e, style: const TextStyle(fontSize: 26)),
                    ),
                  )).toList(),
                ),
              ),
            ),
          ),
          // Action menu
          Positioned(
            left: globalPos.dx.clamp(8, size.width - 190),
            top: above ? globalPos.dy - 108 + 62 : globalPos.dy - 14 + 62,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 14)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _overlayBtn(Icons.reply_rounded, 'Reply', _P.green, () {
                      _removeEmojiOverlay();
                      setState(() => _replyingTo = msg);
                    }),
                    if (msg.text != null && msg.text!.isNotEmpty)
                      _overlayBtn(Icons.copy_rounded, 'Copy', _P.bubbleTextSecondary, () {
                        _removeEmojiOverlay();
                        Clipboard.setData(ClipboardData(text: msg.text!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
    Overlay.of(context).insert(_emojiOverlay!);
  }

  Widget _overlayBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: _P.bubbleText, fontSize: 14)),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  ROOM BUILD
  // ══════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.chatWall,
      appBar: _buildRoomAppBar(),
      body: Column(children: [
        Expanded(child: ValueListenableBuilder<int>(
          valueListenable: widget.notifier,
          builder: (_, __, ___) => _buildMessageList(),
        )),
        if (_replyingTo != null) _buildReplyBar(),
        _buildInputBar(),
      ]),
    );
  }

  AppBar _buildRoomAppBar() {
    return AppBar(
      backgroundColor: _P.card,
      elevation: 0.5,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _P.iosBlue, size: 19),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(children: [
        // Avatar
        widget.isPublic
            ? (widget.groupPhotoUrl != null && widget.groupPhotoUrl!.isNotEmpty
                ? CircleAvatar(radius: 18, backgroundImage: NetworkImage(widget.groupPhotoUrl!))
                : const CircleAvatar(radius: 18, backgroundColor: _P.green,
                    child: Icon(Icons.people_alt_rounded, color: Colors.white, size: 18)))
            : _buildAvatar(widget.title, null, radius: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title,
                style: const TextStyle(color: _P.textPrimary, fontWeight: FontWeight.w600, fontSize: 15.5),
                overflow: TextOverflow.ellipsis),
              if (widget.subtitle != null)
                Text(widget.subtitle!,
                  style: const TextStyle(color: _P.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ]),
      actions: [
        if (widget.isPublic && widget.isAdmin)
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: _P.iosBlue, size: 22),
            onPressed: _showGroupSettings,
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildMessageList() {
    final messages = widget.messagesGetter();
    // Auto-scroll to bottom setelah rebuild (dipicu notifier)
    WidgetsBinding.instance.addPostFrameCallback((_) => _animateToBottom());
    if (messages.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              Icon(Icons.lock_outline_rounded, color: _P.textSecondary.withOpacity(0.7), size: 28),
              const SizedBox(height: 6),
              const Text('Messages are end-to-end\nencrypted', textAlign: TextAlign.center,
                  style: TextStyle(color: _P.textSecondary, fontSize: 12.5)),
            ]),
          ),
        ]),
      );
    }

    return GestureDetector(
      onTap: () {
        _removeEmojiOverlay();
        _focusNode.unfocus();
      },
      child: ListView.builder(
        controller: widget.scrollCtrl,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        itemCount: messages.length,
        // addAutomaticKeepAlives: false for performance
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemBuilder: (_, i) {
          final msg = messages[i];
          final prev = i > 0 ? messages[i - 1] : null;
          final showDate = prev == null || !_sameDay(msg.time, prev.time);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showDate) _buildDateChip(msg.time),
              _buildBubble(msg),
            ],
          );
        },
      ),
    );
  }

  bool _sameDay(String a, String b) {
    try {
      final ta = DateTime.parse(a).toLocal();
      final tb = DateTime.parse(b).toLocal();
      return ta.year == tb.year && ta.month == tb.month && ta.day == tb.day;
    } catch (_) { return false; }
  }

  Widget _buildDateChip(String iso) {
    String label;
    try {
      final t = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (now.day == t.day && now.month == t.month && now.year == t.year) {
        label = 'Today';
      } else if (now.difference(t).inDays == 1) {
        label = 'Yesterday';
      } else {
        label = DateFormat('d MMMM y').format(t);
      }
    } catch (_) { label = ''; }
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)],
        ),
        child: Text(label, style: const TextStyle(color: _P.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    final isMe = msg.fromMe;

    return GestureDetector(
      onLongPressStart: (d) => _showEmojiOverlay(msg, d.globalPosition),
      child: Padding(
        padding: EdgeInsets.only(
          top: 2, bottom: 2,
          left: isMe ? 48 : 4,
          right: isMe ? 4 : 48,
        ),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar (other, public only)
            if (!isMe && widget.isPublic) ...[
              _buildAvatar(msg.from, null, radius: 14),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Bubble
                  Container(
                    padding: msg.mediaType == 'image' || msg.mediaType == 'video'
                        ? const EdgeInsets.all(3)
                        : const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.73),
                    decoration: BoxDecoration(
                      color: isMe ? _P.meBubble : _P.otherBubble,
                      borderRadius: BorderRadius.only(
                        topLeft:     const Radius.circular(16),
                        topRight:    const Radius.circular(16),
                        bottomLeft:  Radius.circular(isMe ? 16 : 3),
                        bottomRight: Radius.circular(isMe ? 3 : 16),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 3, offset: const Offset(0, 1))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Sender name in public group
                        if (widget.isPublic && !isMe)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3, left: 2, top: 1),
                            child: Text(msg.from,
                              style: TextStyle(color: _roleColor(msg.role), fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        // Reply quote
                        if (msg.replyToId != null && msg.replyToText != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 5),
                            padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(9),
                              border: const Border(left: BorderSide(color: _P.green, width: 3.5)),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(msg.replyToFrom ?? '',
                                style: const TextStyle(color: _P.green, fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(msg.replyToText!,
                                style: const TextStyle(color: _P.bubbleTextSecondary, fontSize: 12),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            ]),
                          ),
                        // Badge tipe pesan (foto/video/file/poll) — warna beda biar cepat kebaca
                        if (msg.mediaType != 'text')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5, left: 1),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_mediaTypeIcon(msg.mediaType), size: 12, color: _mediaTypeColor(msg.mediaType)),
                                const SizedBox(width: 4),
                                Text(
                                  _mediaTypeLabel(msg.mediaType),
                                  style: TextStyle(
                                    color: _mediaTypeColor(msg.mediaType),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Message content
                        _buildContent(msg),
                        // Time + ticks
                        Padding(
                          padding: const EdgeInsets.only(top: 3, right: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                DateFormat('HH:mm').format(DateTime.tryParse(msg.time)?.toLocal() ?? DateTime.now()),
                                style: TextStyle(
                                  color: isMe ? const Color(0xFF7DAE6C) : _P.bubbleTextSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 3),
                                const Icon(Icons.done_all_rounded, size: 14, color: _P.iosBlue),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Reactions
                  if (msg.reactions.isNotEmpty) _buildReactions(msg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ChatMessage msg) {
    switch (msg.mediaType) {
      case 'image':
        if (msg.mediaUrl == null) return const Text('📷 Photo', style: TextStyle(color: _P.bubbleText));
        return GestureDetector(
          onTap: () => _openImageViewer(msg.mediaUrl!),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Hero(
              tag: 'img_${msg.id}',
              child: Image.network(
                msg.mediaUrl!,
                width: 220,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, prog) => prog == null ? child : Container(
                  width: 220, height: 180,
                  color: Colors.black.withOpacity(0.05),
                  child: const Center(child: SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _P.green))),
                ),
                errorBuilder: (_, __, ___) => Container(
                  width: 220, height: 140,
                  color: Colors.black.withOpacity(0.05),
                  child: const Icon(Icons.broken_image_rounded, color: _P.bubbleTextSecondary, size: 36),
                ),
              ),
            ),
          ),
        );

      case 'video':
        if (msg.mediaUrl == null) return const Text('🎥 Video', style: TextStyle(color: _P.bubbleText));
        return GestureDetector(
          onTap: () => _openVideoViewer(msg.mediaUrl!),
          child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _VideoThumb(url: msg.mediaUrl!)),
        );

      case 'file':
        return GestureDetector(
          onTap: () => _openFile(msg.mediaUrl, msg.fileName),
          child: Container(
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: _mediaTypeColor('file').withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.insert_drive_file_rounded, color: _mediaTypeColor('file'), size: 20),
              ),
              const SizedBox(width: 10),
              Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(msg.fileName ?? 'File',
                  style: const TextStyle(color: _P.bubbleText, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                const Text('Tap to open', style: TextStyle(color: _P.bubbleTextSecondary, fontSize: 11)),
              ])),
            ]),
          ),
        );

      case 'poll':
        if (msg.poll == null) return const Text('📊 Poll', style: TextStyle(color: _P.bubbleText));
        return _buildPollWidget(msg);

      default:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: SelectableText(msg.text ?? '', style: const TextStyle(color: _P.bubbleText, fontSize: 15.5)),
        );
    }
  }

  Widget _buildPollWidget(ChatMessage msg) {
    final poll   = msg.poll!;
    final myVote = poll.votes[widget.currentUsername];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.poll_rounded, color: _P.green, size: 15),
        const SizedBox(width: 5),
        const Text('POLL', style: TextStyle(color: _P.green, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
      ]),
      const SizedBox(height: 7),
      Text(poll.question, style: const TextStyle(color: _P.bubbleText, fontWeight: FontWeight.w700, fontSize: 14.5)),
      const SizedBox(height: 10),
      ...poll.options.map((opt) {
        final count  = poll.voteCount(opt);
        final pct    = poll.totalVotes > 0 ? count / poll.totalVotes : 0.0;
        final voted  = myVote == opt;
        return GestureDetector(
          onTap: () => widget.onVotePoll(msg.id, opt),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            child: Stack(children: [
              // Progress bar
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: voted ? _P.green : Colors.transparent, width: 1.5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: voted ? _P.green.withOpacity(0.18) : _P.iosBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              // Label
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(children: [
                    Icon(voted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: voted ? _P.green : _P.bubbleTextSecondary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(opt, style: const TextStyle(color: _P.bubbleText, fontSize: 13))),
                    Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: TextStyle(color: voted ? _P.greenDark : _P.bubbleTextSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),
        );
      }),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('${poll.totalVotes} votes', style: const TextStyle(color: _P.bubbleTextSecondary, fontSize: 11)),
      ),
    ]);
  }

  Widget _buildReactions(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(
        spacing: 4,
        children: msg.reactions.entries.where((e) => e.value.isNotEmpty).map((e) {
          return GestureDetector(
            onTap: () => widget.onReact(msg.id, e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)],
              ),
              child: Text('${e.key} ${e.value.length}', style: const TextStyle(fontSize: 12)),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Reply Bar ────────────────────────────────────

  Widget _buildReplyBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: const BoxDecoration(
        color: _P.inputBg,
        border: Border(top: BorderSide(color: _P.divider, width: 0.5)),
      ),
      child: Row(children: [
        Container(width: 3.5, height: 42, color: _P.green, margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(2))),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Icon(Icons.reply_rounded, color: _P.green, size: 12),
              const SizedBox(width: 4),
              Text('@${_replyingTo!.from}',
                style: const TextStyle(color: _P.green, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 2),
            Text(
              _replyingTo!.text ?? '📷 Media',
              style: const TextStyle(color: _P.textSecondary, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ],
        )),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: _P.textSecondary, size: 18),
          onPressed: () => setState(() => _replyingTo = null),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ]),
    );
  }

  // ── Input Bar ────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      color: _P.inputBg,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attach button
            GestureDetector(
              onTap: _showAttachMenu,
              child: Container(
                width: 36, height: 36, margin: const EdgeInsets.only(right: 6),
                decoration: const BoxDecoration(color: Color(0xFF3A3A3C), shape: BoxShape.circle),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              ),
            ),
            // Text input
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 38, maxHeight: 120),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFF3A3A3C)),
                ),
                child: TextField(
                  controller: _textCtrl,
                  focusNode: _focusNode,
                  style: const TextStyle(color: _P.textPrimary, fontSize: 15.5),
                  maxLines: 5,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    hintText: 'Message',
                    hintStyle: TextStyle(color: Color(0xFF8E8E93), fontSize: 15.5),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Send button
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 38, height: 38,
                decoration: const BoxDecoration(color: _P.green, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Attach Menu ──────────────────────────────────

  void _showAttachMenu() {
    _focusNode.unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: _P.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: _P.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _attachIcon(Icons.image_rounded,              'Photo',    const Color(0xFF8E44AD), () { Navigator.pop(context); _pickMedia('image'); }),
            _attachIcon(Icons.videocam_rounded,           'Video',    const Color(0xFFE74C3C), () { Navigator.pop(context); _pickMedia('video'); }),
            _attachIcon(Icons.insert_drive_file_rounded,  'File',     const Color(0xFF5B7FDE), () { Navigator.pop(context); _pickMedia('file'); }),
            _attachIcon(Icons.poll_rounded,               'Poll',     const Color(0xFFF5A623), () { Navigator.pop(context); _showPollDialog(); }),
          ]),
        ]),
      ),
    );
  }

  Widget _attachIcon(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 58, height: 58,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 4))]),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 7),
        Text(label, style: const TextStyle(color: _P.textSecondary, fontSize: 12.5)),
      ]),
    );
  }

  // ── Poll Dialog ──────────────────────────────────

  void _showPollDialog() {
    final qCtrl = TextEditingController();
    final opts  = [TextEditingController(), TextEditingController()];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _P.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Create Poll', style: TextStyle(color: _P.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: qCtrl,
              style: const TextStyle(color: _P.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Question',
                hintStyle: TextStyle(color: _P.textSecondary),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _P.green)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _P.green, width: 2)),
              ),
            ),
            const SizedBox(height: 12),
            ...opts.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: e.value,
                    style: const TextStyle(color: _P.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Option ${e.key + 1}',
                      hintStyle: const TextStyle(color: _P.textSecondary),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _P.divider)),
                    ),
                  ),
                ),
                if (e.key >= 2)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                    onPressed: () => setSt(() => opts.removeAt(e.key)),
                  ),
              ]),
            )),
            if (opts.length < 5)
              TextButton.icon(
                onPressed: () => setSt(() => opts.add(TextEditingController())),
                icon: const Icon(Icons.add, color: _P.green, size: 18),
                label: const Text('Add option', style: TextStyle(color: _P.green)),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _P.green, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  final q = qCtrl.text.trim();
                  final options = opts.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                  if (q.isNotEmpty && options.length >= 2) {
                    Navigator.pop(ctx);
                    widget.onSendPoll(q, options);
                  }
                },
                child: const Text('Send Poll', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Group Settings ────────────────────────────────

  void _showGroupSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _P.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _GroupSettingsSheet(
        sessionKey: widget.sessionKey,
        currentName: widget.title,
        currentDesc: '',
        currentPhotoUrl: widget.groupPhotoUrl,
        onSaved: widget.onGroupSettingsUpdated,
      ),
    );
  }

  // ── Viewers ──────────────────────────────────────

  void _openImageViewer(String url) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _ImageViewerPage(url: url)));
  }

  void _openVideoViewer(String url) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _VideoViewerPage(url: url)));
  }

  Future<void> _openFile(String? url, String? fileName) async {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open ${fileName ?? 'file'}')),
      );
    }
  }
}

// ══════════════════════════════════════════════════
//  GROUP SETTINGS SHEET
// ══════════════════════════════════════════════════

class _GroupSettingsSheet extends StatefulWidget {
  final String sessionKey;
  final String currentName;
  final String currentDesc;
  final String? currentPhotoUrl;
  final void Function(String name, String desc, String? photoUrl)? onSaved;

  const _GroupSettingsSheet({
    required this.sessionKey,
    required this.currentName,
    required this.currentDesc,
    this.currentPhotoUrl,
    this.onSaved,
  });

  @override
  State<_GroupSettingsSheet> createState() => _GroupSettingsSheetState();
}

class _GroupSettingsSheetState extends State<_GroupSettingsSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  File? _pickedPhoto;
  String? _previewPhotoUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl        = TextEditingController(text: widget.currentName);
    _descCtrl        = TextEditingController(text: widget.currentDesc);
    _previewPhotoUrl = widget.currentPhotoUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img != null && mounted) setState(() { _pickedPhoto = File(img.path); _previewPhotoUrl = null; });
  }

  Future<void> _saveSettings() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final req = http.MultipartRequest('POST', Uri.parse('${Srv.baseUrl}/api/chat/group/settings'));
      req.fields['key'] = widget.sessionKey;
      final name = _nameCtrl.text.trim();
      final desc = _descCtrl.text.trim();
      if (name.isNotEmpty) req.fields['name'] = name;
      if (desc.isNotEmpty) req.fields['description'] = desc;
      if (_pickedPhoto != null) {
        final mime = lookupMimeType(_pickedPhoto!.path) ?? 'image/jpeg';
        req.files.add(await http.MultipartFile.fromPath('photo', _pickedPhoto!.path, contentType: MediaType.parse(mime)));
      }
      final res = await req.send().timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final body = jsonDecode(await res.stream.bytesToString());
        final newPhoto = body['settings']?['photoUrl'] as String?;
        if (mounted) {
          widget.onSaved?.call(name.isNotEmpty ? name : widget.currentName, desc, newPhoto ?? _previewPhotoUrl);
          Navigator.pop(context);
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save, try again')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget photoW;
    if (_pickedPhoto != null) {
      photoW = CircleAvatar(radius: 46, backgroundImage: FileImage(_pickedPhoto!));
    } else if (_previewPhotoUrl != null && _previewPhotoUrl!.isNotEmpty) {
      photoW = CircleAvatar(radius: 46, backgroundImage: NetworkImage(_previewPhotoUrl!));
    } else {
      photoW = CircleAvatar(radius: 46, backgroundColor: _P.green.withOpacity(0.18),
          child: const Icon(Icons.people_alt_rounded, color: _P.green, size: 46));
    }

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('Group Settings', style: TextStyle(color: _P.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 22),
          Center(
            child: Stack(children: [
              photoW,
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(color: _P.green, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: _P.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Group Name',
              labelStyle: TextStyle(color: _P.textSecondary),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _P.divider)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _P.green, width: 2)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descCtrl,
            style: const TextStyle(color: _P.textPrimary),
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description',
              labelStyle: TextStyle(color: _P.textSecondary),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _P.divider)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _P.green, width: 2)),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _P.green, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saving ? null : _saveSettings,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
//  STATUS VIEWER
// ══════════════════════════════════════════════════

class _StatusViewerPage extends StatefulWidget {
  final StatusItem status;
  const _StatusViewerPage({required this.status});

  @override
  State<_StatusViewerPage> createState() => _StatusViewerPageState();
}

class _StatusViewerPageState extends State<_StatusViewerPage> {
  VideoPlayerController? _videoCtrl;
  bool _videoReady   = false;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    if (widget.status.mediaType == 'video' && widget.status.mediaUrl != null) _initVideo();
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  Future<void> _initVideo() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.status.mediaUrl!));
      await c.initialize();
      await c.setLooping(true);
      await c.play();
      if (mounted) setState(() { _videoCtrl = c; _videoReady = true; });
    } catch (e) { debugPrint('Video init: $e'); }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _videoCtrl?.pause();
    _videoCtrl?.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _togglePlay() {
    if (_videoCtrl == null) return;
    setState(() {
      _videoCtrl!.value.isPlaying ? _videoCtrl!.pause() : _videoCtrl!.play();
    });
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(fit: StackFit.expand, children: [
          // Content
          Center(
            child: widget.status.mediaType == 'image' && widget.status.mediaUrl != null
                ? InteractiveViewer(
                    child: Image.network(widget.status.mediaUrl!, fit: BoxFit.contain,
                      frameBuilder: (_, c, f, __) => f == null ? const CircularProgressIndicator(color: Colors.white) : c))
                : widget.status.mediaType == 'video'
                    ? _videoReady && _videoCtrl != null
                        ? AspectRatio(aspectRatio: _videoCtrl!.value.aspectRatio, child: VideoPlayer(_videoCtrl!))
                        : const CircularProgressIndicator(color: Colors.white)
                    : Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(widget.status.text ?? '', textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                      ),
          ),

          // Video play/pause
          if (widget.status.mediaType == 'video' && _videoReady && _showControls)
            Center(
              child: GestureDetector(
                onTap: _togglePlay,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                    child: ValueListenableBuilder(
                      valueListenable: _videoCtrl!,
                      builder: (_, val, __) => Icon(
                        val.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white, size: 36),
                    ),
                  ),
                ),
              ),
            ),

          // Video seek bar
          if (widget.status.mediaType == 'video' && _videoReady && _showControls)
            Positioned(
              bottom: 80, left: 16, right: 16,
              child: ValueListenableBuilder(
                valueListenable: _videoCtrl!,
                builder: (_, val, __) {
                  final pos = val.position.inMilliseconds.toDouble();
                  final dur = val.duration.inMilliseconds.toDouble();
                  return Column(children: [
                    Slider(
                      value: dur > 0 ? pos.clamp(0, dur) : 0,
                      min: 0, max: dur > 0 ? dur : 1,
                      activeColor: Colors.white, inactiveColor: Colors.white30,
                      onChanged: (v) => _videoCtrl!.seekTo(Duration(milliseconds: v.toInt())),
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(_fmt(val.position), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      Text(_fmt(val.duration),  style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ]),
                  ]);
                },
              ),
            ),

          // Top bar
          AnimatedOpacity(
            opacity: _showControls ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.65), Colors.transparent],
                  ),
                ),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: widget.status.profilePhoto != null ? NetworkImage(widget.status.profilePhoto!) : null,
                    backgroundColor: Colors.white24,
                    child: widget.status.profilePhoto == null
                        ? Text(widget.status.username[0].toUpperCase(), style: const TextStyle(color: Colors.white))
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(widget.status.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      DateFormat('HH:mm').format(DateTime.tryParse(widget.status.time)?.toLocal() ?? DateTime.now()),
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
//  VIDEO THUMBNAIL (bubble preview)
// ══════════════════════════════════════════════════

class _VideoThumb extends StatefulWidget {
  final String url;
  const _VideoThumb({required this.url});

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await c.initialize();
      if (!mounted) { c.dispose(); return; }
      setState(() { _ctrl = c; _ready = true; });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() { _ctrl?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    const w = 220.0;
    final aspect = _ready && _ctrl != null ? _ctrl!.value.aspectRatio : 16 / 9;
    final h = (w / aspect).clamp(110.0, 260.0);
    return SizedBox(
      width: w, height: h,
      child: Stack(fit: StackFit.expand, alignment: Alignment.center, children: [
        if (_ready && _ctrl != null)
          FittedBox(fit: BoxFit.cover,
            child: SizedBox(width: _ctrl!.value.size.width, height: _ctrl!.value.size.height, child: VideoPlayer(_ctrl!)))
        else if (_error)
          Container(color: Colors.black12, child: const Icon(Icons.videocam_off_rounded, color: _P.bubbleTextSecondary, size: 36))
        else
          Container(color: Colors.black12,
            child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: _P.green)))),
        // Play button overlay
        Container(
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.4)),
          padding: const EdgeInsets.all(10),
          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════
//  FULL-SCREEN IMAGE VIEWER
// ══════════════════════════════════════════════════

class _ImageViewerPage extends StatelessWidget {
  final String url;
  const _ImageViewerPage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5, maxScale: 6,
          child: Image.network(
            url, fit: BoxFit.contain,
            loadingBuilder: (_, child, prog) =>
                prog == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
//  FULL-SCREEN VIDEO VIEWER
// ══════════════════════════════════════════════════

class _VideoViewerPage extends StatefulWidget {
  final String url;
  const _VideoViewerPage({required this.url});

  @override
  State<_VideoViewerPage> createState() => _VideoViewerPageState();
}

class _VideoViewerPageState extends State<_VideoViewerPage> {
  VideoPlayerController? _ctrl;
  bool _ready        = false;
  bool _showControls = true;
  bool _error        = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _init();
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await c.initialize();
      await c.play();
      if (!mounted) { c.dispose(); return; }
      setState(() { _ctrl = c; _ready = true; });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() { _hideTimer?.cancel(); _ctrl?.dispose(); super.dispose(); }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _togglePlay() {
    if (_ctrl == null) return;
    setState(() { _ctrl!.value.isPlaying ? _ctrl!.pause() : _ctrl!.play(); });
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(fit: StackFit.expand, children: [
          Center(
            child: _ready && _ctrl != null
                ? AspectRatio(aspectRatio: _ctrl!.value.aspectRatio, child: VideoPlayer(_ctrl!))
                : _error
                    ? const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 64)
                    : const CircularProgressIndicator(color: Colors.white),
          ),
          if (_ready && _ctrl != null && _showControls)
            Center(
              child: GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                  child: ValueListenableBuilder(
                    valueListenable: _ctrl!,
                    builder: (_, val, __) => Icon(
                      val.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white, size: 36,
                    ),
                  ),
                ),
              ),
            ),
          if (_ready && _ctrl != null && _showControls)
            Positioned(
              bottom: 32, left: 16, right: 16,
              child: SafeArea(
                top: false,
                child: ValueListenableBuilder(
                  valueListenable: _ctrl!,
                  builder: (_, val, __) {
                    final pos = val.position.inMilliseconds.toDouble();
                    final dur = val.duration.inMilliseconds.toDouble();
                    return Column(children: [
                      Slider(
                        value: dur > 0 ? pos.clamp(0, dur) : 0,
                        min: 0, max: dur > 0 ? dur : 1,
                        activeColor: Colors.white, inactiveColor: Colors.white30,
                        onChanged: (v) => _ctrl!.seekTo(Duration(milliseconds: v.toInt())),
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(_fmt(val.position), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        Text(_fmt(val.duration),  style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ]),
                    ]);
                  },
                ),
              ),
            ),
          AnimatedOpacity(
            opacity: _showControls ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.65), Colors.transparent],
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
