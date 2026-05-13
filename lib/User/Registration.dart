import 'dart:convert';
import 'dart:io';
import 'package:evesta_app/login.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class Signuppage extends StatefulWidget {
  const Signuppage({super.key});

  @override
  State<Signuppage> createState() => _SignuppageState();
}

class _SignuppageState extends State<Signuppage> {

  TextEditingController nameC = TextEditingController();
  TextEditingController DobC = TextEditingController();
  TextEditingController emailC = TextEditingController();
  TextEditingController phoneC = TextEditingController();
  TextEditingController UsernnameC = TextEditingController();
  TextEditingController passwordC = TextEditingController();
  TextEditingController confirmPasswordC = TextEditingController();
  TextEditingController questionC = TextEditingController();
  TextEditingController answerC = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  String? emailError;
  String? phoneError;
  String? passwordError;
  String? genderError;

  String? _selectedGender;
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

  XFile? _image;

  // ── Location variables ──────────────────────────────────────────────────────
  double? _latitude;
  double? _longitude;
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _imgFromGallery() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img != null) setState(() => _image = img);
  }

  Future<void> _imgFromCamera() async {
    final img = await ImagePicker().pickImage(source: ImageSource.camera);
    if (img != null) setState(() => _image = img);
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Wrap(children: [
        ListTile(
          leading: Icon(Icons.camera_alt),
          title: Text("Camera"),
          onTap: () { _imgFromCamera(); Navigator.pop(context); },
        ),
        ListTile(
          leading: Icon(Icons.photo),
          title: Text("Gallery"),
          onTap: () { _imgFromGallery(); Navigator.pop(context); },
        ),
      ]),
    );
  }

  void validate() {
    setState(() {
      emailError = emailC.text.endsWith("@gmail.com")
          ? null
          : "Email must end with @gmail.com";

      phoneError = phoneC.text.length == 10
          ? null
          : "Phone must be 10 digits";

      passwordError = passwordC.text == confirmPasswordC.text
          ? null
          : "Passwords do not match";

      genderError = _selectedGender != null
          ? null
          : "Please select your gender";
    });
  }

  void _showDialog({
    required bool success,
    required String title,
    required String message,
    VoidCallback? onOk,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: success
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.check_circle_rounded : Icons.error_rounded,
                color: success ? Colors.green : Colors.red,
                size: 45,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: success ? Colors.green : Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: success ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  if (onOk != null) onOk();
                },
                child: const Text("OK", style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Location permission + fetch ─────────────────────────────────────────────
  Future<bool> _requestLocationAndFetch() async {
    // Show a friendly explanation dialog before triggering OS permission prompt
    bool userAgreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B9D).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on,
                color: Color(0xFFFF6B9D),
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Allow Location Access",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "Evesta uses your location to recommend events happening near you. You can skip this if you prefer.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFF6B9D)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    "Skip",
                    style: TextStyle(color: Color(0xFFFF6B9D)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B9D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Allow"),
                ),
              ),
            ]),
          ],
        ),
      ),
    ) ?? false;

    // User chose to skip — proceed with registration without location
    if (!userAgreed) return true;

    final status = await Permission.locationWhenInUse.request();

    if (status.isGranted) {
      try {
        Position pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
        });
      } catch (e) {
        // Could not fetch coordinates — proceed without them
      }
      return true;
    } else if (status.isPermanentlyDenied) {
      _showDialog(
        success: false,
        title: "Location Denied",
        message:
        "Please enable location access in app settings to get personalised event recommendations.",
        onOk: () => openAppSettings(),
      );
      return false;
    }

    // Denied (not permanently) — proceed without location
    return true;
  }
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFF6B9D),
              Color(0xFFC06C84),
              Color(0xFF6C5B7B),
              Color(0xFF355C7D),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [

                const SizedBox(height: 20),

                const Text("Join Evesta",
                    style: TextStyle(
                        fontSize: 26,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),

                const SizedBox(height: 25),

                GestureDetector(
                  onTap: _showPicker,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.white,
                        child: _image != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(55),
                          child: Image.file(File(_image!.path),
                              fit: BoxFit.cover,
                              width: 110,
                              height: 110),
                        )
                            : const Icon(Icons.person, size: 50),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6B9D),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Column(
                    children: [

                      _field(nameC, "Full Name"),
                      _dobField(),
                      _field(emailC, "Email", error: emailError),
                      _phoneField(),
                      _genderDropdown(),
                      _field(UsernnameC, "Username"),

                      _passwordField(passwordC, "Password",
                          _obscurePassword, () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          }),

                      _passwordField(confirmPasswordC, "Confirm Password",
                          _obscureConfirm, () {
                            setState(() => _obscureConfirm = !_obscureConfirm);
                          }, error: passwordError),

                      _field(questionC, "Security Question"),
                      _field(answerC, "Security Answer"),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B9D),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: _isLoading ? null : () async {

                            validate();

                            if (emailError != null ||
                                phoneError != null ||
                                passwordError != null ||
                                genderError != null) {
                              return;
                            }

                            if (_image == null) {
                              _showDialog(
                                success: false,
                                title: "No Photo",
                                message: "Please select a profile photo to continue.",
                              );
                              return;
                            }

                            // ── Request location before proceeding ──────────
                            bool canProceed = await _requestLocationAndFetch();
                            if (!canProceed) return;
                            // ────────────────────────────────────────────────

                            setState(() => _isLoading = true);

                            try {
                              final sh = await SharedPreferences.getInstance();
                              String url = sh.getString("url").toString();

                              var req = http.MultipartRequest(
                                  'POST', Uri.parse('$url/user_register/'));

                              req.files.add(await http.MultipartFile.fromPath(
                                  'Photo', _image!.path));

                              req.fields['Name']     = nameC.text;
                              req.fields['DOB']      = DobC.text;
                              req.fields['Email']    = emailC.text;
                              req.fields['Phoneno']  = phoneC.text;
                              req.fields['Gender']   = _selectedGender!;
                              req.fields['username'] = UsernnameC.text;
                              req.fields['password'] = passwordC.text;
                              req.fields['question'] = questionC.text;
                              req.fields['answer']   = answerC.text;

                              // ── Send location if available ───────────────
                              if (_latitude != null && _longitude != null) {
                                req.fields['latitude']  = _latitude.toString();
                                req.fields['longitude'] = _longitude.toString();
                              }
                              // ────────────────────────────────────────────

                              var res = await req.send();
                              String responseBody =
                              await res.stream.bytesToString();
                              print("REGISTER RESPONSE: $responseBody");

                              setState(() => _isLoading = false);

                              if (res.statusCode == 200) {
                                var data = jsonDecode(responseBody);

                                if (data['status'] == 'ok') {
                                  _showDialog(
                                    success: true,
                                    title: "Registration Successful!",
                                    message:
                                    "Your account has been created.\nPlease login to continue.",
                                    onOk: () => Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const LoginPage()),
                                    ),
                                  );
                                } else if (data['status'] == 'exists') {
                                  _showDialog(
                                    success: false,
                                    title: "Username Taken",
                                    message:
                                    "This username already exists.\nPlease choose a different one.",
                                  );
                                } else {
                                  _showDialog(
                                    success: false,
                                    title: "Registration Failed",
                                    message:
                                    "Something went wrong. Please try again.",
                                  );
                                }
                              } else {
                                _showDialog(
                                  success: false,
                                  title: "Server Error",
                                  message:
                                  "Could not connect to server (${res.statusCode}).\nPlease try again.",
                                );
                              }
                            } catch (e) {
                              setState(() => _isLoading = false);
                              _showDialog(
                                success: false,
                                title: "Network Error",
                                message: "Please check your connection and try again.",
                              );
                            }
                          },
                          child: _isLoading
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : const Text("Register",
                              style: TextStyle(fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _genderDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: _selectedGender,
        decoration: InputDecoration(
          hintText: "Select Gender",
          errorText: genderError,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.person_outline),
        ),
        items: _genderOptions.map((g) {
          return DropdownMenuItem(value: g, child: Text(g));
        }).toList(),
        onChanged: (val) => setState(() {
          _selectedGender = val;
          genderError = null;
        }),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, {String? error}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          hintText: hint,
          errorText: error,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _phoneField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: phoneC,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          prefixText: "+91 ",
          hintText: "Phone",
          errorText: phoneError,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _passwordField(TextEditingController c, String hint, bool obscure,
      VoidCallback toggle, {String? error}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: c,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          errorText: error,
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
            onPressed: toggle,
          ),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dobField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: DobC,
        readOnly: true,
        onTap: () async {
          DateTime now = DateTime.now();
          DateTime lastDate = DateTime(now.year - 16);

          DateTime? picked = await showDatePicker(
            context: context,
            initialDate: lastDate,
            firstDate: DateTime(1900),
            lastDate: lastDate,
          );

          if (picked != null) {
            DobC.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
          }
        },
        decoration: const InputDecoration(
          hintText: "Date of Birth",
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.calendar_today),
        ),
      ),
    );
  }
}