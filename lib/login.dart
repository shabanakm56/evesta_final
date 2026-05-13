import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'User/homepage.dart';
import 'User/registration.dart';
import 'User/forgot_password.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  TextEditingController uname = TextEditingController();
  TextEditingController password = TextEditingController();

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFc0446e),
              Color(0xFF8B3D5A),
              Color(0xFF4A3B58),
              Color(0xFF1E3A52),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),

        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24, 24, 24,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),

                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    // ══ EVESTA LOGO + NAME ══
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        AnimatedBuilder(
                          animation: _glowAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D1228),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color.fromRGBO(78, 205, 196, _glowAnimation.value),
                                    blurRadius: 20,
                                    spreadRadius: 3,
                                  ),
                                  BoxShadow(
                                    color: Color.fromRGBO(78, 205, 196, _glowAnimation.value * 0.4),
                                    blurRadius: 40,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                              child: CustomPaint(
                                painter: _EvestaLogoPainter(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(width: 14),

                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFFFFCC00),
                              Color(0xFFFF6B6B),
                              Color(0xFF4ECDC4),
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'EVESTA',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 7,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    const Text(
                      "Welcome Back",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      "Login to continue",
                      style: TextStyle(color: Colors.white70),
                    ),

                    const SizedBox(height: 40),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),

                      child: Column(
                        children: [

                          TextField(
                            controller: uname,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.person, color: Color(0xFFFF6B9D)),
                              hintText: "Username",
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),

                          const SizedBox(height: 15),

                          TextField(
                            controller: password,
                            obscureText: true,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock, color: Color(0xFFFF6B9D)),
                              hintText: "Password",
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),

                          const SizedBox(height: 25),

                          Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B9D), Color(0xFFC06C84)],
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                              ),
                              onPressed: () async {
                                String uname_ = uname.text;
                                String password_ = password.text;

                                if (uname_.isEmpty || password_.isEmpty) {
                                  Fluttertoast.showToast(
                                    msg: 'Please fill all fields',
                                    backgroundColor: Colors.orange,
                                  );
                                  return;
                                }

                                SharedPreferences sh = await SharedPreferences.getInstance();
                                String url = sh.getString('url')!;
                                final urls = Uri.parse('$url/login_post/');

                                try {
                                  final response = await http.post(urls, body: {
                                    "username": uname_,
                                    "pass": password_,
                                  });

                                  if (response.statusCode == 200) {
                                    var data = jsonDecode(response.body);

                                    if (data['status'] == 'ok') {
                                      String lid = data['lid'].toString();
                                      sh.setString("lid", lid);

                                      Fluttertoast.showToast(
                                        msg: 'Login Successful!',
                                        backgroundColor: Colors.green,
                                      );

                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const HomePage(),
                                        ),
                                      );
                                    } else if (data['status'] == 'blocked') {
                                      // show blocked dialog — cannot dismiss
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (_) => AlertDialog(
                                          backgroundColor: const Color(0xFF1A1F3A),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20)),
                                          icon: const Icon(
                                            Icons.gpp_bad_rounded,
                                            color: Color(0xFFFF6B6B),
                                            size: 48,
                                          ),
                                          title: const Text(
                                            "Account Suspended",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                            ),
                                          ),
                                          content: Text(
                                            data['msg'] ?? 'Your account has been suspended by the administrator.\n\nPlease contact support.',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 14,
                                              height: 1.6,
                                            ),
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
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text(
                                                  "OK, Understood",
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.bold, fontSize: 15),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    } else {
                                      Fluttertoast.showToast(
                                        msg: 'Invalid Credentials',
                                        backgroundColor: Colors.red,
                                      );
                                    }
                                  } else {
                                    Fluttertoast.showToast(
                                      msg: 'Server Error',
                                      backgroundColor: Colors.red,
                                    );
                                  }
                                } catch (e) {
                                  Fluttertoast.showToast(
                                    msg: 'Network Error',
                                    backgroundColor: Colors.red,
                                  );
                                }
                              },
                              child: const Text(
                                "Login",
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),

                          const SizedBox(height: 15),

                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ForgotPasswordPage(),
                                ),
                              );
                            },
                            child: const Text(
                              "Forgot Password?",
                              style: TextStyle(color: Color(0xFFFF6B9D)),
                            ),
                          ),

                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const Signuppage(),
                                ),
                              );
                            },
                            child: const Text(
                              "Don't have an account? Register",
                              style: TextStyle(color: Color(0xFFFF6B9D)),
                            ),
                          ),

                        ],
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EvestaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 - 6;

    canvas.drawCircle(
      Offset(cx, cy), 18,
      Paint()
        ..color = const Color(0xFF1A2A5E).withOpacity(0.6)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy), 18,
      Paint()
        ..color = const Color(0xFF4ECDC4).withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final pinPath = Path();
    pinPath.moveTo(cx, cy - 13);
    pinPath.cubicTo(cx + 9, cy - 13, cx + 9, cy - 2, cx, cy + 10);
    pinPath.cubicTo(cx - 9, cy - 2, cx - 9, cy - 13, cx, cy - 13);
    canvas.drawPath(
      pinPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(
      Offset(cx, cy - 4), 5,
      Paint()
        ..color = const Color(0xFF4ECDC4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.drawCircle(
      Offset(cx, cy - 4), 2.2,
      Paint()
        ..color = const Color(0xFF4ECDC4)
        ..style = PaintingStyle.fill,
    );

    void drawPlus(Offset o, double r, Color color) {
      final p = Paint()
        ..color = color
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(o.dx - r, o.dy), Offset(o.dx + r, o.dy), p);
      canvas.drawLine(Offset(o.dx, o.dy - r), Offset(o.dx, o.dy + r), p);
    }

    drawPlus(Offset(cx - 12, cy - 20), 2.5, const Color(0xFFFFCC00).withOpacity(0.8));
    drawPlus(Offset(cx + 14, cy - 18), 2.0, const Color(0xFF4ECDC4).withOpacity(0.7));
    drawPlus(Offset(cx + 16, cy + 4),  1.8, const Color(0xFFFFCC00).withOpacity(0.5));

    final bottomY = size.height - 10.0;
    _drawPerson(canvas, Offset(cx - 10, bottomY), const Color(0xFF3A7D8C));
    _drawPerson(canvas, Offset(cx + 10, bottomY), const Color(0xFF3A7D8C));
    _drawPerson(canvas, Offset(cx, bottomY - 2), const Color(0xFFFFCC00), scale: 1.2);
  }

  void _drawPerson(Canvas canvas, Offset pos, Color color, {double scale = 1.0}) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(pos.dx, pos.dy - 7 * scale), 3.5 * scale, paint);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(pos.dx, pos.dy - 1 * scale),
        width: 7 * scale,
        height: 5 * scale,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_EvestaLogoPainter old) => false;
}