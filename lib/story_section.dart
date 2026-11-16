import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'srv.dart';

// ─── 🎨 CARTOON 3D PALETTE ──────────────────────────────────────
//   Putih     = Background
//   Hitam     = Border semua card/button
//   Hijau     = Tombol utama / success
//   Merah     = Tombol destructive / danger
//   Kuning    = Tombol warning / secondary
//   Biru Muda = Tombol info / netral
//   Biru Tua  = Tombol nav / aksi sekunder
const Color _kWhite        = Color(0xFFFFFFFF);
const Color _kCream        = Color(0xFFFFFDF7);
const Color _kBlack        = Color(0xFF000000);
const Color _kTextMain     = Color(0xFFFFFFFF);
const Color _kTextSub      = Color(0xFF52525B);
const Color _kGreen        = Color(0xFF22C55E);
const Color _kRed          = Color(0xFFEF4444);
const Color _kYellow       = Color(0xFFFBBF24);
const Color _kBlueLight    = Color(0xFF38BDF8);
const Color _kBlueDark     = Color(0xFF1E40AF);

// Aliases (kompatibel dengan nama lama)
const Color _kCyan   = _kGreen;
const Color _kPink   = _kRed;
const Color _kPurple = _kBlueDark;
const Color _kCard   = _kCream;

// Cartoon geometry
const double _kR  = 14;
const double _kBW = 3.0;

// ─── MODEL ───────────────────────────────────────────────────────
class StoryItem {
  final String id;
  final String ownerUsername;
  final String type;
  final String content;
  final String bgColor;
  final String txtColor;
  final String thumbnailUrl;
  final DateTime createdAt;
  final List<String> viewers;
  final List<String> likes;

  const StoryItem({
    required this.id,
    required this.ownerUsername,
    required this.type,
    required this.content,
    required this.bgColor,
    required this.txtColor,
    required this.thumbnailUrl,
    required this.createdAt,
    required this.viewers,
    required this.likes,
  });

  factory StoryItem.fromJson(Map<String, dynamic> j) => StoryItem(
        id: j['id']?.toString() ?? '',
        ownerUsername: j['username'] ?? '',
        type: j['type'] ?? 'text',
        content: j['content'] ?? '',
        bgColor: j['bg_color'] ?? '#0d0d1a',
        txtColor: j['txt_color'] ?? '#00F5FF',
        thumbnailUrl: j['thumbnail'] ?? '',
        createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
        viewers: List<String>.from(j['viewers'] ?? []),
        likes: List<String>.from(j['likes'] ?? []),
      );

  StoryItem copyWith({
    List<String>? viewers,
    List<String>? likes,
  }) =>
      StoryItem(
        id: id,
        ownerUsername: ownerUsername,
        type: type,
        content: content,
        bgColor: bgColor,
        txtColor: txtColor,
        thumbnailUrl: thumbnailUrl,
        createdAt: createdAt,
        viewers: viewers ?? this.viewers,
        likes: likes ?? this.likes,
      );
}

class UserStoryGroup {
  final String username;
  final List<StoryItem> stories;
  final bool isMe;

  const UserStoryGroup({
    required this.username,
    required this.stories,
    required this.isMe,
  });
}

// ─── SERVICE ─────────────────────────────────────────────────────
class StoryService {
  final String baseUrl;
  final String sessionKey;
  final String username;

  StoryService({
    required this.baseUrl,
    required this.sessionKey,
    required this.username,
  });

  String _url(String endpoint) => '$baseUrl$endpoint?key=$sessionKey';

  Future<List<StoryItem>> fetchAll() async {
    try {
      final res = await http
          .get(Uri.parse(_url('/api/stories')))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        return data.map((e) => StoryItem.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> postTextStory({
    required String text,
    required String bgColor,
    required String txtColor,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse(_url('/api/stories')),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'type': 'text',
              'content': text,
              'bg_color': bgColor,
              'txt_color': txtColor,
            }),
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> postImageStory(File imageFile) async {
    try {
      final req = http.MultipartRequest(
          'POST', Uri.parse(_url('/api/stories/upload')))
        ..fields['type'] = 'image'
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      final res = await req.send().timeout(const Duration(seconds: 30));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> postVideoStory(File videoFile) async {
    try {
      final req = http.MultipartRequest(
          'POST', Uri.parse(_url('/api/stories/upload')))
        ..fields['type'] = 'video'
        ..files.add(await http.MultipartFile.fromPath('file', videoFile.path));
      final res = await req.send().timeout(const Duration(seconds: 60));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<void> markViewed(String storyId) async {
    try {
      await http
          .post(Uri.parse(_url('/api/stories/view/$storyId')))
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<bool> toggleLike(String storyId) async {
    try {
      final res = await http
          .post(Uri.parse(_url('/api/stories/like/$storyId')))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteStory(String storyId) async {
    try {
      final res = await http
          .delete(Uri.parse(_url('/api/stories/$storyId')))
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// ─── MAIN SECTION WIDGET ─────────────────────────────────────────
class StorySection extends StatefulWidget {
  final String username;
  final String sessionKey;
  final String serverUrl;

  const StorySection({
    super.key,
    required this.username,
    required this.sessionKey,
    required this.serverUrl,
  });

  @override
  State<StorySection> createState() => _StorySectionState();
}

class _StorySectionState extends State<StorySection> {
  late StoryService _svc;
  List<UserStoryGroup> _groups = [];
  bool _loading = true;

  final Set<String> _locallyViewedIds = {};
  final Set<String> _locallyLikedIds = {};

  @override
  void initState() {
    super.initState();
    _svc = StoryService(
      baseUrl: widget.serverUrl,
      sessionKey: widget.sessionKey,
      username: widget.username,
    );
    _loadLocalCache();
    _load();
  }

  Future<void> _loadLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final viewed =
          prefs.getStringList('viewed_story_ids_${widget.username}');
      final liked =
          prefs.getStringList('liked_story_ids_${widget.username}');
      if (viewed != null) _locallyViewedIds.addAll(viewed);
      if (liked != null) _locallyLikedIds.addAll(liked);
    } catch (_) {}
  }

  Future<void> _persistViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          'viewed_story_ids_${widget.username}', _locallyViewedIds.toList());
    } catch (_) {}
  }

  Future<void> _persistLiked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          'liked_story_ids_${widget.username}', _locallyLikedIds.toList());
    } catch (_) {}
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final stories = await _svc.fetchAll();

    final now = DateTime.now();
    final active = stories
        .where((s) => now.difference(s.createdAt).inHours < 24)
        .map((s) {
      var updated = s;
      if (_locallyViewedIds.contains(s.id) &&
          !updated.viewers.contains(widget.username)) {
        updated = updated.copyWith(
          viewers: [...updated.viewers, widget.username],
        );
      }
      if (_locallyLikedIds.contains(s.id) &&
          !updated.likes.contains(widget.username)) {
        updated = updated.copyWith(
          likes: [...updated.likes, widget.username],
        );
      }
      return updated;
    }).toList();

    final Map<String, List<StoryItem>> map = {};
    for (final s in active) {
      map.putIfAbsent(s.ownerUsername, () => []).add(s);
    }

    final groups = map.entries.map((e) {
      return UserStoryGroup(
        username: e.key,
        stories: e.value..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        isMe: e.key == widget.username,
      );
    }).toList();

    groups.sort((a, b) {
      if (a.isMe) return -1;
      if (b.isMe) return 1;
      return 0;
    });

    if (!groups.any((g) => g.isMe)) {
      groups.insert(
        0,
        UserStoryGroup(username: widget.username, stories: [], isMe: true),
      );
    }

    if (mounted) {
      setState(() {
        _groups = groups;
        _loading = false;
      });
    }
  }

  void _openViewer(int groupIndex) {
    final realGroups = _groups.where((g) => g.stories.isNotEmpty).toList();
    if (realGroups.isEmpty) return;
    final realIndex = realGroups.indexWhere(
      (g) => g.username == _groups[groupIndex].username,
    );

    Navigator.push<Set<String>>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => _StoryViewerPage(
          groups: realGroups,
          initialIndex: realIndex < 0 ? 0 : realIndex,
          service: _svc,
          currentUsername: widget.username,
          onLikeToggled: (storyId, isLiked) async {
            if (isLiked) {
              _locallyLikedIds.add(storyId);
            } else {
              _locallyLikedIds.remove(storyId);
            }
            await _persistLiked();
          },
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    ).then((viewedSet) {
      if (viewedSet != null) {
        _locallyViewedIds.addAll(viewedSet);
        _persistViewed();
      }
      _load();
    });
  }

  void _openCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CreateStoryPage(
          service: _svc,
          username: widget.username,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 104,
        child: Center(
            child: CircularProgressIndicator(color: _kGreen, strokeWidth: 3)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ═════ HEADER ═════
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              // 🟢 HIJAU icon
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _kGreen,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _kBlack, width: 2.5),
                ),
                child: const Icon(Icons.auto_stories_rounded,
                    color: Colors.white, size: 14),
              ),
              const SizedBox(width: 6),
              const Text(
                'SYXGRAM',
                style: TextStyle(
                  color: _kTextMain,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  fontFamily: 'Orbitron',
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              // 🟡 KUNING refresh
              GestureDetector(
                onTap: _load,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _kYellow,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _kBlack, width: 2),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: Colors.black, size: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            physics: const BouncingScrollPhysics(),
            itemCount: _groups.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final g = _groups[i];
              final bool hasUnviewed = g.stories.any(
                (s) =>
                    !s.viewers.contains(widget.username) &&
                    !_locallyViewedIds.contains(s.id),
              );
              return _StoryRing(
                group: g,
                hasUnviewed: hasUnviewed,
                onTap: () {
                  if (g.stories.isEmpty) {
                    _openCreate();
                  } else {
                    _openViewer(i);
                  }
                },
                onAddTap: g.isMe ? _openCreate : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── RING WIDGET (CARTOON) ───────────────────────────────────────
class _StoryRing extends StatelessWidget {
  final UserStoryGroup group;
  final bool hasUnviewed;
  final VoidCallback onTap;
  final VoidCallback? onAddTap;

  const _StoryRing({
    required this.group,
    required this.hasUnviewed,
    required this.onTap,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring — cartoon border
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasUnviewed
                        ? _kGreen // 🟢 unviewed = hijau
                        : _kCream, // ⚪ viewed = cream
                    border: Border.all(color: _kBlack, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: _kBlack,
                        offset: Offset(3, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
                // Inner circle
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kCream,
                    border: Border.all(color: _kBlack, width: 2.5),
                  ),
                  child: ClipOval(
                    child: group.stories.isNotEmpty &&
                            group.stories.first.type == 'image'
                        ? Image.network(
                            group.stories.first.content,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _initial(),
                          )
                        : _initial(),
                  ),
                ),
                // 🟡 KUNING add button
                if (group.isMe)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: onAddTap,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _kYellow,
                          shape: BoxShape.circle,
                          border: Border.all(color: _kBlack, width: 2.5),
                          boxShadow: const [
                            BoxShadow(
                              color: _kBlack,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add,
                            size: 14, color: Colors.black),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              group.isMe ? 'My Story' : group.username,
              style: const TextStyle(
                color: _kTextMain,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'ShareTechMono',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _initial() => Container(
        color: _kCream,
        alignment: Alignment.center,
        child: Text(
          group.username.isNotEmpty ? group.username[0].toUpperCase() : '?',
          style: const TextStyle(
            color: _kGreen,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFamily: 'Orbitron',
          ),
        ),
      );
}

// ─── VIEWER PAGE ─────────────────────────────────────────────────
class _StoryViewerPage extends StatefulWidget {
  final List<UserStoryGroup> groups;
  final int initialIndex;
  final StoryService service;
  final String currentUsername;
  final Future<void> Function(String storyId, bool isLiked)? onLikeToggled;

  const _StoryViewerPage({
    required this.groups,
    required this.initialIndex,
    required this.service,
    required this.currentUsername,
    this.onLikeToggled,
  });

  @override
  State<_StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<_StoryViewerPage>
    with TickerProviderStateMixin {
  late int _gi, _si;
  late AnimationController _prog;
  VideoPlayerController? _vid;

  final Set<String> _viewedSessionIds = {};

  @override
  void initState() {
    super.initState();
    _gi = widget.initialIndex;
    _si = 0;
    _prog = AnimationController(vsync: this);
    _load();
  }

  UserStoryGroup get _cg => widget.groups[_gi];
  StoryItem get _cs => _cg.stories[_si];

  Future<void> _load() async {
    _prog.reset();
    await _vid?.dispose();
    _vid = null;

    _viewedSessionIds.add(_cs.id);
    final isAlreadyViewed = _cs.viewers.contains(widget.currentUsername);
    if (!isAlreadyViewed) {
      final newViewers = List<String>.from(_cs.viewers)
        ..add(widget.currentUsername);
      _updateStoryViewers(_cs.id, newViewers);
      widget.service.markViewed(_cs.id);
    }

    if (_cs.type == 'video') {
      _vid = VideoPlayerController.networkUrl(Uri.parse(_cs.content));
      await _vid!.initialize();
      if (mounted) {
        setState(() {});
        _vid!.play();
        _start(_vid!.value.duration);
      }
    } else {
      if (mounted) setState(() {});
      _start(const Duration(seconds: 5));
    }
  }

  void _updateStoryViewers(String storyId, List<String> newViewers) {
    for (final g in widget.groups) {
      final idx = g.stories.indexWhere((s) => s.id == storyId);
      if (idx >= 0) {
        g.stories[idx] = g.stories[idx].copyWith(viewers: newViewers);
        return;
      }
    }
  }

  void _updateStoryLikes(String storyId, List<String> newLikes) {
    for (final g in widget.groups) {
      final idx = g.stories.indexWhere((s) => s.id == storyId);
      if (idx >= 0) {
        g.stories[idx] = g.stories[idx].copyWith(likes: newLikes);
        return;
      }
    }
  }

  Future<void> _toggleLike() async {
    final storyId = _cs.id;
    final isLiked = _cs.likes.contains(widget.currentUsername);

    final newLikes = List<String>.from(_cs.likes);
    if (isLiked) {
      newLikes.remove(widget.currentUsername);
    } else {
      newLikes.add(widget.currentUsername);
    }

    setState(() {
      _updateStoryLikes(storyId, newLikes);
    });

    if (widget.onLikeToggled != null) {
      await widget.onLikeToggled!(storyId, !isLiked);
    }

    final ok = await widget.service.toggleLike(storyId);
    if (!ok && mounted) {
      setState(() {
        _updateStoryLikes(storyId, _cs.likes);
      });
    }
  }

  void _start(Duration d) {
    _prog.duration = d;
    _prog.forward().then((_) {
      if (mounted) _next();
    });
  }

  void _next() {
    if (_si < _cg.stories.length - 1) {
      setState(() => _si++);
    } else if (_gi < widget.groups.length - 1) {
      setState(() {
        _gi++;
        _si = 0;
      });
    } else {
      _closeAndPop();
      return;
    }
    _load();
  }

  void _prev() {
    if (_si > 0) {
      setState(() => _si--);
    } else if (_gi > 0) {
      setState(() {
        _gi--;
        _si = _cg.stories.length - 1;
      });
    }
    _load();
  }

  void _closeAndPop() {
    Navigator.pop(context, _viewedSessionIds);
  }

  @override
  void dispose() {
    _prog.dispose();
    _vid?.dispose();
    super.dispose();
  }

  void _showUserList({
    required String title,
    required List<String> users,
    required Color color,
    required IconData icon,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_kR)),
        side: BorderSide(color: _kBlack, width: 3),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kBlack, width: 2.5),
                  ),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: _kTextMain,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    fontFamily: 'Orbitron',
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kBlack, width: 2),
                  ),
                  child: Text(
                    '${users.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (users.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text(
                    'Belum ada',
                    style: TextStyle(
                      color: _kTextSub,
                      fontFamily: 'ShareTechMono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: users.length,
                  separatorBuilder: (_, __) => Divider(
                    color: _kBlack.withOpacity(0.15),
                    height: 1,
                  ),
                  itemBuilder: (_, i) {
                    final u = users[i];
                    final isMe = u == widget.currentUsername;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: color,
                        child: Text(
                          u.isNotEmpty ? u[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                      ),
                      title: Text(
                        isMe ? '$u (Kamu)' : u,
                        style: TextStyle(
                          color: isMe ? color : _kTextMain,
                          fontSize: 13,
                          fontWeight:
                              isMe ? FontWeight.w900 : FontWeight.w600,
                          fontFamily: 'ShareTechMono',
                        ),
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

  @override
  Widget build(BuildContext context) {
    final s = _cs;
    final isLiked = s.likes.contains(widget.currentUsername);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (d) {
          final w = MediaQuery.of(context).size.width;
          if (d.globalPosition.dx < w / 2) {
            _prev();
          } else {
            _next();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (s.type == 'text')
              _textContent(s)
            else if (s.type == 'image')
              Image.network(s.content, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _textContent(s))
            else if (_vid != null && _vid!.value.isInitialized)
              Center(
                  child: AspectRatio(
                aspectRatio: _vid!.value.aspectRatio,
                child: VideoPlayer(_vid!),
              ))
            else
              const Center(
                  child: CircularProgressIndicator(
                      color: _kGreen, strokeWidth: 3)),

            // Top gradient
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 140,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent
                    ],
                  ),
                ),
              ),
            ),

            // Bottom gradient
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 140,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.85),
                      Colors.transparent
                    ],
                  ),
                ),
              ),
            ),

            // Progress bars
            Positioned(
              top: MediaQuery.of(context).padding.top + 6,
              left: 8,
              right: 8,
              child: Row(
                children: List.generate(
                  _cg.stories.length,
                  (i) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: AnimatedBuilder(
                        animation: _prog,
                        builder: (_, __) => ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: i < _si
                                ? 1.0
                                : i == _si
                                    ? _prog.value
                                    : 0.0,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(_kGreen),
                            minHeight: 4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Top info bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 18,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  // 🟢 HIJAU avatar
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _kGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: Center(
                      child: Text(
                        _cg.username.isNotEmpty
                            ? _cg.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_cg.username,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(_ago(s.createdAt),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11)),
                  const Spacer(),
                  // 🔴 MERAH delete (own story)
                  if (_cg.username == widget.currentUsername)
                    GestureDetector(
                      onTap: () async {
                        await widget.service.deleteStory(s.id);
                        _closeAndPop();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _kRed,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  const SizedBox(width: 6),
                  // ⚪ Close button
                  GestureDetector(
                    onTap: _closeAndPop,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _kCream,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: _kTextMain, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom action row
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  // 🟢 HIJAU viewers
                  _statButton(
                    icon: Icons.remove_red_eye_rounded,
                    count: s.viewers.length,
                    color: _kGreen,
                    onTap: () => _showUserList(
                      title: 'DILIHAT OLEH',
                      users: s.viewers,
                      color: _kGreen,
                      icon: Icons.remove_red_eye_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 🔴 MERAH likes
                  _statButton(
                    icon: Icons.favorite_rounded,
                    count: s.likes.length,
                    color: _kRed,
                    onTap: () => _showUserList(
                      title: 'DISUKAI OLEH',
                      users: s.likes,
                      color: _kRed,
                      icon: Icons.favorite_rounded,
                    ),
                  ),
                  const Spacer(),
                  // 🔴 MERAH like button
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isLiked ? _kRed : _kCream,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.black, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(3, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isLiked ? Colors.white : _kRed,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isLiked ? 'Disukai' : 'Suka',
                            style: TextStyle(
                              color: isLiked ? Colors.white : _kRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statButton({
    required IconData icon,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _kCream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(2.5, 2.5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: const TextStyle(
                color: _kTextMain,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                fontFamily: 'ShareTechMono',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textContent(StoryItem s) {
    Color bg = Colors.black;
    try {
      bg = Color(int.parse('FF${s.bgColor.replaceAll('#', '')}', radix: 16));
    } catch (_) {}
    Color txt = _kGreen;
    try {
      txt = Color(int.parse('FF${s.txtColor.replaceAll('#', '')}', radix: 16));
    } catch (_) {}
    return Container(
      color: bg,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Text(s.content,
          style: TextStyle(
              color: txt,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.4),
          textAlign: TextAlign.center),
    );
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inHours}h';
  }
}

// ─── CREATE PAGE (CARTOON) ───────────────────────────────────────
class _CreateStoryPage extends StatefulWidget {
  final StoryService service;
  final String username;

  const _CreateStoryPage({required this.service, required this.username});

  @override
  State<_CreateStoryPage> createState() => _CreateStoryPageState();
}

class _CreateStoryPageState extends State<_CreateStoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _ctrl = TextEditingController();
  bool _loading = false;
  String _bg = '#0d0d1a';
  String _txt = '#00F5FF';
  File? _img, _vid;

  static const _bgOpts = [
    '#0d0d1a',
    '#050014',
    '#1A0B3D',
    '#0f3460',
    '#533483',
    '#e94560',
    '#f5a623',
    '#2ecc71',
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Color _hex(String h) {
    try {
      return Color(int.parse('FF${h.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return Colors.black;
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    bool ok = false;
    switch (_tab.index) {
      case 0:
        if (_ctrl.text.trim().isEmpty) {
          setState(() => _loading = false);
          return;
        }
        ok = await widget.service.postTextStory(
            text: _ctrl.text.trim(), bgColor: _bg, txtColor: _txt);
        break;
      case 1:
        if (_img == null) {
          setState(() => _loading = false);
          return;
        }
        ok = await widget.service.postImageStory(_img!);
        break;
      case 2:
        if (_vid == null) {
          setState(() => _loading = false);
          return;
        }
        ok = await widget.service.postVideoStory(_vid!);
        break;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Gagal upload. Coba lagi.',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_kR - 4),
            side: const BorderSide(color: _kBlack, width: 3),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kWhite,
      appBar: AppBar(
        backgroundColor: _kCream,
        elevation: 0,
        title: const Text(
          'Buat Story',
          style: TextStyle(
            color: _kTextMain,
            fontFamily: 'Orbitron',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        iconTheme: const IconThemeData(color: _kTextMain),
        actions: [
          _loading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: _kGreen),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  // 🟢 HIJAU bagikan button
                  child: GestureDetector(
                    onTap: _submit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _kGreen,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBlack, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: _kBlack,
                            offset: Offset(2.5, 2.5),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Bagikan',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _kGreen,
          labelColor: _kTextMain,
          unselectedLabelColor: _kTextSub,
          labelStyle: const TextStyle(
            fontFamily: 'ShareTechMono',
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
          tabs: const [
            Tab(text: 'TEKS'),
            Tab(text: 'FOTO'),
            Tab(text: 'VIDEO')
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_textTab(), _imgTab(), _vidTab()],
      ),
    );
  }

  Widget _textTab() => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Preview card dengan border hitam tebal
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: _hex(_bg),
              borderRadius: BorderRadius.circular(_kR),
              border: Border.all(color: _kBlack, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: _kBlack,
                  offset: Offset(6, 6),
                  blurRadius: 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: Text(
              _ctrl.text.isEmpty ? 'Preview...' : _ctrl.text,
              style: TextStyle(
                  color: _hex(_txt),
                  fontSize: 22,
                  fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          // Input field cartoon
          Container(
            decoration: BoxDecoration(
              color: _kCream,
              borderRadius: BorderRadius.circular(_kR - 4),
              border: Border.all(color: _kBlack, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: _kBlack,
                  offset: Offset(3, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: TextField(
              controller: _ctrl,
              maxLines: 4,
              maxLength: 200,
              style: const TextStyle(
                color: _kTextMain,
                fontWeight: FontWeight.w600,
              ),
              cursorColor: _kGreen,
              decoration: const InputDecoration(
                hintText: 'Tulis sesuatu...',
                hintStyle: TextStyle(
                  color: _kTextSub,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
                counterStyle: TextStyle(color: _kTextSub),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Background',
              style: TextStyle(
                color: _kTextMain,
                fontWeight: FontWeight.w900,
                fontFamily: 'Orbitron',
                fontSize: 12,
              )),
          const SizedBox(height: 8),
          Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _bgOpts.map((h) {
                final sel = _bg == h;
                return GestureDetector(
                  onTap: () => setState(() => _bg = h),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _hex(h),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sel ? _kBlack : Colors.black.withOpacity(0.3),
                        width: sel ? 3.5 : 2,
                      ),
                      boxShadow: sel
                          ? const [
                              BoxShadow(
                                color: _kBlack,
                                offset: Offset(2.5, 2.5),
                                blurRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList()),
          const SizedBox(height: 16),
          const Text('Warna Teks',
              style: TextStyle(
                color: _kTextMain,
                fontWeight: FontWeight.w900,
                fontFamily: 'Orbitron',
                fontSize: 12,
              )),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _txtBtn('#00F5FF', 'Cyan'),
            _txtBtn('#ffffff', 'Putih'),
            _txtBtn('#FF00FF', 'Pink'),
            _txtBtn('#FFE600', 'Kuning'),
          ]),
        ]),
      );

  Widget _txtBtn(String h, String label) {
    final sel = _txt == h;
    return GestureDetector(
      onTap: () => setState(() => _txt = h),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? _hex(h) : _kCream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBlack, width: 2.5),
          boxShadow: sel
              ? const [
                  BoxShadow(
                    color: _kBlack,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Text(label,
            style: TextStyle(
              color: sel
                  ? (_hex(h).computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white)
                  : _kTextMain,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              fontFamily: 'Orbitron',
            )),
      ),
    );
  }

  Widget _imgTab() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_img != null) ...[
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_kR),
                border: Border.all(color: _kBlack, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: _kBlack,
                    offset: Offset(6, 6),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(_kR - 3),
                  child: Image.file(_img!,
                      height: 280, width: 280, fit: BoxFit.cover)),
            ),
            const SizedBox(height: 16),
            // 🟡 KUNING ganti foto
            TextButton.icon(
              onPressed: _pickImg,
              icon: const Icon(Icons.refresh, color: Colors.black),
              label: const Text('Ganti Foto',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Orbitron',
                  )),
              style: TextButton.styleFrom(
                backgroundColor: _kYellow,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: _kBlack, width: 2.5),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _kCream,
                borderRadius: BorderRadius.circular(_kR),
                border: Border.all(color: _kBlack, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: _kBlack,
                    offset: Offset(5, 5),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: const Icon(Icons.photo_library_rounded,
                  size: 64, color: _kBlueLight),
            ),
            const SizedBox(height: 16),
            // 🔵 BIRU MUDA pilih foto
            ElevatedButton.icon(
              onPressed: _pickImg,
              icon: const Icon(Icons.photo, color: Colors.white),
              label: const Text('Pilih Foto',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Orbitron',
                  )),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlueLight,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: _kBlack, width: 3),
                ),
              ),
            ),
          ],
        ]),
      );

  Widget _vidTab() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kCream,
              borderRadius: BorderRadius.circular(_kR),
              border: Border.all(color: _kBlack, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: _kBlack,
                  offset: Offset(5, 5),
                  blurRadius: 0,
                ),
              ],
            ),
            child: const Icon(Icons.videocam_rounded,
                size: 64, color: _kBlueDark),
          ),
          const SizedBox(height: 16),
          if (_vid != null) ...[
            Text(_vid!.path.split('/').last,
                style: const TextStyle(
                  color: _kTextMain,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'ShareTechMono',
                ),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Icon(Icons.check_circle_rounded,
                color: _kGreen, size: 28),
            const SizedBox(height: 12),
            // 🟡 KUNING ganti video
            TextButton.icon(
              onPressed: _pickVid,
              icon: const Icon(Icons.refresh, color: Colors.black),
              label: const Text('Ganti Video',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Orbitron',
                  )),
              style: TextButton.styleFrom(
                backgroundColor: _kYellow,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: _kBlack, width: 2.5),
                ),
              ),
            ),
          ] else
            // 🔵 BIRU TUA pilih video
            ElevatedButton.icon(
              onPressed: _pickVid,
              icon: const Icon(Icons.video_library, color: Colors.white),
              label: const Text('Pilih Video (max 1 menit)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Orbitron',
                  )),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlueDark,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: _kBlack, width: 3),
                ),
              ),
            ),
        ]),
      );

  Future<void> _pickImg() async {
    final p = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (p != null && mounted) setState(() => _img = File(p.path));
  }

  Future<void> _pickVid() async {
    final p = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60));
    if (p != null && mounted) setState(() => _vid = File(p.path));
  }
}