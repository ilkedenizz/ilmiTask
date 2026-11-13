import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/models/category_model.dart';
import '../data/models/reminder_model.dart';
import '../data/models/subtask_model.dart';
import '../data/repositories/reminder_repository.dart';
import '../services/geofence_service.dart';
import '../theme/app_colors.dart';
import '../widgets/category_management_dialog.dart';
import '../widgets/reminder_card.dart';
import '../widgets/system_shield_banner.dart';
import '../widgets/system_shield_dialog.dart';
import 'reminder_editor_sheet.dart';

enum FilterType { all, pinned, completed, category }

class HomeScreen extends StatefulWidget {
  final ReminderRepository? repository;

  const HomeScreen({super.key, this.repository});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ReminderRepository _repository;
  final TextEditingController _searchController = TextEditingController();

  List<CategoryModel> _categories = [];
  List<Reminder> _allReminders = [];
  bool _isLoading = true;

  FilterType _activeFilter = FilterType.all;
  int? _selectedCategoryId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ReminderRepository();
    _loadData();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      GeofenceMonitorService().startMonitoring(repository: _repository);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final categories = await _repository.getAllCategories();
    final reminders = await _repository.getAllReminders();

    setState(() {
      _categories = categories;
      _allReminders = reminders;
      _isLoading = false;
    });
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.accent;
    try {
      final formatted = hex.replaceFirst('#', '');
      return Color(int.parse('FF$formatted', radix: 16));
    } catch (_) {
      return AppColors.accent;
    }
  }

  // Filter & Search Logic
  List<Reminder> get _filteredReminders {
    var list = _allReminders;

    // Apply main filter
    switch (_activeFilter) {
      case FilterType.all:
        list = list.where((r) => !r.isCompleted).toList();
        break;
      case FilterType.pinned:
        list = list.where((r) => r.isPinned && !r.isCompleted).toList();
        break;
      case FilterType.completed:
        list = list.where((r) => r.isCompleted).toList();
        break;
      case FilterType.category:
        if (_selectedCategoryId != null) {
          list = list
              .where((r) =>
                  r.categoryId == _selectedCategoryId && !r.isCompleted)
              .toList();
        }
        break;
    }

    // Apply search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((r) {
        final matchesTitle = r.title.toLowerCase().contains(q);
        final matchesNotes = r.notes?.toLowerCase().contains(q) ?? false;
        final matchesSubtask =
            r.subtasks.any((st) => st.title.toLowerCase().contains(q));
        return matchesTitle || matchesNotes || matchesSubtask;
      }).toList();
    }

    return list;
  }

  List<Reminder> get _pinnedList {
    if (_activeFilter == FilterType.completed) return [];
    final pinned = _filteredReminders.where((r) => r.isPinned).toList();
    _sortRemindersByDueDate(pinned);
    return pinned;
  }

  List<Reminder> get _unpinnedList {
    if (_activeFilter == FilterType.completed ||
        _activeFilter == FilterType.pinned) {
      return _filteredReminders;
    }
    final unpinned = _filteredReminders.where((r) => !r.isPinned).toList();
    _sortRemindersByDueDate(unpinned);
    return unpinned;
  }

  void _sortRemindersByDueDate(List<Reminder> list) {
    list.sort((a, b) {
      if (a.dueDatetime == null && b.dueDatetime == null) {
        return b.createdAt.compareTo(a.createdAt);
      }
      if (a.dueDatetime == null) return 1;
      if (b.dueDatetime == null) return -1;
      return a.dueDatetime!.compareTo(b.dueDatetime!);
    });
  }

  Future<void> _toggleComplete(Reminder reminder, bool isCompleted) async {
    if (reminder.id == null) return;
    await _repository.toggleReminderCompletion(reminder.id!, isCompleted);
    await _loadData();
  }

  Future<void> _togglePin(Reminder reminder) async {
    if (reminder.id == null) return;
    await _repository.toggleReminderPinned(reminder.id!, !reminder.isPinned);
    await _loadData();
  }

  Future<void> _toggleSubtask(Subtask subtask) async {
    if (subtask.id == null) return;
    await _repository.toggleSubtaskCompletion(subtask.id!, !subtask.isDone);
    await _loadData();
  }

  Future<void> _deleteReminderWithUndo(Reminder reminder) async {
    if (reminder.id == null) return;
    final deletedReminder = reminder;
    await _repository.deleteReminder(reminder.id!);
    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.cardBorder),
          ),
          content: Text(
            'Deleted "${deletedReminder.title}"',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.accent,
            onPressed: () async {
              await _repository
                  .insertReminder(deletedReminder.copyWith(id: null));
              await _loadData();
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _openEditor([Reminder? reminder]) async {
    final changed = await ReminderEditorSheet.show(
      context,
      reminder: reminder,
      repository: _repository,
    );
    if (changed == true) {
      await _loadData();
    }
  }

  Future<void> _openCategoryManager() async {
    await CategoryManagementDialog.show(context, repository: _repository);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final pinned = _pinnedList;
    final unpinned = _unpinnedList;
    final totalCount = _filteredReminders.length;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Search Input & Category Management Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: SearchBar(
                      controller: _searchController,
                      hintText: 'Search reminders...',
                      hintStyle: const WidgetStatePropertyAll(
                        TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                      textStyle: const WidgetStatePropertyAll(
                        TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      leading: const Icon(
                        Icons.search,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      trailing: [
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              Icons.clear,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                      ],
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                      },
                      backgroundColor:
                          const WidgetStatePropertyAll(AppColors.card),
                      elevation: const WidgetStatePropertyAll(0),
                      side: const WidgetStatePropertyAll(
                        BorderSide(color: AppColors.cardBorder, width: 1),
                      ),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.shield_outlined,
                        size: 19,
                        color: AppColors.textSecondary,
                      ),
                      tooltip: 'System Reliability Shield',
                      onPressed: () => SystemShieldDialog.show(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.category_outlined,
                        size: 19,
                        color: AppColors.textSecondary,
                      ),
                      tooltip: 'Manage Categories',
                      onPressed: _openCategoryManager,
                    ),
                  ),
                ],
              ),
            ),

            // Diagnostic Reliability Shield Banner
            SystemShieldBanner(
              onOpenShieldDialog: () => SystemShieldDialog.show(context),
            ),

            // Minimalist Category & Filter Bar
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFilterPill(
                    label: 'All',
                    selected: _activeFilter == FilterType.all,
                    onSelected: () {
                      setState(() {
                        _activeFilter = FilterType.all;
                        _selectedCategoryId = null;
                      });
                    },
                  ),
                  _buildFilterPill(
                    label: 'Pinned',
                    icon: Icons.push_pin,
                    selected: _activeFilter == FilterType.pinned,
                    onSelected: () {
                      setState(() {
                        _activeFilter = FilterType.pinned;
                        _selectedCategoryId = null;
                      });
                    },
                  ),
                  _buildFilterPill(
                    label: 'Completed',
                    icon: Icons.check_circle_outline,
                    selected: _activeFilter == FilterType.completed,
                    onSelected: () {
                      setState(() {
                        _activeFilter = FilterType.completed;
                        _selectedCategoryId = null;
                      });
                    },
                  ),
                  ..._categories.map((cat) {
                    final catColor = _parseColor(cat.colorHex);
                    final isSelected = _activeFilter == FilterType.category &&
                        _selectedCategoryId == cat.id;
                    return _buildFilterPill(
                      label: cat.name,
                      colorDot: catColor,
                      selected: isSelected,
                      onSelected: () {
                        setState(() {
                          _activeFilter = FilterType.category;
                          _selectedCategoryId = cat.id;
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Reminders List Body
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: 2,
                      ),
                    )
                  : totalCount == 0
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: AppColors.accent,
                          backgroundColor: AppColors.card,
                          onRefresh: _loadData,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
                            children: [
                              // Pinned Section
                              if (pinned.isNotEmpty &&
                                  _activeFilter != FilterType.pinned) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.push_pin,
                                        size: 13,
                                        color: AppColors.accent,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'PINNED (${pinned.length})',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.accent,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...pinned.map((r) => ReminderCard(
                                      key: ValueKey('pinned_${r.id}'),
                                      reminder: r,
                                      onToggleComplete: (val) =>
                                          _toggleComplete(r, val),
                                      onTogglePin: () => _togglePin(r),
                                      onDelete: () =>
                                          _deleteReminderWithUndo(r),
                                      onTap: () => _openEditor(r),
                                      onToggleSubtask: _toggleSubtask,
                                    )),
                                const SizedBox(height: 12),
                              ],

                              // Active / Non-pinned Section
                              if (unpinned.isNotEmpty) ...[
                                if (pinned.isNotEmpty &&
                                    _activeFilter != FilterType.pinned)
                                  Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(4, 6, 4, 6),
                                    child: Text(
                                      'TASKS (${unpinned.length})',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textMuted,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ...unpinned.map((r) => ReminderCard(
                                      key: ValueKey('rem_${r.id}'),
                                      reminder: r,
                                      onToggleComplete: (val) =>
                                          _toggleComplete(r, val),
                                      onTogglePin: () => _togglePin(r),
                                      onDelete: () =>
                                          _deleteReminderWithUndo(r),
                                      onTap: () => _openEditor(r),
                                      onToggleSubtask: _toggleSubtask,
                                    )),
                              ],
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'Add reminder',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    IconData? icon,
    Color? colorDot,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onSelected,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceInteractive : AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.cardBorder,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (colorDot != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colorDot,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: selected ? AppColors.accent : AppColors.textMuted,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = 'No reminders yet';
    IconData icon = Icons.event_available_outlined;

    if (_searchQuery.isNotEmpty) {
      message = 'No reminders matching "$_searchQuery"';
      icon = Icons.search_off;
    } else if (_activeFilter == FilterType.pinned) {
      message = 'No pinned reminders.\nSwipe right on any task to pin it.';
      icon = Icons.push_pin_outlined;
    } else if (_activeFilter == FilterType.completed) {
      message = 'No completed reminders yet.';
      icon = Icons.done_all;
    } else if (_activeFilter == FilterType.category) {
      message = 'No reminders in this category.';
      icon = Icons.folder_open;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: AppColors.borderInteractive,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
