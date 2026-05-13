import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  CHAT PAGE
// ══════════════════════════════════════════════════════════════════════════════
class ChatPage extends StatefulWidget {
  final String startupId;    // UsersTable id of the other person
  final String startupName;

  const ChatPage({
    super.key,
    required this.startupId,
    required this.startupName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _msgCtrl     = TextEditingController();
  final ScrollController       _scrollCtrl = ScrollController();

  String? _loginId;
  String? _baseUrl;

  bool _loading = true;
  bool _sending = false;

  List<dynamic> _messages = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final sh  = await SharedPreferences.getInstance();
    _loginId  = sh.getString('lid');
    _baseUrl  = sh.getString('url');

    if (_loginId != null && _baseUrl != null) {
      await _fetchMessages();
      _pollTimer = Timer.periodic(
          const Duration(seconds: 5), (_) => _fetchMessages());
    }
  }

  // ── fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchMessages() async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/User_viewchat/'),
        body: {
          'login_id':   _loginId!,
          'to_user_id': widget.startupId,
        },
      );

      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') {
        final msgs = data['data'] as List;
        setState(() {
          _messages = msgs;
          _loading  = false;
        });
        // only scroll if near bottom
        _scrollToBottom();
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // ── send ───────────────────────────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _msgCtrl.clear();
    setState(() => _sending = true);

    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/User_sendchat/'),
        body: {
          'login_id':   _loginId!,
          'to_user_id': widget.startupId,
          'message':    text,
        },
      );

      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') {
        await _fetchMessages();
      } else {
        _showSnack("Failed to send: ${data['msg'] ?? ''}");
      }
    } catch (e) {
      _showSnack("Send failed: $e");
    }

    setState(() => _sending = false);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFE74C3C),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F3A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: GestureDetector(
          // ✅ Tap name → go to profile
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfilePage(
                userId:   widget.startupId,
                userName: widget.startupName,
                baseUrl:  _baseUrl ?? '',
              ),
            ),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [Color(0xFF9B59B6), Color(0xFF4ECDC4)]),
              ),
              child: const Center(
                  child: Icon(Icons.person, color: Colors.white, size: 20)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.startupName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const Text("",
                      style:
                      TextStyle(color: Color(0xFF4ECDC4), fontSize: 10)),
                ],
              ),
            ),
          ]),
        ),
        actions: [

        ],
      ),

      body: Column(children: [

        // ── message list ────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF4ECDC4)))
              : _messages.isEmpty
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                      color: Color(0xFF1A1F3A),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.chat_bubble_outline,
                      color: Color(0xFF4ECDC4), size: 48),
                ),
                const SizedBox(height: 16),
                const Text("No messages yet",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Say hi to ${widget.startupName}! 👋",
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 13)),
              ],
            ),
          )
              : ListView.builder(
            controller: _scrollCtrl,
            padding:
            const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: _messages.length,
            itemBuilder: (_, i) {
              final m    = _messages[i];
              final isMe =
                  m['from'].toString() == _loginId;
              final time = m['time']?.toString() ?? '';

              final showDate = i == 0 ||
                  _dayOf(m['date']) !=
                      _dayOf(_messages[i - 1]['date']);

              return Column(children: [
                if (showDate)
                  _dateSeparator(m['date']?.toString() ?? ''),
                _bubble(
                  text:  m['msg'] ?? '',
                  time:  time,
                  isMe:  isMe,
                ),
              ]);
            },
          ),
        ),

        // ── input bar ───────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1F3A),
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E27),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white12),
                ),
                child: TextField(
                  controller: _msgCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: "Type a message...",
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _sending ? null : _sendMessage,
              child: Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [Color(0xFF9B59B6), Color(0xFF4ECDC4)]),
                ),
                child: _sending
                    ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  Widget _bubble({required String text, required String time, required bool isMe}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
              colors: [Color(0xFF9B59B6), Color(0xFF4ECDC4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight)
              : null,
          color: isMe ? null : const Color(0xFF1A1F3A),
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(18),
            topRight:    const Radius.circular(18),
            bottomLeft:  Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          border: isMe ? null : Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(text,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, height: 1.4)),
            const SizedBox(height: 4),
            Text(time,
                style: TextStyle(
                    fontSize: 10,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.white38)),
          ],
        ),
      ),
    );
  }

  Widget _dateSeparator(String dateStr) {
    String label = '';
    try {
      final dt   = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(dt).inDays;
      if (diff == 0)      label = "Today";
      else if (diff == 1) label = "Yesterday";
      else                label = DateFormat('MMM d, yyyy').format(dt);
    } catch (_) { label = dateStr; }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(child: Divider(color: Colors.white12)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ),
        const Expanded(child: Divider(color: Colors.white12)),
      ]),
    );
  }

  String _formatTime(String s) {
    try { return DateFormat('hh:mm a').format(DateTime.parse(s).toLocal()); }
    catch (_) { return ''; }
  }

  String _dayOf(dynamic s) {
    try { return DateTime.parse(s.toString()).toLocal().toString().substring(0, 10); }
    catch (_) { return ''; }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  USER PROFILE PAGE  (shown when tapping name in chat)
// ══════════════════════════════════════════════════════════════════════════════
class UserProfilePage extends StatefulWidget {
  final String userId;
  final String userName;
  final String baseUrl;

  const UserProfilePage({
    super.key,
    required this.userId,
    required this.userName,
    required this.baseUrl,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  bool _loading = true;
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/'),
        body: {'user_id': widget.userId},
      );
      final data = jsonDecode(res.body);
      if (data['status'] == 'ok') {
        setState(() {
          // ✅ Try these one by one depending on your API response structure:
          _profile = data['data'] ?? data['user'] ?? data;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF4ECDC4)))
          : CustomScrollView(
        slivers: [

          // ── hero header ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF0A0E27),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // background gradient
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF9B59B6), Color(0xFF4ECDC4),
                          Color(0xFF0A0E27)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),

                  // avatar + name
                  Positioned(
                    bottom: 24, left: 0, right: 0,
                    child: Column(children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                              colors: [Color(0xFF9B59B6),
                                Color(0xFF4ECDC4)]),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4ECDC4)
                                  .withValues(alpha: 0.4),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(3),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF1A1F3A),
                          backgroundImage: (_profile['Image'] ?? '')
                              .isNotEmpty
                              ? NetworkImage(
                              widget.baseUrl.replaceAll('/myapp', '') +
                                  _profile['Image'])
                              : null,
                          child: (_profile['Image'] ?? '').isEmpty
                              ? const Icon(Icons.person,
                              size: 50, color: Color(0xFF4ECDC4))
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(_profile['Name'] ?? widget.userName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _profile['Gender'] ?? '',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          // ── body ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── stats row ──────────────────────────────────────
                  Row(children: [
                    _statCard(
                      icon:  Icons.event_available,
                      label: "Events Attended",
                      value: _profile['events_attended']?.toString() ?? '0',
                      color: const Color(0xFF4ECDC4),
                    ),
                    const SizedBox(width: 12),
                    _statCard(
                      icon:  Icons.star_rounded,
                      label: "Avg Rating",
                      value: _profile['avg_rating']?.toString() ?? '0',
                      color: const Color(0xFFFFD93D),
                    ),
                  ]),

                  const SizedBox(height: 12),

                  // ── top category ───────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F3A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.favorite_rounded,
                            color: Color(0xFFFF6B6B), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Favourite Category",
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            _profile['top_category'] ?? 'None',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ]),
                  ),

                  const SizedBox(height: 20),

                  // ── contact details ────────────────────────────────
                  const Text("Contact Info",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  _infoTile(Icons.email_rounded,
                      _profile['Email'] ?? '', const Color(0xFFFF6B6B)),
                  _infoTile(Icons.phone_rounded,
                      _profile['Phoneno'] ?? '', const Color(0xFF4ECDC4)),
                  _infoTile(Icons.cake_rounded,
                      _profile['DOB'] ?? '', const Color(0xFFFFD93D)),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _infoTile(IconData icon, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ),
      ]),
    );
  }
}