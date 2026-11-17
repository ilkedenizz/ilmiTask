import 'package:flutter/material.dart';
import '../data/models/category_model.dart';
import '../data/repositories/reminder_repository.dart';
import '../theme/app_colors.dart';

class CategoryManagementDialog extends StatefulWidget {
  final ReminderRepository repository;
  final CategoryModel? initialCategoryToEdit;

  const CategoryManagementDialog({
    super.key,
    required this.repository,
    this.initialCategoryToEdit,
  });

  static Future<void> show(
    BuildContext context, {
    required ReminderRepository repository,
    CategoryModel? initialCategoryToEdit,
  }) {
    return showDialog(
      context: context,
      builder: (context) => CategoryManagementDialog(
        repository: repository,
        initialCategoryToEdit: initialCategoryToEdit,
      ),
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
  CategoryModel? _editingCategory;

  final List<String> _colorPresets = [
    '#FF5500', // International Orange
    '#3B82F6', // Blue
    '#10B981', // Emerald
    '#F59E0B', // Amber
    '#EF4444', // Red
    '#8B5CF6', // Purple
    '#06B6D4', // Cyan
    '#EC4899', // Pink
  ];
  late String _selectedColorHex;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategoryToEdit != null) {
      _editingCategory = widget.initialCategoryToEdit;
      _nameController.text = widget.initialCategoryToEdit!.name;
      _selectedColorHex = widget.initialCategoryToEdit!.colorHex;
    } else {
      _selectedColorHex = _colorPresets.first;
    }
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
      return AppColors.accent;
    }
  }

  Future<void> _saveCategory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    if (_editingCategory != null) {
      final updated = _editingCategory!.copyWith(
        name: name,
        colorHex: _selectedColorHex,
      );
      await widget.repository.updateCategory(updated);
      _editingCategory = null;
    } else {
      final newCat = CategoryModel(
        name: name,
        colorHex: _selectedColorHex,
        iconCode: Icons.folder.codePoint,
      );
      await widget.repository.insertCategory(newCat);
    }
    _nameController.clear();
    await _loadCategories();
  }

  Future<void> _deleteCategory(int id) async {
    await widget.repository.deleteCategory(id);
    if (_editingCategory?.id == id) {
      _editingCategory = null;
      _nameController.clear();
    }
    await _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _editingCategory != null;

    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      title: Row(
        children: [
          const Icon(Icons.category_outlined, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Text(
            isEditing ? 'Edit Category' : 'Manage Categories',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing
                        ? 'EDIT: ${_editingCategory!.name.toUpperCase()}'
                        : 'ADD CATEGORY',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isEditing ? AppColors.accent : AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (isEditing)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _editingCategory = null;
                          _nameController.clear();
                          _selectedColorHex = _colorPresets.first;
                        });
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Category name',
                        hintStyle: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.surfaceInteractive,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.cardBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.cardBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.accent,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _saveCategory,
                    icon: Icon(isEditing ? Icons.check : Icons.add, size: 20),
                    tooltip: isEditing ? 'Update Category' : 'Save Category',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Minimal color preset selector
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _colorPresets.map((hex) {
                  final color = _parseColor(hex);
                  final isSelected = _selectedColorHex == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorHex = hex),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Colors.white,
                                width: 2,
                              )
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 13,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const Divider(color: AppColors.cardBorder, height: 26),

              const Text(
                'Existing Categories',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (_categories.isEmpty)
                const Text(
                  'No categories found.',
                  style: TextStyle(color: AppColors.textMuted),
                )
              else
                ..._categories.map((cat) {
                  final catColor = _parseColor(cat.colorHex);
                  final isCurrentlyEditing = _editingCategory?.id == cat.id;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: isCurrentlyEditing
                          ? AppColors.surfaceInteractive
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrentlyEditing
                          ? Border.all(color: AppColors.accent.withValues(alpha: 0.5))
                          : null,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: catColor,
                        radius: 5,
                      ),
                      title: Text(
                        cat.name,
                        style: TextStyle(
                          fontWeight: isCurrentlyEditing
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize: 13,
                          color: isCurrentlyEditing
                              ? AppColors.accent
                              : AppColors.textPrimary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 17,
                              color: AppColors.textSecondary,
                            ),
                            tooltip: 'Edit',
                            onPressed: () {
                              setState(() {
                                _editingCategory = cat;
                                _nameController.text = cat.name;
                                _selectedColorHex = cat.colorHex;
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 17,
                              color: AppColors.danger,
                            ),
                            tooltip: 'Delete',
                            onPressed: () => _deleteCategory(cat.id!),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
