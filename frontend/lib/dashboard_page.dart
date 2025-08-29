import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Dashboard")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Welcome to your Dashboard!", style: TextStyle(fontSize: 24)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Example of navigating to another page
                Navigator.pushNamed(context, '/some-other-page');
              },
              child: Text("Go to Another Page"),
            ),
          ],
        ),
      ),
    );
  }
}
