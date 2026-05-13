import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetailPage extends StatelessWidget {
  final String name;
  final String date;
  final String time;
  final String location;
  final String type;
  final String details;
  final String link;
  final String imageUrl;

  const EventDetailPage({
    super.key,
    required this.name,
    required this.date,
    required this.time,
    required this.location,
    required this.type,
    required this.details,
    required this.link,
    required this.imageUrl,
  });

  // ✅ FIXED: robust URL launcher that handles edge cases
  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;

    // ✅ Ensure scheme is present
    String finalUrl = url.trim();
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    final uri = Uri.parse(finalUrl);

    try {
      // ✅ Try externalApplication first
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      // ✅ Fallback to in-app browser if external fails
      if (!launched) {
        await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
        );
      }
    } catch (e) {
      // ✅ Last resort fallback
      try {
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      } catch (_) {
        debugPrint('Could not launch $finalUrl');
      }
    }
  }

  Future<void> _openMap(String locationName) async {
    final query = Uri.encodeComponent(locationName);
    final googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$query';
    await _launchUrl(googleMapsUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: CustomScrollView(
        slivers: [

          // ── HERO IMAGE APP BAR ──
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: const Color(0xFF0A0E27),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(
                    imageUrl,
                    fit: BoxFit.fitWidth,
                    errorBuilder: (_, __, ___) => _gradientPlaceholder(),
                  )
                      : _gradientPlaceholder(),

                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Color(0xFF0A0E27),
                        ],
                        stops: [0.0, 0.5, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (type.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              type.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 10),
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

          // ── CONTENT ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── QUICK INFO ROW ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F3A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _quickInfo(Icons.calendar_today_rounded,
                            date, 'Date', const Color(0xFFFF6B6B)),
                        _divider(),
                        _quickInfo(
                            Icons.access_time_rounded,
                            time.length > 5 ? time.substring(0, 5) : time,
                            'Time',
                            const Color(0xFF4ECDC4)),
                        _divider(),
                        _quickInfo(Icons.location_on_rounded,
                            location, 'Venue', const Color(0xFFFFD93D)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── ABOUT SECTION ──
                  if (details.isNotEmpty) ...[
                    _sectionTitle('About This Event'),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1F3A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Text(
                        details,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── LINK PREVIEW ──
                  // ✅ Shows the actual URL so user can see what will open


                  // ── ACTION BUTTONS ──
                  _sectionTitle('Actions'),
                  const SizedBox(height: 12),

                  _actionButton(
                    icon: Icons.map_rounded,
                    label: 'Track Location',
                    subtitle: 'Open in Google Maps',
                    gradient: const [Color(0xFFFFD93D), Color(0xFFFF6B6B)],
                    onTap: () => _openMap(location),
                  ),

                  const SizedBox(height: 12),

                  if (link.isNotEmpty)
                    _actionButton(
                      icon: Icons.open_in_new_rounded,
                      label: 'Visit Website',
                      subtitle: link.trim().length > 35
                          ? '${link.trim().substring(0, 35)}...'
                          : link.trim(),
                      gradient: const [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                      onTap: () => _launchUrl(link),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.event_rounded, size: 80, color: Colors.white54),
    );
  }

  Widget _quickInfo(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(height: 50, width: 1, color: Colors.white12);
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}