import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';

class AddTaskPage extends StatefulWidget {
  const AddTaskPage({Key? key}) : super(key: key);

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _taskController = TextEditingController();
  final _notesController = TextEditingController();
  final _subtaskController = TextEditingController();
  String? _selectedCategory;
  String? _selectedPriority;
  DateTime? _dueDate;
  DateTime? _reminderTime;
  File? _attachment;
  bool _isLoading = false;
  List<String> _categories = [];
  List<String> _subtasks = [];
  bool _showSubtaskInput = false;


  final Map<String, Color> priorities = {
    'High': Colors.red,
    'Medium': Colors.orange,
    'Easy': Colors.green,
  };

  @override
  void initState() {
    super.initState();
    _loadCategories();
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
          _categories = List<String>.from(response['category']);
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _createTask() async {
    if (_taskController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul tugas tidak boleh kosong')),
      );
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori terlebih dahulu')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? attachmentUrl;
      if (_attachment != null) {
        final fileExt = _attachment!.path.split('.').last;
        final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
        final bytes = await _attachment!.readAsBytes();
        
        final response = await Supabase.instance.client.storage
          .from('task_attachments')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
            ),
          );
        
        attachmentUrl = Supabase.instance.client.storage
          .from('task_attachments')
          .getPublicUrl(fileName);
      }
      await Supabase.instance.client.from('tasks').insert({
        'user_id': Supabase.instance.client.auth.currentUser!.id,
        'title': _taskController.text,
        'category': _selectedCategory,
        'priority': _selectedPriority,
        'due_date': _dueDate?.toIso8601String(),
        'reminder_time': _reminderTime?.toIso8601String(),
        'notes': _notesController.text,
        'attachment_url': attachmentUrl,
        'is_completed': false,
        'created_at': DateTime.now().toIso8601String(),
        'subtasks': _subtasks.isNotEmpty ? _subtasks : null,
      });
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tugas berhasil ditambahkan')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${error.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showPriorityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Pilih Prioritas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: priorities.entries.map((entry) {
            return ListTile(
              leading: Icon(
                Icons.flag,
                color: entry.value,
              ),
              title: Text(entry.key),
              onTap: () {
                setState(() {
                  _selectedPriority = entry.key;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _attachment = File(image.path);
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
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
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildCategoryButton() {
    return GestureDetector(
      onTap: () {
        final RenderBox button = context.findRenderObject() as RenderBox;
        final Offset offset = button.localToGlobal(Offset.zero);
        
        showMenu(
          context: context,
          position: RelativeRect.fromLTRB(
            offset.dx,
            offset.dy + button.size.height,
            offset.dx + button.size.width,
            offset.dy + button.size.height + 200,
          ),
          items: [
            PopupMenuItem(
              height: 40,
              child: Text(
                'Tidak Ada Kategori',
                style: TextStyle(
                  color: Colors.blue[300],
                  fontSize: 14,
                ),
              ),
              onTap: () {
                setState(() {
                  _selectedCategory = null;
                });
              },
            ),
            ..._categories.map((category) => PopupMenuItem(
              height: 40,
              child: Text(
                category,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              onTap: () {
                setState(() {
                  _selectedCategory = category;
                });
              },
            )).toList(),
            PopupMenuItem(
              height: 40,
              child: Row(
                children: [
                  Icon(
                    Icons.add,
                    size: 18,
                    color: Colors.blue[300],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Buat baru',
                    style: TextStyle(
                      color: Colors.blue[300],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              onTap: () {
                Future.delayed(const Duration(milliseconds: 10), () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      final TextEditingController categoryController = TextEditingController();
                      return AlertDialog(
                        title: const Text(
                          'Tambah Kategori Baru',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        content: TextField(
                          controller: categoryController,
                          decoration: const InputDecoration(
                            hintText: 'Nama kategori',
                            hintStyle: TextStyle(fontSize: 14),
                          ),
                        ),
                        actions: [
                          TextButton(
                            child: Text(
                              'BATAL',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          TextButton(
                            child: Text(
                              'SIMPAN',
                              style: TextStyle(
                                color: Colors.blue[300],
                                fontSize: 14,
                              ),
                            ),
                            onPressed: () async {
                              if (categoryController.text.isNotEmpty) {
                                try {
                                  final userId = Supabase.instance.client.auth.currentUser!.id;
                                  final newCategories = [..._categories, categoryController.text];
                                  
                                  await Supabase.instance.client
                                      .from('profiles')
                                      .update({
                                        'category': newCategories,
                                      })
                                      .eq('id', userId);

                                  setState(() {
                                    _categories = newCategories;
                                    _selectedCategory = categoryController.text;
                        });

                                  if (!mounted) return;
                        Navigator.pop(context);
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                          ),
                ],
                      );
                    },
            );
                });
              },
            ),
          ],
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedCategory ?? 'Tidak Ada Kategori',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.grey[600],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tambah Tugas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                color: Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _taskController,
                    decoration: const InputDecoration(
                      hintText: 'Masukan tugas baru disini',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF69D1F7),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow, color: Colors.white),
                  onPressed: _isLoading ? null : _createTask,
                ),
              ),
            ],
          ),
            if (_showSubtaskInput) ...[
              const SizedBox(height: 10),
              Row(
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
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          setState(() {
                            _subtasks.add(value);
                            _subtaskController.clear();
                            _showSubtaskInput = false;
                          });
                        }
                      },
                      autofocus: true,
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _showSubtaskInput = false;
                        _subtaskController.clear();
                      });
                    },
                  ),
                ],
              ),
            ],
            if (_subtasks.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._subtasks.asMap().entries.map((entry) {
                final index = entry.key;
                final subtask = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
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
                        child: Text(
                          subtask,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: Colors.grey[400],
                        ),
                        onPressed: () {
                          setState(() {
                            _subtasks.removeAt(index);
                          });
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
            children: [
              _buildCategoryButton(),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      if (_dueDate != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(_dueDate!),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
                GestureDetector(
                  onTap: _showPriorityDialog,
                  child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                      mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                          Icons.flag,
                      size: 16,
                          color: _selectedPriority != null 
                              ? priorities[_selectedPriority]
                              : Colors.grey[600],
                        ),
                        if (_selectedPriority != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            _selectedPriority!,
                            style: TextStyle(
                      color: Colors.grey[600],
                              fontSize: 12,
                            ),
                    ),
                        ],
                  ],
                ),
              ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showSubtaskInput = true;
                    });
                  },
                  child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                      mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                          Icons.checklist,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ],
                    ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _taskController.dispose();
    _notesController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }
}
