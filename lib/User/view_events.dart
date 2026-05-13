import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'Post_events.dart';

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
  final String status; // ← NEW

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
    required this.status,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id:        json['id'].toString(),
      name:      json['EventName'] ?? "",
      date:      json['Date'] ?? "",
      time:      json['Time'] ?? "",
      location:  json['Location'] ?? "",
      details:   json['Details'] ?? "",
      link:      json['Link'] ?? "",
      type:      json['Type'] ?? "",
      latitude:  json['Latitude'].toString(),
      longitude: json['Longitude'].toString(),
      image:     json['Image'] ?? "",
      status:    json['Status'] ?? "pending",
    );
  }
}

/// ================= MY EVENTS PAGE =================
class view_eventpage extends StatefulWidget {
  const view_eventpage({super.key});

  @override
  State<view_eventpage> createState() => _view_eventpageState();
}

class _view_eventpageState extends State<view_eventpage> {
  List<EventModel> events = [];
  bool loading = true;
  String baseUrl = "";

  @override
  void initState() {
    super.initState();
    fetchEvents();
  }

  String getImageUrl(String imagePath) {
    if (imagePath.isEmpty) return "";
    if (imagePath.startsWith("http")) return imagePath;
    return baseUrl.replaceAll("/myapp", "") + imagePath;
  }

  /// ================= FETCH MY EVENTS =================
  Future<void> fetchEvents() async {
    try {
      setState(() => loading = true);
      final prefs = await SharedPreferences.getInstance();
      baseUrl      = prefs.getString("url") ?? "";
      final lid    = prefs.getString("lid") ?? "";

      if (baseUrl.isEmpty || lid.isEmpty) {
        Fluttertoast.showToast(msg: "Configuration error");
        setState(() => loading = false);
        return;
      }

      final response = await http.post(
        Uri.parse("$baseUrl/my_events/"),
        body: {"lid": lid},
      );

      final jsonData = json.decode(response.body);

      if (jsonData["status"] == "ok") {
        setState(() {
          events = (jsonData["data"] as List)
              .map((e) => EventModel.fromJson(e))
              .toList();
        });
      } else {
        setState(() => events = []);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  // ── STATUS BADGE ──────────────────────────────────────────────────────────
  Widget _statusBadge(String status) {
    Color color;
    IconData icon;
    String label;

    switch (status.toLowerCase()) {
      case 'accepted':
        color = Colors.green;
        icon  = Icons.check_circle_rounded;
        label = 'Accepted';
        break;
      case 'rejected':
        color = Colors.red;
        icon  = Icons.cancel_rounded;
        label = 'Rejected';
        break;
      default:
        color = Colors.orange;
        icon  = Icons.hourglass_top_rounded;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
  // ──────────────────────────────────────────────────────────────────────────

  /// ================= EVENT CARD =================
  Widget eventCard(EventModel e) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Event Image
          if (e.image.isNotEmpty)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  child: Image.network(
                    getImageUrl(e.image),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          const Color(0xFFFF6B6B).withOpacity(0.6),
                          const Color(0xFF4ECDC4).withOpacity(0.6),
                        ]),
                      ),
                      child: const Icon(Icons.event,
                          size: 60, color: Colors.white),
                    ),
                  ),
                ),
                // gradient overlay
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
                // type badge top right
                if (e.type.isNotEmpty)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        e.type,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Event name + status badge row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        e.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusBadge(e.status),
                  ],
                ),

                const SizedBox(height: 8),

                // status message
                _statusMessage(e.status),

                const SizedBox(height: 16),

                _infoRow(Icons.calendar_today, e.date,
                    const Color(0xFFFF6B6B)),
                _infoRow(Icons.access_time, e.time,
                    const Color(0xFF4ECDC4)),
                _infoRow(Icons.location_on, e.location,
                    const Color(0xFFFFD93D)),

                if (e.details.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    e.details,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── STATUS MESSAGE ────────────────────────────────────────────────────────
  Widget _statusMessage(String status) {
    String msg;
    Color color;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'accepted':
        msg   = "Your event has been approved and is now live!";
        color = Colors.green;
        icon  = Icons.celebration_rounded;
        break;
      case 'rejected':
        msg   = "Your event was not approved by the coordinator.";
        color = Colors.red;
        icon  = Icons.info_outline_rounded;
        break;
      default:
        msg   = "Your event is under review by the coordinator.";
        color = Colors.orange;
        icon  = Icons.schedule_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                  color: color.withOpacity(0.9),
                  fontSize: 12,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
  // ──────────────────────────────────────────────────────────────────────────

  Widget _infoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
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
            child: Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  /// ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: CustomScrollView(
        slivers: [
          /// APP BAR
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: const Color(0xFF0A0E27),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: fetchEvents,
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
                    bottom: 50,
                    left: 24,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        const Text(
                          'My Events',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${events.length} event${events.length != 1 ? 's' : ''} posted',
                          style:
                          const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── STATUS LEGEND ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _legendChip(Colors.orange, Icons.hourglass_top_rounded,
                      "Pending"),
                  _legendChip(Colors.green, Icons.check_circle_rounded,
                      "Accepted"),
                  _legendChip(
                      Colors.red, Icons.cancel_rounded, "Rejected"),
                ],
              ),
            ),
          ),
          // ──────────────────────────────────────────────────────────

          /// BODY
          SliverToBoxAdapter(
            child: loading
                ? const SizedBox(
              height: 400,
              child: Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF4ECDC4)),
              ),
            )
                : events.isEmpty
                ? SizedBox(
              height: 400,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A1F3A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.event_busy,
                        size: 60,
                        color: Color(0xFF4ECDC4)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "No Events Yet",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Tap the + button to create your first event!",
                    style: TextStyle(color: Colors.white60),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : Column(
              children: [
                ...events.map((e) => eventCard(e)).toList(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),

      /// FAB — Add Event
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4ECDC4).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Add_events()),
            );
            fetchEvents();
          },
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            "Add Event",
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _legendChip(Color color, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}