import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final client = Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://iyylimmyuqlgrmsclvqp.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml5eWxpbW15dXFsZ3Jtc2NsdnFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcxNTc4NDAsImV4cCI6MjA4MjczMzg0MH0.5Fo43YPkOrxbrSUBCfQwqj8AE7FaLgGFDzAf9S8QBrY',
    );
  }
}
