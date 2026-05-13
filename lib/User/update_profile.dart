import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class UpdateProfile extends StatelessWidget {
  const UpdateProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return const UpdateProfilePage(title: 'Edit Profile');
  }
}

class UpdateProfilePage extends StatefulWidget {
  const UpdateProfilePage({super.key, required this.title});
  final String title;

  @override
  State<UpdateProfilePage> createState() => _UpdateProfilePageState();
}

class _UpdateProfilePageState extends State<UpdateProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final nameController  = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final dobController   = TextEditingController();

  // FIX 1: gender is now a dropdown, not a text controller
  String? _selectedGender;
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

  File? _selectedImage;
  String imageUrl = '';

  bool isLoading = true;
  bool isSaving  = false;

  @override
  void initState() {
    super.initState();
    _getData();
  }

  Future<void> _getData() async {
    try {
      SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl    = sh.getString('url') ?? '';
      // FIX 2: derive imgBaseUrl same way as view_profile
      String imgBaseUrl = baseUrl.replaceAll("/myapp", "");
      String lid        = sh.getString('lid') ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/viewprofile/'),
        body: {'lid': lid},
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['status'] == 'ok') {
          setState(() {
            // FIX 3: use correct capitalised field keys matching Django model
            nameController.text  = data['Name']    ?? data['name']   ?? '';
            emailController.text = data['Email']   ?? data['email']  ?? '';
            phoneController.text = data['Phoneno'] ?? data['phone']  ?? '';
            dobController.text   = data['DOB']     ?? data['dob']    ?? '';

            // FIX 4: prefill gender dropdown
            String g = data['Gender'] ?? data['gender'] ?? '';
            if (_genderOptions.contains(g)) {
              _selectedGender = g;
            }

            // FIX 5: build image URL correctly
            String photo = data['Photo'] ??
                data['photo'] ??
                data['Image'] ??
                data['image'] ?? '';
            if (photo.isNotEmpty) {
              imageUrl = photo.startsWith('http')
                  ? photo
                  : '$imgBaseUrl$photo';
            }

            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("UpdateProfile _getData error: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickDOB() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4ECDC4),
              onPrimary: Color(0xFF0A0E27),
              surface: Color(0xFF1A1F3A),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1A1F3A),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      dobController.text =
      "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  Future<void> _pickImage() async {
    if (await Permission.photos.request().isGranted) {
      final picked =
      await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() => _selectedImage = File(picked.path));
      }
    }
  }

  Future<void> _sendData() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGender == null) {
      Fluttertoast.showToast(msg: "Please select your gender");
      return;
    }

    setState(() => isSaving = true);

    try {
      SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid     = sh.getString('lid') ?? '';

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/updateprofile/'),
      );

      request.fields.addAll({
        'lid':    lid,
        'Name':   nameController.text.trim(),
        'Email':  emailController.text.trim(),
        'Phoneno': phoneController.text.trim(),
        'DOB':    dobController.text.trim(),
        'Gender': _selectedGender!,
      });

      if (_selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('Image', _selectedImage!.path),
        );
      }

      var response = await request.send();
      var respStr  = await response.stream.bytesToString();
      var data     = jsonDecode(respStr);

      setState(() => isSaving = false);

      if (data['status'] == 'ok') {
        Fluttertoast.showToast(msg: "Profile updated successfully!");
        Navigator.pop(context, true);
      } else {
        Fluttertoast.showToast(msg: "Update failed: ${data['msg'] ?? ''}");
      }
    } catch (e) {
      setState(() => isSaving = false);
      Fluttertoast.showToast(msg: "Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: CustomScrollView(
        slivers: [
          // ── Gradient App Bar ────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0A0E27),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24, bottom: 60),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '✏️ EDIT PROFILE',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Update Your\nInformation',
                          style: TextStyle(
                            fontSize: 32,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Content ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: isLoading
                ? SizedBox(
              height: MediaQuery.of(context).size.height - 200,
              child: const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF4ECDC4)),
              ),
            )
                : Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Profile Picture ──────────────────────
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F3A),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4ECDC4)
                                            .withOpacity(0.3),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Colors.grey[800],
                                    backgroundImage:
                                    _selectedImage != null
                                        ? FileImage(_selectedImage!)
                                        : (imageUrl.isNotEmpty
                                        ? NetworkImage(imageUrl)
                                        : null)
                                    as ImageProvider?,
                                    child: (_selectedImage == null &&
                                        imageUrl.isEmpty)
                                        ? Icon(Icons.person_rounded,
                                        size: 60,
                                        color: Colors.grey[400])
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _pickImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF4ECDC4),
                                            Color(0xFF44A08D)
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF1A1F3A),
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF4ECDC4)
                                                .withOpacity(0.4),
                                            blurRadius: 12,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tap camera to change photo',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    const Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Form Fields ──────────────────────────
                    _buildField(
                      controller: nameController,
                      label: "Full Name",
                      icon: Icons.person_rounded,
                      gradient: [
                        const Color(0xFFFF6B6B),
                        const Color(0xFFFF8E53)
                      ],
                    ),

                    _buildField(
                      controller: emailController,
                      label: "Email Address",
                      icon: Icons.email_rounded,
                      gradient: [
                        const Color(0xFFE74C3C),
                        const Color(0xFFC0392B)
                      ],
                      keyboard: TextInputType.emailAddress,
                    ),

                    _buildField(
                      controller: phoneController,
                      label: "Phone Number",
                      icon: Icons.phone_rounded,
                      gradient: [
                        const Color(0xFF6BCF7F),
                        const Color(0xFF44A08D)
                      ],
                      keyboard: TextInputType.phone,
                    ),

                    _buildField(
                      controller: dobController,
                      label: "Date of Birth",
                      icon: Icons.cake_rounded,
                      gradient: [
                        const Color(0xFFFFD93D),
                        const Color(0xFFFF6B6B)
                      ],
                      readOnly: true,
                      onTap: _pickDOB,
                    ),

                    // FIX: Gender Dropdown instead of text field
                    _buildGenderDropdown(),

                    const SizedBox(height: 32),

                    // ── Save Button ──────────────────────────
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF4ECDC4),
                            Color(0xFF44A08D),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                            const Color(0xFF4ECDC4).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: isSaving ? null : _sendData,
                          child: Center(
                            child: isSaving
                                ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                                : const Row(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: 24),
                                SizedBox(width: 12),
                                Text(
                                  "Save Changes",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Gender Dropdown ────────────────────────────────────────────────────────
  Widget _buildGenderDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedGender,
        dropdownColor: const Color(0xFF1A1F3A),
        style: const TextStyle(
            fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: "Gender",
          labelStyle: TextStyle(
              color: Colors.white.withOpacity(0.6), fontSize: 14),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9B59B6), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9B59B6).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.wc_rounded,
                color: Colors.white, size: 20),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
                color: Color(0xFF9B59B6), width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFF1A1F3A),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 18),
        ),
        items: _genderOptions.map((g) {
          return DropdownMenuItem(
            value: g,
            child: Text(g,
                style: const TextStyle(color: Colors.white)),
          );
        }).toList(),
        onChanged: (val) => setState(() => _selectedGender = val),
        validator: (v) => v == null ? "Please select gender" : null,
      ),
    );
  }
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required List<Color> gradient,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboard,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(16),
        border:
        Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboard,
        validator: (v) =>
        v!.isEmpty ? "$label is required" : null,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          suffixIcon: readOnly
              ? Icon(Icons.arrow_drop_down_rounded,
              color: Colors.white.withOpacity(0.6))
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
            BorderSide(color: gradient[0], width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
                color: Color(0xFFE74C3C), width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
                color: Color(0xFFE74C3C), width: 2),
          ),
          errorStyle:
          const TextStyle(color: Color(0xFFE74C3C)),
          filled: true,
          fillColor: const Color(0xFF1A1F3A),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 18),
        ),
      ),
    );
  }
}