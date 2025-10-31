import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:resqmob/pages/authentication/signup.dart';
import '../../Class Models/user.dart';
import '../admin/admin home.dart';
import '../homepage/homepage.dart';

class login extends StatefulWidget {
  const login({super.key});

  @override
  State<login> createState() => _loginState();
}

class _loginState extends State<login> {
  String btn_text = "Log in";
  bool isloading = false;
  bool loading = false;
  bool _obscurePassword = true;

  Position? _currentPosition;

  // Controllers defined outside build to prevent reset on rebuild
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  @override
  void initState() {
    _getCurrentLocation();
    super.initState();
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (defaultTargetPlatform == TargetPlatform.windows) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      if (!mounted) return;
      print('Error getting location: $e');
    }
  }

  Future<bool> signin({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = FirebaseAuth.instance.currentUser;
      print(FirebaseAuth.instance.currentUser);

      final data = await FirebaseFirestore.instance
          .collection("Users")
          .doc(user!.uid)
          .get();

      final userData = data.data();
      if (userData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("User document does not exist.")),
          );
        }
        return false;
      }
      UserModel cuser = UserModel.fromJson(userData);

      await Future.delayed(Duration(seconds: 1));

      // FCM token update
      if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          print(fcmToken);
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .update({
            'fcmToken': fcmToken,
          });
        }
      }

      // Get current location
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
      }
      print(serviceEnabled.toString());
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }
      print(permission.toString());

      if (_currentPosition != null) {
        await FirebaseFirestore.instance
            .collection("Users")
            .doc(user.uid)
            .update({
          'location': {
            'latitude': _currentPosition!.latitude,
            'longitude': _currentPosition!.longitude,
            'timestamp': DateTime.now().toIso8601String(),
          }
        });
      }

      final isadmin = await cuser.admin;
      print(cuser.admin);

      if (mounted) {
        if (isadmin) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => AdminDashboard()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => MyHomePage()),
          );
        }
      }

    } on FirebaseAuthException catch (e) {
      print(e.code.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.code.toString())),
        );
      }
      return false;
    } catch (e) {
      print(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white),
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 80,
                width: 80,
                child: CircularProgressIndicator(
                  color: Color(0xff093125),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 24),
              Text(
                "Logging in...",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color(0xff093125),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white),
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 40),
                  // Logo container
                  Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/rlogo.png'),
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),
                  // Welcome text
                  Text(
                    "Welcome Back",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Sign in to continue",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 40),
                  // Email field
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 700),
                    child: TextField(
                      controller: email,
                      decoration: InputDecoration(
                        labelText: "Username",
                        hintText: "Enter Username",
                        prefixIcon: Icon(Icons.person_outline, color: Colors.black),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.black, width: 2),
                        ),
                        floatingLabelStyle: TextStyle(color: Colors.black),
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Password field
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 700),
                    child: TextField(
                      controller: password,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: "Password",
                        hintText: "Enter Password",
                        prefixIcon: Icon(Icons.lock_outline, color: Colors.black),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.black, width: 2),
                        ),
                        floatingLabelStyle: TextStyle(color: Colors.black),
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  // Login button
                  SizedBox(
                    width: 500,
                    height: 56,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 400),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xff25282b),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () async {
                          setState(() {
                            loading = true;
                            btn_text = "Logging in...";
                          });

                          bool success = await signin(
                            email: email.text.trim(),
                            password: password.text,
                            context: context,
                          );

                          if (mounted) {
                            setState(() {
                              loading = false;
                              btn_text = "Log in";
                            });
                          }
                        },
                        child: Text(
                          btn_text,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  // Sign up row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => signup()),
                          );
                        },
                        child: Text(
                          "Sign Up",
                          style: TextStyle(
                            color: Color(0xff093125),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
}