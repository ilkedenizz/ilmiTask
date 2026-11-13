import 'package:flutter/material.dart';
import '../data/models/category_model.dart';
import '../data/repositories/reminder_repository.dart';

class CategoryManagementDialog extends StatefulWidget {
  final ReminderRepository repository;

  const CategoryManagementDialog({super.key, required this.repository});

  static Future<void> show(
    BuildContext context, {
    required ReminderRepository repository,
  }) {
    return showDialog(
      context: context,
      builder: (context) => CategoryManagementDialog(repository: repository),
    );
  }

  @override
  State<CategoryManagementDialog> createState() =>
      _CategoryManagementDialogState();
}

class _CategoryManagementDialogState extends State<CategoryManagementDialog> {
  final TextEditingController _nameController = TextEditingController();
  List<CategoryModel> _categories = [];
  bool _isLoading = true;

  final List<String> _colorPresets = [
    '#2196F3', // Blue
    '#4CAF50', // Green
    '#FF9800', // Orange
    '#F44336', // Red
    '#9C27B0', // Purple
    '#009688', // Teal
    '#E91E63', // Pink
    '#795548', // Brown
  ];
  late String _selectedColorHex;

  @override
  void initState() {
    super.initState();
    _selectedColorHex = _colorPresets.first;
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final categories = await widget.repository.getAllCategories();
    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  Color _parseColor(String hex) {
    try {
      final formatted = hex.replaceFirst('#', '');
      return Color(int.parse('FF$formatted', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  Future<void> _addCategory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final newCat = CategoryModel(
      name: name,
      colorHex: _selectedColorHex,
      iconCode: Icons.folder.codePoint,
    );

    await widget.repository.insertCategory(newCat);
    _nameController.clear();
    await _loadCategories();
  }

  Future<void> _deleteCategory(int id) async {
    await widget.repository.deleteCategory(id);
    await _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.category_outlined),
          SizedBox(width: 8),
          Text('Manage Categories'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Create new category form
              Text(
                'Add Category',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'Category name',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addCategory,
                    icon: const Icon(Icons.add),
                    tooltip: 'Save Category',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Color preset picker
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _colorPresets.map((hex) {
                  final color = _parseColor(hex);
                  final isSelected = _selectedColorHex == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorHex = hex),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: theme.colorScheme.onSurface,
                                width: 2.5,
                              )
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 28),

              // Existing categories list
              Text(
                'Existing Categories',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_categories.isEmpty)
                const Text('No categories found.')
              else
                ..._categories.map((cat) {
                  final catColor = _parseColor(cat.colorHex);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: catColor,
                      radius: 8,
                    ),
                    title: Text(
                      cat.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.red,
                      ),
                      tooltip: 'Delete',
                      onPressed: () => _deleteCategory(cat.id!),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
