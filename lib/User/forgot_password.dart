import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {

  TextEditingController usernameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController answerController = TextEditingController();
  TextEditingController newPasswordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  String securityQuestion = "";

  bool questionLoaded = false;
  bool verified = false;

  bool obscureNewPassword = true;
  bool obscureConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),

              child: Column(
                children: [

                  const SizedBox(height: 20),

                  const Text(
                    "Forgot Password",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: Column(
                      children: [

                        // USERNAME
                        TextField(
                          controller: usernameController,
                          decoration: const InputDecoration(
                            labelText: "Username",
                          ),
                        ),

                        const SizedBox(height: 15),

                        // EMAIL
                        TextField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: "Email",
                          ),
                        ),

                        const SizedBox(height: 20),

                        // GET QUESTION
                        ElevatedButton(
                          onPressed: () async {

                            final url = Uri.parse("http://192.168.1.4:8000/myapp/get_question/");

                            final response = await http.post(url, body: {
                              "username": usernameController.text,
                              "email": emailController.text,
                            });

                            var data = jsonDecode(response.body);

                            if (data['status'] == 'no_user') {
                              Fluttertoast.showToast(msg: "User not found");
                              return;
                            }

                            setState(() {
                              securityQuestion = data['question'];
                              questionLoaded = true;
                            });

                          },
                          child: const Text("Next"),
                        ),

                        const SizedBox(height: 20),

                        if (questionLoaded) ...[

                          Text(
                            securityQuestion,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),

                          const SizedBox(height: 10),

                          TextField(
                            controller: answerController,
                            decoration: const InputDecoration(
                              labelText: "Your Answer",
                            ),
                          ),

                          const SizedBox(height: 15),

                          ElevatedButton(
                            onPressed: () async {

                              final url = Uri.parse("http://192.168.1.4:8000/myapp/verify_answer/");

                              final response = await http.post(url, body: {
                                "username": usernameController.text,
                                "email": emailController.text,
                                "answer": answerController.text,
                              });

                              var data = jsonDecode(response.body);

                              if (data['status'] == 'ok') {
                                setState(() {
                                  verified = true;
                                });

                                Fluttertoast.showToast(
                                  msg: "Verified",
                                  backgroundColor: Colors.green,
                                );
                              } else {
                                Fluttertoast.showToast(
                                  msg: "Incorrect Answer",
                                  backgroundColor: Colors.red,
                                );
                              }

                            },
                            child: const Text("Verify"),
                          ),
                        ],

                        const SizedBox(height: 20),

                        if (verified) ...[

                          TextField(
                            controller: newPasswordController,
                            obscureText: obscureNewPassword,
                            decoration: const InputDecoration(
                              labelText: "New Password",
                            ),
                          ),

                          const SizedBox(height: 15),

                          TextField(
                            controller: confirmPasswordController,
                            obscureText: obscureConfirmPassword,
                            decoration: const InputDecoration(
                              labelText: "Confirm Password",
                            ),
                          ),

                          const SizedBox(height: 20),

                          ElevatedButton(
                            onPressed: () async {

                              final url = Uri.parse("http://192.168.1.4:8000/myapp/reset_password/");

                              final response = await http.post(url, body: {
                                "username": emailController.text,
                                "password": newPasswordController.text,
                              });

                              var data = jsonDecode(response.body);

                              if (data['status'] == 'ok') {
                                Fluttertoast.showToast(msg: "Password Reset Successful");
                                Navigator.pop(context);
                              }

                            },
                            child: const Text("Reset Password"),
                          ),
                        ]

                      ],
                    ),
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}