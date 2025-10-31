import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:resqmob/wrapper.dart';
import 'backend/firebase config/firebase message.dart';
import 'backend/firebase config/firebase_options.dart';




bool get isSkiaWeb => kIsWeb;

@pragma('vm:entry-point')
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  print('Background message received: ${message.notification?.title}');
}



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
   );
  //await initializeService();
  final firebaseApi = FirebaseApi();
  if (!isSkiaWeb && !(Platform.isWindows)) {
    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
    await firebaseApi.initNotifications();
  }


  //this part cause problem in edge and phone web

try {
  if (kIsWeb) {
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await FirebaseMessaging.instance.getToken(
        vapidKey: "BLwCHwZWPFgo5l5EpYdly8u2Fv0kxwVnTw1e3r5Fx21zbkFs5TapD369ibH1FQoa7mKbR-CyzfOHi0oQW2_OPR0");
  }
  }catch(e){
    print(e.toString());
}



  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ResQmob',
      theme: ThemeData(
        fontFamily: 'Verdana',
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: Wrapper(),
    );
  }
}



