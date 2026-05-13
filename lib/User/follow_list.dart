import 'dart:convert';
import 'package:evesta_app/User/chat.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ViewFollowListPage extends StatefulWidget {
  const ViewFollowListPage({super.key});

  @override
  State<ViewFollowListPage> createState() => _ViewFollowListPageState();
}

class _ViewFollowListPageState extends State<ViewFollowListPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> followList = [];

  @override
  void initState() {
    super.initState();
    fetchFollowList();
  }

  Future<void> fetchFollowList() async {
    final pref = await SharedPreferences.getInstance();
    final baseUrl = pref.getString("url") ?? "";
    final lid = pref.getString("lid") ?? "";

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/view_followlist/"),
        body: {'lid': lid},
      );

      if (res.statusCode == 200) {
        final jsonData = json.decode(res.body);
        if (jsonData['status'] == 'ok') {
          setState(() {
            followList = List<Map<String, dynamic>>.from(jsonData['data']);
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> unfollowUser(int index) async {
    final pref = await SharedPreferences.getInstance();
    final baseUrl = pref.getString("url") ?? "";
    final lid = pref.getString("lid") ?? "";

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/unfollow_user/"),
        body: {
          'from_lid': lid,
          'to_user_id': followList[index]['id'].toString(),
        },
      );

      if (res.statusCode == 200) {
        final followedIds =
        (pref.getStringList("followed_user_ids") ?? []).toSet();
        followedIds.remove(followList[index]['id'].toString());
        await pref.setStringList("followed_user_ids", followedIds.toList());

        setState(() => followList.removeAt(index));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text("Unfollowed successfully"),
              ]),
              backgroundColor: const Color(0xFFE74C3C),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: const Color(0xFFE74C3C),
          ),
        );
      }
    }
  }

  Widget _userCard(Map<String, dynamic> user, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── USER INFO ROW ──
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9B59B6), Color(0xFF4ECDC4)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4ECDC4).withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(3),
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: const Color(0xFF1A1F3A),
                    backgroundImage: user['Image'] != null &&
                        user['Image'].toString().isNotEmpty
                        ? NetworkImage(user['Image'])
                        : null,
                    child: user['Image'] == null ||
                        user['Image'].toString().isEmpty
                        ? const Icon(Icons.person,
                        size: 35, color: Color(0xFF4ECDC4))
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['Name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _infoChip(Icons.email, user['Email'] ?? '',
                          const Color(0xFFFF6B6B)),
                      const SizedBox(height: 4),
                      _infoChip(Icons.phone,
                          user['Phoneno']?.toString() ?? '',
                          const Color(0xFF4ECDC4)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── BUTTON ROW ──
            // No boxShadow on buttons — that was causing the 0.353px overflow
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Chat Button
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6BCF7F), Color(0xFF1ABC9C)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        // ← NO boxShadow here
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(
                                  startupId: user['id'].toString(),
                                  startupName: user['Name'] ?? 'User',
                                ),
                              ),
                            );
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                "Chat",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Unfollow Button
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE74C3C), Color(0xFFC0392B)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        // ← NO boxShadow here
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: const Color(0xFF1A1F3A),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                title: const Text("Unfollow User",
                                    style: TextStyle(color: Colors.white)),
                                content: Text(
                                  "Are you sure you want to unfollow ${user['Name']}?",
                                  style:
                                  const TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Cancel",
                                        style: TextStyle(
                                            color: Colors.white70)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      unfollowUser(index);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                      const Color(0xFFE74C3C),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(12)),
                                    ),
                                    child: const Text("Unfollow"),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_remove,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                "Unfollow",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Widget _infoChip(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: CustomScrollView(
        slivers: [
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
                  Image.network(
                    'https://images.pexels.com/photos/3184292/pexels-photo-3184292.jpeg',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF9B59B6).withValues(alpha: 0.7),
                          const Color(0xFF4ECDC4).withValues(alpha: 0.8),
                          const Color(0xFF0A0E27).withValues(alpha: 0.95),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 60,
                    left: 24,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),
                        const Text(
                          'Following',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${followList.length} connection${followList.length != 1 ? 's' : ''}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: isLoading
                ? const SizedBox(
              height: 400,
              child: Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF4ECDC4))),
            )
                : followList.isEmpty
                ? SizedBox(
              height: 400,
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(30),
                      decoration: const BoxDecoration(
                          color: Color(0xFF1A1F3A),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.people_outline,
                          size: 60, color: Color(0xFF9B59B6)),
                    ),
                    const SizedBox(height: 20),
                    const Text("No Connections Yet",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      "Start following people to build your network!",
                      style: TextStyle(color: Colors.white60),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
                : RefreshIndicator(
              onRefresh: fetchFollowList,
              color: const Color(0xFF4ECDC4),
              backgroundColor: const Color(0xFF1A1F3A),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  ...List.generate(
                    followList.length,
                        (index) => _userCard(followList[index], index),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}