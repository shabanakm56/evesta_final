import 'dart:convert';
import 'dart:io';

import 'package:evesta_app/User/view_events.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class Add_events extends StatefulWidget {
  const Add_events({super.key});

  @override
  State<Add_events> createState() => _Add_eventsState();
}

class _Add_eventsState extends State<Add_events> {
  final TextEditingController eventNameC = TextEditingController();
  final TextEditingController locationC  = TextEditingController();
  final TextEditingController detailsC   = TextEditingController();
  final TextEditingController dateC      = TextEditingController();
  final TextEditingController timeC      = TextEditingController();
  final TextEditingController linkC      = TextEditingController();
  final TextEditingController typeC      = TextEditingController();

  File? _image;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  // Map variables
  LatLng _selectedLocation = const LatLng(11.2588, 75.7804);
  Marker? _marker;
  String _latitude  = '';
  String _longitude = '';
  final MapController _mapController = MapController();

  // ── SEARCH variables ──────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searchLoading = false;
  // ──────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // ── GET CURRENT LOCATION ──────────────────────────────────────────────────
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) { _setMarker(_selectedLocation); return; }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _setMarker(_selectedLocation);
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _setMarker(LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      _setMarker(_selectedLocation);
    }
  }

  // ── SET MARKER ────────────────────────────────────────────────────────────
  void _setMarker(LatLng point) {
    setState(() {
      _selectedLocation = point;
      _latitude         = point.latitude.toString();
      _longitude        = point.longitude.toString();
      _marker           = Marker(
        point:  point,
        width:  40,
        height: 40,
        child:  const Icon(Icons.location_pin,
            color: Color(0xFFFF5722), size: 40),
      );
    });
    // animate map to new location
    Future.delayed(const Duration(milliseconds: 100), () {
      _mapController.move(point, 15);
    });
  }

  // ── LOCATION SEARCH (Nominatim / OpenStreetMap) ───────────────────────────
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _searchLoading = true);

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
            '?q=${Uri.encodeComponent(query)}'
            '&format=json&limit=5',
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'EvestaApp/1.0',
      });

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _searchResults = data
              .map((e) => {
            'name': e['display_name'],
            'lat':  double.parse(e['lat']),
            'lon':  double.parse(e['lon']),
          })
              .toList();
        });
      }
    } catch (e) {
      print("Location search error: $e");
    } finally {
      setState(() => _searchLoading = false);
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final point = LatLng(result['lat'], result['lon']);
    _setMarker(point);

    // fill location field with selected place name
    final shortName = result['name'].toString().split(',').take(3).join(',');
    locationC.text = shortName;

    setState(() {
      _searchResults  = [];
      _searchController.text = shortName;
    });
  }
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> pickImage() async {
    final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF4ECDC4),
            onPrimary: Colors.white,
            surface: Color(0xFF1A1F3A),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      dateC.text =
      "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  Future<void> pickTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF4ECDC4),
            onPrimary: Colors.white,
            surface: Color(0xFF1A1F3A),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      timeC.text =
      "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: CustomScrollView(
        slivers: [
          /// ── GRADIENT APP BAR ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
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
                    'https://images.pexels.com/photos/1190298/pexels-photo-1190298.jpeg',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF6B6B).withOpacity(0.8),
                          const Color(0xFF4ECDC4).withOpacity(0.85),
                          const Color(0xFF0A0E27).withOpacity(0.95),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 40,
                    left: 24,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 10),
                        Text(
                          'New Event',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// ── FORM BODY ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// IMAGE PICKER
                  _sectionTitle("Event Image"),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: pickImage,
                    child: Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: _image == null
                            ? LinearGradient(colors: [
                          const Color(0xFFFF6B6B).withOpacity(0.3),
                          const Color(0xFF4ECDC4).withOpacity(0.3),
                        ])
                            : null,
                        color: _image != null
                            ? null
                            : const Color(0xFF1A1F3A),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: _image == null
                          ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                                Icons.add_photo_alternate,
                                size: 50,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          const Text("Upload Event Image",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          const Text("Tap to select from gallery",
                              style:
                              TextStyle(color: Colors.white60)),
                        ],
                      )
                          : Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.file(_image!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius:
                                BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.edit,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  /// BASIC INFO
                  _sectionTitle("Basic Information"),
                  const SizedBox(height: 12),
                  _buildField(eventNameC, "Event Name", Icons.event,
                      const Color(0xFFFF6B6B)),
                  _buildField(typeC, "Event Type", Icons.category,
                      const Color(0xFF4ECDC4)),
                  _buildField(locationC, "Location", Icons.location_on,
                      const Color(0xFFFFD93D)),

                  const SizedBox(height: 24),

                  /// SCHEDULE
                  _sectionTitle("Schedule"),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: pickDate,
                          child: AbsorbPointer(
                            child: _buildField(dateC, "Date",
                                Icons.calendar_today,
                                const Color(0xFF9B59B6)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: pickTime,
                          child: AbsorbPointer(
                            child: _buildField(timeC, "Time",
                                Icons.access_time,
                                const Color(0xFF3498DB)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  /// DETAILS
                  _sectionTitle("Additional Details"),
                  const SizedBox(height: 12),
                  _buildField(detailsC, "Event Details",
                      Icons.description, const Color(0xFF1ABC9C),
                      maxLines: 4),
                  _buildField(linkC, "Event Link (Optional)", Icons.link,
                      const Color(0xFFE67E22)),

                  const SizedBox(height: 24),

                  /// MAP SECTION with SEARCH
                  _sectionTitle("Event Location on Map"),
                  const SizedBox(height: 12),

                  // ── SEARCH BOX ─────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F3A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFF4ECDC4).withOpacity(0.4)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Search location...",
                        hintStyle:
                        const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search,
                            color: Color(0xFF4ECDC4)),
                        suffixIcon: _searchLoading
                            ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF4ECDC4),
                            ),
                          ),
                        )
                            : _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white38, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(
                                    () => _searchResults = []);
                          },
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 14),
                      ),
                      onChanged: (val) => _searchLocation(val),
                    ),
                  ),
                  // ── SEARCH RESULTS DROPDOWN ────────────────────────────
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1F3A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1, color: Colors.white10),
                        itemBuilder: (_, i) {
                          final r = _searchResults[i];
                          return ListTile(
                            leading: const Icon(Icons.location_on,
                                color: Color(0xFF4ECDC4), size: 20),
                            title: Text(
                              r['name'].toString().split(',').first,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              r['name']
                                  .toString()
                                  .split(',')
                                  .skip(1)
                                  .take(2)
                                  .join(','),
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectSearchResult(r),
                          );
                        },
                      ),
                    ),
                  // ──────────────────────────────────────────────────────

                  const SizedBox(height: 12),

                  // MAP
                  Container(
                    height: 280,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                        const Color(0xFF4ECDC4).withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                          const Color(0xFF4ECDC4).withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _selectedLocation,
                          initialZoom: 15,
                          onTap: (_, point) => _setMarker(point),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                            "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                            userAgentPackageName:
                            'com.example.evesta_app',
                          ),
                          if (_marker != null)
                            MarkerLayer(markers: [_marker!]),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Map instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F3A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4ECDC4)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.info_outline,
                              color: Color(0xFF4ECDC4), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Search a location above or tap anywhere on the map to pin the event location.',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Coordinates display
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F3A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.my_location,
                            color: Color(0xFFFF5722), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Lat: ${_latitude.isNotEmpty ? double.parse(_latitude).toStringAsFixed(4) : "0.0000"}, '
                              'Long: ${_longitude.isNotEmpty ? double.parse(_longitude).toStringAsFixed(4) : "0.0000"}',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  /// SUBMIT BUTTON
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color:
                          const Color(0xFF4ECDC4).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : addEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                          color: Colors.white)
                          : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline,
                              color: Colors.white),
                          SizedBox(width: 12),
                          Text(
                            "Create Event",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
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

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
  );

  Widget _buildField(
      TextEditingController controller,
      String label,
      IconData icon,
      Color accentColor, {
        int maxLines = 1,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle:
            TextStyle(color: accentColor.withOpacity(0.8)),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
          ),
        ),
      ),
    );
  }

  Future<void> addEvent() async {
    if (_image == null ||
        eventNameC.text.isEmpty ||
        locationC.text.isEmpty ||
        dateC.text.isEmpty ||
        timeC.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                  child: Text(
                      "Fill all required fields & upload image")),
            ],
          ),
          backgroundColor: const Color(0xFFE74C3C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final sh  = await SharedPreferences.getInstance();
      String url = sh.getString("url") ?? "";
      String lid = sh.getString("lid") ?? "";

      var request =
      http.MultipartRequest('POST', Uri.parse('$url/Add_event/'));

      request.fields.addAll({
        'lid':       lid,
        'EventName': eventNameC.text,
        'Location':  locationC.text,
        'Details':   detailsC.text,
        'Date':      dateC.text,
        'Time':      timeC.text,
        'Link':      linkC.text,
        'Type':      typeC.text,
        'Latitude':  _latitude,
        'Longitude': _longitude,
      });

      request.files.add(
          await http.MultipartFile.fromPath('Image', _image!.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text("Event Created Successfully!"),
              ],
            ),
            backgroundColor: const Color(0xFF4ECDC4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const view_eventpage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text("Error: $e")),
            ],
          ),
          backgroundColor: const Color(0xFFE74C3C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}