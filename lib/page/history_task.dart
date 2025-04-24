import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryTaskPage extends StatefulWidget {
  const HistoryTaskPage({Key? key}) : super(key: key);

  @override
  State<HistoryTaskPage> createState() => _HistoryTaskPageState();
}

class _HistoryTaskPageState extends State<HistoryTaskPage> {
  List<Map<String, dynamic>> _completedTasks = [];
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _groupedTasks = {};

  @override
  void initState() {
    super.initState();
    _loadCompletedTasks();
  }

  Future<void> _loadCompletedTasks() async {
    try {
      final response = await Supabase.instance.client
          .from('tasks')
          .select()
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id)
          .eq('is_completed', true)
          .not('completed_at', 'is', null)
          .order('completed_at', ascending: false);

      final tasks = List<Map<String, dynamic>>.from(response);
      
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (var task in tasks) {
        if (task['completed_at'] == null) continue;
        
        final completedDate = DateTime.parse(task['completed_at']);
        final date = '${completedDate.year}/${completedDate.month.toString().padLeft(2, '0')}/${completedDate.day.toString().padLeft(2, '0')}';
        
        if (!grouped.containsKey(date)) {
          grouped[date] = [];
        }
        grouped[date]!.add(task);
      }

      setState(() {
        _completedTasks = tasks;
        _groupedTasks = grouped;
        _isLoading = false;
      });
      print('Total completed tasks: ${tasks.length}');
      print('Grouped dates: ${grouped.keys.toList()}');
      for (var date in grouped.keys) {
        print('Tasks for $date: ${grouped[date]!.length}');
      }
    } catch (e) {
      debugPrint('Error loading completed tasks: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAllCompletedTasks() async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hapus Semua Tugas Selesai'),
          content: const Text('Apakah Anda yakin ingin menghapus semua tugas yang sudah selesai? Tindakan ini tidak dapat dibatalkan.'),
          actions: [
            TextButton(
              child: Text(
                'BATAL',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              onPressed: () => Navigator.pop(context, false),
            ),
            TextButton(
              child: const Text(
                'HAPUS',
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );

      if (confirm == true) {
        setState(() => _isLoading = true);
        await Supabase.instance.client
            .from('tasks')
            .delete()
            .eq('user_id', Supabase.instance.client.auth.currentUser!.id)
            .eq('is_completed', true);

        await _loadCompletedTasks();

        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua tugas selesai telah dihapus'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error deleting completed tasks: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus tugas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Waktu Selesai',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          if (_completedTasks.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.delete_sweep,
                color: Colors.red,
              ),
              onPressed: _deleteAllCompletedTasks,
              tooltip: 'Hapus Semua Tugas Selesai',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _completedTasks.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada tugas yang selesai',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _groupedTasks.length,
                  itemBuilder: (context, index) {
                    final date = _groupedTasks.keys.elementAt(index);
                    final tasks = _groupedTasks[date]!;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Color(0xFF69D1F7),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              date,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          margin: const EdgeInsets.only(left: 5),
                          padding: const EdgeInsets.only(left: 20),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Column(
                            children: tasks.map((task) {
                              final completedTime = DateTime.parse(task['completed_at']);
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF69D1F7),
                                          width: 2,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Color(0xFF69D1F7),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task['title'] ?? '',
                                            style: const TextStyle(
                                              decoration: TextDecoration.lineThrough,
                                              color: Colors.grey,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (task['category'] != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                task['category'],
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                            ),
                                          ),
                                          if (task['reminder_time'] != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                task['reminder_time'].toString().split('T')[1].substring(0, 5),
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                ),
    );
  }
}
