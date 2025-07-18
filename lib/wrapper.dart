import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:resqmob/pages/admin/admin home.dart';
import 'package:resqmob/pages/authentication/login.dart';
import 'package:resqmob/pages/homepage.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold();
        }

        if (userSnapshot.hasData && userSnapshot.data != null) {
          final userId = userSnapshot.data!.uid;

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection("Users").doc(userId).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Colors.white,
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                return const Scaffold(
                  backgroundColor: Colors.white,
                  body: Center(child: Text("User not found.")),
                );
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final isAdmin = data['admin'] ?? false;

              if (isAdmin) {
                return const BasicFlutterMapPage();
              }

              // Check for Windows-only block
              if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Windows Version is only for admins.",
                          style: TextStyle(fontSize: 24),
                        ),
                        TextButton(
                          onPressed: () {
                            FirebaseAuth.instance.signOut();
                          },
                          child: const Text("Sign Out"),
                        )
                      ],
                    ),
                  ),
                );
              }
              else

              return const MyHomePage();
            },
          );
        } else {
          return const login();
        }
      },
    );
  }
}
