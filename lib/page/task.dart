import 'package:flutter/material.dart';
import 'package:to_do_list/page/add_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:to_do_list/page/task_detail.dart';
import 'package:to_do_list/page/history_task.dart';
import 'package:to_do_list/page/side_bar.dart';
import 'package:to_do_list/page/kelola_kategori.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({Key? key}) : super(key: key);

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  int _selectedTab = 0;
  List<Map<String, dynamic>> _tasks = [];
  List<String> _categories = ['Semua']; // Inisialisasi dengan 'Semua'
  bool _isLoading = true;
  bool _isSelectionMode = false;
  Set<String> _selectedTasks = {};
  bool _isTasksOpen = true;
  bool _isCompletedTasksOpen = true;
  List<String> _subtasks = [];
  List<TextEditingController> _subtaskControllers = [];
  List<bool> _editingSubtasks = [];

  @override
  void initState() {
    super.initState();
    _loadCategories(); // Tambahkan ini
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
          // Reset categories terlebih dahulu
          _categories = ['Semua'];
          // Tambahkan kategori baru dari database
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

      // Filter berdasarkan kategori yang dipilih
      if (_selectedTab != 0) { // Jika bukan "Semua"
        query = query.eq('category', _categories[_selectedTab]);
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
      final newStatus = !(task['is_completed'] ?? false);
      final now = DateTime.now().toIso8601String();
      
      // Debug print
      print('Toggling task: ${task['title']}');
      print('New status: $newStatus');
      print('Completed at: ${newStatus ? now : null}');

      // Update di Supabase
      await Supabase.instance.client
          .from('tasks')
          .update({
            'is_completed': newStatus,
            'completed_at': newStatus ? now : null,
          })
          .eq('id', task['id']);
      
      // Reload tasks untuk memperbarui tampilan
      _loadTasks();

      // Tampilkan snackbar sukses
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? 'Tugas selesai' : 'Tugas dibatalkan'),
          backgroundColor: newStatus ? Colors.green : Colors.grey,
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
      
      // Debug print
      print('Completing ${_selectedTasks.length} tasks');
      print('Completion time: $now');

      // Update status task yang dipilih menjadi selesai
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

      // Reset mode seleksi
      setState(() {
        _isSelectionMode = false;
        _selectedTasks.clear();
      });

      // Reload tasks
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
      
      // Update di Supabase
      final updatedTask = await Supabase.instance.client
          .from('tasks')
          .update({
            'priority': newPriority,
          })
          .eq('id', taskId)
          .select()
          .single();

      // Update state lokal
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
        buttonPosition.dx - 10, // Sedikit ke kiri dari ikon
        buttonPosition.dy - size.height, // Sejajar dengan task
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
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: SideBar(
        onTaskSelected: (taskId) {
          // Cari task berdasarkan ID
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
                case 'telusuri':
                  // TODO: Implementasi telusuri
                  break;
                case 'cetak':
                  // TODO: Implementasi cetak tugas
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'kelola_kategori',
                child: Text('Kelola Kategori'),
              ),
              const PopupMenuItem<String>(
                value: 'telusuri',
                child: Text('Telusuri'),
              ),
              const PopupMenuItem<String>(
                value: 'cetak',
                child: Text('Cetak Tugas'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab Bar Menu dengan kategori dinamis
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
          // Task List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/cuate.png',
                            height: 200,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Belum ada tugas',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          // Tugas Hari Ini (Belum Selesai)
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
                          if (_isTasksOpen) ...[
                            ..._tasks.where((task) => !task['is_completed']).map((task) => 
                              _buildTaskItem(task)
                            ).toList(),
                          ],

                          // Selesai Hari Ini
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
                                      'Selesai Hari Ini',
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
                            if (_isCompletedTasksOpen) ...[
                              ..._tasks.where((task) => task['is_completed']).map((task) =>
                                _buildTaskItem(task)
                              ).toList(),
                            ],
                            if (!_isCompletedTasksOpen) ...[
                              InkWell(
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const HistoryTaskPage(),
                                    ),
                                  );
                                  // Refresh task list jika ada perubahan di history
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
            
            // Reload tasks jika ada task baru ditambahkan
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

  Widget _buildTab(String text, int index) {
    bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
        _loadTasks(); // Reload tasks ketika tab berubah
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

  Widget _buildTaskItem(Map<String, dynamic> task) {
    // Fungsi untuk mendapatkan warna prioritas
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
              child: Text(
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
            ),
            // Indikator subtask
            if (task['subtasks'] != null && (task['subtasks'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.assignment,
                  size: 20,
                  color: Colors.blue[300],
                ),
              ),
            // Indikator prioritas yang bisa diklik
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
            if (task['due_date'] != null)
              Text(
                task['due_date'].toString().split('T')[0],
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

