import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/category_model.dart';
import '../data/models/reminder_model.dart';
import '../data/models/subtask_model.dart';
import '../data/repositories/reminder_repository.dart';
import '../l10n/app_strings.dart';
import '../services/app_events.dart';
import '../services/geofence_service.dart';
import '../services/widget_service.dart';
import '../theme/app_colors.dart';
import '../widgets/category_management_dialog.dart';
import '../widgets/reminder_card.dart';
import '../widgets/system_shield_banner.dart';
import '../widgets/system_shield_dialog.dart';
import 'reminder_editor_sheet.dart';

enum FilterType { all, today, scheduled, pinned, location, completed, category }
enum HomeViewMode { list, calendar }

class HomeScreen extends StatefulWidget {
  final ReminderRepository? repository;

  const HomeScreen({super.key, this.repository});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final ReminderRepository _repository;
  final TextEditingController _searchController = TextEditingController();

  List<CategoryModel> _categories = [];
  List<Reminder> _allReminders = [];
  bool _isLoading = true;

  FilterType _activeFilter = FilterType.all;
  int? _selectedCategoryId;
  String _searchQuery = '';

  // Calendar / Agenda View state
  HomeViewMode _viewMode = HomeViewMode.list;
  late DateTime _selectedAgendaDate;
  late DateTime _agendaViewMonth;
  bool _agendaSlideForward = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedAgendaDate = DateTime(now.year, now.month, now.day);
    _agendaViewMonth = DateTime(now.year, now.month, 1);

    _repository = widget.repository ?? ReminderRepository();
    _loadData();
    WidgetsBinding.instance.addObserver(this);
    AppEvents.reminderDataRevision.addListener(_onExternalDataChange);

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      GeofenceMonitorService().startMonitoring(repository: _repository);
      WidgetService.listenForQuickAdd(() => _openEditor());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Background notification actions write SQLite from another isolate;
    // pick those changes up as soon as the user returns to the app.
    if (state == AppLifecycleState.resumed) {
      _loadData(silent: true);
    }
  }

  void _onExternalDataChange() {
    if (mounted) _loadData(silent: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppEvents.reminderDataRevision.removeListener(_onExternalDataChange);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final categories = await _repository.getAllCategories();
      final reminders = await _repository.getAllReminders();

      if (mounted) {
        setState(() {
          _categories = categories;
          _allReminders = reminders;
          _isLoading = false;
        });
        WidgetService.syncWidgetData(reminders);
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

  List<Reminder> get _agendaRemindersForSelectedDate {
    final list = _allReminders.where((r) {
      if (r.dueDatetime == null) return false;
      final d = r.dueDatetime!;
      return d.year == _selectedAgendaDate.year &&
          d.month == _selectedAgendaDate.month &&
          d.day == _selectedAgendaDate.day;
    }).toList();
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

  Future<void> _openEditor([Reminder? reminder, DateTime? prefilledDate]) async {
    final changed = await ReminderEditorSheet.show(
      context,
      reminder: reminder ??
          (prefilledDate != null
              ? Reminder(
                  title: '',
                  dueDatetime: prefilledDate,
                  createdAt: DateTime.now(),
                )
              : null),
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
    final strings = AppStrings.of(context);
    final filtered = _filteredReminders;
    final totalCount = filtered.length;

    // High-performance single-pass partitioning
    final pinned = <Reminder>[];
    final overdue = <Reminder>[];
    final upcoming = <Reminder>[];
    final someday = <Reminder>[];

    final now = DateTime.now();
    if (_activeFilter != FilterType.completed) {
      for (final r in filtered) {
        if (r.isPinned) {
          pinned.add(r);
        } else if (_activeFilter != FilterType.pinned) {
          if (r.dueDatetime == null) {
            someday.add(r);
          } else if (r.dueDatetime!.isBefore(now)) {
            overdue.add(r);
          } else {
            upcoming.add(r);
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Search Input, Language Toggle & Dialog Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SearchBar(
                      controller: _searchController,
                      hintText: strings.searchHint,
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
                  const SizedBox(width: 6),

                  // Language Toggle Button (TR / EN)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      LocaleController.instance.toggleLocale();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: strings.isTr
                              ? AppColors.accent.withValues(alpha: 0.6)
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'TR',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: strings.isTr
                                  ? AppColors.accent
                                  : AppColors.textMuted,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2.5),
                            child: Text(
                              '/',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          Text(
                            'EN',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: !strings.isTr
                                  ? AppColors.accent
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // System Shield Button
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
                      tooltip: strings.systemShieldTitle,
                      onPressed: () => SystemShieldDialog.show(context),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Category Management Button
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
                      tooltip: strings.manageCategories,
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

            // Prominent View Mode Switcher: [ LİSTE ] | [ AJANDA ]
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Container(
                height: 38,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            setState(() => _viewMode = HomeViewMode.list),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: _viewMode == HomeViewMode.list
                                ? AppColors.surfaceInteractive
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _viewMode == HomeViewMode.list
                                  ? AppColors.borderInteractive
                                  : Colors.transparent,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.format_list_bulleted,
                                size: 14,
                                color: _viewMode == HomeViewMode.list
                                    ? AppColors.accent
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                strings.viewList,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: _viewMode == HomeViewMode.list
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            setState(() => _viewMode = HomeViewMode.calendar),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: _viewMode == HomeViewMode.calendar
                                ? AppColors.surfaceInteractive
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _viewMode == HomeViewMode.calendar
                                  ? AppColors.borderInteractive
                                  : Colors.transparent,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                size: 14,
                                color: _viewMode == HomeViewMode.calendar
                                    ? AppColors.accent
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                strings.viewCalendar,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: _viewMode == HomeViewMode.calendar
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Conditional View Rendering: List Mode vs Calendar/Agenda Mode
            if (_viewMode == HomeViewMode.calendar)
              Expanded(
                child: _buildCalendarAgendaView(strings),
              )
            else ...[
              // Minimalist Category & Filter Bar
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildFilterPill(
                      label: strings.all,
                      selected: _activeFilter == FilterType.all,
                      onSelected: () {
                        setState(() {
                          _activeFilter = FilterType.all;
                          _selectedCategoryId = null;
                        });
                      },
                    ),
                    _buildFilterPill(
                      label: strings.pinned,
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
                      label: strings.completed,
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
                            if (_activeFilter == FilterType.category &&
                                _selectedCategoryId == cat.id) {
                              _activeFilter = FilterType.all;
                              _selectedCategoryId = null;
                            } else {
                              _activeFilter = FilterType.category;
                              _selectedCategoryId = cat.id;
                            }
                          });
                        },
                        onLongPress: () async {
                          await CategoryManagementDialog.show(
                            context,
                            repository: _repository,
                            initialCategoryToEdit: cat,
                          );
                          await _loadData();
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
                            label: strings.summaryToday,
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
                            label: strings.summaryScheduled,
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
                            label: strings.summaryImportant,
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
                            label: strings.summaryLocation,
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
                            label: strings.summaryDone,
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
                        ? _buildEmptyState(strings)
                        : RefreshIndicator(
                            color: AppColors.accent,
                            backgroundColor: AppColors.card,
                            onRefresh: _loadData,
                            child: Builder(
                              builder: (context) {
                                final listItems = <Widget>[];

                                // Completed Mode View
                                if (_activeFilter == FilterType.completed) {
                                  listItems.add(
                                    _buildSectionHeader(
                                      strings.isTr
                                          ? 'TAMAMLANANLAR'
                                          : 'COMPLETED',
                                      filtered.length,
                                      icon: Icons.check_circle_outline,
                                      color: AppColors.success,
                                    ),
                                  );
                                  for (final r in filtered) {
                                    listItems.add(
                                      ReminderCard(
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
                                    );
                                  }
                                } else {
                                  // 1. Pinned Section
                                  if (pinned.isNotEmpty) {
                                    listItems.add(
                                      _buildSectionHeader(
                                        strings.isTr ? 'SABİTLENEN' : 'PINNED',
                                        pinned.length,
                                        icon: Icons.push_pin,
                                        color: AppColors.accent,
                                      ),
                                    );
                                    for (final r in pinned) {
                                      listItems.add(
                                        ReminderCard(
                                          key: ValueKey('pinned_${r.id}'),
                                          reminder: r,
                                          onToggleComplete: (val) =>
                                              _toggleComplete(r, val),
                                          onTogglePin: () => _togglePin(r),
                                          onDelete: () =>
                                              _deleteReminderWithUndo(r),
                                          onTap: () => _openEditor(r),
                                          onToggleSubtask: _toggleSubtask,
                                        ),
                                      );
                                    }
                                    listItems.add(const SizedBox(height: 6));
                                  }

                                  // 2. Overdue Section
                                  if (overdue.isNotEmpty) {
                                    listItems.add(
                                      _buildSectionHeader(
                                        strings.isTr
                                            ? 'GECİKEN / GEÇMİŞ'
                                            : 'OVERDUE / PASSED',
                                        overdue.length,
                                        icon: Icons.warning_amber_rounded,
                                        color: AppColors.danger,
                                      ),
                                    );
                                    for (final r in overdue) {
                                      listItems.add(
                                        ReminderCard(
                                          key: ValueKey('overdue_${r.id}'),
                                          reminder: r,
                                          onToggleComplete: (val) =>
                                              _toggleComplete(r, val),
                                          onTogglePin: () => _togglePin(r),
                                          onDelete: () =>
                                              _deleteReminderWithUndo(r),
                                          onTap: () => _openEditor(r),
                                          onToggleSubtask: _toggleSubtask,
                                        ),
                                      );
                                    }
                                    listItems.add(const SizedBox(height: 6));
                                  }

                                  // 3. Upcoming Section
                                  if (upcoming.isNotEmpty) {
                                    listItems.add(
                                      _buildSectionHeader(
                                        strings.isTr
                                            ? 'YAKLAŞAN'
                                            : 'UPCOMING',
                                        upcoming.length,
                                        icon: Icons.schedule,
                                        color: AppColors.accent,
                                      ),
                                    );
                                    for (final r in upcoming) {
                                      listItems.add(
                                        ReminderCard(
                                          key: ValueKey('upcoming_${r.id}'),
                                          reminder: r,
                                          onToggleComplete: (val) =>
                                              _toggleComplete(r, val),
                                          onTogglePin: () => _togglePin(r),
                                          onDelete: () =>
                                              _deleteReminderWithUndo(r),
                                          onTap: () => _openEditor(r),
                                          onToggleSubtask: _toggleSubtask,
                                        ),
                                      );
                                    }
                                    listItems.add(const SizedBox(height: 6));
                                  }

                                  // 4. Someday / No Date Section
                                  if (someday.isNotEmpty) {
                                    listItems.add(
                                      _buildSectionHeader(
                                        strings.isTr
                                            ? 'TÜM GÖREVLER'
                                            : 'ALL TASKS',
                                        someday.length,
                                        icon: Icons.inbox_outlined,
                                        color: AppColors.textMuted,
                                      ),
                                    );
                                    for (final r in someday) {
                                      listItems.add(
                                        ReminderCard(
                                          key: ValueKey('someday_${r.id}'),
                                          reminder: r,
                                          onToggleComplete: (val) =>
                                              _toggleComplete(r, val),
                                          onTogglePin: () => _togglePin(r),
                                          onDelete: () =>
                                              _deleteReminderWithUndo(r),
                                          onTap: () => _openEditor(r),
                                          onToggleSubtask: _toggleSubtask,
                                        ),
                                      );
                                    }
                                  }
                                }

                                return ListView.builder(
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 4, 14, 88),
                                  itemCount: listItems.length,
                                  itemBuilder: (context, index) =>
                                      listItems[index],
                                );
                              },
                            ),
                          ),
              ),
            ],
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
        onPressed: () => _openEditor(null, _viewMode == HomeViewMode.calendar ? _selectedAgendaDate : null),
        icon: const Icon(Icons.add, size: 20),
        label: Text(
          strings.addReminderFab,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  // --- CALENDAR / AGENDA VIEW ---
  String _upper(AppStrings strings, String s) =>
      strings.isTr ? s.replaceAll('i', 'İ').toUpperCase() : s.toUpperCase();

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Color _categoryColorFor(Reminder r) {
    if (r.categoryId == null) return AppColors.textMuted;
    for (final c in _categories) {
      if (c.id == r.categoryId) return _parseColor(c.colorHex);
    }
    return AppColors.textMuted;
  }

  void _shiftAgendaMonth(int delta) {
    setState(() {
      _agendaSlideForward = delta > 0;
      _agendaViewMonth = DateTime(
        _agendaViewMonth.year,
        _agendaViewMonth.month + delta,
        1,
      );
    });
  }

  void _jumpAgendaToToday() {
    final now = DateTime.now();
    final target = DateTime(now.year, now.month, 1);
    setState(() {
      _agendaSlideForward = target.isAfter(_agendaViewMonth);
      _agendaViewMonth = target;
      _selectedAgendaDate = DateTime(now.year, now.month, now.day);
    });
  }

  DateTime get _selectedAgendaNoon => DateTime(
        _selectedAgendaDate.year,
        _selectedAgendaDate.month,
        _selectedAgendaDate.day,
        12,
        0,
      );

  Widget _buildCalendarAgendaView(AppStrings strings) {
    final daysInMonth = DateTime(
      _agendaViewMonth.year,
      _agendaViewMonth.month + 1,
      0,
    ).day;
    final firstWeekday =
        DateTime(_agendaViewMonth.year, _agendaViewMonth.month, 1).weekday;
    final leadingEmptyCount = firstWeekday - 1;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final agendaTasks = _agendaRemindersForSelectedDate;

    // Bucket the month's reminders by day once (O(n)) for cell previews.
    final Map<int, List<Reminder>> byDay = {};
    for (final r in _allReminders) {
      final d = r.dueDatetime;
      if (d == null) continue;
      if (d.year != _agendaViewMonth.year || d.month != _agendaViewMonth.month) {
        continue;
      }
      byDay.putIfAbsent(d.day, () => []).add(r);
    }
    for (final list in byDay.values) {
      list.sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        return a.dueDatetime!.compareTo(b.dueDatetime!);
      });
    }

    final isViewingCurrentMonth = _agendaViewMonth.year == today.year &&
        _agendaViewMonth.month == today.month;
    final pendingCount = agendaTasks.where((r) => !r.isCompleted).length;
    final doneCount = agendaTasks.length - pendingCount;
    final monthKey = '${_agendaViewMonth.year}-${_agendaViewMonth.month}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 88),
      children: [
        // Calendar Card Surface
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              // Month navigator
              Row(
                children: [
                  IconButton(
                    key: const Key('agenda_prev_month'),
                    icon: const Icon(Icons.chevron_left,
                        color: AppColors.textSecondary),
                    onPressed: () => _shiftAgendaMonth(-1),
                    tooltip: strings.isTr ? 'Önceki ay' : 'Previous month',
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        _upper(strings, strings.monthYear(_agendaViewMonth)),
                        key: ValueKey('title_$monthKey'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  if (!isViewingCurrentMonth ||
                      !_isSameDay(_selectedAgendaDate, today))
                    Tooltip(
                      message: strings.agendaJumpToday,
                      child: InkWell(
                        key: const Key('agenda_jump_today'),
                        borderRadius: BorderRadius.circular(6),
                        onTap: _jumpAgendaToToday,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Text(
                            strings.agendaToday,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  IconButton(
                    key: const Key('agenda_next_month'),
                    icon: const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                    onPressed: () => _shiftAgendaMonth(1),
                    tooltip: strings.isTr ? 'Sonraki ay' : 'Next month',
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Weekday labels
              Row(
                children: strings.weekdayShort
                    .map(
                      (w) => Expanded(
                        child: Center(
                          child: Text(
                            w,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 6),

              // Calendar Days Grid (swipeable, animated per month)
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v < -250) _shiftAgendaMonth(1);
                  if (v > 250) _shiftAgendaMonth(-1);
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final isIncoming =
                        child.key == ValueKey('grid_$monthKey');
                    final dir = _agendaSlideForward ? 1.0 : -1.0;
                    final begin = Offset(isIncoming ? 0.12 * dir : -0.12 * dir, 0);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: begin,
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, ?current],
                  ),
                  child: GridView.builder(
                    key: ValueKey('grid_$monthKey'),
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: leadingEmptyCount + daysInMonth,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      mainAxisExtent: 66,
                    ),
                    itemBuilder: (ctx, index) {
                      if (index < leadingEmptyCount) {
                        return const SizedBox.shrink();
                      }
                      final day = index - leadingEmptyCount + 1;
                      final cellDate = DateTime(
                        _agendaViewMonth.year,
                        _agendaViewMonth.month,
                        day,
                      );
                      return _buildCalendarCell(
                        strings: strings,
                        cellDate: cellDate,
                        tasks: byDay[day] ?? const [],
                        isSelected: _isSameDay(cellDate, _selectedAgendaDate),
                        isToday: _isSameDay(cellDate, today),
                        isPast: cellDate.isBefore(today),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Selected Date Agenda Header
        Row(
          children: [
            Container(
              width: 3,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _upper(strings, strings.agendaDate(_selectedAgendaDate)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    agendaTasks.isEmpty
                        ? strings.agendaTaskCount(0)
                        : strings.agendaSummary(pendingCount, doneCount),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('agenda_header_add'),
              icon: const Icon(Icons.add_circle_outline, color: AppColors.accent),
              tooltip: strings.addForThisDay,
              onPressed: () => _openEditor(null, _selectedAgendaNoon),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Tasks for selected date — animated per selected day
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(
              sizeFactor: animation,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(
                'agenda_${_selectedAgendaDate.toIso8601String()}_${agendaTasks.length}'),
            child: agendaTasks.isEmpty
                ? _buildAgendaEmptyState(strings)
                : Column(
                    children: [
                      for (int i = 0; i < agendaTasks.length; i++)
                        _buildAgendaTimelineRow(
                          strings,
                          agendaTasks[i],
                          isLast: i == agendaTasks.length - 1,
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarCell({
    required AppStrings strings,
    required DateTime cellDate,
    required List<Reminder> tasks,
    required bool isSelected,
    required bool isToday,
    required bool isPast,
  }) {
    const maxPreviews = 2;
    final previews = tasks.take(maxPreviews).toList();
    final overflow = tasks.length - previews.length;

    final Color dayColor = isSelected
        ? AppColors.canvas
        : (isToday
            ? AppColors.accent
            : (isPast ? AppColors.textMuted : AppColors.textPrimary));

    return InkWell(
      key: ValueKey(
          'cal_cell_${cellDate.year}_${cellDate.month}_${cellDate.day}'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _selectedAgendaDate = cellDate),
      onLongPress: () {
        setState(() => _selectedAgendaDate = cellDate);
        _openEditor(
          null,
          DateTime(cellDate.year, cellDate.month, cellDate.day, 12, 0),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(3, 3, 3, 2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.14)
              : (tasks.isNotEmpty
                  ? AppColors.surfaceInteractive
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.accent
                : (isToday
                    ? AppColors.accent.withValues(alpha: 0.45)
                    : (tasks.isNotEmpty
                        ? AppColors.cardBorder
                        : Colors.transparent)),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  height: 15,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${cellDate.day}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      height: 1.0,
                      fontWeight: isSelected || isToday
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: dayColor,
                    ),
                  ),
                ),
                const Spacer(),
                if (overflow > 0)
                  Text(
                    strings.agendaMore(overflow),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            for (final r in previews)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: _buildCellSnippet(r),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCellSnippet(Reminder r) {
    final color = _categoryColorFor(r);
    final time = r.dueDatetime != null
        ? DateFormat('HH:mm').format(r.dueDatetime!)
        : '';
    return Container(
      height: 20,
      padding: const EdgeInsets.only(left: 3, right: 1),
      decoration: BoxDecoration(
        color: AppColors.canvas.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(3),
        border: Border(left: BorderSide(color: color, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            r.title,
            maxLines: 1,
            overflow: TextOverflow.clip,
            softWrap: false,
            style: TextStyle(
              fontSize: 7.5,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: r.isCompleted
                  ? AppColors.textMuted
                  : AppColors.textPrimary,
              decoration: r.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          Text(
            time,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 6.5,
              height: 1.1,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaTimelineRow(
    AppStrings strings,
    Reminder r, {
    required bool isLast,
  }) {
    final color = _categoryColorFor(r);
    final due = r.dueDatetime;
    final timeLabel = due != null ? DateFormat('HH:mm').format(due) : '--:--';
    final isOverdue =
        due != null && !r.isCompleted && due.isBefore(DateTime.now());

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Text(
                  timeLabel,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: r.isCompleted
                        ? AppColors.textMuted
                        : (isOverdue ? AppColors.danger : AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: r.isCompleted ? Colors.transparent : color,
                    border: Border.all(color: color, width: 1.5),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.only(top: 4),
                      color: AppColors.cardBorder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ReminderCard(
              key: ValueKey('agenda_${r.id}'),
              reminder: r,
              onToggleComplete: (val) => _toggleComplete(r, val),
              onTogglePin: () => _togglePin(r),
              onDelete: () => _deleteReminderWithUndo(r),
              onTap: () => _openEditor(r),
              onToggleSubtask: _toggleSubtask,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaEmptyState(AppStrings strings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.08),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.event_available_outlined,
              size: 22,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            strings.emptyAgendaTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.emptyAgendaSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('agenda_empty_add'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.canvas,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => _openEditor(null, _selectedAgendaNoon),
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              strings.addForThisDay,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.16)
              : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.cardBorder,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 15,
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: count > 0
                        ? (isSelected ? AppColors.accent : AppColors.textPrimary)
                        : (isSelected ? AppColors.accent : AppColors.textMuted),
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
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
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
    VoidCallback? onLongPress,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onSelected,
        onLongPress: onLongPress,
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

  Widget _buildEmptyState(AppStrings strings) {
    String message = strings.emptyActiveSubtitle;
    IconData icon = Icons.event_available_outlined;

    if (_searchQuery.isNotEmpty) {
      message = 'No reminders matching "$_searchQuery"';
      icon = Icons.search_off;
    } else if (_activeFilter == FilterType.today) {
      message = strings.isTr ? 'Bugün için planlanan görev yok.' : 'No reminders due today.';
      icon = Icons.calendar_today_outlined;
    } else if (_activeFilter == FilterType.scheduled) {
      message = strings.isTr ? 'Planlanan hatırlatıcı yok.' : 'No scheduled reminders.';
      icon = Icons.event_outlined;
    } else if (_activeFilter == FilterType.pinned) {
      message = strings.isTr ? 'Sabitlenen görev yok.' : 'No pinned reminders.';
      icon = Icons.push_pin_outlined;
    } else if (_activeFilter == FilterType.location) {
      message = strings.isTr ? 'Konum uyarılı görev yok.' : 'No geofenced reminders.';
      icon = Icons.location_on_outlined;
    } else if (_activeFilter == FilterType.completed) {
      message = strings.isTr ? 'Henüz tamamlanan görev yok.' : 'No completed reminders yet.';
      icon = Icons.done_all;
    } else if (_activeFilter == FilterType.category) {
      message = strings.isTr ? 'Bu kategoride görev yok.' : 'No reminders in this category.';
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
