import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  User? get user => _user;

  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _user = SupabaseService.client.auth.currentUser;
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      notifyListeners();
    });
  }

  Future<void> signIn(String email, String password) async {
    await SupabaseService.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUp(String email, String password) async {
    await SupabaseService.client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await SupabaseService.client.auth.signOut();
  }
}
