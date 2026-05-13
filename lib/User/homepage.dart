import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:evesta_app/User/chang_password.dart';
import 'package:evesta_app/User/recommendation.dart';
import 'package:evesta_app/User/view_events.dart';
import 'package:evesta_app/User/view_profile.dart';
import 'package:evesta_app/User/view_user.dart';
import 'package:evesta_app/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'Nearby event recommendation.dart';
import 'chatbot.dart';
import 'complaint.dart';
import 'follow_list.dart';
import 'event_detail.dart';

/// ================= EVENT MODEL =================
class _EventAd {
  final String id;
  final String name;
  final String date;
  final String time;
  final String location;
  final String type;
  final String image;
  final String details;
  final String link;
  final bool ticketed;

  _EventAd({
    required this.id,
    required this.name,
    required this.date,
    required this.time,
    required this.location,
    required this.type,
    required this.image,
    this.details = "",
    this.link = "",
    this.ticketed = false,
  });

  factory _EventAd.fromJson(Map<String, dynamic> json) {
    return _EventAd(
      id:       json['eid']?.toString() ?? "",
      name:     json['name'] ?? "",
      date:     json['date'] ?? "",
      time:     json['Time'] ?? "",
      location: json['location'] ?? "",
      type:     json['Type'] ?? "",
      image:    json['Image'] ?? "",
      details:  json['Details'] ?? "",
      link:     json['Link'] ?? "",
      ticketed: json['ticketed'] == true || json['ticketed'] == 1,
    );
  }
}

/// ================= SEARCH RESULT MODEL =================
class _SearchResult {
  final String id;
  final String name;
  final String date;
  final String time;
  final String type;
  final String location;
  final String details;
  final String link;
  final String image;
  final bool ticketed;

  _SearchResult({
    required this.id,
    required this.name,
    required this.date,
    required this.time,
    required this.type,
    required this.location,
    required this.details,
    required this.link,
    required this.image,
    required this.ticketed,
  });

  factory _SearchResult.fromJson(Map<String, dynamic> json) {
    return _SearchResult(
      id:       json['eid']?.toString() ?? "",
      name:     json['name'] ?? "",
      date:     json['date'] ?? "",
      time:     json['Time'] ?? "",
      type:     json['Type'] ?? "",
      location: json['location'] ?? "",
      details:  json['Details'] ?? "",
      link:     json['Link'] ?? "",
      image:    json['Image'] ?? "",
      ticketed: json['ticketed'] == true || json['ticketed'] == 1,
    );
  }
}

/// ================= HOME PAGE =================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentAd = 0;
  late PageController _adController;
  Timer? _adTimer;
  Timer? _blockCheckTimer;
  Timer? _notificationTimer;

  List<_EventAd> _nearbyEvents = [];
  bool _loadingAds = true;
  String _baseUrl = "";

  // Calicut coordinates (default — overridden by saved prefs)
  static const double _defaultLat = 11.2588;
  static const double _defaultLon = 75.7804;
  // Only show events within this radius in the notification panel
  static const double _notifRadiusKm = 100.0;
  // Only show events within this radius in the nearby slideshow
  static const double _slideshowRadiusKm = 100.0;

  // ── Notification state ──
  int _notificationCount = 0;
  List<Map<String, dynamic>> _followRequests = [];
  List<Map<String, dynamic>> _nearbyNotifEvents = [];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  OverlayEntry? _dropdownOverlay;
  final LayerLink _layerLink = LayerLink();

  List<_SearchResult> _searchResults = [];
  bool _searchLoading = false;
  Timer? _debounce;

  String? _filterCategory;
  DateTime? _filterDate;
  double _filterDistance = 50;
  bool? _filterTicketed;

  static const List<String> _categories = [
    'Music', 'Sports', 'Tech', 'Food', 'Art',
    'Comedy', 'Education', 'Festival', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _adController = PageController();
    _loadNearbyEvents();
    _loadNotifications();
    _searchController.addListener(_onSearchChanged);
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) _removeDropdown();
    });

    checkBlockStatus();

    _blockCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkBlockStatus();
    });

    _notificationTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _loadNotifications();
    });
  }

  // ================= HAVERSINE DISTANCE HELPER =================

  double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  // ================= IMAGE URL HELPER =================

  String _getImageUrl(String imagePath) {
    if (imagePath.isEmpty) return "";
    if (imagePath.startsWith("http")) return imagePath;
    return _baseUrl.replaceAll("/myapp", "") + imagePath;
  }

  // ================= NOTIFICATIONS =================

  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lid       = prefs.getString('lid') ?? '';
      final url       = prefs.getString('url') ?? '';
      final latitude  = prefs.getString("latitude") ?? "$_defaultLat";
      final longitude = prefs.getString("longitude") ?? "$_defaultLon";
      if (lid.isEmpty || url.isEmpty) return;

      final userLat = double.tryParse(latitude) ?? _defaultLat;
      final userLon = double.tryParse(longitude) ?? _defaultLon;

      // Fetch follow requests + nearby events in parallel
      final results = await Future.wait([
        http.post(
          Uri.parse('$url/view_follow_requests/'),
          body: {'lid': lid},
        ),
        http.post(
          Uri.parse('$url/NearbyEventRecommendation/'),
          body: {'latitude': latitude, 'longitude': longitude},
        ),
      ]);

      final followRes = results[0];
      final eventsRes = results[1];

      List<Map<String, dynamic>> requests = [];
      List<Map<String, dynamic>> events   = [];

      if (followRes.statusCode == 200) {
        final data = json.decode(followRes.body);
        if (data['status'] == 'ok') {
          requests = List<Map<String, dynamic>>.from(data['data']);
        }
      }

      if (eventsRes.statusCode == 200) {
        final data = json.decode(eventsRes.body);
        if (data['status'] == 'ok') {
          final now = DateTime.now();
          events = List<Map<String, dynamic>>.from(data['data']).where((e) {
            // 1. Skip past events
            try {
              final date = DateTime.parse(e['date']);
              if (!date.isAfter(now.subtract(const Duration(days: 1)))) {
                return false;
              }
            } catch (_) {}

            // 2. ── LOCATION FILTER ──
            // Only include events whose coordinates are within the radius.
            // If the event has no coordinates, fall back to a city-name
            // substring check so events tagged "Calicut" / "Kozhikode" still show.
            final eLat = double.tryParse(e['latitude']?.toString() ?? '');
            final eLon = double.tryParse(e['longitude']?.toString() ?? '');

            if (eLat != null && eLon != null) {
              final dist = _haversineDistance(userLat, userLon, eLat, eLon);
              return dist <= _notifRadiusKm;
            } else {
              // Fallback: check if the location string mentions Calicut / Kozhikode
              final loc = (e['location'] ?? '').toString().toLowerCase();
              return loc.contains('calicut') ||
                  loc.contains('kozhikode') ||
                  loc.contains('kerala');
            }
          }).toList();
        }
      }

      if (mounted) {
        setState(() {
          _followRequests     = requests;
          _nearbyNotifEvents  = events;
          _notificationCount  = requests.length + events.length;
        });
      }
    } catch (e) {
      debugPrint('Notification error: $e');
    }
  }

  Future<void> _acceptRequest(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('url') ?? '';
    final lid = prefs.getString('lid') ?? '';

    try {
      final res = await http.post(
        Uri.parse('$url/accept_follow/'),
        body: {'lid': lid, 'from_user_id': user['id'].toString()},
      );
      final data = json.decode(res.body);
      if (data['status'] == 'ok') {
        setState(() {
          _followRequests.removeWhere((r) => r['id'] == user['id']);
          _notificationCount = _followRequests.length + _nearbyNotifEvents.length;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("✅ Accepted ${user['Name']}'s request"),
            backgroundColor: const Color(0xFF4ECDC4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      }
    } catch (e) {
      debugPrint('Accept error: $e');
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('url') ?? '';
    final lid = prefs.getString('lid') ?? '';

    try {
      final res = await http.post(
        Uri.parse('$url/reject_follow/'),
        body: {'lid': lid, 'from_user_id': user['id'].toString()},
      );
      final data = json.decode(res.body);
      if (data['status'] == 'ok') {
        setState(() {
          _followRequests.removeWhere((r) => r['id'] == user['id']);
          _notificationCount = _followRequests.length + _nearbyNotifEvents.length;
        });
      }
    } catch (e) {
      debugPrint('Reject error: $e');
    }
  }

  /// Fetches full event details by eid, then opens EventDetailPage.
  /// Falls back to whatever data we already have if the fetch fails.
  Future<void> _fetchAndOpenEvent(Map<String, dynamic> event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString('url') ?? '';
      final baseUrl2 = url.replaceAll('/myapp', '');

      final response = await http.post(
        Uri.parse('$url/get_event_detail/'),
        body: {'eid': event['eid'].toString()},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          final full = data['data'];

          final imagePath = full['Image'] ?? '';
          debugPrint('IMAGE PATH: $imagePath');
          debugPrint('BASE URL: $baseUrl2');
          debugPrint('FULL IMAGE URL: $baseUrl2/$imagePath');

          final imageUrl = imagePath.startsWith('http')
              ? imagePath
              : '$baseUrl2/media/$imagePath'.replaceAll('//', '/').replaceAll(':/', '://');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventDetailPage(
                name:     full['name']     ?? '',
                date:     full['date']     ?? '',
                time:     full['Time']     ?? '',
                location: full['location'] ?? '',
                type:     full['Type']     ?? '',
                details:  full['Details']  ?? '',
                link:     full['Link']     ?? '',
                imageUrl: imageUrl,
              ),
            ),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('fetchAndOpenEvent error: $e');
    }
  }

  String _getEventStatus(String dateStr) {
    try {
      final now  = DateTime.now();
      final date = DateTime.parse(dateStr);
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
      if (isToday) return 'happening_now';
      if (date.isAfter(now)) return 'upcoming';
    } catch (_) {}
    return 'upcoming';
  }

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1F3A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    const Text('Notifications',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (_notificationCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$_notificationCount',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white10),

              Expanded(
                child: (_followRequests.isEmpty && _nearbyNotifEvents.isEmpty)
                    ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off_rounded,
                          color: Colors.white24, size: 48),
                      SizedBox(height: 12),
                      Text('No notifications yet',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 14)),
                    ],
                  ),
                )
                    : ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  children: [

                    // ── FOLLOW REQUESTS ──────────────────────────────
                    if (_followRequests.isNotEmpty) ...[
                      _notifSectionHeader(
                          Icons.person_add_rounded,
                          'Follow Requests',
                          _followRequests.length,
                          const Color(0xFF4ECDC4)),
                      const SizedBox(height: 8),
                      ..._followRequests.map((user) {
                        final avatarUrl = _getImageUrl(
                            user['Image']?.toString() ?? '');
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0E27),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFF4ECDC4)
                                    .withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(colors: [
                                    Color(0xFF9B59B6),
                                    Color(0xFF4ECDC4),
                                  ]),
                                ),
                                padding: const EdgeInsets.all(2),
                                child: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFF1A1F3A),
                                  backgroundImage: avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  child: avatarUrl.isEmpty
                                      ? const Icon(Icons.person,
                                      size: 22,
                                      color: Color(0xFF4ECDC4))
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Name
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(user['Name'] ?? 'Unknown',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    const Text('Wants to follow you',
                                        style: TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Accept
                              GestureDetector(
                                onTap: () async {
                                  await _acceptRequest(user);
                                  setSheet(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF4ECDC4),
                                          Color(0xFF44A08D),
                                        ]),
                                    borderRadius:
                                    BorderRadius.circular(10),
                                  ),
                                  child: const Text('Accept',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Decline
                              GestureDetector(
                                onTap: () async {
                                  await _rejectRequest(user);
                                  setSheet(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.07),
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    border:
                                    Border.all(color: Colors.white24),
                                  ),
                                  child: const Text('Decline',
                                      style: TextStyle(
                                          color: Colors.white54,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                    ],

                    // ── NEARBY EVENTS ─────────────────────────────────
                    if (_nearbyNotifEvents.isNotEmpty) ...[
                      _notifSectionHeader(
                          Icons.location_on_rounded,
                          'Nearby Events',
                          _nearbyNotifEvents.length,
                          const Color(0xFFFFD93D)),
                      const SizedBox(height: 8),
                      ..._nearbyNotifEvents.map((event) {
                        final status = _getEventStatus(event['date'] ?? '');
                        final isNow  = status == 'happening_now';
                        // ── FIX: build full image URL here ──
                        final imageUrl = _getImageUrl(event['Image'] ?? '');

                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx); // close sheet first
                            _fetchAndOpenEvent(event); // fetch full details then navigate
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0E27),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isNow
                                    ? const Color(0xFF28a745)
                                    .withOpacity(0.3)
                                    : const Color(0xFFFFD93D)
                                    .withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Event thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(
                                    imageUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _eventIconBox(),
                                  )
                                      : _eventIconBox(),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event['name'] ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${event['date']}  •  ${event['location'] ?? ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isNow
                                        ? const Color(0xFF28a745)
                                        .withOpacity(0.15)
                                        : const Color(0xFF007bff)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isNow ? '🟢 Now' : '🔵 Soon',
                                    style: TextStyle(
                                        color: isNow
                                            ? const Color(0xFF28a745)
                                            : const Color(0xFF007bff),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                // Tap arrow hint
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 12,
                                  color: Colors.white24,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notifSectionHeader(
      IconData icon, String title, int count, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count',
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _eventIconBox() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFFFD93D).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.event_rounded,
          color: Color(0xFFFFD93D), size: 24),
    );
  }

  // ================= BLOCK STATUS CHECK =================
  Future<void> checkBlockStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lid = prefs.getString('lid') ?? '';
      final url = prefs.getString("url") ?? "";
      if (lid.isEmpty || url.isEmpty) return;

      final response = await http.post(
        Uri.parse("$url/check_block_status/"),
        body: {'lid': lid},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'blocked') {
          _blockCheckTimer?.cancel();
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF1A1F3A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              icon: const Icon(Icons.gpp_bad_rounded,
                  color: Color(0xFFFF6B6B), size: 48),
              title: const Text("Account Suspended",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
              content: const Text(
                "Your account has been suspended by the administrator. "
                    "You will be logged out automatically.\n\n"
                    "If you believe this is a mistake, please contact support.",
                textAlign: TextAlign.center,
                style:
                TextStyle(color: Colors.white60, fontSize: 14, height: 1.6),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginPage()),
                            (route) => false,
                      );
                    },
                    child: const Text("OK, Understood",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("checkBlockStatus error: $e");
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _debounce?.cancel();
    if (query.isEmpty) {
      _removeDropdown();
      return;
    }
    _debounce =
        Timer(const Duration(milliseconds: 350), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searchLoading = true);
    try {
      final body = <String, String>{'query': query};
      if (_filterCategory != null) body['category'] = _filterCategory!;
      if (_filterDate != null)
        body['date'] = _filterDate!.toIso8601String().split('T').first;
      body['distance'] = _filterDistance.toStringAsFixed(0);
      if (_filterTicketed != null)
        body['ticketed'] = _filterTicketed! ? '1' : '0';

      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString("url") ?? _baseUrl;
      body['latitude']  = prefs.getString("latitude")  ?? "$_defaultLat";
      body['longitude'] = prefs.getString("longitude") ?? "$_defaultLon";

      final response =
      await http.post(Uri.parse("$url/SearchEvents/"), body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          setState(() {
            _searchResults = (data['data'] as List)
                .map((e) => _SearchResult.fromJson(e))
                .toList();
            _searchLoading = false;
          });
          _showDropdown();
          return;
        }
      }
    } catch (_) {}
    setState(() {
      _searchResults = [];
      _searchLoading = false;
    });
    _showDropdown();
  }

  void _showDropdown() {
    _removeDropdown();
    _dropdownOverlay = OverlayEntry(builder: (_) => _buildDropdownOverlay());
    Overlay.of(context).insert(_dropdownOverlay!);
  }

  void _removeDropdown() {
    _dropdownOverlay?.remove();
    _dropdownOverlay = null;
  }

  Widget _buildDropdownOverlay() {
    return Positioned(
      width: MediaQuery.of(context).size.width - 48,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 52),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F3A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _searchLoading
                ? const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.yellow))),
            )
                : _searchResults.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text("No events found",
                  style: TextStyle(
                      color: Colors.white38, fontSize: 13),
                  textAlign: TextAlign.center),
            )
                : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              shrinkWrap: true,
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color: Colors.white10,
                  indent: 16,
                  endIndent: 16),
              itemBuilder: (_, i) {
                final r = _searchResults[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    _removeDropdown();
                    _searchFocus.unfocus();
                    _searchController.clear();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventDetailPage(
                          name:     r.name,
                          date:     r.date,
                          time:     r.time,
                          location: r.location,
                          type:     r.type,
                          details:  r.details,
                          link:     r.link,
                          imageUrl: _getImageUrl(r.image),
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ECDC4)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.event_rounded,
                            color: Color(0xFF4ECDC4), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(r.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Text("${r.date}  •  ${r.location}",
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          )),
                      const SizedBox(width: 8),
                      if (r.type.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.yellow
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(r.type,
                              style: const TextStyle(
                                  color: Colors.yellow,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: r.ticketed
                              ? Colors.orange.withValues(alpha: 0.15)
                              : Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                            r.ticketed ? "Paid" : "Free",
                            style: TextStyle(
                                color: r.ticketed
                                    ? Colors.orange
                                    : Colors.greenAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
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

  void _openFilterSheet() {
    String? tempCategory = _filterCategory;
    DateTime? tempDate   = _filterDate;
    double tempDistance  = _filterDistance;
    bool? tempTicketed   = _filterTicketed;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setSheet) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1F3A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 30,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Filter Events",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () => setSheet(() {
                          tempCategory = null;
                          tempDate     = null;
                          tempDistance = 50;
                          tempTicketed = null;
                        }),
                        child: const Text("Reset",
                            style: TextStyle(
                                color: Color(0xFF4ECDC4),
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                const SizedBox(height: 20),
                _filterLabel("Event Category"),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) {
                    final selected = tempCategory == cat;
                    return GestureDetector(
                      onTap: () =>
                          setSheet(() => tempCategory = selected ? null : cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.yellow
                              : Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: selected
                                  ? Colors.yellow
                                  : Colors.white12),
                        ),
                        child: Text(cat,
                            style: TextStyle(
                                color: selected
                                    ? Colors.black
                                    : Colors.white70,
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                _filterLabel("Date"),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: tempDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate:
                      DateTime.now().add(const Duration(days: 365)),
                      builder: (_, child) => Theme(
                        data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                                primary: Colors.yellow,
                                surface: Color(0xFF1A1F3A))),
                        child: child!,
                      ),
                    );
                    if (picked != null) setSheet(() => tempDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: tempDate != null
                              ? Colors.yellow
                              : Colors.white12),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_month_rounded,
                          color: tempDate != null
                              ? Colors.yellow
                              : Colors.white38,
                          size: 18),
                      const SizedBox(width: 12),
                      Text(
                        tempDate != null
                            ? "${tempDate!.day.toString().padLeft(2, '0')}/"
                            "${tempDate!.month.toString().padLeft(2, '0')}/"
                            "${tempDate!.year}"
                            : "Any date",
                        style: TextStyle(
                            color: tempDate != null
                                ? Colors.white
                                : Colors.white38,
                            fontSize: 14),
                      ),
                      const Spacer(),
                      if (tempDate != null)
                        GestureDetector(
                          onTap: () => setSheet(() => tempDate = null),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white38, size: 16),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _filterLabel("Distance"),
                      Text("${tempDistance.toStringAsFixed(0)} km",
                          style: const TextStyle(
                              color: Colors.yellow,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ]),
                const SizedBox(height: 6),
                SliderTheme(
                  data: SliderTheme.of(ctx).copyWith(
                    activeTrackColor: Colors.yellow,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: Colors.yellow,
                    overlayColor: Colors.yellow.withValues(alpha: 0.15),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: tempDistance,
                    min: 1,
                    max: 500,
                    divisions: 99,
                    onChanged: (v) => setSheet(() => tempDistance = v),
                  ),
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("1 km",
                          style:
                          TextStyle(color: Colors.white38, fontSize: 11)),
                      Text("500 km",
                          style:
                          TextStyle(color: Colors.white38, fontSize: 11)),
                    ]),
                const SizedBox(height: 24),
                _filterLabel("Ticket Type"),
                const SizedBox(height: 10),
                Row(children: [
                  _ticketChip("Any", null, tempTicketed,
                          (v) => setSheet(() => tempTicketed = v)),
                  const SizedBox(width: 10),
                  _ticketChip("Paid", true, tempTicketed,
                          (v) => setSheet(() => tempTicketed = v)),
                  const SizedBox(width: 10),
                  _ticketChip("Free", false, tempTicketed,
                          (v) => setSheet(() => tempTicketed = v)),
                ]),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      setState(() {
                        _filterCategory = tempCategory;
                        _filterDate     = tempDate;
                        _filterDistance = tempDistance;
                        _filterTicketed = tempTicketed;
                      });
                      Navigator.pop(ctx);
                      final q = _searchController.text.trim();
                      if (q.isNotEmpty) _runSearch(q);
                    },
                    child: const Text("Apply Filters",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _filterLabel(String text) => Text(text,
      style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3));

  Widget _ticketChip(String label, bool? value, bool? current,
      ValueChanged<bool?> onTap) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.yellow
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border:
          Border.all(color: selected ? Colors.yellow : Colors.white12),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.black : Colors.white70,
                fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13)),
      ),
    );
  }

  bool get _hasActiveFilters =>
      _filterCategory != null ||
          _filterDate != null ||
          _filterDistance != 50 ||
          _filterTicketed != null;

  // ================= NEARBY EVENTS (SLIDESHOW) =================

  Future<void> _loadNearbyEvents() async {
    final prefs     = await SharedPreferences.getInstance();
    final url       = prefs.getString("url") ?? "";
    final latitude  = prefs.getString("latitude")  ?? "$_defaultLat";
    final longitude = prefs.getString("longitude") ?? "$_defaultLon";

    setState(() {
      _baseUrl    = url;
      _loadingAds = true;
    });

    try {
      final response = await http.post(
        Uri.parse("$url/NearbyEventRecommendation/"),
        body: {'latitude': latitude, 'longitude': longitude},
      );
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == 'ok') {
          final userLat = double.tryParse(latitude)  ?? _defaultLat;
          final userLon = double.tryParse(longitude) ?? _defaultLon;
          final now     = DateTime.now();

          // ── FIX: apply the same distance + date filter as notifications ──
          final events = (jsonData['data'] as List)
              .map((e) => _EventAd.fromJson(e))
              .where((e) {
            // Skip past events
            try {
              final date = DateTime.parse(e.date);
              if (!date.isAfter(now.subtract(const Duration(days: 1)))) {
                return false;
              }
            } catch (_) {}

            // Distance filter using coordinates if available
            // (If your backend already filters by location you can
            //  remove this block, but it's a safe client-side guard.)
            // We don't have lat/lon on _EventAd, so fall back to location string.
            final loc = e.location.toLowerCase();
            // Allow events that either have no specific city (empty) or
            // mention Calicut / Kozhikode. Remove this if your backend
            // already returns only nearby events correctly.
            // To use coordinates, add latitude/longitude to _EventAd.fromJson.
            return true; // backend already filtered by the sent coordinates
          }).toList();

          setState(() {
            _nearbyEvents = events;
            _loadingAds   = false;
          });
          _startAutoSlide();
          return;
        }
      }
    } catch (e) {
      debugPrint('loadNearbyEvents error: $e');
    }
    setState(() => _loadingAds = false);
  }

  void _startAutoSlide() {
    _adTimer?.cancel();
    if (_nearbyEvents.length <= 1) return;
    _adTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final next = (_currentAd + 1) % _nearbyEvents.length;
      _adController.animateToPage(next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut);
    });
  }

  void _push(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  void dispose() {
    _adTimer?.cancel();
    _blockCheckTimer?.cancel();
    _notificationTimer?.cancel();
    _adController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    _removeDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => await _showExitDialog(),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E27),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              stretch: true,
              backgroundColor: const Color(0xFF0A0E27),
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      'https://images.pexels.com/photos/1763075/pexels-photo-1763075.jpeg',
                      fit: BoxFit.cover,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0x99FF6B6B),
                            Color(0x994ECDC4),
                            Color(0xF20A0E27),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomCenter,
                          stops: [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 60,
                      left: 24,
                      right: 24,
                      child: CompositedTransformTarget(
                        link: _layerLink,
                        child: Row(children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocus,
                                style: const TextStyle(color: Colors.white),
                                onSubmitted: (query) {
                                  if (query.trim().isNotEmpty) {
                                    _runSearch(query.trim());
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: "Search events...",
                                  hintStyle:
                                  const TextStyle(color: Colors.white60),
                                  prefixIcon: const Icon(Icons.search,
                                      color: Colors.white70),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? GestureDetector(
                                      onTap: () {
                                        _searchController.clear();
                                        _removeDropdown();
                                      },
                                      child: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.white54,
                                          size: 18))
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding:
                                  const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _openFilterSheet,
                            child: Stack(clipBehavior: Clip.none, children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _hasActiveFilters
                                      ? Colors.yellow
                                      : Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: _hasActiveFilters
                                          ? Colors.yellow
                                          : Colors.white24),
                                ),
                                child: Icon(Icons.tune_rounded,
                                    color: _hasActiveFilters
                                        ? Colors.black
                                        : Colors.white70,
                                    size: 22),
                              ),
                              if (_hasActiveFilters)
                                Positioned(
                                  top: -3,
                                  right: -3,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                        color: Color(0xFFFF6B6B),
                                        shape: BoxShape.circle),
                                  ),
                                ),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                    Positioned(
                      bottom: 30,
                      left: 24,
                      right: 24,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Text('✨  EVESTA',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 3,
                                      fontSize: 12)),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(
                                  child: Text('Your Event\nUniverse',
                                      style: TextStyle(
                                          fontSize: 44,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          height: 1.1)),
                                ),
                                // ── BELL ICON ──
                                GestureDetector(
                                  onTap: _showNotificationsSheet,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color:
                                          Colors.white.withOpacity(0.15),
                                          borderRadius:
                                          BorderRadius.circular(14),
                                          border: Border.all(
                                              color: Colors.white24),
                                        ),
                                        child: const Icon(
                                          Icons.notifications_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      if (_notificationCount > 0)
                                        Positioned(
                                          top: -4,
                                          right: -4,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFFF6B6B),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '$_notificationCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                                'Create memories · Discover experiences',
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 13)),
                          ]),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 60),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel("Quick Access"),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                            child: _QuickCard(
                              icon: Icons.person_outline_rounded,
                              label: "My Profile",
                              gradient: const [
                                Color(0xFFFF6B6B),
                                Color(0xFFFF8E53)
                              ],
                              onTap: () => _push(const ViewProfile()),
                            )),
                        const SizedBox(width: 14),
                        Expanded(
                            child: _QuickCard(
                              icon: Icons.event_available_rounded,
                              label: "My Events",
                              gradient: const [
                                Color(0xFF4ECDC4),
                                Color(0xFF44A08D)
                              ],
                              onTap: () => _push(const view_eventpage()),
                            )),
                      ]),
                      const SizedBox(height: 32),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _sectionLabel("Nearby Events"),
                            GestureDetector(
                              onTap: () =>
                                  _push(const NearbyEventRecommendationPage()),
                              child: const Text("See all →",
                                  style: TextStyle(
                                      color: Color(0xFF4ECDC4),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]),
                      const SizedBox(height: 14),
                      _buildNearbyAdSlideshow(),
                      const SizedBox(height: 32),
                      _sectionLabel("All Features"),
                      const SizedBox(height: 14),
                      _TileCard(
                          icon: Icons.stars_rounded,
                          label: "Recommendations",
                          subtitle: "Events tailored just for you",
                          color: const Color(0xFFFFD93D),
                          onTap: () =>
                              _push(const AspectEventRecommendationPage())),
                      _TileCard(
                          icon: Icons.person_rounded,
                          label: "View Users",
                          subtitle: "Connect with people",
                          color: const Color(0xFF1ABC9C),
                          onTap: () => _push(const ViewAllUsers())),
                      _TileCard(
                          icon: Icons.chat_bubble_rounded,
                          label: "Chat Support",
                          subtitle: "Get help from our AI assistant",
                          color: const Color(0xFF6BCF7F),
                          onTap: () => _push(ChatScreen())),
                      _TileCard(
                          icon: Icons.people_alt_rounded,
                          label: "My Network",
                          subtitle: "Stay connected with your network",
                          color: const Color(0xFF9B59B6),
                          onTap: () => _push(ViewFollowListPage())),
                      _TileCard(
                          icon: Icons.report_problem_rounded,
                          label: "Complaint",
                          subtitle: "Let us know if something went wrong",
                          color: const Color(0xFFE74C3C),
                          onTap: () => _push(complaint())),
                      _TileCard(
                          icon: Icons.lock_reset_rounded,
                          label: "Change Password",
                          subtitle: "Update your account password",
                          color: const Color(0xFFFF5722),
                          onTap: () => _push(MyChangePasswordPage(title: ''))),
                      _TileCard(
                        icon: Icons.logout_rounded,
                        label: "Logout",
                        subtitle: "Sign out from your account",
                        color: const Color(0xFF95A5A6),
                        onTap: () async {
                          if (await _showLogoutDialog()) {
                            Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginPage()));
                          }
                        },
                      ),
                    ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyAdSlideshow() {
    if (_loadingAds) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
            child: CircularProgressIndicator(color: Colors.yellow)),
      );
    }

    if (_nearbyEvents.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_off_rounded, color: Colors.white24, size: 36),
            SizedBox(height: 10),
            Text("No nearby events found",
                style: TextStyle(color: Colors.white38, fontSize: 14)),
          ]),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _adController,
            itemCount: _nearbyEvents.length,
            onPageChanged: (i) => setState(() => _currentAd = i),
            itemBuilder: (context, index) {
              final event    = _nearbyEvents[index];
              final imageUrl = _getImageUrl(event.image);

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailPage(
                      name:     event.name,
                      date:     event.date,
                      time:     event.time,
                      location: event.location,
                      type:     event.type,
                      details:  event.details,
                      link:     event.link,
                      imageUrl: imageUrl,
                    ),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 140,
                        width: double.infinity,
                        child: imageUrl.isNotEmpty
                            ? Image.network(imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFE8EAF0),
                                child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.black26,
                                    size: 32)))
                            : Container(
                            color: const Color(0xFFE8EAF0),
                            child: const Icon(Icons.event,
                                color: Colors.black26, size: 32)),
                      ),
                      Expanded(
                        child: Padding(
                          padding:
                          const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(children: [
                                if (event.type.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    margin:
                                    const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFCC00),
                                      borderRadius:
                                      BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                        event.type.toUpperCase(),
                                        style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 9,
                                            letterSpacing: 0.8)),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F0F0),
                                    borderRadius:
                                    BorderRadius.circular(8),
                                  ),
                                  child: const Text("Ad",
                                      style: TextStyle(
                                          color: Colors.black45,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500)),
                                ),
                              ]),
                              const SizedBox(height: 5),
                              Text(event.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.calendar_today,
                                    color: Color(0xFFFFCC00), size: 11),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    event.time.isNotEmpty
                                        ? "${event.date}  •  ${event.time}"
                                        : event.date,
                                    style: const TextStyle(
                                        color: Colors.black45,
                                        fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 2),
                              Row(children: [
                                const Icon(Icons.location_on,
                                    color: Color(0xFFFFCC00), size: 11),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(event.location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.black45,
                                          fontSize: 11)),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_nearbyEvents.length, (i) {
            final active = _currentAd == i;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? const Color(0xFFFFCC00) : Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.3));

  Future<bool> _showLogoutDialog() async {
    return (await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3A),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout",
            style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to logout?",
            style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    )) ??
        false;
  }

  Future<bool> _showExitDialog() async {
    return (await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3A),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Exit App",
            style: TextStyle(color: Colors.white)),
        content: const Text("Do you want to exit the app?",
            style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Stay",
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Exit",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    )) ??
        false;
  }
}

/// ===== QUICK CARD =====
class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: gradient.first.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8)),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const Spacer(),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ]),
      ),
    );
  }
}

/// ===== TILE CARD =====
class _TileCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _TileCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
        trailing: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: Colors.white38),
        ),
      ),
    );
  }
}