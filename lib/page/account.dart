import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'detail_account.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({Key? key}) : super(key: key);

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String? username;
  String? email;
  String? avatarUrl;
  List<String> categories = [];
  int _completedTasks = 0;
  int _pendingTasks = 0;
  Map<DateTime, int> _dailyCompletions = {};
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

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
            .select('username, email, category, avatar_url')
            .eq('id', userId)
            .single();
        
        setState(() {
          username = data['username'];
          email = data['email'];
          categories = List<String>.from(data['category']);
          avatarUrl = data['avatar_url'];
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

  Future<void> _uploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (image == null) return;

      setState(() => _isLoading = true);

      // Debug: Print file path dan extension
      print('File path: ${image.path}');
      final String originalFileExt = image.path.split('.').last.toLowerCase();
      print('Original file extension: $originalFileExt');

      // Baca file sebagai bytes
      final bytes = await image.readAsBytes();
      
      // Generate nama file yang unik dengan ekstensi .jpg
      final String userId = Supabase.instance.client.auth.currentUser!.id;
      final String fileName = 'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      print('Uploading file: $fileName');

      // Upload ke bucket avatars
      final String path = await Supabase.instance.client
          .storage
          .from('avatars')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      print('File berhasil diupload ke: $path');

      // Dapatkan public URL
      final String publicUrl = Supabase.instance.client
          .storage
          .from('avatars')
          .getPublicUrl(fileName);

      print('Public URL: $publicUrl');

      // Update profile dengan URL avatar baru
      await Supabase.instance.client
          .from('profiles')
          .update({
            'avatar_url': publicUrl,
          })
          .eq('id', userId);

      setState(() {
        avatarUrl = publicUrl;
        _isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto profil berhasil diperbarui'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error uploading image: $e');
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengupload foto: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildProfileImage() {
    if (_isLoading) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        shape: BoxShape.circle,
      ),
      child: avatarUrl != null && avatarUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading image: $error');
                  return const Icon(
                    Icons.person_outline,
                    color: Colors.grey,
                    size: 40,
                  );
                },
              ),
            )
          : const Icon(
              Icons.person_outline,
              color: Colors.grey,
              size: 40,
            ),
    );
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
                  GestureDetector(
                    onTap: _uploadImage,
                    child: Stack(
                      children: [
                        _buildProfileImage(),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF69D1F7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ],
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
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DetailAccountPage(),
                        ),
                      ).then((_) => _loadUserData());
                    },
                    child: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[400],
                      size: 16,
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
