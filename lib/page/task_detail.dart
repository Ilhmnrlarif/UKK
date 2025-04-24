import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class TaskDetailPage extends StatefulWidget {
  final Map<String, dynamic> task;
  final Function(Map<String, dynamic>) onTaskUpdated;

  const TaskDetailPage({
    Key? key, 
    required this.task,
    required this.onTaskUpdated,
  }) : super(key: key);

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final TextEditingController _notesController = TextEditingController();
  DateTime? _dueDate;
  TimeOfDay? _reminderTime;
  TimeOfDay? _reminderBefore;
  String? _reminderType = 'Notifikasi';
  bool _hasRepeat = false;
  List<String> _attachmentUrls = [];
  bool _isLoading = false;
  String? _category;
  List<String> _availableCategories = [];
  final TextEditingController _subtaskController = TextEditingController();
  List<Map<String, dynamic>> _subtasks = [];
  bool _showSubtaskInput = false;
  final TextEditingController _taskTitleController = TextEditingController();
  bool _isEditingTitle = false;
  Map<int, bool> _editingSubtasks = {};
  Map<int, TextEditingController> _subtaskControllers = {};

  @override
  void initState() {
    super.initState();
    _loadTaskDetails();
    _loadCategories();
    _taskTitleController.text = widget.task['title'] ?? '';
  }

  void _loadTaskDetails() {
    _notesController.text = widget.task['notes'] ?? '';
    _dueDate = widget.task['due_date'] != null 
        ? DateTime.parse(widget.task['due_date'])
        : null;
    if (widget.task['reminder_time'] != null) {
      final DateTime reminderDateTime = DateTime.parse(widget.task['reminder_time']);
      _reminderTime = TimeOfDay.fromDateTime(reminderDateTime);
    }
    
    if (widget.task['attachment_url'] != null) {
      if (widget.task['attachment_url'] is List) {
        _attachmentUrls = List<String>.from(widget.task['attachment_url']);
      } else if (widget.task['attachment_url'] is String) {
        _attachmentUrls = [widget.task['attachment_url']];
      }
    }
    
    _category = widget.task['category'];
    if (widget.task['subtasks'] != null) {
      final List<dynamic> subtasksJson = widget.task['subtasks'] as List<dynamic>;
      _subtasks = subtasksJson.map((task) {
        if (task is Map<String, dynamic>) {
          return task;
        } else {
          return {
            'text': task.toString(),
            'is_completed': false
          };
        }
      }).toList();
    } else {
      _subtasks = [];
    }
  }

  Future<void> _loadCategories() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('category')
            .eq('id', userId)
            .single();
        
        if (data['category'] != null) {
          setState(() {
            _availableCategories = List<String>.from(data['category']);
          });
        }
      }
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _updateCategory(String newCategory) async {
    try {
      setState(() {
        widget.task['category'] = newCategory;
        _category = newCategory;
      });

      final updatedTask = await Supabase.instance.client
          .from('tasks')
          .update({
            'category': newCategory,
          })
          .eq('id', widget.task['id'])
          .select()
          .single();

      widget.onTaskUpdated(updatedTask);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kategori berhasil diperbarui'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        widget.task['category'] = _category;
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error memperbarui kategori: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteSubtask(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Tugas Sampingan'),
        content: const Text('Apakah Anda yakin ingin menghapus tugas sampingan ini?'),
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

    if (confirm != true) return;

    try {
      setState(() => _isLoading = true);
      
      List<Map<String, dynamic>> updatedSubtasks = List.from(_subtasks);
      updatedSubtasks.removeAt(index);
      
      final updatedTask = await Supabase.instance.client
          .from('tasks')
          .update({
            'subtasks': updatedSubtasks,
          })
          .eq('id', widget.task['id'])
          .select()
          .single();

      setState(() {
        _subtasks = updatedSubtasks;
        _subtaskControllers.remove(index);
        _editingSubtasks.remove(index);
      });

      widget.onTaskUpdated(updatedTask);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tugas sampingan berhasil dihapus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error menghapus tugas sampingan: $e'),
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
        actions: [
          IconButton(
            icon: Icon(
              widget.task['is_completed'] == true
                  ? Icons.check_circle
                  : Icons.check_circle_outline,
              color: widget.task['is_completed'] == true
                  ? Colors.green
                  : Colors.grey,
            ),
            onPressed: () => _updateTaskStatus(!(widget.task['is_completed'] ?? false)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Hapus Tugas'),
                  content: const Text('Apakah Anda yakin ingin menghapus tugas ini? Tindakan ini tidak dapat dibatalkan.'),
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
                try {
                  setState(() => _isLoading = true);
                  if (_attachmentUrls.isNotEmpty) {
                    for (String url in _attachmentUrls) {
                      final fileName = url.split('/').last;
                      await Supabase.instance.client.storage
                          .from('task_attachments')
                          .remove([fileName]);
                    }
                  }

                  await Supabase.instance.client
                      .from('tasks')
                      .delete()
                      .eq('id', widget.task['id']);

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tugas berhasil dihapus'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context, true);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gagal menghapus tugas'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } finally {
                  setState(() => _isLoading = false);
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.white,
                        title: const Text('Pilih Kategori'),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: _availableCategories.map((category) {
                              return ListTile(
                                title: Text(category),
                                selected: category == widget.task['category'],
                                onTap: () {
                                  Navigator.pop(context);
                                  _updateCategory(category);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                        actions: [
                          TextButton(
                            child: Text(
                              'BATAL',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.task['category'] ?? 'Tidak Ada Kategori',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 12,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: _isEditingTitle
                      ? TextField(
                          controller: _taskTitleController,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: _updateTaskTitle,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _isEditingTitle = false;
                                      _taskTitleController.text = widget.task['title'] ?? '';
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          onSubmitted: (_) => _updateTaskTitle(),
                          autofocus: true,
                        )
                      : GestureDetector(
                          onTap: () {
                            setState(() {
                              _isEditingTitle = true;
                            });
                          },
                                child: Text(
                                  widget.task['title'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                  ),
                          ),
                        ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_subtasks.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ..._subtasks.asMap().entries.map((entry) {
                        final index = entry.key;
                        final subtask = entry.value;
                        
                        if (!_subtaskControllers.containsKey(index)) {
                          _subtaskControllers[index] = TextEditingController(text: subtask['text']);
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _toggleSubtaskStatus(index),
                                child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                    border: Border.all(
                                      color: subtask['is_completed'] == true
                                          ? Colors.green
                                          : Colors.grey[400]!,
                                    ),
                                  ),
                                  child: subtask['is_completed'] == true
                                      ? const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.green,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _editingSubtasks[index] == true
                                    ? SizedBox(
                                        height: 20,
                                        child: TextField(
                                          controller: _subtaskControllers[index],
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                            decoration: subtask['is_completed'] == true
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                            border: InputBorder.none,
                                            suffixIcon: SizedBox(
                                              width: 80,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    icon: const Icon(Icons.check, color: Colors.green, size: 20),
                                                    onPressed: () => _updateSubtaskText(
                                                      index,
                                                      _subtaskControllers[index]!.text,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                                    onPressed: () {
                                                      setState(() {
                                                        _editingSubtasks[index] = false;
                                                        _subtaskControllers[index]!.text = subtask['text'];
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          onSubmitted: (value) => _updateSubtaskText(index, value),
                                          autofocus: true,
                                        ),
                                      )
                                    : GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _editingSubtasks[index] = true;
                                            });
                                          },
                                          child: Text(
                                          subtask['text'],
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            decoration: subtask['is_completed'] == true
                                                ? TextDecoration.lineThrough
                                                : null,
                                            ),
                                          ),
                                        ),
                                      ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.red[300],
                                ),
                                onPressed: () => _deleteSubtask(index),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],

                    if (_showSubtaskInput)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey[400]!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _subtaskController,
                                decoration: const InputDecoration(
                                  hintText: 'Masukan tugas sampingan',
                                  hintStyle: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                ),
                                onSubmitted: (value) async {
                                  if (value.isNotEmpty) {
                                    setState(() {
                                      _subtasks.add({
                                        'text': value,
                                        'is_completed': false
                                      });
                                      _subtaskController.clear();
                                      _showSubtaskInput = false;
                                    });
                                    await _updateSubtasks();
                                  }
                                },
                                autofocus: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                                          InkWell(
                      onTap: () {
                        setState(() {
                          _showSubtaskInput = true;
                        });
                      },
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tambahkan tugas sampingan',
                            style: TextStyle(
                              color: Colors.blue[300],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSection(
                    icon: Icons.calendar_today_outlined,
                    title: 'Batas waktu',
                    content: _dueDate != null 
                        ? '${_dueDate!.year}/${_dueDate!.month}/${_dueDate!.day}'
                        : '2025/03/13',
                    onTap: () async {
                      final DateTime now = DateTime.now();
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? now,
                        firstDate: now,
                        lastDate: DateTime(now.year + 5),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFF69D1F7),
                                onPrimary: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setState(() => _dueDate = date);
                        _updateTask();
                      }
                    },
                  ),
                  const Divider(height: 1),

                  _buildSection(
                    icon: Icons.access_time_outlined,
                    title: 'Waktu & Pengingat',
                    content: _reminderTime?.format(context) ?? '2:14 AM',
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _reminderTime ?? TimeOfDay.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              timePickerTheme: TimePickerThemeData(
                                backgroundColor: Colors.white,
                                hourMinuteColor: MaterialStateColor.resolveWith((states) =>
                                    states.contains(MaterialState.selected) 
                                        ? const Color(0xFF69D1F7)
                                        : Colors.transparent),
                                hourMinuteTextColor: MaterialStateColor.resolveWith((states) =>
                                    states.contains(MaterialState.selected) 
                                        ? Colors.white 
                                        : Colors.black87),
                                dayPeriodColor: MaterialStateColor.resolveWith((states) =>
                                    states.contains(MaterialState.selected) 
                                        ? const Color(0xFF69D1F7)
                                        : Colors.transparent),
                                dayPeriodTextColor: MaterialStateColor.resolveWith((states) =>
                                    states.contains(MaterialState.selected) 
                                        ? Colors.white 
                                        : Colors.black87),
                                dialHandColor: const Color(0xFF69D1F7),
                                dialBackgroundColor: Colors.grey[50],
                                dialTextColor: Colors.black87,
                                entryModeIconColor: Colors.black87,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (time != null) {
                        setState(() => _reminderTime = time);
                        _updateTask();
                      }
                    },
                  ),
                  const Divider(height: 1),

                  _buildSection(
                    icon: Icons.note_outlined,
                    title: 'Catatan',
                    content: '',
                    isNote: true,
                    onTap: () {
                      _showNotesDialog();
                    },
                  ),
                  const Divider(height: 1),

                  _buildSection(
                    icon: Icons.attach_file_outlined,
                    title: 'Lampiran',
                    content: 'TAMBAH',
                    isAttachment: true,
                    onTap: () {
                      _pickImage();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
    required VoidCallback onTap,
    bool isNote = false,
    bool isAttachment = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.grey[600], size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                      if (isNote || isAttachment)
                        Text(
                          isNote ? 'EDIT' : 'TAMBAH',
                          style: TextStyle(
                            color: Colors.blue[300],
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                  if (isNote && _notesController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _notesController.text,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (isAttachment && _attachmentUrls.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _attachmentUrls.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(_attachmentUrls[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Hapus Lampiran'),
                                      content: const Text('Apakah Anda yakin ingin menghapus lampiran ini?'),
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
                                    await _deleteImage(index);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            if (!isNote && !isAttachment)
              Text(
                content,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showNotesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Catatan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            hintText: 'Tulis catatan disini',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
          ),
          maxLines: null,
        ),
        actions: [
          TextButton(
            child: Text(
              'BATAL',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text(
              'SIMPAN',
              style: TextStyle(
                color: Colors.blue,
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _updateTask();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _updateTask() async {
    setState(() => _isLoading = true);
    try {
      final updatedTask = await Supabase.instance.client
          .from('tasks')
          .update({
            'due_date': _dueDate?.toIso8601String(),
            'reminder_time': _reminderTime != null 
                ? DateTime(
                    _dueDate?.year ?? DateTime.now().year,
                    _dueDate?.month ?? DateTime.now().month,
                    _dueDate?.day ?? DateTime.now().day,
                    _reminderTime!.hour,
                    _reminderTime!.minute,
                  ).toIso8601String()
                : null,
            'reminder_before': _reminderBefore != null
                ? DateTime(
                    _dueDate?.year ?? DateTime.now().year,
                    _dueDate?.month ?? DateTime.now().month,
                    _dueDate?.day ?? DateTime.now().day,
                    _reminderBefore!.hour,
                    _reminderBefore!.minute,
                  ).toIso8601String()
                : null,
            'reminder_type': _reminderType,
            'notes': _notesController.text,
          })
          .eq('id', widget.task['id'])
          .select()
          .single();

      widget.onTaskUpdated(updatedTask);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() => _isLoading = true);
      try {
        final bytes = await image.readAsBytes();
        final fileExt = image.path.split('.').last.toLowerCase();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        String contentType;
        switch (fileExt) {
          case 'jpg':
          case 'jpeg':
            contentType = 'image/jpeg';
            break;
          case 'png':
            contentType = 'image/png';
            break;
          case 'gif':
            contentType = 'image/gif';
            break;
          case 'webp':
            contentType = 'image/webp';
            break;
          default:
            contentType = 'image/jpeg';
        }
        await Supabase.instance.client.storage
            .from('task_attachments')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(
                contentType: contentType,
                upsert: true,
              ),
            );
        final String publicUrl = Supabase.instance.client.storage
            .from('task_attachments')
            .getPublicUrl(fileName);

        setState(() {
          _attachmentUrls = [..._attachmentUrls, publicUrl];
        });

        final updatedTask = await Supabase.instance.client
            .from('tasks')
            .update({'attachment_url': _attachmentUrls})
            .eq('id', widget.task['id'])
            .select()
            .single();
        widget.onTaskUpdated(updatedTask);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gambar berhasil diunggah'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Error uploading image: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error mengunggah gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateSubtasks() async {
    try {
      final List<dynamic> subtasksJson = _subtasks.map((task) => task).toList();
      
      final updatedTask = await Supabase.instance.client
          .from('tasks')
          .update({
            'subtasks': subtasksJson,
          })
          .eq('id', widget.task['id'])
          .select()
          .single();
      
      widget.onTaskUpdated(updatedTask);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tugas sampingan berhasil disimpan')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error menyimpan tugas sampingan: $e')),
      );
    }
  }

  Future<void> _updateTaskTitle() async {
    if (_taskTitleController.text.isEmpty) return;
    
    try {
      setState(() => _isLoading = true);
      setState(() {
        widget.task['title'] = _taskTitleController.text;
        _isEditingTitle = false;
      });

      final updatedTask = await Supabase.instance.client
          .from('tasks')
          .update({
            'title': _taskTitleController.text,
          })
          .eq('id', widget.task['id'])
          .select()
          .single();

      widget.onTaskUpdated(updatedTask);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Judul tugas berhasil diperbarui'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        widget.task['title'] = widget.task['title'];
        _taskTitleController.text = widget.task['title'];
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error memperbarui judul: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSubtaskText(int index, String newText) async {
    if (newText.isEmpty) return;
    
    try {
      setState(() => _isLoading = true);
      
      List<Map<String, dynamic>> updatedSubtasks = List.from(_subtasks);
      updatedSubtasks[index]['text'] = newText;
      
      final updatedTask = await Supabase.instance.client
          .from('tasks')
          .update({
            'subtasks': updatedSubtasks,
          })
          .eq('id', widget.task['id'])
          .select()
          .single();

      widget.onTaskUpdated(updatedTask);

      setState(() {
        _subtasks = updatedSubtasks;
        _editingSubtasks[index] = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tugas sampingan berhasil diperbarui'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error memperbarui tugas sampingan: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteImage(int index) async {
    try {
      setState(() => _isLoading = true);
      final String urlToDelete = _attachmentUrls[index];
      final fileName = urlToDelete.split('/').last;
      await Supabase.instance.client.storage
          .from('task_attachments')
          .remove([fileName]);
          
      setState(() {
        _attachmentUrls.removeAt(index);
      });


      await Supabase.instance.client
          .from('tasks')
          .update({
            'attachment_url': _attachmentUrls,
          })
          .eq('id', widget.task['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lampiran berhasil dihapus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error deleting image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menghapus lampiran'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSubtaskStatus(int index) async {
    try {
      setState(() => _isLoading = true);
      setState(() {
        _subtasks[index]['is_completed'] = !(_subtasks[index]['is_completed'] ?? false);
      });
      final updatedTask = await Supabase.instance.client
          .from('tasks')
          .update({
            'subtasks': _subtasks,
          })
          .eq('id', widget.task['id'])
          .select()
          .single();

      widget.onTaskUpdated(updatedTask);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_subtasks[index]['is_completed'] 
              ? 'Tugas sampingan selesai' 
              : 'Tugas sampingan dibatalkan'),
          backgroundColor: _subtasks[index]['is_completed'] 
              ? Colors.green 
              : Colors.grey,
        ),
      );
    } catch (e) {
      setState(() {
        _subtasks[index]['is_completed'] = !(_subtasks[index]['is_completed'] ?? false);
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error mengubah status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _areAllSubtasksCompleted() {
    if (_subtasks.isEmpty) return true;
    return _subtasks.every((subtask) => subtask['is_completed'] == true);
  }

  Future<void> _updateTaskStatus(bool newStatus) async {
    if (widget.task['is_completed'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tugas yang sudah selesai tidak dapat diubah kembali'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (newStatus && !_areAllSubtasksCompleted()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selesaikan semua tugas sampingan terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);
      
      final now = DateTime.now().toIso8601String();
      
      final updatedTask = await Supabase.instance.client
          .from('tasks')
          .update({
            'is_completed': true,
            'completed_at': now,
          })
          .eq('id', widget.task['id'])
          .select()
          .single();

      widget.task['is_completed'] = true;
      widget.onTaskUpdated(updatedTask);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tugas selesai'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error mengubah status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _taskTitleController.dispose();
    _subtaskControllers.values.forEach((controller) => controller.dispose());
    _subtaskController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}