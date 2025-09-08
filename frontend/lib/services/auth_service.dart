import 'package:flutter/foundation.dart';

class AuthService {
  static Future<bool> isUserAuthenticated() async {
    return true;
  }
  
  static Future<String?> getCurrentUserId() async {
    return "user_123";
  }
  
  static Future<void> signOut() async {
    if (kDebugMode) {
      print("User signed out");
    }
  }
  
  static Future<bool> signIn(String email, String password) async {

    return true;
  }
  
  static Future<bool> register(String email, String password, String name) async {
    return true;
  }
}