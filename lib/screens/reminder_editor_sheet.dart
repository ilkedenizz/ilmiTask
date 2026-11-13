import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../data/models/category_model.dart';
import '../data/models/reminder_model.dart';
import '../data/models/subtask_model.dart';
import '../data/repositories/reminder_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/location_picker_sheet.dart';

class ReminderEditorSheet extends StatefulWidget {
  final Reminder? reminder;
  final ReminderRepository repository;

  const ReminderEditorSheet({
    super.key,
    this.reminder,
    required this.repository,
  });

  static Future<bool?> show(
    BuildContext context, {
    Reminder? reminder,
    required ReminderRepository repository,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ReminderEditorSheet(
        reminder: reminder,
        repository: repository,
      ),
    );
  }

  @override
  State<ReminderEditorSheet> createState() => _ReminderEditorSheetState();
}

class _ReminderEditorSheetState extends State<ReminderEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _subtaskInputController = TextEditingController();

  List<CategoryModel> _categories = [];
  int? _selectedCategoryId;
  DateTime? _selectedDueDateTime;
  int _earlyAlertMinutes = 0;
  String _repeatRule = ReminderRepeatRule.none;
  String _alertSeverity = ReminderAlertSeverity.short;
  bool _isPinned = false;
  String? _imagePath;
  bool _enableLocation = false;
  double? _locationLat;
  double? _locationLng;
  double _locationRadius = 250.0;
  String _locationTriggerType = LocationTriggerType.arrive;

  // Checklist items
  final List<Subtask> _subtasks = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadCategories();

    if (widget.reminder != null) {
      final r = widget.reminder!;
      _titleController.text = r.title;
      _notesController.text = r.notes ?? '';
      _selectedCategoryId = r.categoryId;
      _selectedDueDateTime = r.dueDatetime;
      _earlyAlertMinutes = r.earlyAlertMinutes;
      _repeatRule = r.repeatRule;
      _alertSeverity = r.alertSeverity;
      _isPinned = r.isPinned;
      _imagePath = r.imagePath;
      _subtasks.addAll(r.subtasks);
      _locationLat = r.locationLat;
      _locationLng = r.locationLng;
      _locationRadius = r.locationRadius ?? 250.0;
      _locationTriggerType =
          r.locationTriggerType ?? LocationTriggerType.arrive;
      _enableLocation = r.locationLat != null && r.locationLng != null;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _subtaskInputController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await widget.repository.getAllCategories();
    setState(() {
      _categories = categories;
      if (_selectedCategoryId == null && _categories.isNotEmpty && widget.reminder == null) {
        _selectedCategoryId = _categories.first.id;
      }
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

  // Preset Date Handlers
  void _setPresetTodayEvening() {
    final now = DateTime.now();
    DateTime target = DateTime(now.year, now.month, now.day, 18, 0);
    if (now.isAfter(target)) {
      target = DateTime(now.year, now.month, now.day, 21, 0);
    }
    setState(() => _selectedDueDateTime = target);
  }

  void _setPresetTomorrowMorning() {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    setState(() {
      _selectedDueDateTime =
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
    });
  }

  void _setPresetNextWeek() {
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));
    setState(() {
      _selectedDueDateTime =
          DateTime(nextWeek.year, nextWeek.month, nextWeek.day, 9, 0);
    });
  }

  Future<void> _pickCustomDateTime() async {
    final now = DateTime.now();
    final initialDate = _selectedDueDateTime ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedDueDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _imagePath = picked.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to attach photo: $e')),
        );
      }
    }
  }

  void _addSubtask() {
    final text = _subtaskInputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _subtasks.add(
        Subtask(
          reminderId: widget.reminder?.id,
          title: text,
          isDone: false,
        ),
      );
      _subtaskInputController.clear();
    });
  }

  void _removeSubtask(int index) {
    setState(() {
      _subtasks.removeAt(index);
    });
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    final reminderToSave = Reminder(
      id: widget.reminder?.id,
      title: title,
      notes: notes,
      categoryId: _selectedCategoryId,
      dueDatetime: _selectedDueDateTime,
      earlyAlertMinutes: _earlyAlertMinutes,
      repeatRule: _repeatRule,
      alertSeverity: _alertSeverity,
      locationLat: _enableLocation ? (_locationLat ?? 39.9334) : null,
      locationLng: _enableLocation ? (_locationLng ?? 32.8597) : null,
      locationRadius: _enableLocation ? _locationRadius : null,
      locationTriggerType: _enableLocation ? _locationTriggerType : null,
      imagePath: _imagePath,
      isPinned: _isPinned,
      isCompleted: widget.reminder?.isCompleted ?? false,
      createdAt: widget.reminder?.createdAt ?? DateTime.now(),
      subtasks: _subtasks,
    );

    if (widget.reminder == null) {
      await widget.repository.insertReminder(reminderToSave);
    } else {
      await widget.repository.updateReminder(
        reminderToSave,
        syncSubtasks: true,
      );
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.reminder != null;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.90,
        child: Column(
          children: [
            // Header Handle and Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel',
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Edit Reminder' : 'New Reminder',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saveReminder,
                    child: Text(isEditing ? 'Save' : 'Create'),
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(20.0),
                  children: [
                    // Title Input
                    TextFormField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'What do you need to be reminded of?',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.task_alt),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a reminder title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Notes Input
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        hintText: 'Add extra details, checklist hints, or links',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Category & Pin Toggle Row
                    Row(
                      children: [
                        // Category Selector
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: _selectedCategoryId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            items: _categories.map((cat) {
                              final catColor = _parseColor(cat.colorHex);
                              return DropdownMenuItem<int?>(
                                value: cat.id,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: catColor,
                                      radius: 6,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(cat.name),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _selectedCategoryId = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Pin Toggle Switch
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isPinned
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined,
                                color: _isPinned
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                              ),
                              const SizedBox(width: 6),
                              const Text('Pin'),
                              Switch(
                                value: _isPinned,
                                onChanged: (val) =>
                                    setState(() => _isPinned = val),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 36),

                    // Due Date & Time Section
                    Row(
                      children: [
                        const Icon(Icons.event),
                        const SizedBox(width: 8),
                        Text(
                          'Schedule Date & Time',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_selectedDueDateTime != null)
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _selectedDueDateTime = null),
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text('No Alert'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Quick Preset Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.wb_twilight, size: 16),
                          label: const Text('Today Evening'),
                          onPressed: _setPresetTodayEvening,
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.wb_sunny_outlined, size: 16),
                          label: const Text('Tomorrow 09:00'),
                          onPressed: _setPresetTomorrowMorning,
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.next_plan_outlined, size: 16),
                          label: const Text('Next Week'),
                          onPressed: _setPresetNextWeek,
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.edit_calendar, size: 16),
                          label: Text(
                            _selectedDueDateTime != null
                                ? DateFormat('MMM d, y • HH:mm')
                                    .format(_selectedDueDateTime!)
                                : 'Custom Date/Time',
                            style: TextStyle(
                              fontWeight: _selectedDueDateTime != null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _selectedDueDateTime != null
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                          ),
                          onPressed: _pickCustomDateTime,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Early Alert & Repeat Row
                    Row(
                      children: [
                        // Early Alert Dropdown
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _earlyAlertMinutes,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Pre-Alert',
                              prefixIcon: Icon(Icons.hourglass_top),
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 0,
                                child: Text('None (On time)'),
                              ),
                              DropdownMenuItem(
                                value: 15,
                                child: Text('15 mins before'),
                              ),
                              DropdownMenuItem(
                                value: 30,
                                child: Text('30 mins before'),
                              ),
                              DropdownMenuItem(
                                value: 60,
                                child: Text('1 hour before'),
                              ),
                              DropdownMenuItem(
                                value: 1440,
                                child: Text('1 day before'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _earlyAlertMinutes = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Repeat Rule Dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _repeatRule,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Repeat',
                              prefixIcon: Icon(Icons.repeat),
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: ReminderRepeatRule.none,
                                child: Text('None'),
                              ),
                              DropdownMenuItem(
                                value: ReminderRepeatRule.daily,
                                child: Text('Daily'),
                              ),
                              DropdownMenuItem(
                                value: ReminderRepeatRule.weekdays,
                                child: Text('Weekdays'),
                              ),
                              DropdownMenuItem(
                                value: ReminderRepeatRule.weekly,
                                child: Text('Weekly'),
                              ),
                              DropdownMenuItem(
                                value: ReminderRepeatRule.monthly,
                                child: Text('Monthly'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _repeatRule = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 36),

                    // Alert Severity 3-Tier Selector
                    Text(
                      'Alert Severity',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildSeverityCard(
                          context,
                          severity: ReminderAlertSeverity.light,
                          title: 'Light',
                          subtitle: 'Silent, in shade',
                          icon: Icons.notifications_none,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(width: 8),
                        _buildSeverityCard(
                          context,
                          severity: ReminderAlertSeverity.short,
                          title: 'Short',
                          subtitle: 'Standard chime',
                          icon: Icons.notifications,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        _buildSeverityCard(
                          context,
                          severity: ReminderAlertSeverity.strongFullscreen,
                          title: 'Strong',
                          subtitle: 'Full-screen alarm',
                          icon: Icons.alarm,
                          color: Colors.red,
                        ),
                      ],
                    ),
                    const Divider(height: 36),

                    // Dynamic Checklist Builder
                    Row(
                      children: [
                        const Icon(Icons.checklist),
                        const SizedBox(width: 8),
                        Text(
                          'Checklist / Subtasks (${_subtasks.length})',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Subtask input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _subtaskInputController,
                            decoration: const InputDecoration(
                              hintText: 'Add a subtask item...',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addSubtask(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: _addSubtask,
                          icon: const Icon(Icons.add),
                          tooltip: 'Add item',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Subtask list
                    if (_subtasks.isNotEmpty)
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _subtasks.length,
                        onReorderItem: (oldIndex, newIndex) {
                          setState(() {
                            final item = _subtasks.removeAt(oldIndex);
                            _subtasks.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final item = _subtasks[index];
                          return ListTile(
                            key: ValueKey('st_$index'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: Icon(
                              item.isDone
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              color: item.isDone
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                decoration:
                                    item.isDone ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _removeSubtask(index),
                                ),
                                const Icon(Icons.drag_handle, size: 18),
                              ],
                            ),
                          );
                        },
                      ),
                    const Divider(height: 36),

                    // Image Attachment
                    Row(
                      children: [
                        const Icon(Icons.attach_file),
                        const SizedBox(width: 8),
                        Text(
                          'Photo Attachment',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_imagePath != null)
                          TextButton(
                            onPressed: () => setState(() => _imagePath = null),
                            child: const Text('Remove'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_imagePath != null && File(_imagePath!).existsSync())
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_imagePath!),
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                              ),
                              onPressed: () =>
                                  setState(() => _imagePath = null),
                              icon: const Icon(Icons.close, color: Colors.white),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('From Gallery'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Take Photo'),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),

                    // LOCATION TRIGGER (GEOFENCING) SECTION
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 18,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Location Trigger (Geofencing)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: _enableLocation,
                                activeThumbColor: AppColors.accent,
                                activeTrackColor:
                                    AppColors.accent.withValues(alpha: 0.3),
                                inactiveThumbColor: AppColors.textMuted,
                                inactiveTrackColor:
                                    AppColors.surfaceInteractive,
                                onChanged: (val) {
                                  setState(() {
                                    _enableLocation = val;
                                    if (val && _locationLat == null) {
                                      _locationLat = 39.9334;
                                      _locationLng = 32.8597;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                          if (_enableLocation) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'TRIGGER TYPE',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Center(
                                      child: Text('ARRIVING'),
                                    ),
                                    labelStyle: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _locationTriggerType ==
                                              LocationTriggerType.arrive
                                          ? AppColors.canvas
                                          : AppColors.textSecondary,
                                    ),
                                    selected: _locationTriggerType ==
                                        LocationTriggerType.arrive,
                                    selectedColor: AppColors.accent,
                                    backgroundColor:
                                        AppColors.surfaceInteractive,
                                    side: BorderSide(
                                      color: _locationTriggerType ==
                                              LocationTriggerType.arrive
                                          ? AppColors.accent
                                          : AppColors.cardBorder,
                                    ),
                                    onSelected: (val) {
                                      if (val) {
                                        setState(() {
                                          _locationTriggerType =
                                              LocationTriggerType.arrive;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Center(
                                      child: Text('LEAVING'),
                                    ),
                                    labelStyle: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _locationTriggerType ==
                                              LocationTriggerType.leave
                                          ? AppColors.canvas
                                          : AppColors.textSecondary,
                                    ),
                                    selected: _locationTriggerType ==
                                        LocationTriggerType.leave,
                                    selectedColor: AppColors.accent,
                                    backgroundColor:
                                        AppColors.surfaceInteractive,
                                    side: BorderSide(
                                      color: _locationTriggerType ==
                                              LocationTriggerType.leave
                                          ? AppColors.accent
                                          : AppColors.cardBorder,
                                    ),
                                    onSelected: (val) {
                                      if (val) {
                                        setState(() {
                                          _locationTriggerType =
                                              LocationTriggerType.leave;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'GEOFENCE RADIUS',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final r in [100.0, 250.0, 500.0, 1000.0])
                                  ChoiceChip(
                                    label: Text('${r.toInt()}m'),
                                    labelStyle: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _locationRadius == r
                                          ? AppColors.canvas
                                          : AppColors.textSecondary,
                                    ),
                                    selected: _locationRadius == r,
                                    selectedColor: AppColors.accent,
                                    backgroundColor:
                                        AppColors.surfaceInteractive,
                                    side: BorderSide(
                                      color: _locationRadius == r
                                          ? AppColors.accent
                                          : AppColors.cardBorder,
                                    ),
                                    onSelected: (val) {
                                      if (val) {
                                        setState(() => _locationRadius = r);
                                      }
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'COORDINATES',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  '${(_locationLat ?? 39.9334).toStringAsFixed(4)}, ${(_locationLng ?? 32.8597).toStringAsFixed(4)}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: [
                                ActionChip(
                                  label: const Text('Center'),
                                  labelStyle: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  backgroundColor:
                                      AppColors.surfaceInteractive,
                                  side: const BorderSide(
                                    color: AppColors.cardBorder,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _locationLat = 39.9334;
                                      _locationLng = 32.8597;
                                    });
                                  },
                                ),
                                ActionChip(
                                  label: const Text('Home'),
                                  labelStyle: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  backgroundColor:
                                      AppColors.surfaceInteractive,
                                  side: const BorderSide(
                                    color: AppColors.cardBorder,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _locationLat = 39.9208;
                                      _locationLng = 32.8541;
                                    });
                                  },
                                ),
                                ActionChip(
                                  label: const Text('Office'),
                                  labelStyle: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  backgroundColor:
                                      AppColors.surfaceInteractive,
                                  side: const BorderSide(
                                    color: AppColors.cardBorder,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _locationLat = 39.9080;
                                      _locationLng = 32.7800;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.accent,
                                  side: const BorderSide(
                                    color: AppColors.accent,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                ),
                                onPressed: () async {
                                  final result = await showModalBottomSheet<
                                      LocationPickerResult>(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (ctx) => LocationPickerSheet(
                                      initialLat: _locationLat,
                                      initialLng: _locationLng,
                                      initialRadius: _locationRadius,
                                    ),
                                  );

                                  if (result != null) {
                                    setState(() {
                                      _locationLat = result.latitude;
                                      _locationLng = result.longitude;
                                      _locationRadius = result.radius;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.map_outlined, size: 16),
                                label: const Text(
                                  'Open Dark Map Picker',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityCard(
    BuildContext context, {
    required String severity,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isSelected = _alertSeverity == severity;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _alertSeverity = severity),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.15)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : theme.colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected ? color : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
