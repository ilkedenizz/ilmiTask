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

enum FilterType { all, today, scheduled, pinned, location, completed, category }

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
    try {
      final categories = await _repository.getAllCategories();
      final reminders = await _repository.getAllReminders();

      if (mounted) {
        setState(() {
          _categories = categories;
          _allReminders = reminders;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('HomeScreen _loadData error: $e\n$stack');
      if (mounted) {
        setState(() {
          _categories = [];
          _allReminders = [];
          _isLoading = false;
        });
      }
    }
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

  DateTime get _startOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _endOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  bool _isToday(DateTime? dt) {
    if (dt == null) return false;
    return dt.isAfter(_startOfToday.subtract(const Duration(milliseconds: 1))) &&
        dt.isBefore(_endOfToday.add(const Duration(milliseconds: 1)));
  }

  // Dashboard Counts for Summary Cards
  int get _todayCount => _allReminders
      .where((r) => !r.isCompleted && _isToday(r.dueDatetime))
      .length;

  int get _scheduledCount => _allReminders
      .where((r) => !r.isCompleted && r.dueDatetime != null)
      .length;

  int get _pinnedCount =>
      _allReminders.where((r) => !r.isCompleted && r.isPinned).length;

  int get _locationCount => _allReminders
      .where((r) =>
          !r.isCompleted && r.locationLat != null && r.locationLng != null)
      .length;

  int get _completedCount =>
      _allReminders.where((r) => r.isCompleted).length;

  // Filter & Search Logic
  List<Reminder> get _filteredReminders {
    var list = _allReminders;

    // Apply active filter
    switch (_activeFilter) {
      case FilterType.all:
        list = list.where((r) => !r.isCompleted).toList();
        break;
      case FilterType.today:
        list = list
            .where((r) => !r.isCompleted && _isToday(r.dueDatetime))
            .toList();
        break;
      case FilterType.scheduled:
        list = list
            .where((r) => !r.isCompleted && r.dueDatetime != null)
            .toList();
        break;
      case FilterType.pinned:
        list = list.where((r) => r.isPinned && !r.isCompleted).toList();
        break;
      case FilterType.location:
        list = list
            .where((r) =>
                !r.isCompleted &&
                r.locationLat != null &&
                r.locationLng != null)
            .toList();
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

  // Section Partitioning
  List<Reminder> get _pinnedList {
    if (_activeFilter == FilterType.completed) return [];
    final pinned = _filteredReminders.where((r) => r.isPinned).toList();
    _sortRemindersByDueDate(pinned);
    return pinned;
  }

  List<Reminder> get _overdueList {
    if (_activeFilter == FilterType.completed ||
        _activeFilter == FilterType.pinned) {
      return [];
    }
    final now = DateTime.now();
    final list = _filteredReminders
        .where((r) =>
            !r.isPinned && r.dueDatetime != null && r.dueDatetime!.isBefore(now))
        .toList();
    _sortRemindersByDueDate(list);
    return list;
  }

  List<Reminder> get _upcomingList {
    if (_activeFilter == FilterType.completed ||
        _activeFilter == FilterType.pinned) {
      return [];
    }
    final now = DateTime.now();
    final list = _filteredReminders
        .where((r) =>
            !r.isPinned &&
            r.dueDatetime != null &&
            !r.dueDatetime!.isBefore(now))
        .toList();
    _sortRemindersByDueDate(list);
    return list;
  }

  List<Reminder> get _somedayList {
    if (_activeFilter == FilterType.completed ||
        _activeFilter == FilterType.pinned) {
      return [];
    }
    final list = _filteredReminders
        .where((r) => !r.isPinned && r.dueDatetime == null)
        .toList();
    _sortRemindersByDueDate(list);
    return list;
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

  void _toggleFilter(FilterType type) {
    setState(() {
      if (_activeFilter == type) {
        _activeFilter = FilterType.all;
      } else {
        _activeFilter = type;
      }
      _selectedCategoryId = null;
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
    final overdue = _overdueList;
    final upcoming = _upcomingList;
    final someday = _somedayList;
    final totalCount = _filteredReminders.length;

    return Scaffold(
      backgroundColor: AppColors.canvas,
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
              height: 38,
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
            const SizedBox(height: 8),

            // Top Summary Cards Grid (Samsung Reminder Dashboard Touch)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  // Row 1: Today & Scheduled
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          label: 'TODAY',
                          count: _todayCount,
                          icon: Icons.calendar_today_outlined,
                          accentColor: AppColors.accent,
                          isSelected: _activeFilter == FilterType.today,
                          onTap: () => _toggleFilter(FilterType.today),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          label: 'SCHEDULED',
                          count: _scheduledCount,
                          icon: Icons.event_outlined,
                          accentColor: const Color(0xFF38BDF8),
                          isSelected: _activeFilter == FilterType.scheduled,
                          onTap: () => _toggleFilter(FilterType.scheduled),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Row 2: Important, Location, Done
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          label: 'IMPORTANT',
                          count: _pinnedCount,
                          icon: Icons.push_pin_outlined,
                          accentColor: AppColors.accentAmber,
                          isSelected: _activeFilter == FilterType.pinned,
                          onTap: () => _toggleFilter(FilterType.pinned),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          label: 'LOCATION',
                          count: _locationCount,
                          icon: Icons.location_on_outlined,
                          accentColor: const Color(0xFFA78BFA),
                          isSelected: _activeFilter == FilterType.location,
                          onTap: () => _toggleFilter(FilterType.location),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          label: 'DONE',
                          count: _completedCount,
                          icon: Icons.check_circle_outline,
                          accentColor: AppColors.success,
                          isSelected: _activeFilter == FilterType.completed,
                          onTap: () => _toggleFilter(FilterType.completed),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

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
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 88),
                            children: [
                              // Completed Mode View
                              if (_activeFilter == FilterType.completed) ...[
                                _buildSectionHeader(
                                  'COMPLETED',
                                  _filteredReminders.length,
                                  icon: Icons.check_circle_outline,
                                  color: AppColors.success,
                                ),
                                ..._filteredReminders.map(
                                  (r) => ReminderCard(
                                    key: ValueKey('comp_${r.id}'),
                                    reminder: r,
                                    onToggleComplete: (val) =>
                                        _toggleComplete(r, val),
                                    onTogglePin: () => _togglePin(r),
                                    onDelete: () =>
                                        _deleteReminderWithUndo(r),
                                    onTap: () => _openEditor(r),
                                    onToggleSubtask: _toggleSubtask,
                                  ),
                                ),
                              ] else ...[
                                // 1. Pinned Section
                                if (pinned.isNotEmpty) ...[
                                  _buildSectionHeader(
                                    'PINNED',
                                    pinned.length,
                                    icon: Icons.push_pin,
                                    color: AppColors.accent,
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
                                  const SizedBox(height: 6),
                                ],

                                // 2. Overdue Section
                                if (overdue.isNotEmpty) ...[
                                  _buildSectionHeader(
                                    'OVERDUE / PASSED',
                                    overdue.length,
                                    icon: Icons.warning_amber_rounded,
                                    color: AppColors.danger,
                                  ),
                                  ...overdue.map((r) => ReminderCard(
                                        key: ValueKey('overdue_${r.id}'),
                                        reminder: r,
                                        onToggleComplete: (val) =>
                                            _toggleComplete(r, val),
                                        onTogglePin: () => _togglePin(r),
                                        onDelete: () =>
                                            _deleteReminderWithUndo(r),
                                        onTap: () => _openEditor(r),
                                        onToggleSubtask: _toggleSubtask,
                                      )),
                                  const SizedBox(height: 6),
                                ],

                                // 3. Upcoming Section
                                if (upcoming.isNotEmpty) ...[
                                  _buildSectionHeader(
                                    'UPCOMING',
                                    upcoming.length,
                                    icon: Icons.schedule,
                                    color: AppColors.accent,
                                  ),
                                  ...upcoming.map((r) => ReminderCard(
                                        key: ValueKey('upcoming_${r.id}'),
                                        reminder: r,
                                        onToggleComplete: (val) =>
                                            _toggleComplete(r, val),
                                        onTogglePin: () => _togglePin(r),
                                        onDelete: () =>
                                            _deleteReminderWithUndo(r),
                                        onTap: () => _openEditor(r),
                                        onToggleSubtask: _toggleSubtask,
                                      )),
                                  const SizedBox(height: 6),
                                ],

                                // 4. Someday / No Date Section
                                if (someday.isNotEmpty) ...[
                                  _buildSectionHeader(
                                    'ALL TASKS',
                                    someday.length,
                                    icon: Icons.inbox_outlined,
                                    color: AppColors.textMuted,
                                  ),
                                  ...someday.map((r) => ReminderCard(
                                        key: ValueKey('someday_${r.id}'),
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

  Widget _buildSummaryCard({
    required String label,
    required int count,
    required IconData icon,
    required Color accentColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.12)
              : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? accentColor : AppColors.textSecondary,
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: count > 0
                        ? (isSelected ? accentColor : AppColors.textPrimary)
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: isSelected ? accentColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count, {
    IconData? icon,
    Color color = AppColors.textMuted,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            '$title ($count)',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
        ],
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
    } else if (_activeFilter == FilterType.today) {
      message = 'No reminders due today.';
      icon = Icons.calendar_today_outlined;
    } else if (_activeFilter == FilterType.scheduled) {
      message = 'No scheduled reminders.';
      icon = Icons.event_outlined;
    } else if (_activeFilter == FilterType.pinned) {
      message = 'No pinned reminders.\nSwipe right on any task to pin it.';
      icon = Icons.push_pin_outlined;
    } else if (_activeFilter == FilterType.location) {
      message = 'No geofenced reminders.';
      icon = Icons.location_on_outlined;
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
