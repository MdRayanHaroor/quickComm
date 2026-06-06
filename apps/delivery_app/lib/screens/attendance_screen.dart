import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<Map<String, dynamic>> _stats = [];
  bool _isLoading = true;
  int _totalMinutes = 0;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  Future<void> _fetchAttendance() async {
    final riderId = SupabaseService.client.auth.currentUser?.id;
    if (riderId == null) return;

    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final dateString = "${thirtyDaysAgo.year}-${thirtyDaysAgo.month.toString().padLeft(2, '0')}-${thirtyDaysAgo.day.toString().padLeft(2, '0')}";

      final data = await SupabaseService.client
          .from('rider_daily_stats')
          .select('date, online_minutes')
          .eq('rider_id', riderId)
          .gte('date', dateString)
          .order('date', ascending: false)
          .limit(30);

      final statsList = List<Map<String, dynamic>>.from(data);
      final total = statsList.fold<int>(0, (sum, r) => sum + (r['online_minutes'] as int? ?? 0));

      if (mounted) {
        setState(() {
          _stats = statsList;
          _totalMinutes = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () { setState(() => _isLoading = true); _fetchAttendance(); })
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.orange.shade700]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Last 30 Days Total', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        _formatDuration(_totalMinutes),
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      Text('${_stats.length} days worked', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),

                // Daily list
                Expanded(
                  child: _stats.isEmpty
                      ? const Center(child: Text('No attendance data yet.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _stats.length,
                          itemBuilder: (context, i) {
                            final stat = _stats[i];
                            final date = DateTime.parse(stat['date']);
                            final minutes = stat['online_minutes'] as int? ?? 0;
                            final dayName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: minutes > 0 ? Colors.green.shade50 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(dayName, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                                      Text('${date.day}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: minutes > 0 ? Colors.green.shade700 : Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                                title: Text(
                                  '${date.day}/${date.month}/${date.year}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(minutes > 0 ? 'Active' : 'No activity', style: TextStyle(color: minutes > 0 ? Colors.green : Colors.grey)),
                                trailing: Text(
                                  _formatDuration(minutes),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: minutes > 0 ? Colors.green.shade700 : Colors.grey,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
