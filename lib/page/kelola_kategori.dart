import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryColor {
  static const List<Color> colors = [
    Color(0xFFFF5733), // Merah-Oranye
    Color(0xFFFFB733), // Kuning
    Color(0xFF8BC34A), // Hijau
    Color(0xFF009688), // Teal
    Color(0xFF2196F3), // Biru
    Color(0xFF9C27B0), // Ungu
  ];
}

class KelolaKategoriPage extends StatefulWidget {
  const KelolaKategoriPage({Key? key}) : super(key: key);

  @override
  State<KelolaKategoriPage> createState() => _KelolaKategoriPageState();
}

class _KelolaKategoriPageState extends State<KelolaKategoriPage> {
  List<Map<String, dynamic>> _categories = [];
  Map<String, int> _taskCounts = {};
  bool _isLoading = true;
  final TextEditingController _categoryController = TextEditingController();
  Color _selectedColor = CategoryColor.colors[4]; // Default blue color

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      
      final response = await Supabase.instance.client
          .from('profiles')
          .select('category, category_colors')
          .eq('id', userId)
          .single();

      if (response != null) {
        List<String> categories = [];
        Map<String, int> colors = {};
        
        if (response['category'] != null) {
          categories = List<String>.from(response['category']);
        }
        
        if (response['category_colors'] != null) {
          colors = Map<String, int>.from(response['category_colors']);
        }
        
        for (String category in categories) {
          final taskCount = await Supabase.instance.client
              .from('tasks')
              .select('id', const FetchOptions(count: CountOption.exact))
              .eq('user_id', userId)
              .eq('category', category);

          setState(() {
            _taskCounts[category] = taskCount.count ?? 0;
            _categories = categories.map((cat) => {
              'name': cat,
              'count': _taskCounts[cat] ?? 0,
              'color': colors[cat] ?? CategoryColor.colors[4].value,
            }).toList();
          });
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateCategories(List<Map<String, dynamic>> categories) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      List<String> categoryNames = categories.map((cat) => cat['name'] as String).toList();
      
      // Membuat map warna kategori
      Map<String, int> categoryColors = {};
      for (var category in categories) {
        categoryColors[category['name']] = category['color'] ?? CategoryColor.colors[4].value;
      }
      
      await Supabase.instance.client
          .from('profiles')
          .update({
            'category': categoryNames,
            'category_colors': categoryColors,
          })
          .eq('id', userId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori berhasil diperbarui')),
      );
      
      // Memperbarui tampilan kalender
      await _updateCalendarColors(categoryColors);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _updateCalendarColors(Map<String, int> categoryColors) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      
      // Update warna untuk semua tugas yang sesuai dengan kategori
      for (var entry in categoryColors.entries) {
        await Supabase.instance.client
            .from('tasks')
            .update({'color': entry.value})
            .eq('user_id', userId)
            .eq('category', entry.key);
      }
    } catch (e) {
      debugPrint('Error updating calendar colors: $e');
    }
  }

  Future<void> _editCategory(String oldName, Color currentColor) async {
    _categoryController.text = oldName;
    _selectedColor = currentColor;
    bool _showColorPicker = false;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Buat kategori baru',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _categoryController,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      suffixText: '${_categoryController.text.length}/50',
                      suffixStyle: TextStyle(color: Colors.grey[600]),
                    ),
                    maxLength: 50,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  ),
                ),
                const SizedBox(height: 24),
                InkWell(
                  onTap: () {
                    setState(() {
                      _showColorPicker = !_showColorPicker;
                    });
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Warna kategori',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Warna akan ditampilkan di antarmuka kalender',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showColorPicker) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ...CategoryColor.colors.map((color) => GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColor = color;
                            _showColorPicker = false;
                          });
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: color == _selectedColor
                                ? Border.all(color: Colors.blue, width: 2)
                                : null,
                          ),
                        ),
                      )),
                      // Custom color picker (disabled for now)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Icon(Icons.color_lens, color: Colors.grey[400], size: 18),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'BATAL',
                        style: TextStyle(
                          color: Colors.blue[200],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () async {
                        if (_categoryController.text.isNotEmpty) {
                          final newCategories = _categories.map((cat) {
                            if (cat['name'] == oldName) {
                              return {
                                'name': _categoryController.text,
                                'count': cat['count'],
                                'color': _selectedColor.value,
                              };
                            }
                            return cat;
                          }).toList();
                          
                          await _updateCategories(newCategories);
                          setState(() {
                            _categories = newCategories;
                          });
                          if (mounted) Navigator.pop(context);
                        }
                      },
                      child: Text(
                        'SIMPAN',
                        style: TextStyle(
                          color: Colors.blue[400],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCategory(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text('Apakah Anda yakin ingin menghapus kategori "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final newCategories = _categories.where((cat) => cat['name'] != name).toList();
      await _updateCategories(newCategories);
      setState(() {
        _categories = newCategories;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kelola Kategori',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  color: Colors.blue.shade50,
                  child: const Center(
                    child: Text(
                      'Kategori yang ditampilkan di beranda',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          return ReorderableDragStartListener(
                            key: ValueKey(category['name']),
                            index: index,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(category['color'] ?? CategoryColor.colors[4].value),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      category['name'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${category['count']}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    iconSize: 20,
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: Colors.grey[600],
                                    ),
                                    color: Colors.white,
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                      const PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text('Hapus'),
                                      ),
                                    ],
                                    onSelected: (String value) {
                                      if (value == 'edit') {
                                        _editCategory(category['name'], Color(category['color'] ?? CategoryColor.colors[4].value));
                                      } else if (value == 'delete') {
                                        _deleteCategory(category['name']);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            final item = _categories.removeAt(oldIndex);
                            _categories.insert(newIndex, item);
                            _updateCategories(_categories);
                          });
                        },
                      ),
                      InkWell(
                        onTap: () async {
                          _categoryController.clear();
                          await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: const Text('Kategori Baru'),
                              content: TextField(
                                controller: _categoryController,
                                decoration: const InputDecoration(
                                  labelText: 'Nama Kategori',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Batal'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    if (_categoryController.text.isNotEmpty) {
                                      final newCategory = {
                                        'name': _categoryController.text,
                                        'count': 0,
                                      };
                                      final newCategories = [..._categories, newCategory];
                                      await _updateCategories(newCategories);
                                      setState(() {
                                        _categories = newCategories;
                                      });
                                      if (mounted) Navigator.pop(context);
                                    }
                                  },
                                  child: const Text('Tambah'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              Icon(Icons.add, color: Colors.blue[400], size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'Buat baru',
                                style: TextStyle(
                                  color: Colors.blue[400],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Center(
                          child: Text(
                            'Klik lama dan seret untuk menyusun ulang',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
