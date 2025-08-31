import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(); // Initialize Firebase
    print("Firebase Initialized");

    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL); // Set persistence
    print("Persistence set to LOCAL");
    
  } catch (e) {
    print("Error initializing Firebase or setting persistence: $e");
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shelf Mate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(), // Your HomePage widget
    );
  }
}
