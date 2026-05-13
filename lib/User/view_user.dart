import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'user_profile.dart';

/// ================= USER MODEL =================
class UserModel {
  final String id;
  final String name;
  final String gender;
  final String image;

  UserModel({
    required this.id,
    required this.name,
    required this.gender,
    required this.image,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:     json['id'].toString().trim(),
      name:   json['Name'] ?? '',
      gender: json['Gender'] ?? '',
      image:  json['Image'] ?? '',
    );
  }
}

/// ================= VIEW ALL USERS =================
class ViewAllUsers extends StatefulWidget {
  const ViewAllUsers({super.key});

  @override
  State<ViewAllUsers> createState() => _ViewAllUsersState();
}

class _ViewAllUsersState extends State<ViewAllUsers> {
  List<UserModel> _allUsers = [];
  List<UserModel> _filtered = [];
  bool   _isLoading = true;
  String _baseUrl   = "";
  String _lid       = "";

  final TextEditingController _searchCtrl  = TextEditingController();
  final FocusNode             _searchFocus = FocusNode();
  OverlayEntry? _dropdownOverlay;
  final LayerLink _layerLink = LayerLink();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    fetchUsers();
    _searchCtrl.addListener(_onSearchChanged);
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) _removeDropdown();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _removeDropdown();
    super.dispose();
  }

  /// Builds a full image URL from the relative path the backend returns.
  String _fullImageUrl(String rawPath) {
    if (rawPath.isEmpty) return '';
    if (rawPath.startsWith('http')) return rawPath;
    return _baseUrl.replaceAll('/myapp', '') + rawPath;
  }

  Future<void> fetchUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _baseUrl = prefs.getString("url") ?? "";
      _lid     = (prefs.getString("lid") ?? "").trim();

      final response = await http.post(
        Uri.parse("$_baseUrl/view_user/"),
        body: {"lid": _lid},
      );

      final jsonData = jsonDecode(response.body);

      print('=== MY LID: "$_lid"');           // 👈 add this
      print('=== RAW DATA: ${jsonData["data"]}'); // 👈 add this

      if (jsonData["status"] == "ok") {
        final all = (jsonData["data"] as List)
            .map((e) => UserModel.fromJson(e))
            .toList();

        for (var u in all) {                  // 👈 add this
          print('User id: "${u.id}" == lid: "$_lid" → ${u.id == _lid}');
        }

        final fetched = all.where((u) => u.id.trim() != _lid.trim()).toList();

        setState(() {
          _allUsers = fetched;
          _filtered = fetched;
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── search ────────────────────────────────────────────────────────────────
  void _onSearchChanged() {
    _debounce?.cancel();
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      _removeDropdown();
      setState(() => _filtered = _allUsers);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final results = _allUsers
          .where((u) => u.name.toLowerCase().contains(q.toLowerCase()))
          .toList();
      setState(() => _filtered = results);
      _showDropdown(results);
    });
  }

  void _showDropdown(List<UserModel> results) {
    _removeDropdown();
    _dropdownOverlay = OverlayEntry(builder: (_) => _buildDropdown(results));
    Overlay.of(context).insert(_dropdownOverlay!);
  }

  void _removeDropdown() {
    _dropdownOverlay?.remove();
    _dropdownOverlay = null;
  }

  Widget _buildDropdown(List<UserModel> results) {
    return Positioned(
      width: MediaQuery.of(context).size.width - 48,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 52),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F3A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: results.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text("No users found",
                  style: TextStyle(
                      color: Colors.white38, fontSize: 13),
                  textAlign: TextAlign.center),
            )
                : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              shrinkWrap: true,
              itemCount: results.length,
              separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color: Colors.white10,
                  indent: 16,
                  endIndent: 16),
              itemBuilder: (_, i) {
                final u = results[i];
                final imageUrl = _fullImageUrl(u.image);
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    _removeDropdown();
                    _searchFocus.unfocus();
                    _openProfile(u);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                        const Color(0xFF0A0E27),
                        backgroundImage: imageUrl.isNotEmpty
                            ? NetworkImage(imageUrl)
                            : null,
                        child: imageUrl.isEmpty
                            ? _avatarFallback(u.name,
                            size: 18)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(u.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight:
                                FontWeight.w600),
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      _genderBadge(u.gender),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _openProfile(UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          userId: user.id,
          baseUrl: _baseUrl,
          lid: _lid,
        ),
      ),
    );
  }

  Widget _genderBadge(String gender) {
    final isMale = gender.toLowerCase() == 'male';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isMale
            ? const Color(0xFF3498DB)
            : const Color(0xFFE91E63))
            .withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        gender,
        style: TextStyle(
          color: isMale
              ? const Color(0xFF3498DB)
              : const Color(0xFFE91E63),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ── user card ─────────────────────────────────────────────────────────────
  Widget _userCard(UserModel user) {
    final imageUrl = _fullImageUrl(user.image);
    return GestureDetector(
      onTap: () => _openProfile(user),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // Avatar with gradient ring
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)]),
              ),
              padding: const EdgeInsets.all(2.5),
              child: CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFF1A1F3A),
                backgroundImage: imageUrl.isNotEmpty
                    ? NetworkImage(imageUrl)
                    : null,
                child: imageUrl.isEmpty
                    ? _avatarFallback(user.name, size: 32)
                    : null,
              ),
            ),

            const SizedBox(width: 16),

            // Name + gender
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 6),
                  _genderBadge(user.gender),
                ],
              ),
            ),

            // Arrow
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Color(0xFF4ECDC4)),
            ),
          ]),
        ),
      ),
    );
  }

  /// Letter-avatar fallback — shows first initial, like Gmail / WhatsApp.
  Widget _avatarFallback(String name, {double size = 22}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Text(
      initial,
      style: TextStyle(
        color: const Color(0xFF4ECDC4),
        fontSize: size * 0.7,
        fontWeight: FontWeight.bold,
      ),
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
                    'https://images.pexels.com/photos/1181686/pexels-photo-1181686.jpeg',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF6B6B).withOpacity(0.7),
                          const Color(0xFF4ECDC4).withOpacity(0.8),
                          const Color(0xFF0A0E27).withOpacity(0.95),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),

                  // Search bar
                  Positioned(
                    top: 60,
                    left: 24,
                    right: 24,
                    child: CompositedTransformTarget(
                      link: _layerLink,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Search by name...",
                            hintStyle: const TextStyle(
                                color: Colors.white60),
                            prefixIcon: const Icon(Icons.search,
                                color: Colors.white70),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  _removeDropdown();
                                  setState(
                                          () => _filtered = _allUsers);
                                },
                                child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white54,
                                    size: 18))
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                        ),
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
                        const Text('Discover\nPeople',
                            style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.1)),
                        const SizedBox(height: 6),
                        Text(
                          '${_filtered.length} user${_filtered.length != 1 ? 's' : ''} • Tap to view profile',
                          style: const TextStyle(
                              color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _isLoading
                ? const SizedBox(
                height: 400,
                child: Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF4ECDC4))))
                : _filtered.isEmpty
                ? const SizedBox(
              height: 400,
              child: Center(
                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline,
                        size: 60, color: Colors.white24),
                    SizedBox(height: 16),
                    Text("No Users Found",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight:
                            FontWeight.bold)),
                  ],
                ),
              ),
            )
                : RefreshIndicator(
              onRefresh: fetchUsers,
              color: const Color(0xFF4ECDC4),
              backgroundColor: const Color(0xFF1A1F3A),
              child: Column(children: [
                const SizedBox(height: 12),
                ..._filtered.map((u) => _userCard(u)),
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}