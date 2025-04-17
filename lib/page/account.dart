import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({Key? key}) : super(key: key);

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String? username;
  String? email;
  List<String> categories = [];
  int _completedTasks = 0;
  int _pendingTasks = 0;
  Map<DateTime, int> _dailyCompletions = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTaskSummary();
    _loadDailyCompletions();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('username, email, category')
            .eq('id', userId)
            .single();
        
        setState(() {
          username = data['username'];
          email = data['email'];
          categories = List<String>.from(data['category']);
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _loadTaskSummary() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        // Mengambil tugas yang selesai
        final completedResponse = await Supabase.instance.client
            .from('tasks')
            .select()
            .eq('user_id', userId)
            .eq('is_completed', true);
        
        // Mengambil tugas yang belum selesai
        final pendingResponse = await Supabase.instance.client
            .from('tasks')
            .select()
            .eq('user_id', userId)
            .eq('is_completed', false);

        setState(() {
          _completedTasks = completedResponse.length;
          _pendingTasks = pendingResponse.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading task summary: $e');
    }
  }

  Future<void> _loadDailyCompletions() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        // Mengambil data 7 hari terakhir
        final DateTime now = DateTime.now();
        final DateTime weekAgo = now.subtract(const Duration(days: 7));

        final response = await Supabase.instance.client
            .from('tasks')
            .select()
            .eq('user_id', userId)
            .eq('is_completed', true)
            .gte('completed_at', weekAgo.toIso8601String())
            .lte('completed_at', now.toIso8601String());

        Map<DateTime, int> dailyCount = {};
        for (var task in response) {
          if (task['completed_at'] != null) {
            final date = DateTime.parse(task['completed_at']).toLocal();
            final dateKey = DateTime(date.year, date.month, date.day);
            dailyCount[dateKey] = (dailyCount[dateKey] ?? 0) + 1;
          }
        }

        setState(() {
          _dailyCompletions = dailyCount;
        });
      }
    } catch (e) {
      debugPrint('Error loading daily completions: $e');
    }
  }

  Widget _buildDailyCompletionChart() {
    final List<BarChartGroupData> barGroups = [];
    final DateTime now = DateTime.now();
    
    // Membuat data untuk 7 hari
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final count = _dailyCompletions[date] ?? 0;
      
      barGroups.add(
        BarChartGroupData(
          x: 6 - i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: const Color(0xFF69D1F7),
              width: 20,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 2,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 12,
          barGroups: barGroups,
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const Text('0');
                  if (value == 6) return const Text('6');
                  if (value == 12) return const Text('12');
                  return const Text('');
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final date = now.subtract(Duration(days: (6 - value).toInt()));
                  return Text(
                    DateFormat('E').format(date).substring(0, 3),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 60),
            // Profile Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.grey,
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username ?? 'Loading...',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Task Summary
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ringkasan Tugas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _completedTasks.toString(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tugas Selesai',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _pendingTasks.toString(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tugas tertunda',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Daily Task Completion Chart
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Penyelesaian tugas harian',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        DateFormat('M/d').format(DateTime.now().subtract(const Duration(days: 6))) +
                        '-' +
                        DateFormat('M/d').format(DateTime.now()),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _dailyCompletions.isEmpty
                      ? Container(
                          height: 200,
                          alignment: Alignment.center,
                          child: Text(
                            'Tidak ada data tugas',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 16,
                            ),
                          ),
                        )
                      : _buildDailyCompletionChart(),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
