import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SideBar extends StatefulWidget {
  final Function(String) onTaskSelected;
  final Function() onRefresh;

  const SideBar({
    Key? key, 
    required this.onTaskSelected,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<SideBar> createState() => _SideBarState();
}

class _SideBarState extends State<SideBar> {
  List<Map<String, dynamic>> _tasks = [];
  List<String> _categories = [];
  bool _isLoading = true;
  bool _isCategoryExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      
      final categoryResponse = await Supabase.instance.client
          .from('profiles')
          .select('category')
          .eq('id', Supabase.instance.client.auth.currentUser!.id)
          .single();

      if (categoryResponse != null && categoryResponse['category'] != null) {
        _categories = List<String>.from(categoryResponse['category']);
      }

      final taskResponse = await Supabase.instance.client
          .from('tasks')
          .select()
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id)
          .eq('is_completed', false)
          .order('created_at', ascending: false);

      setState(() {
        _tasks = List<Map<String, dynamic>>.from(taskResponse);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading sidebar data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCategory(String category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text('Apakah Anda yakin ingin menghapus kategori "$category"?'),
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
        List<String> updatedCategories = _categories.where((c) => c != category).toList();
        
        await Supabase.instance.client
            .from('profiles')
            .update({
              'category': updatedCategories,
            })
            .eq('id', Supabase.instance.client.auth.currentUser!.id);
            
        await _loadData();
        widget.onRefresh();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kategori berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        debugPrint('Error deleting category: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus kategori: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteTask(String taskId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Tugas'),
        content: const Text('Apakah Anda yakin ingin menghapus tugas ini?'),
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
        await Supabase.instance.client
            .from('tasks')
            .delete()
            .eq('id', taskId);
            
        await _loadData();
        widget.onRefresh();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tugas berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        debugPrint('Error deleting task: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus tugas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createNewCategory() async {
    final TextEditingController _controller = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buat Kategori Baru'),
        content: TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: 'Nama kategori',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
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
                color: Color(0xFF69D1F7),
              ),
            ),
            onPressed: () => Navigator.pop(context, _controller.text),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      try {
        List<String> updatedCategories = [..._categories, result];
        
        await Supabase.instance.client
            .from('profiles')
            .update({
              'category': updatedCategories,
            })
            .eq('id', Supabase.instance.client.auth.currentUser!.id);
            
        await _loadData();
        widget.onRefresh();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kategori baru berhasil ditambahkan'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        debugPrint('Error creating category: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menambahkan kategori: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
        child: Column(
          children: [
          // Header
            Container(
              width: double.infinity,
              height: 120,
              color: const Color(0xFF69D1F7),
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            child: const Text(
                    "Kategori",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          
          // Content
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Kategori Section
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
              initiallyExpanded: _isCategoryExpanded,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const Icon(
                Icons.grid_view,
                color: Color(0xFF69D1F7),
                size: 20,
              ),
              title: const Text(
                "Kategori",
                style: TextStyle(
                  fontSize: 14,
                        fontWeight: FontWeight.w500,
                ),
              ),
              onExpansionChanged: (expanded) {
                setState(() => _isCategoryExpanded = expanded);
              },
              children: _categories.map((category) {
                return ListTile(
                        leading: const SizedBox(
                    width: 20,
                    height: 20,
                          child: Icon(
                            Icons.radio_button_unchecked,
                            size: 20,
                            color: Color(0xFF69D1F7),
                    ),
                  ),
                  title: Text(
                    category,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                  ),
                  trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                    onPressed: () => _deleteCategory(category),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 32),
                );
              }).toList(),
                  ),
            ),
            
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(height: 1),
                ),
            
                // Tasks Section
            if (_tasks.isNotEmpty) ...[
              Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  "Tugas",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                  ),
                ),
              ),
              ..._tasks.take(5).map((task) => 
                ListTile(
                      leading: const SizedBox(
                    width: 20,
                    height: 20,
                        child: Icon(
                          Icons.radio_button_unchecked,
                          size: 20,
                          color: Color(0xFF69D1F7),
                    ),
                  ),
                  title: Text(
                    task['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                    onPressed: () => _deleteTask(task['id']),
                  ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
                  onTap: () {
                    widget.onTaskSelected(task['id']);
                    Navigator.pop(context);
                  },
                ),
              ).toList(),
            ],
            
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(height: 1),
                ),

                // Add New Category Button
                ListTile(
                  leading: const Icon(
                      Icons.add,
                      color: Color(0xFF69D1F7),
                      size: 20,
                    ),
                  title: const Text(
                      "Buat Baru",
                      style: TextStyle(
                      color: Color(0xFF69D1F7),
                        fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  onTap: _createNewCategory,
                ),
              ],
              ),
            ),
          ],
      ),
    );
  }
}
