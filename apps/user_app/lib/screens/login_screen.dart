import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool returnToCheckout;
  const LoginScreen({super.key, this.returnToCheckout = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : () async {
                setState(() => _isLoading = true);
                try {
                  await Provider.of<AuthProvider>(context, listen: false).signIn(
                    _emailController.text,
                    _passwordController.text,
                  );
                  if (!mounted) return;
                  
                  if (widget.returnToCheckout) {
                    Navigator.pop(context); // Go back to where we came from (Cart/Checkout)
                  } else {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                      (route) => false,
                    );
                  }
                  
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
                setState(() => _isLoading = false);
              },
              child: _isLoading ? const CircularProgressIndicator() : const Text('Login'),
            ),
             TextButton(
              onPressed: _isLoading ? null : () async {
                setState(() => _isLoading = true);
                try {
                  await Provider.of<AuthProvider>(context, listen: false).signUp(
                    _emailController.text,
                    _passwordController.text,
                  );
                  if (!mounted) return;
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign up successful! Please login.')));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
                setState(() => _isLoading = false);
              },
              child: const Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
