import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    final data = await SupabaseService.client
        .from('profiles')
        .select('full_name, phone_number, must_change_password')
        .eq('id', userId)
        .single();
    if (mounted) setState(() => _profile = data);
  }

  Future<void> _changePassword() async {
    final newPwd = _newPasswordController.text.trim();
    final confirmPwd = _confirmPasswordController.text.trim();

    if (newPwd.isEmpty || confirmPwd.isEmpty) {
      _showSnack('Please fill all fields');
      return;
    }
    if (newPwd.length < 8) {
      _showSnack('Password must be at least 8 characters');
      return;
    }
    if (newPwd != confirmPwd) {
      _showSnack('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Update the auth password
      await SupabaseService.client.auth.updateUser(UserAttributes(password: newPwd));

      // Clear the must_change_password flag
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId != null) {
        await SupabaseService.client
            .from('profiles')
            .update({'must_change_password': false})
            .eq('id', userId);
      }

      _newPasswordController.clear();
      _confirmPasswordController.clear();
      await _loadProfile();

      if (mounted) {
        _showSnack('Password changed successfully!');
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    }
    setState(() => _isLoading = false);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.client.auth.currentUser;
    final mustChange = _profile?['must_change_password'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Info Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.orange.shade100,
                      child: Icon(Icons.person, size: 32, color: Colors.orange.shade700),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profile?['full_name'] ?? 'Rider',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(user?.email ?? '', style: TextStyle(color: Colors.grey.shade600)),
                          if (_profile?['phone_number'] != null && _profile!['phone_number'].isNotEmpty)
                            Text(_profile!['phone_number'], style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Warning if default password
            if (mustChange)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You are using the default password. Please change it for security.',
                        style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            // Change Password Section
            Text('Change Password', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Update Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
