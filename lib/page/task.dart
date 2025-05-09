import 'package:flutter/material.dart';
import 'package:to_do_list/page/add_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:to_do_list/page/task_detail.dart';
import 'package:to_do_list/page/history_task.dart';
import 'package:to_do_list/page/side_bar.dart';
import 'package:to_do_list/page/kelola_kategori.dart';
import 'package:to_do_list/page/search_task.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({Key? key}) : super(key: key);

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  int _selectedTab = 0;
  List<Map<String, dynamic>> _tasks = [];
  List<String> _categories = ['Semua']; 
  bool _isLoading = true;
  bool _isSelectionMode = false;
  Set<String> _selectedTasks = {};
  bool _isTasksOpen = true;
  bool _isCompletedTasksOpen = true;
  List<String> _subtasks = [];
  List<TextEditingController> _subtaskControllers = [];
  List<bool> _editingSubtasks = [];
  String _currentView = 'Semua';
  bool _isUpcomingOpen = true;
  bool _isTodayOpen = true;
  bool _isOverdueOpen = true;
  bool _isCompletedOpen = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadTasks();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('category')
          .eq('id', Supabase.instance.client.auth.currentUser!.id)
          .single();

      if (response != null && response['category'] != null) {
        setState(() {
          _categories = ['Semua'];
          _categories.addAll(List<String>.from(response['category']));
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _loadTasks() async {
    try {
      var query = Supabase.instance.client
          .from('tasks')
          .select()
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id);

      if (_selectedTab != 0) {
        query = query.eq('category', _categories[_selectedTab]);
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
      final tomorrow = DateTime(now.year, now.month, now.day + 1).toIso8601String();

      // Filter berdasarkan tab yang dipilih
      switch (_currentView) {
        case 'Semua':
          // Tampilkan semua tugas
          break;
        case 'Upcoming':
          // Tampilkan tugas yang due date-nya besok atau lebih
          query = query.gte('due_date', tomorrow);
          break;
        case 'Overdue':
          // Tampilkan tugas yang telat (due date sebelum hari ini dan belum selesai)
          query = query.lt('due_date', startOfDay).eq('is_completed', false);
          break;
        default: // Hari ini
          // Tampilkan tugas untuk hari ini
          query = query.gte('due_date', startOfDay).lt('due_date', endOfDay);
          break;
      }

      final response = await query.order('created_at', ascending: false);

      setState(() {
        _tasks = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleTaskStatus(Map<String, dynamic> task) async {
    try {
      if (task['is_completed'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tugas yang sudah selesai tidak dapat diubah kembali'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (task['subtasks'] != null && task['subtasks'].isNotEmpty) {
        final List<dynamic> subtasks = task['subtasks'];
        bool allSubtasksCompleted = subtasks.every((subtask) => 
          subtask is Map<String, dynamic> && subtask['is_completed'] == true
        );

        if (!allSubtasksCompleted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selesaikan semua tugas sampingan terlebih dahulu'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      final now = DateTime.now();
      String? completionStatus;
      
      if (task['due_date'] != null) {
        final dueDate = DateTime.parse(task['due_date']);
        final today = DateTime(now.year, now.month, now.day);
        final taskDate = DateTime(dueDate.year, dueDate.month, dueDate.day);

        // Hanya set status untuk tugas upcoming atau overdue
        if (taskDate.isAfter(today)) {
          completionStatus = 'early';
        } else if (taskDate.isBefore(today)) {
          completionStatus = 'terlambat';
        }
      }

      await Supabase.instance.client
          .from('tasks')
          .update({
            'is_completed': true,
            'completed_at': now.toIso8601String(),
            'completion_status': completionStatus,
          })
          .eq('id', task['id']);
      
      _loadTasks();

      if (!mounted) return;
      String message = 'Tugas selesai';
      if (completionStatus != null) {
        message += ' ($completionStatus)';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: completionStatus == 'early' ? Colors.green : 
                         completionStatus == 'terlambat' ? Colors.orange : 
                         Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error toggling task status: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completeSelectedTasks() async {
    try {
      setState(() => _isLoading = true);
      
      final now = DateTime.now().toIso8601String();
      print('Completing ${_selectedTasks.length} tasks');
      print('Completion time: $now');

      for (String taskId in _selectedTasks) {
        print('Completing task ID: $taskId');
        await Supabase.instance.client
            .from('tasks')
            .update({
              'is_completed': true,
              'completed_at': now,
            })
            .eq('id', taskId);
      }

      setState(() {
        _isSelectionMode = false;
        _selectedTasks.clear();
      });

      _loadTasks();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedTasks.length} tugas telah diselesaikan'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error completing tasks: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyelesaikan tugas'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onTaskUpdated(Map<String, dynamic> updatedTask) {
    setState(() {
      final index = _tasks.indexWhere((task) => task['id'] == updatedTask['id']);
      if (index != -1) {
        _tasks[index] = updatedTask;
      }
    });
  }

  Future<void> _updateTaskPriority(String taskId, String newPriority) async {
    try {
      setState(() => _isLoading = true);
      
      final updatedTask = await Supabase.instance.client
          .from('tasks')
          .update({
            'priority': newPriority,
          })
          .eq('id', taskId)
          .select()
          .single();

      setState(() {
        final index = _tasks.indexWhere((task) => task['id'] == taskId);
        if (index != -1) {
          _tasks[index] = updatedTask;
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prioritas berhasil diperbarui'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error memperbarui prioritas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showPriorityMenu(BuildContext context, Map<String, dynamic> task, RenderBox buttonBox, Offset buttonPosition) {
    final Size size = buttonBox.size;
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonPosition.dx - 10,
        buttonPosition.dy - size.height,
        buttonPosition.dx + size.width,
        buttonPosition.dy,
      ),
      items: [
        PopupMenuItem(
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const Text('High', style: TextStyle(fontSize: 14)),
            ],
          ),
          onTap: () => _updateTaskPriority(task['id'], 'High'),
        ),
        PopupMenuItem(
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flag, color: Colors.yellow[700], size: 20),
              const SizedBox(width: 8),
              const Text('Medium', style: TextStyle(fontSize: 14)),
            ],
          ),
          onTap: () => _updateTaskPriority(task['id'], 'Medium'),
        ),
        PopupMenuItem(
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text('Easy', style: TextStyle(fontSize: 14)),
            ],
          ),
          onTap: () => _updateTaskPriority(task['id'], 'Easy'),
        ),
      ],
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      color: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Filter tasks berdasarkan kategori waktu
    final upcomingTasks = _tasks.where((task) => 
      task['due_date'] != null && 
      DateTime.parse(task['due_date']).isAfter(endOfDay) &&
      !task['is_completed']
    ).toList();

    final todayTasks = _tasks.where((task) => 
      task['due_date'] != null && 
      DateTime.parse(task['due_date']).isAfter(startOfDay) &&
      DateTime.parse(task['due_date']).isBefore(endOfDay) &&
      !task['is_completed']
    ).toList();

    final overdueTasks = _tasks.where((task) => 
      task['due_date'] != null && 
      DateTime.parse(task['due_date']).isBefore(startOfDay) &&
      !task['is_completed']
    ).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: SideBar(
        onTaskSelected: (taskId) {
          final selectedTask = _tasks.firstWhere(
            (task) => task['id'] == taskId,
            orElse: () => {},
          );
          
          if (selectedTask.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TaskDetailPage(
                  task: selectedTask,
                  onTaskUpdated: _onTaskUpdated,
                ),
              ),
            ).then((result) {
              if (result == true) {
                _loadTasks();
              }
            });
          }
        },
        onRefresh: () {
          _loadTasks();
        },
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: Colors.grey[600],
            ),
            color: Colors.white,
            onSelected: (value) {
              switch (value) {
                case 'kelola_kategori':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const KelolaKategoriPage(),
                    ),
                  ).then((_) => _loadCategories());
                  break;
                case 'Cari Tugas':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SearchTaskPage(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'kelola_kategori',
                child: Text('Kelola Kategori'),
              ),
              const PopupMenuItem<String>(
                value: 'Cari Tugas',
                child: Text('Cari Tugas'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.asMap().entries.map((entry) {
                    return Row(
                      children: [
                        _buildTab(entry.value, entry.key),
                        const SizedBox(width: 10),
                      ],
                    );
                  }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // Upcoming Section
                      if (upcomingTasks.isNotEmpty) ...[
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isUpcomingOpen = !_isUpcomingOpen;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                        children: [
                          const Text(
                                  'Upcoming',
                            style: TextStyle(
                              fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Icon(
                                  _isUpcomingOpen 
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isUpcomingOpen)
                          ...upcomingTasks.map((task) => _buildTaskItem(task)).toList(),
                      ],

                      // Today Section
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isTasksOpen = !_isTasksOpen;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  const Text(
                                    'Hari ini',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Icon(
                                    _isTasksOpen 
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      if (_isTasksOpen)
                        ...todayTasks.map((task) => _buildTaskItem(task)).toList(),

                      // Overdue Section
                      if (overdueTasks.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isOverdueOpen = !_isOverdueOpen;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                const Text(
                                  'Overdue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Icon(
                                  _isOverdueOpen 
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isOverdueOpen)
                          ...overdueTasks.map((task) => _buildTaskItem(task)).toList(),
                      ],

                      // Completed Section
                      if (_tasks.any((task) => task['is_completed'])) ...[
                        const SizedBox(height: 24),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isCompletedTasksOpen = !_isCompletedTasksOpen;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                const Text(
                                  'Selesai',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Icon(
                                  _isCompletedTasksOpen 
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isCompletedTasksOpen)
                          ..._tasks
                              .where((task) => task['is_completed'])
                              .map((task) => _buildTaskItem(task))
                              .toList(),
                        if (!_isCompletedTasksOpen)
                          InkWell(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const HistoryTaskPage(),
                                ),
                              );
                              if (result == true) {
                                _loadTasks();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'Periksa semua tugas yang sudah selesai',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: FloatingActionButton(
          onPressed: () async {
            final result = await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: const AddTaskPage(),
              ),
            );
            
            if (result == true) {
              _loadTasks();
            }
          },
          backgroundColor: const Color(0xFF69D1F7),
          child: const Icon(
            Icons.add,
            color: Colors.white,
          ),
          shape: const CircleBorder(),
          elevation: 2,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSection(String title, String count, List<Map<String, dynamic>> tasks) {
    return Column(
      children: [
        InkWell(
      onTap: () {
        setState(() {
              switch (title) {
                case 'Upcoming':
                  _isUpcomingOpen = !_isUpcomingOpen;
                  break;
                case 'Today':
                  _isTodayOpen = !_isTodayOpen;
                  break;
                case 'Overdue':
                  _isOverdueOpen = !_isOverdueOpen;
                  break;
                case 'Completed':
                  _isCompletedOpen = !_isCompletedOpen;
                  break;
              }
            });
          },
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
                    color: Colors.yellow,
                    borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
                    count,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  _getSectionOpenState(title) 
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
        if (_getSectionOpenState(title))
          ...tasks.map((task) => _buildTaskItem(task)).toList(),
      ],
    );
  }

  bool _getSectionOpenState(String title) {
    switch (title) {
      case 'Upcoming':
        return _isUpcomingOpen;
      case 'Today':
        return _isTodayOpen;
      case 'Overdue':
        return _isOverdueOpen;
      case 'Completed':
        return _isCompletedOpen;
      default:
        return false;
    }
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    Color getPriorityColor(String? priority) {
      switch (priority) {
        case 'High':
          return Colors.red;
        case 'Medium':
          return Colors.yellow[700]!;
        case 'Easy':
          return Colors.green;
        default:
          return Colors.grey;
      }
    }

    String formatDate(String? dateStr) {
      if (dateStr == null) return '';
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final taskDate = DateTime(date.year, date.month, date.day);

      // Format tanggal standar: DD-MM
      String standardDate = '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}';

      // Cek jika tugas overdue
      if (taskDate.isBefore(today) && !task['is_completed']) {
        final difference = today.difference(taskDate).inDays;
        return '$standardDate (${difference}d late)';
      }

      return standardDate;
    }

    bool isOverdue() {
      if (task['due_date'] == null) return false;
      final date = DateTime.parse(task['due_date']);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final taskDate = DateTime(date.year, date.month, date.day);
      return taskDate.isBefore(today) && !task['is_completed'];
    }

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (_selectedTasks.contains(task['id'])) {
              _selectedTasks.remove(task['id']);
            } else {
              _selectedTasks.add(task['id']);
            }
          });
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailPage(
                task: task,
                onTaskUpdated: _onTaskUpdated,
              ),
            ),
          ).then((result) {
            if (result == true) {
              _loadTasks();
            }
          });
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedTasks.add(task['id']);
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (_isSelectionMode)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _selectedTasks.contains(task['id'])
                        ? const Color(0xFF69D1F7)
                        : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: _selectedTasks.contains(task['id'])
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Color(0xFF69D1F7),
                      )
                    : null,
              )
            else
              GestureDetector(
                onTap: () => _toggleTaskStatus(task),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF69D1F7),
                      width: 2,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: task['is_completed'] == true 
                            ? const Color(0xFF69D1F7) 
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      decoration: task['is_completed'] == true
                          ? TextDecoration.lineThrough
                          : null,
                      color: task['is_completed'] == true
                          ? Colors.grey
                          : Colors.black,
                    ),
                  ),
                  if (task['due_date'] != null)
                    Row(
                      children: [
                        if (isOverdue())
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.red,
                          ),
                        if (isOverdue())
                          const SizedBox(width: 4),
                        Text(
                          formatDate(task['due_date']),
                          style: TextStyle(
                            color: isOverdue() ? Colors.red : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        if (task['is_completed'] == true && task['completion_status'] != null)
                          Row(
                            children: [
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: task['completion_status'] == 'early' 
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  task['completion_status'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: task['completion_status'] == 'early' 
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                ],
              ),
            ),
            if (task['subtasks'] != null && (task['subtasks'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.assignment,
                  size: 20,
                  color: Colors.blue[300],
                ),
              ),
            if (!_isSelectionMode)
              Builder(
                builder: (context) => GestureDetector(
                  onTap: () {
                    final RenderBox button = context.findRenderObject() as RenderBox;
                    final Offset position = button.localToGlobal(Offset.zero);
                    _showPriorityMenu(context, task, button, position);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.flag,
                      size: 20,
                      color: getPriorityColor(task['priority']),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String text, int index) {
    bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
        _loadTasks();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF69D1F7) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}