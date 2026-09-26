import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickComm Rider',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(),
    );
  }
}
