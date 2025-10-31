import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../Class Models/user.dart';
import '../../backend/firebase config/Authentication.dart';
import 'login.dart';

class signup extends StatefulWidget {
  const signup({super.key});

  @override
  State<signup> createState() => _signupState();
}

class _signupState extends State<signup> {
  @override
  @override
  void initState() {
    // TODO: implement initState
    printFcmToken();
    super.initState();
  }
  void printFcmToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    print("🔑 FCM Token: $token");
  }
  String btn_text = "Sign Up";
  File? image;
  String path = "";
  String url = "";
  bool _obscurePassword = true;
  bool isLoading = false;

  TextEditingController name = TextEditingController();
  TextEditingController email = TextEditingController();
  TextEditingController password = TextEditingController();

  getImage() async {
    var pic = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pic != null) {
      setState(() {
        image = File(pic.path);
      });
    }
  }

  createAccount(context) async {
    setState(() {
      isLoading = true;
      btn_text = "Creating Account...";
    });

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text.trim()
      );

      path = 'UserPhotos/${DateTime.now().millisecondsSinceEpoch}.jpeg';

      if (image != null) {
        final ref = FirebaseStorage.instance.ref(path);
        await ref.putFile(image!);
        url = await ref.getDownloadURL();
      }

      // Get user location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Create user model with location
      UserModel newUser = UserModel(
        id: credential.user!.uid,
        name: name.text,
        admin: false,
        email: email.text,
        profileImageUrl: url,
        msg : "initial help message",
        location: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': Timestamp.now(),
        },
      );


      await FirebaseFirestore.instance
          .collection("Users")
          .doc(credential.user!.uid)
          .set(newUser.toJson());

      await Authentication().signout(context);
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => login())
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        isLoading = false;
        btn_text = "Sign Up";
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.code.toString()),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          )
      );
    } catch (e) {
      setState(() {
        isLoading = false;
        btn_text = "Sign Up";
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          )
      );
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 80,
                width: 80,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 24),
              Text(
                "Creating your account...",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white,),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20),

                // Header
                Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Sign up to get started",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 30),

                // Profile Image
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                        image: image != null
                            ? DecorationImage(
                          image: FileImage(image!),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: image == null
                          ? Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.grey[400],
                      )
                          : null,
                    ),
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        color: Colors.black,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: getImage,
                        icon: Icon(
                          Icons.add_a_photo_outlined,
                          size: 20,
                        ),
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 30),

                // Name Field
                ConstrainedBox(
                  constraints:  BoxConstraints(maxWidth: 700),
                  child: TextField(
                    controller: name,
                    decoration: InputDecoration(
                      labelText: "Name",
                      hintText: "Enter your full name",
                      prefixIcon: Icon(Icons.person_outline,  color: Colors.black,),
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
                        borderSide: BorderSide( color: Colors.black, width: 2),
                      ),
                      floatingLabelStyle: TextStyle( color: Colors.black,),
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Email Field
                ConstrainedBox(
                  constraints:  BoxConstraints(maxWidth: 700),
                  child: TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "Email",
                      hintText: "Enter your email address",
                      prefixIcon: Icon(Icons.email_outlined,  color: Colors.black,),
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
                        borderSide: BorderSide( color: Colors.black, width: 2),
                      ),
                      floatingLabelStyle: TextStyle( color: Colors.black,),
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Password Field
                ConstrainedBox(
                  constraints:  BoxConstraints(maxWidth: 700),
                  child: TextField(
                    controller: password,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: "Password",
                      hintText: "Create a password",
                      prefixIcon: Icon(Icons.lock_outline,  color: Colors.black,),
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
                        borderSide: BorderSide( color: Colors.black, width: 2),
                      ),
                      floatingLabelStyle: TextStyle( color: Colors.black,),
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                SizedBox(height: 30),

                // Sign Up Button
                SizedBox(
                  width: 500,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:   Color(0xff25282b),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => createAccount(context),
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
                SizedBox(height: 30),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account?",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => login()),
                        );
                      },
                      child: Text(
                        "Log In",
                        style: TextStyle(
                          color: Colors.black,
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
