import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

enum PickerMode { date, time }

class DarkDateTimePickerSheet extends StatefulWidget {
  final DateTime? initialDateTime;

  const DarkDateTimePickerSheet({
    super.key,
    this.initialDateTime,
  });

  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initialDateTime,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DarkDateTimePickerSheet(
        initialDateTime: initialDateTime,
      ),
    );
  }

  @override
  State<DarkDateTimePickerSheet> createState() =>
      _DarkDateTimePickerSheetState();
}

class _DarkDateTimePickerSheetState extends State<DarkDateTimePickerSheet> {
  late DateTime _selectedDate;
  late int _selectedHour;
  late int _selectedMinute;
  late DateTime _viewMonth;
  PickerMode _currentMode = PickerMode.date;

  @override
  void initState() {
    super.initState();
    final init = widget.initialDateTime ?? DateTime.now();
    _selectedDate = DateTime(init.year, init.month, init.day);
    _selectedHour = init.hour;
    // Snap minutes to nearest 5 for clean UX if needed, or keep exact
    _selectedMinute = init.minute;
    _viewMonth = DateTime(init.year, init.month, 1);
  }

  DateTime get _composedDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedHour,
        _selectedMinute,
      );

  void _prevMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 1);
    });
  }

  void _adjustMinute(int delta) {
    setState(() {
      int totalMinutes = _selectedHour * 60 + _selectedMinute + delta;
      if (totalMinutes < 0) totalMinutes += 24 * 60;
      totalMinutes = totalMinutes % (24 * 60);
      _selectedHour = totalMinutes ~/ 60;
      _selectedMinute = totalMinutes % 60;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final formattedDate =
        DateFormat('EEE, MMM d, y').format(_selectedDate).toUpperCase();
    final formattedTime =
        '${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')}';

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: AppColors.cardBorder, width: 1),
          left: BorderSide(color: AppColors.cardBorder, width: 1),
          right: BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.dragHandle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header Bar with Monospace readout and close button
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceInteractive,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: const Text(
                        'SCHEDULE',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$formattedDate  ',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: formattedTime,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Mode Selector Tabs: [ DATE ] & [ TIME ]
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceInteractive,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(7),
                          onTap: () =>
                              setState(() => _currentMode = PickerMode.date),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _currentMode == PickerMode.date
                                  ? AppColors.accent
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 14,
                                  color: _currentMode == PickerMode.date
                                      ? AppColors.canvas
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'DATE',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: _currentMode == PickerMode.date
                                        ? AppColors.canvas
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(7),
                          onTap: () =>
                              setState(() => _currentMode = PickerMode.time),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _currentMode == PickerMode.time
                                  ? AppColors.accent
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.access_time_outlined,
                                  size: 14,
                                  color: _currentMode == PickerMode.time
                                      ? AppColors.canvas
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'TIME',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: _currentMode == PickerMode.time
                                        ? AppColors.canvas
                                        : AppColors.textSecondary,
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
                const SizedBox(height: 16),

                // Picker View depending on Mode
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _currentMode == PickerMode.date
                      ? _buildCalendarView()
                      : _buildTimeView(),
                ),
                const SizedBox(height: 18),

                // Bottom Confirmation Row
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.borderInteractive,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            foregroundColor: AppColors.textSecondary,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'CANCEL',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 44,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.canvas,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop(_composedDateTime);
                          },
                          child: const Text(
                            'SET DATE & TIME',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
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

  // --- CALENDAR VIEW ---
  Widget _buildCalendarView() {
    final monthTitle =
        DateFormat('MMMM yyyy').format(_viewMonth).toUpperCase();

    // Days calculation
    final daysInMonth =
        DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    // Weekday of 1st day (1 = Monday, 7 = Sunday)
    final firstWeekday =
        DateTime(_viewMonth.year, _viewMonth.month, 1).weekday;
    final leadingEmptyCount = firstWeekday - 1;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      key: const ValueKey('calendar_view'),
      children: [
        // Month navigator
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(
                Icons.chevron_left,
                color: AppColors.textSecondary,
              ),
              onPressed: _prevMonth,
              tooltip: 'Previous month',
            ),
            Text(
              monthTitle,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 1.0,
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
              onPressed: _nextMonth,
              tooltip: 'Next month',
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Weekday labels
        Row(
          children: const ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU']
              .map(
                (w) => Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),

        // Days Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leadingEmptyCount + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (ctx, index) {
            if (index < leadingEmptyCount) {
              return const SizedBox.shrink();
            }

            final day = index - leadingEmptyCount + 1;
            final cellDate =
                DateTime(_viewMonth.year, _viewMonth.month, day);
            final isSelected = cellDate.year == _selectedDate.year &&
                cellDate.month == _selectedDate.month &&
                cellDate.day == _selectedDate.day;
            final isToday = cellDate.year == today.year &&
                cellDate.month == today.month &&
                cellDate.day == today.day;

            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() => _selectedDate = cellDate);
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent
                      : (isToday
                          ? AppColors.surfaceInteractive
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accent
                        : (isToday
                            ? AppColors.accent.withValues(alpha: 0.5)
                            : Colors.transparent),
                  ),
                ),
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: isSelected
                        ? AppColors.canvas
                        : (isToday
                            ? AppColors.accent
                            : AppColors.textPrimary),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // Quick Preset Chips for Date
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            _buildQuickChip('Today', () {
              setState(() {
                _selectedDate = today;
                _viewMonth = DateTime(today.year, today.month, 1);
              });
            }),
            _buildQuickChip('Tomorrow', () {
              final tom = today.add(const Duration(days: 1));
              setState(() {
                _selectedDate = tom;
                _viewMonth = DateTime(tom.year, tom.month, 1);
              });
            }),
            _buildQuickChip('+3 Days', () {
              final d = today.add(const Duration(days: 3));
              setState(() {
                _selectedDate = d;
                _viewMonth = DateTime(d.year, d.month, 1);
              });
            }),
            _buildQuickChip('+1 Week', () {
              final w = today.add(const Duration(days: 7));
              setState(() {
                _selectedDate = w;
                _viewMonth = DateTime(w.year, w.month, 1);
              });
            }),
          ],
        ),
      ],
    );
  }

  // --- TIME VIEW ---
  Widget _buildTimeView() {
    return Column(
      key: const ValueKey('time_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Monospace Fine Adjuster Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceInteractive,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TIME FINE-TUNE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              Row(
                children: [
                  _buildStepperButton('-15m', () => _adjustMinute(-15)),
                  const SizedBox(width: 4),
                  _buildStepperButton('-5m', () => _adjustMinute(-5)),
                  const SizedBox(width: 4),
                  _buildStepperButton('+5m', () => _adjustMinute(5)),
                  const SizedBox(width: 4),
                  _buildStepperButton('+15m', () => _adjustMinute(15)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Hours Section
        const Text(
          'HOUR (24-HOUR)',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 24,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.5,
          ),
          itemBuilder: (ctx, h) {
            final isSelected = h == _selectedHour;
            return InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => setState(() => _selectedHour = h),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.surfaceInteractive,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accent
                        : AppColors.cardBorder,
                  ),
                ),
                child: Text(
                  h.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.canvas
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),

        // Minutes Section
        const Text(
          'MINUTES',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 12,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.5,
          ),
          itemBuilder: (ctx, idx) {
            final m = idx * 5;
            final isSelected = m == _selectedMinute;
            return InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => setState(() => _selectedMinute = m),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.surfaceInteractive,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accent
                        : AppColors.cardBorder,
                  ),
                ),
                child: Text(
                  m.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.canvas
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceInteractive,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildStepperButton(String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
