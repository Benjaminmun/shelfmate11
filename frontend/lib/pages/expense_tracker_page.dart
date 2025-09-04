import 'package:flutter/material.dart';

class ExpenseTrackerPage extends StatelessWidget {
  final String householdId;

  const ExpenseTrackerPage({Key? key, required this.householdId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, 
        title: const Text('Expense Tracker'),
        backgroundColor: const Color(0xFF2D5D7C),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.attach_money, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Expense Tracker',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Track your household expenses here',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
