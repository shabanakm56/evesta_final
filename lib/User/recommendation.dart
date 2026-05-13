import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// ================== EVENT MODEL ==================
class EventModel {
  final String id;
  final String name;
  final String date;
  final String time;
  final String location;
  final String details;
  final String link;
  final String type;
  final String latitude;
  final String longitude;
  final String image;

  EventModel({
    required this.id,
    required this.name,
    required this.date,
    required this.time,
    required this.location,
    required this.details,
    required this.link,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.image,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id:        json['eid']?.toString() ?? json['id']?.toString() ?? "",
      name:      json['name']      ?? json['EventName'] ?? "",
      date:      json['date']      ?? json['Date']      ?? "",
      time:      json['Time']      ?? "",
      location:  json['location']  ?? json['Location']  ?? "",
      details:   json['description'] ?? json['Details'] ?? "",
      link:      json['Link']      ?? "",
      type:      json['Type']      ?? "",
      latitude:  json['Latitude']?.toString()  ?? "",
      longitude: json['Longitude']?.toString() ?? "",
      image:     json['Image']     ?? "",
    );
  }

  /// Returns true if the event date is today or in the future.
  bool get isUpcoming {
    try {
      final eventDate = DateTime.parse(date);
      final today     = DateTime.now();
      // Compare date only (ignore time) so today's events still show
      final todayDate = DateTime(today.year, today.month, today.day);
      final evDate    = DateTime(eventDate.year, eventDate.month, eventDate.day);
      return !evDate.isBefore(todayDate);
    } catch (_) {
      // If date can't be parsed, show the event to be safe
      return true;
    }
  }
}

/// ================== API CALL ==================
Future<List<EventModel>> fetchAspectEvents() async {
  final sh  = await SharedPreferences.getInstance();
  final url = sh.getString("url") ?? "";
  final lid = sh.getString("lid") ?? "";

  final response = await http.post(
    Uri.parse("$url/AspectBasedEventRecommendation/"),
    body: {'lid': lid},
  );

  if (response.statusCode == 200) {
    final jsonData = json.decode(response.body);
    if (jsonData['status'] == 'ok') {
      return (jsonData['data'] as List)
          .map((e) => EventModel.fromJson(e))
          .where((e) => e.isUpcoming)   // ← filter out past events
          .toList();
    }
  }
  return [];
}

/// ================== UI PAGE ==================
class AspectEventRecommendationPage extends StatefulWidget {
  const AspectEventRecommendationPage({super.key});

  @override
  State<AspectEventRecommendationPage> createState() =>
      _AspectEventRecommendationPageState();
}

class _AspectEventRecommendationPageState
    extends State<AspectEventRecommendationPage>
    with SingleTickerProviderStateMixin {
  late Future<List<EventModel>> eventList;
  late AnimationController _animationController;
  String baseUrl = "";

  @override
  void initState() {
    super.initState();
    _loadBaseUrl();
    eventList = fetchAspectEvents();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  Future<void> _loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => baseUrl = prefs.getString("url") ?? "");
  }

  String getImageUrl(String imagePath) {
    if (imagePath.isEmpty) return "";
    if (imagePath.startsWith("http")) return imagePath;
    return baseUrl.replaceAll("/myapp", "") + imagePath;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: CustomScrollView(
        slivers: [
          /// ================= APP BAR =================
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF0A0E27),
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back,
                    color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.pexels.com/photos/2747449/pexels-photo-2747449.jpeg',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFD93D).withOpacity(0.7),
                          const Color(0xFF4ECDC4).withOpacity(0.75),
                          const Color(0xFF0A0E27).withOpacity(0.95),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    right: -40,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 100,
                    left: -30,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFD93D).withOpacity(0.1),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'AI POWERED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Personalized\nRecommendations',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.1,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                            const Color(0xFFFFD93D).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Events curated just for you',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// ================= BODY =================
          SliverToBoxAdapter(
            child: FutureBuilder<List<EventModel>>(
              future: eventList,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }
                return Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildInfoBanner(snapshot.data!.length),
                    const SizedBox(height: 16),
                    ...snapshot.data!.asMap().entries.map((entry) {
                      return _buildEventCard(entry.value, entry.key);
                    }),
                    const SizedBox(height: 80),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// ================= INFO BANNER =================
  Widget _buildInfoBanner(int count) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD93D).withOpacity(0.2),
            const Color(0xFF4ECDC4).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD93D).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD93D).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lightbulb_outline,
                color: Color(0xFFFFD93D), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Found $count Upcoming Match${count != 1 ? 'es' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Based on your preferences and history',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.stars, color: Color(0xFFFFD93D), size: 24),
        ],
      ),
    );
  }

  /// ================= LOADING STATE =================
  Widget _buildLoadingState() {
    return SizedBox(
      height: 500,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFD93D).withOpacity(0.2),
                  ),
                ),
                const SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFD93D),
                    strokeWidth: 3,
                  ),
                ),
                const Icon(Icons.auto_awesome,
                    color: Color(0xFFFFD93D), size: 24),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Finding Perfect Events...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Analyzing your preferences',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ================= EMPTY STATE =================
  Widget _buildEmptyState() {
    return SizedBox(
      height: 500,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F3A),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFD93D).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(Icons.explore_off,
                  size: 60, color: Color(0xFFFFD93D)),
            ),
            const SizedBox(height: 24),
            const Text(
              "No Upcoming Recommendations",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Attend more events and rate them to get\npersonalized recommendations!",
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD93D),
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Explore All Events',
                style: TextStyle(
                  color: Color(0xFF0A0E27),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ================= EVENT CARD =================
  Widget _buildEventCard(EventModel event, int index) {
    double? latitude;
    double? longitude;

    try {
      if (event.latitude.isNotEmpty && event.latitude != 'null') {
        latitude = double.parse(event.latitude);
      }
      if (event.longitude.isNotEmpty && event.longitude != 'null') {
        longitude = double.parse(event.longitude);
      }
    } catch (_) {
      latitude  = null;
      longitude = null;
    }

    final bool hasLocation = latitude != null && longitude != null;
    final LatLng? eventLocation =
    hasLocation ? LatLng(latitude!, longitude!) : null;

    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          (index * 0.1).clamp(0.0, 1.0),
          ((index * 0.1) + 0.3).clamp(0.0, 1.0),
          curve: Curves.easeOut,
        ),
      ),
    );

    // ── Days until event label ──
    String dateLabel = '';
    try {
      final eventDate = DateTime.parse(event.date);
      final today     = DateTime.now();
      final diff      = DateTime(eventDate.year, eventDate.month, eventDate.day)
          .difference(DateTime(today.year, today.month, today.day))
          .inDays;
      if (diff == 0) {
        dateLabel = 'Today!';
      } else if (diff == 1) {
        dateLabel = 'Tomorrow';
      } else {
        dateLabel = 'In $diff days';
      }
    } catch (_) {}

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 50 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFFD93D).withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Event Image
            if (event.image.isNotEmpty)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    child: Image.network(
                      getImageUrl(event.image),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            const Color(0xFFFFD93D).withOpacity(0.6),
                            const Color(0xFF4ECDC4).withOpacity(0.6),
                          ]),
                        ),
                        child: const Icon(Icons.event,
                            size: 60, color: Colors.white),
                      ),
                    ),
                  ),
                  // Gradient overlay
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFF1A1F3A).withOpacity(0.7),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Type badge — top right
                  if (event.type.isNotEmpty)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD93D),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          event.type,
                          style: const TextStyle(
                            color: Color(0xFF0A0E27),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Days until badge — top left
                  if (dateLabel.isNotEmpty)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: dateLabel == 'Today!'
                              ? const Color(0xFF28a745).withOpacity(0.9)
                              : const Color(0xFF4ECDC4).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              dateLabel == 'Today!'
                                  ? Icons.fiber_manual_record
                                  : Icons.schedule_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

            /// Event Details
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _infoRow(Icons.calendar_today, event.date,
                      const Color(0xFFFF6B6B)),
                  if (event.time.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _infoRow(Icons.access_time, event.time,
                        const Color(0xFF4ECDC4)),
                  ],
                  const SizedBox(height: 8),
                  _infoRow(Icons.location_on, event.location,
                      const Color(0xFFFFD93D)),

                  if (event.details.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0E27),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        event.details,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                          height: 1.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],

                  if (event.link.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0E27),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.link,
                              size: 16, color: Color(0xFF4ECDC4)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              event.link,
                              style: const TextStyle(
                                color: Color(0xFF4ECDC4),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  /// Map
                  if (hasLocation) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Event Location',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFFD93D).withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: eventLocation!,
                            initialZoom: 15,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.pinchZoom |
                              InteractiveFlag.drag,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                              "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                              userAgentPackageName:
                              'com.example.evesta_app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: eventLocation,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_pin,
                                    color: Color(0xFFFFD93D),
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0E27),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.my_location,
                              size: 14, color: Color(0xFFFFD93D)),
                          const SizedBox(width: 6),
                          Text(
                            'Lat: ${latitude!.toStringAsFixed(4)}, '
                                'Long: ${longitude!.toStringAsFixed(4)}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0E27),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_off,
                              color: Colors.white38, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'No location coordinates available',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ================= INFO ROW =================
  Widget _infoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }
}