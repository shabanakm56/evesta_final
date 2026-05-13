import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';

/// ================= USER PROFILE PAGE =================
/// Shows public info to everyone.
/// Shows private info (email, DOB, phone) only if the viewer
/// is an accepted follower of this user.
class UserProfilePage extends StatefulWidget {
  final String userId;
  final String baseUrl;
  final String lid;

  const UserProfilePage({
    super.key,
    required this.userId,
    required this.baseUrl,
    required this.lid,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Builds a full image URL from the relative path the backend returns.
  String _fullImageUrl(String rawPath) {
    if (rawPath.isEmpty) return '';
    if (rawPath.startsWith('http')) return rawPath;
    return widget.baseUrl.replaceAll('/myapp', '') + rawPath;
  }

  Future<void> _loadProfile() async {
    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/view_user_profile/'),
        body: {
          'user_id':    widget.userId,
          'viewer_lid': widget.lid,
        },
      );
      final data = jsonDecode(response.body);
      if (data['status'] == 'ok') {
        setState(() => _profile = data);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendFollowRequest() async {
    setState(() => _isSending = true);
    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/follow_user/'),
        body: {
          'from_lid':   widget.lid,
          'to_user_id': widget.userId,
        },
      );
      final data = jsonDecode(response.body);
      if (data['status'] == 'ok') {
        final msg = data['message'] ?? '';
        if (msg == 'request_sent') {
          _showSnack('Follow request sent! ✅', const Color(0xFF4ECDC4));
          setState(() => _profile?['follow_status'] = 'pending');
        } else if (msg == 'already_requested') {
          _showSnack('Request already sent', Colors.orange);
        } else if (msg == 'already_following') {
          _showSnack('Already following', Colors.orange);
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e");
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _unfollow() async {
    setState(() => _isSending = true);
    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/unfollow_user/'),
        body: {
          'from_lid':   widget.lid,
          'to_user_id': widget.userId,
        },
      );
      final data = jsonDecode(response.body);
      if (data['status'] == 'ok') {
        _showSnack('Unfollowed', Colors.grey);
        setState(() => _profile?['follow_status'] = 'none');
        _loadProfile();
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e");
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF4ECDC4)))
          : _profile == null
          ? const Center(
          child: Text('Profile not found',
              style: TextStyle(color: Colors.white)))
          : _buildProfile(),
    );
  }

  Widget _buildProfile() {
    final p            = _profile!;
    final name         = p['Name'] ?? '';
    final gender       = p['Gender'] ?? '';
    final rawImage     = p['Image'] ?? '';
    final imageUrl     = _fullImageUrl(rawImage);   // ← fixed
    final followStatus = p['follow_status'] ?? 'none';
    final isAccepted   = followStatus == 'accepted';
    final isPending    = followStatus == 'pending';

    final email        = p['Email']   ?? '';
    final dob          = p['DOB']     ?? '';
    final phoneno      = p['Phoneno'] ?? '';
    final phonePrivate = p['phone_private'] ?? true;

    final isMale = gender.toLowerCase() == 'male';

    return CustomScrollView(
      slivers: [
        // ── Hero App Bar ───────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          backgroundColor: const Color(0xFF0A0E27),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Gradient background
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),

                Positioned(
                  bottom: 30,
                  left: 24,
                  right: 24,
                  child: Column(
                    children: [
                      // ── Profile picture ──────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 55,
                          backgroundColor: const Color(0xFF1A1F3A),
                          // Show network image if URL exists,
                          // otherwise show a styled letter/icon fallback
                          backgroundImage: imageUrl.isNotEmpty
                              ? NetworkImage(imageUrl)
                              : null,
                          child: imageUrl.isEmpty
                              ? _avatarFallback(name, radius: 55)
                              : null,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 6),

                      // Gender badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isMale ? Icons.male : Icons.female,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(gender,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Body ──────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Follow button ──────────────────────────────────────
                if (widget.lid != widget.userId) ...[
                  _buildFollowButton(followStatus, isAccepted, isPending),
                  const SizedBox(height: 24),
                ],

                // ── Privacy notice ─────────────────────────────────────
                if (!isAccepted) _buildPrivacyNotice(isPending),

                // ── Public stats ───────────────────────────────────────
                _sectionTitle('Activity'),
                const SizedBox(height: 12),
                _statsRow(p),
                const SizedBox(height: 24),

                // ── Private info (only if accepted) ───────────────────
                if (isAccepted) ...[
                  _sectionTitle('Contact Information'),
                  const SizedBox(height: 12),

                  if (email.isNotEmpty)
                    _infoCard(
                      icon: Icons.email_rounded,
                      label: 'Email',
                      value: email,
                      gradient: [
                        const Color(0xFFFF6B6B),
                        const Color(0xFFFF8E53)
                      ],
                    ),

                  if (dob.isNotEmpty)
                    _infoCard(
                      icon: Icons.cake_rounded,
                      label: 'Date of Birth',
                      value: dob,
                      gradient: [
                        const Color(0xFFFFD93D),
                        const Color(0xFFFF6B6B)
                      ],
                    ),

                  if (phoneno.isNotEmpty && !phonePrivate)
                    _infoCard(
                      icon: Icons.phone_rounded,
                      label: 'Phone',
                      value: phoneno,
                      gradient: [
                        const Color(0xFF6BCF7F),
                        const Color(0xFF44A08D)
                      ],
                    ),

                  if (phonePrivate) _privatePhoneCard(),

                  const SizedBox(height: 8),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Avatar fallback ────────────────────────────────────────────────────────
  /// Shows a coloured circle with the user's first initial when no photo
  /// is available — same pattern as Gmail / WhatsApp.
  Widget _avatarFallback(String name, {double radius = 55}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Text(
      initial,
      style: TextStyle(
        color: const Color(0xFF4ECDC4),
        fontSize: radius * 0.85,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // ── Follow button ──────────────────────────────────────────────────────────
  Widget _buildFollowButton(
      String status, bool isAccepted, bool isPending) {
    if (isAccepted) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF4ECDC4), width: 2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _isSending ? null : _unfollow,
          icon: const Icon(Icons.check_circle_rounded,
              color: Color(0xFF4ECDC4)),
          label: const Text('Following',
              style: TextStyle(
                  color: Color(0xFF4ECDC4),
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ),
      );
    }

    if (isPending) {
      return Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withOpacity(0.5)),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_top_rounded,
                  color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text('Request Pending',
                  style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
        ),
      );
    }

    // Not following yet
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4ECDC4).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _isSending ? null : _sendFollowRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          icon: _isSending
              ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.person_add_rounded, color: Colors.white),
          label: Text(
            _isSending ? 'Sending...' : 'Send Follow Request',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15),
          ),
        ),
      ),
    );
  }

  // ── Privacy notice ─────────────────────────────────────────────────────────
  Widget _buildPrivacyNotice(bool isPending) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.lock_rounded,
              color: Colors.orange, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            isPending
                ? 'Your follow request is pending.\nContact info will be visible once accepted.'
                : 'Send a follow request to see this\nuser\'s contact information.',
            style: const TextStyle(
                color: Colors.white60, fontSize: 13, height: 1.5),
          ),
        ),
      ]),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────
  Widget _statsRow(Map<String, dynamic> p) {
    return Row(children: [
      _statCard('${p['events_attended'] ?? 0}', 'Events',
          Icons.event_rounded, const Color(0xFF4ECDC4)),
      const SizedBox(width: 12),
      _statCard('${p['avg_rating'] ?? 0}', 'Avg Rating',
          Icons.star_rounded, const Color(0xFFFFD93D)),
      const SizedBox(width: 12),
      _statCard(p['top_category'] ?? 'None', 'Fav Type',
          Icons.category_rounded, const Color(0xFF9B59B6)),
    ]);
  }

  Widget _statCard(
      String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11)),
        ]),
      ),
    );
  }

  // ── Info card ──────────────────────────────────────────────────────────────
  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    required List<Color> gradient,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5))),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _privatePhoneCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.phone_locked_rounded,
                color: Colors.white38, size: 22),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phone Number',
                  style: TextStyle(fontSize: 12, color: Colors.white38)),
              SizedBox(height: 4),
              Text('Private',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.white38,
                      fontStyle: FontStyle.italic)),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
  );
}