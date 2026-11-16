import 'package:flutter/material.dart';

const Color kSilverLight = Color(0xFFF5F5F7);
const Color kSilver      = Color(0xFFD5D5DC);
const Color kSilverMid   = Color(0xFFAFAFB8);
const Color kSilverDark  = Color(0xFF6B6B75);
const Color kGraphite    = Color(0xFF1F1F28);
const Color kObsidian    = Color(0xFF0F1015);
const Color kAccentBlue   = Color(0xFF00D9FF);
const Color kAccentPurple = Color(0xFFB366FF);
const Color kAccentPink   = Color(0xFFFF006E);
const Color kAccentGreen  = Color(0xFF00FF88);

class LockChatWidget extends StatefulWidget {
  final String deviceId;
  final String deviceModel;
  final Function(String) onSendMessage;
  final List<Map<String, dynamic>> messages;

  const LockChatWidget({
    Key? key,
    required this.deviceId,
    required this.deviceModel,
    required this.onSendMessage,
    required this.messages,
  }) : super(key: key);

  @override
  State<LockChatWidget> createState() => _LockChatWidgetState();
}

class _LockChatWidgetState extends State<LockChatWidget> {
  late TextEditingController _msgCtrl;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _msgCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void didUpdateWidget(LockChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kGraphite,
            border: Border(bottom: BorderSide(color: kAccentBlue.withOpacity(0.3))),
          ),
          child: Row(
            children: [
              Icon(Icons.lock, color: kAccentBlue, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hardlock Chat',
                    style: TextStyle(
                      color: kSilverLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Device: ${widget.deviceModel}',
                    style: TextStyle(
                      color: kSilverMid,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: widget.messages.isEmpty
              ? Center(
                  child: Text(
                    'No messages yet',
                    style: TextStyle(color: kSilverDark, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: widget.messages.length,
                  itemBuilder: (ctx, idx) {
                    final msg = widget.messages[idx];
                    final isAdmin = msg['sender'] == 'admin';
                    final text = msg['message'] ?? msg['text'] ?? '';
                    final timestamp = msg['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
                    final time = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
                    final timeStr = '${time.hour}:${time.minute.toString().padLeft(2, '0')}';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: isAdmin ? MainAxisAlignment.start : MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isAdmin ? kGraphite : kAccentBlue.withOpacity(0.2),
                                border: Border.all(
                                  color: isAdmin ? kAccentBlue : kAccentGreen,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: isAdmin ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    isAdmin ? 'HACKER' : 'VICTIM',
                                    style: TextStyle(
                                      color: isAdmin ? kAccentBlue : kAccentGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    text,
                                    style: TextStyle(color: kSilverLight, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeStr,
                                    style: TextStyle(color: kSilverMid, fontSize: 10),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Device: ${widget.deviceId}',
                                    style: TextStyle(
                                      color: kSilverDark,
                                      fontSize: 9,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        // Input
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kGraphite,
            border: Border(top: BorderSide(color: kAccentBlue.withOpacity(0.3))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  decoration: InputDecoration(
                    hintText: 'Type message...',
                    hintStyle: TextStyle(color: kSilverDark),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: kObsidian,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: kSilverDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: kSilverDark.withOpacity(0.5)),
                    ),
                  ),
                  style: TextStyle(color: kSilverLight, fontSize: 13),
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: kAccentBlue,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: () {
                    final msg = _msgCtrl.text.trim();
                    if (msg.isNotEmpty) {
                      widget.onSendMessage(msg);
                      _msgCtrl.clear();
                      _scrollToBottom();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(Icons.send, color: kObsidian, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RansomwareChatWidget extends StatefulWidget {
  final String deviceId;
  final String deviceModel;
  final Function(String) onSendMessage;
  final List<Map<String, dynamic>> messages;

  const RansomwareChatWidget({
    Key? key,
    required this.deviceId,
    required this.deviceModel,
    required this.onSendMessage,
    required this.messages,
  }) : super(key: key);

  @override
  State<RansomwareChatWidget> createState() => _RansomwareChatWidgetState();
}

class _RansomwareChatWidgetState extends State<RansomwareChatWidget> {
  late TextEditingController _msgCtrl;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _msgCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void didUpdateWidget(RansomwareChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kGraphite,
            border: Border(bottom: BorderSide(color: kAccentPink.withOpacity(0.3))),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_rounded, color: kAccentPink, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ransomware Chat',
                    style: TextStyle(
                      color: kSilverLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Device: ${widget.deviceModel}',
                    style: TextStyle(
                      color: kSilverMid,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: widget.messages.isEmpty
              ? Center(
                  child: Text(
                    'No messages yet',
                    style: TextStyle(color: kSilverDark, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: widget.messages.length,
                  itemBuilder: (ctx, idx) {
                    final msg = widget.messages[idx];
                    final isAdmin = msg['sender'] == 'admin';
                    final text = msg['message'] ?? msg['text'] ?? '';
                    final timestamp = msg['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
                    final time = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
                    final timeStr = '${time.hour}:${time.minute.toString().padLeft(2, '0')}';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: isAdmin ? MainAxisAlignment.start : MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isAdmin ? kGraphite : kAccentPink.withOpacity(0.2),
                                border: Border.all(
                                  color: isAdmin ? kAccentPink : kAccentGreen,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: isAdmin ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    isAdmin ? 'HACKER' : 'VICTIM',
                                    style: TextStyle(
                                      color: isAdmin ? kAccentPink : kAccentGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    text,
                                    style: TextStyle(color: kSilverLight, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeStr,
                                    style: TextStyle(color: kSilverMid, fontSize: 10),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Device: ${widget.deviceId}',
                                    style: TextStyle(
                                      color: kSilverDark,
                                      fontSize: 9,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        // Input
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kGraphite,
            border: Border(top: BorderSide(color: kAccentPink.withOpacity(0.3))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  decoration: InputDecoration(
                    hintText: 'Type message...',
                    hintStyle: TextStyle(color: kSilverDark),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: kObsidian,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: kSilverDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: kSilverDark.withOpacity(0.5)),
                    ),
                  ),
                  style: TextStyle(color: kSilverLight, fontSize: 13),
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: kAccentPink,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: () {
                    final msg = _msgCtrl.text.trim();
                    if (msg.isNotEmpty) {
                      widget.onSendMessage(msg);
                      _msgCtrl.clear();
                      _scrollToBottom();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
