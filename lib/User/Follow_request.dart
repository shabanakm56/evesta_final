import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FollowRequestsPage extends StatefulWidget {
  const FollowRequestsPage({super.key});

  @override
  State<FollowRequestsPage> createState() => _FollowRequestsPageState();
}

class _FollowRequestsPageState extends State<FollowRequestsPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> requests = [];

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  Future<void> fetchRequests() async {
    setState(() => isLoading = true);
    final pref = await SharedPreferences.getInstance();
    final baseUrl = pref.getString("url") ?? "";
    final lid = pref.getString("lid") ?? "";

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/view_follow_requests/"),
        body: {'lid': lid},
      );

      if (res.statusCode == 200) {
        final jsonData = json.decode(res.body);
        if (jsonData['status'] == 'ok') {
          setState(() {
            requests = List<Map<String, dynamic>>.from(jsonData['data']);
          });
        }
      }
    } catch (e) {
      _showSnack("Error loading requests: $e", Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> acceptRequest(Map<String, dynamic> user) async {
    final pref = await SharedPreferences.getInstance();
    final baseUrl = pref.getString("url") ?? "";
    final lid = pref.getString("lid") ?? "";

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/accept_follow/"),
        body: {
          'lid': lid,
          'from_user_id': user['id'].toString(),
        },
      );

      final data = json.decode(res.body);
      if (data['status'] == 'ok') {
        setState(() => requests.removeWhere((r) => r['id'] == user['id']));
        _showSnack("✅ Accepted ${user['Name']}'s request", const Color(0xFF4ECDC4));
      } else {
        _showSnack("Failed to accept request", Colors.red);
      }
    } catch (e) {
      _showSnack("Error: $e", Colors.red);
    }
  }

  Future<void> rejectRequest(Map<String, dynamic> user) async {
    final pref = await SharedPreferences.getInstance();
    final baseUrl = pref.getString("url") ?? "";
    final lid = pref.getString("lid") ?? "";

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/reject_follow/"),
        body: {
          'lid': lid,
          'from_user_id': user['id'].toString(),
        },
      );

      final data = json.decode(res.body);
      if (data['status'] == 'ok') {
        setState(() => requests.removeWhere((r) => r['id'] == user['id']));
        _showSnack("❌ Rejected ${user['Name']}'s request", Colors.grey);
      } else {
        _showSnack("Failed to reject request", Colors.red);
      }
    } catch (e) {
      _showSnack("Error: $e", Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Widget _requestCard(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF9B59B6), Color(0xFF4ECDC4)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4ECDC4).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF1A1F3A),
              backgroundImage: user['Image'] != null &&
                  user['Image'].toString().isNotEmpty
                  ? NetworkImage(user['Image'])
                  : null,
              child: user['Image'] == null || user['Image'].toString().isEmpty
                  ? const Icon(Icons.person, size: 30, color: Color(0xFF4ECDC4))
                  : null,
            ),
          ),

          const SizedBox(width: 14),

          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['Name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Wants to follow you',
                  style: TextStyle(fontSize: 12, color: Colors.white38),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Accept button
          GestureDetector(
            onTap: () => acceptRequest(user),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Accept',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Reject button
          GestureDetector(
            onTap: () => rejectRequest(user),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                'Decline',
                style: TextStyle(
                  color: Colors.white60,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E27),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Follow Requests',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF4ECDC4)),
            onPressed: fetchRequests,
          ),
        ],
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
      )
          : requests.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1F3A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_disabled_rounded,
                  size: 60, color: Color(0xFF9B59B6)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Pending Requests',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When someone sends you a follow request,\nit will appear here.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: fetchRequests,
        color: const Color(0xFF4ECDC4),
        backgroundColor: const Color(0xFF1A1F3A),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
              child: Text(
                '${requests.length} pending request${requests.length != 1 ? 's' : ''}',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13),
              ),
            ),
            ...requests.map((r) => _requestCard(r)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}