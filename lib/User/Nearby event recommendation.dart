

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'event_detail.dart';

/// ================= EVENT MODEL =================
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
  final double distance;

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
    this.distance = 0.0,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id:        json['eid']?.toString() ?? "",
      name:      json['name'] ?? "",
      date:      json['date'] ?? "",
      time:      json['Time'] ?? "",
      location:  json['location'] ?? "",
      details:   json['Details'] ?? "",
      link:      json['Link'] ?? "",
      type:      json['Type'] ?? "",
      latitude:  json['Latitude']?.toString() ?? "",
      longitude: json['Longitude']?.toString() ?? "",
      image:     json['Image'] ?? "",
      distance:  (json['distance'] ?? 0.0).toDouble(),
    );
  }
}

/// ================= API =================
Future<List<EventModel>> fetchAllEvents() async {
  final sh         = await SharedPreferences.getInstance();
  String url       = sh.getString("url") ?? "";
  String latitude  = sh.getString("latitude")  ?? "11.2588";
  String longitude = sh.getString("longitude") ?? "75.7804";

  final response = await http.post(
    Uri.parse("$url/view_eventsaccepted/"),
    body: {'latitude': latitude, 'longitude': longitude},
  );

  if (response.statusCode == 200) {
    final jsonData = json.decode(response.body);
    if (jsonData['status'] == 'ok') {
      return (jsonData['data'] as List)
          .map((e) => EventModel.fromJson(e))
          .toList();
    }
  }
  return [];
}

/// ================= PAGE =================
class NearbyEventRecommendationPage extends StatefulWidget {
  const NearbyEventRecommendationPage({super.key});

  @override
  State<NearbyEventRecommendationPage> createState() =>
      _NearbyEventRecommendationPageState();
}

class _NearbyEventRecommendationPageState
    extends State<NearbyEventRecommendationPage> {
  late Future<List<EventModel>> eventList;
  String baseUrl = "";
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    eventList = fetchAllEvents();
    _loadBaseUrl();
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
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: FutureBuilder<List<EventModel>>(
        future: eventList,
        builder: (context, snapshot) {
          final count = snapshot.data?.length ?? 0;

          return CustomScrollView(
            slivers: [
              // ── Hero App Bar ─────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: const Color(0xFF0A0E27),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  if (count > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            "$count events",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        'https://images.pexels.com/photos/1763075/pexels-photo-1763075.jpeg',
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF4ECDC4).withOpacity(0.7),
                              const Color(0xFF556270).withOpacity(0.85),
                              const Color(0xFF0A0E27).withOpacity(0.95),
                            ],
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            const Text(
                              'Discover Events',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$count event${count != 1 ? 's' : ''} • Nearest first',
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Body ─────────────────────────────────────────────────
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
                  ),
                )
              else if (!snapshot.hasData || snapshot.data!.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.event_busy,
                            color: Colors.white24, size: 60),
                        SizedBox(height: 16),
                        Text("No events found",
                            style: TextStyle(
                                color: Colors.white, fontSize: 18)),
                        SizedBox(height: 8),
                        Text("Check back later!",
                            style: TextStyle(
                                color: Colors.white38, fontSize: 14)),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final event = snapshot.data![index];
                        return _EventCard(
                          event:    event,
                          imageUrl: getImageUrl(event.image),
                        );
                      },
                      childCount: snapshot.data!.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// ================= EVENT CARD =================
class _EventCard extends StatelessWidget {
  final EventModel event;
  final String imageUrl;

  const _EventCard({required this.event, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    double? lat = double.tryParse(event.latitude);
    double? lon = double.tryParse(event.longitude);
    final LatLng? location =
    (lat != null && lon != null) ? LatLng(lat, lon) : null;

    String distLabel = '';
    if (event.distance > 0) {
      distLabel = event.distance < 1
          ? '< 1 km away'
          : '${event.distance.toStringAsFixed(1)} km away';
    }

    // ✅ FIXED: wrapped in GestureDetector to navigate to EventDetailPage
    return GestureDetector(
      onTap: () {
        Navigator.push(
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
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Event Image ──────────────────────────────────────────────
            Stack(
              children: [
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF0A0E27),
                      child: const Icon(Icons.image_not_supported,
                          color: Colors.white24, size: 40),
                    ),
                  )
                      : Container(
                    color: const Color(0xFF0A0E27),
                    child: const Icon(Icons.event,
                        color: Colors.white24, size: 40),
                  ),
                ),
                // gradient overlay on image
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF1A1F3A).withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
                // type badge
                if (event.type.isNotEmpty)
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.yellow,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        event.type.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                // distance badge
                if (distLabel.isNotEmpty)
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.near_me,
                              color: Color(0xFF4ECDC4), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            distLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // ── Event Details ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Event Name
                  Text(
                    event.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Date + Time
                  _infoRow(
                    Icons.calendar_today,
                    event.time.isNotEmpty
                        ? "${event.date}  •  ${event.time}"
                        : event.date,
                    const Color(0xFFFF6B6B),
                  ),

                  const SizedBox(height: 8),

                  // Location
                  _infoRow(
                    Icons.location_on,
                    event.location,
                    const Color(0xFFFFD93D),
                  ),

                  // Details
                  if (event.details.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        event.details,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],

                  // Link
                  if (event.link.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.link,
                            color: Color(0xFF4ECDC4), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
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
                  ],

                  // Mini Map
                  if (location != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Event Location',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 130,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: location,
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
                              "com.example.evesta_app",
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: location,
                                  width: 36,
                                  height: 36,
                                  child: const Icon(
                                    Icons.location_pin,
                                    color: Color(0xFFFF5722),
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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

  Widget _infoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
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
}