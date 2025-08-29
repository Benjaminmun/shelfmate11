import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'home_page.dart'; // Import your HomePage widget

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();  // Initialize Firebase
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shelf Mate',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),  // Your HomePage widget
    );
  }
}
