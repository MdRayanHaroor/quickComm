import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  String? _fullName;
  String? _phoneNumber;

  User? get user => _user;
  String? get fullName => _fullName;
  String? get phoneNumber => _phoneNumber;
  bool get isAuthenticated => _user != null;

  /// Returns initials: first two words' initials if 2+ words, otherwise first letter only.
  String get initials {
    if (_fullName != null && _fullName!.trim().isNotEmpty) {
      final parts = _fullName!
          .trim()
          .split(RegExp(r'\s+'))
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.length >= 2) {
        return (parts[0][0] + parts[1][0]).toUpperCase();
      } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
        return parts[0][0].toUpperCase();
      }
    }
    final email = _user?.email;
    if (email != null && email.trim().isNotEmpty) {
      return email.trim()[0].toUpperCase();
    }
    return '';
  }

  AuthProvider() {
    _user = SupabaseService.client.auth.currentUser;
    fetchUserProfile();
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      fetchUserProfile();
    });
  }

  Future<void> fetchUserProfile() async {
    final currentUser = _user ?? SupabaseService.client.auth.currentUser;
    if (currentUser == null) {
      _user = null;
      _fullName = null;
      _phoneNumber = null;
      notifyListeners();
      return;
    }
    _user = currentUser;

    // Check userMetadata first for instant UI response
    final metaName = _user!.userMetadata?['full_name']?.toString();
    if (metaName != null && metaName.trim().isNotEmpty) {
      _fullName = metaName.trim();
    }
    final metaPhone = _user!.userMetadata?['phone_number']?.toString();
    if (metaPhone != null && metaPhone.trim().isNotEmpty) {
      _phoneNumber = metaPhone.trim();
    }

    try {
      final res = await SupabaseService.client
          .from('profiles')
          .select('full_name, phone_number')
          .eq('id', _user!.id)
          .maybeSingle();

      if (res != null) {
        final dbName = res['full_name']?.toString().trim();
        if (dbName != null && dbName.isNotEmpty) {
          _fullName = dbName;
        }
        final dbPhone = res['phone_number']?.toString().trim();
        if (dbPhone != null && dbPhone.isNotEmpty) {
          _phoneNumber = dbPhone;
        }
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    await SupabaseService.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    await fetchUserProfile();
  }

  Future<void> signUp(
    String email,
    String password, {
    String? fullName,
    String? phoneNumber,
  }) async {
    final cleanName = fullName?.trim();
    final cleanPhone = phoneNumber?.trim();
    final data = <String, dynamic>{};
    if (cleanName != null && cleanName.isNotEmpty) {
      data['full_name'] = cleanName;
    }
    if (cleanPhone != null && cleanPhone.isNotEmpty) {
      data['phone_number'] = cleanPhone;
    }

    final res = await SupabaseService.client.auth.signUp(
      email: email,
      password: password,
      data: data.isNotEmpty ? data : null,
    );

    if (cleanName != null && cleanName.isNotEmpty) _fullName = cleanName;
    if (cleanPhone != null && cleanPhone.isNotEmpty) _phoneNumber = cleanPhone;

    final registeredUser = res.user ?? SupabaseService.client.auth.currentUser;
    if (registeredUser != null) {
      try {
        await SupabaseService.client.from('profiles').upsert({
          'id': registeredUser.id,
          if (cleanName != null && cleanName.isNotEmpty) 'full_name': cleanName,
          if (cleanPhone != null && cleanPhone.isNotEmpty) 'phone_number': cleanPhone,
          'role': 'user',
        });
      } catch (e) {
        debugPrint('Error upserting profile in signUp: $e');
      }
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await SupabaseService.client.auth.signOut();
    _user = null;
    _fullName = null;
    _phoneNumber = null;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    final user = _user ?? SupabaseService.client.auth.currentUser;
    if (user == null) return;
    try {
      await SupabaseService.client.rpc('delete_user_account');
    } catch (e) {
      debugPrint('delete_user_account RPC error: $e');
      rethrow;
    }
    await signOut();
  }
}
