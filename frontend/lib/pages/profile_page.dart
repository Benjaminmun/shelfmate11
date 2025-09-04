import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  Future<Map<String, dynamic>?> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return snapshot.data();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF2D5D7C),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text("No user data found"));
          }

          final userData = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF2D5D7C).withOpacity(0.2),
                  child: const Icon(Icons.person, size: 60, color: Color(0xFF2D5D7C)),
                ),
                const SizedBox(height: 16),

                // Name
                Text(
                  userData['fullName'] ?? "No Name",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Email
                Text(
                  userData['email'] ?? "No Email",
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),

                const SizedBox(height: 24),
                const Divider(),

                // Options
                _buildProfileOption(
                  icon: Icons.settings,
                  title: "Settings",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Navigate to Settings")),
                    );
                  },
                ),
                _buildProfileOption(
                  icon: Icons.lock,
                  title: "Change Password",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Navigate to Change Password")),
                    );
                  },
                ),
                _buildProfileOption(
                  icon: Icons.logout,
                  title: "Logout",
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.of(context).pushReplacementNamed("/login");
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2D5D7C)),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
