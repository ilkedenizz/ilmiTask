import 'package:flutter/material.dart';
import '../data/models/category_model.dart';
import '../data/models/reminder_model.dart';
import '../data/models/subtask_model.dart';
import '../data/repositories/reminder_repository.dart';
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
    if (hex == null || hex.isEmpty) return const Color(0xFF2196F3);
    try {
      final formatted = hex.replaceFirst('#', '');
      return Color(int.parse('FF$formatted', radix: 16));
    } catch (_) {
      return const Color(0xFF2196F3);
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

  // Split reminders into Pinned and Active (sorted by due_datetime)
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
      if (a.dueDatetime == null) return 1; // Tasks with no date at the bottom
      if (b.dueDatetime == null) return -1;
      return a.dueDatetime!.compareTo(b.dueDatetime!);
    });
  }

  // Actions
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
          content: Text('Deleted "${deletedReminder.title}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              // Re-insert reminder with subtasks
              await _repository.insertReminder(deletedReminder.copyWith(id: null));
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
    final theme = Theme.of(context);
    final pinned = _pinnedList;
    final unpinned = _unpinnedList;
    final totalCount = _filteredReminders.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Search Input & Category Management Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SearchBar(
                      controller: _searchController,
                      hintText: 'Search reminders...',
                      leading: const Icon(Icons.search),
                      trailing: [
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                      ],
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                      },
                      elevation: const WidgetStatePropertyAll(1),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.shield_outlined),
                    tooltip: 'System Reliability Shield',
                    onPressed: () => SystemShieldDialog.show(context),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.category_outlined),
                    tooltip: 'Manage Categories',
                    onPressed: _openCategoryManager,
                  ),
                ],
              ),
            ),

            // Diagnostic Reliability Shield Banner
            SystemShieldBanner(
              onOpenShieldDialog: () => SystemShieldDialog.show(context),
            ),

            // Category & Filter Bar (Horizontally scrollable)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // 'All' filter chip
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: _activeFilter == FilterType.all,
                      onSelected: (_) {
                        setState(() {
                          _activeFilter = FilterType.all;
                          _selectedCategoryId = null;
                        });
                      },
                    ),
                  ),
                  // 'Pinned' filter chip
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      avatar: const Icon(Icons.push_pin, size: 16),
                      label: const Text('Pinned'),
                      selected: _activeFilter == FilterType.pinned,
                      onSelected: (_) {
                        setState(() {
                          _activeFilter = FilterType.pinned;
                          _selectedCategoryId = null;
                        });
                      },
                    ),
                  ),
                  // 'Completed' filter chip
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      avatar: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Completed'),
                      selected: _activeFilter == FilterType.completed,
                      onSelected: (_) {
                        setState(() {
                          _activeFilter = FilterType.completed;
                          _selectedCategoryId = null;
                        });
                      },
                    ),
                  ),
                  // Dynamic SQLite Categories
                  ..._categories.map((cat) {
                    final catColor = _parseColor(cat.colorHex);
                    final isSelected = _activeFilter == FilterType.category &&
                        _selectedCategoryId == cat.id;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        avatar: CircleAvatar(
                          backgroundColor: catColor,
                          radius: 6,
                        ),
                        label: Text(cat.name),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _activeFilter = FilterType.category;
                            _selectedCategoryId = cat.id;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const Divider(height: 12),

            // Reminders List Body
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : totalCount == 0
                      ? _buildEmptyState(theme)
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(14, 6, 14, 80),
                            children: [
                              // Pinned Section
                              if (pinned.isNotEmpty &&
                                  _activeFilter != FilterType.pinned) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.push_pin,
                                        size: 16,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'PINNED (${pinned.length})',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
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
                                const SizedBox(height: 14),
                              ],

                              // Active / Non-pinned Section
                              if (unpinned.isNotEmpty) ...[
                                if (pinned.isNotEmpty &&
                                    _activeFilter != FilterType.pinned)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      'TASKS (${unpinned.length})',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
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
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Add reminder'),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
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
              size: 64,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
