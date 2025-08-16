import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';

class MonthDayPicker extends StatefulWidget {
  final Set<DateTime> initialSelectedDays;
  final DateTime? initialMonth;
  final Function(Set<DateTime>) onDaysSelected;
  final String? title;
  final bool enableTimeSelection;
  final Function(Map<DateTime, Map<String, TimeOfDay>>)? onDaysWithTimesSelected;

  const MonthDayPicker({
    super.key,
    required this.initialSelectedDays,
    required this.onDaysSelected,
    this.initialMonth,
    this.title,
    this.enableTimeSelection = false,
    this.onDaysWithTimesSelected,
  });

  @override
  State<MonthDayPicker> createState() => _MonthDayPickerState();
}

class _MonthDayPickerState extends State<MonthDayPicker> {
  late DateTime _currentMonth;
  late Set<DateTime> _selectedDays;
  final Map<DateTime, Map<String, TimeOfDay>> _selectedDayTimes = {};

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.initialMonth ?? DateTime.now();
    _selectedDays = Set.from(widget.initialSelectedDays);
    
    // Initialize default times for selected days
    if (widget.enableTimeSelection) {
      for (final day in _selectedDays) {
        _selectedDayTimes[day] = {
          'start': const TimeOfDay(hour: 8, minute: 0),
          'end': const TimeOfDay(hour: 18, minute: 0),
        };
      }
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
  }

  void _toggleDay(DateTime day) async {
    if (_selectedDays.contains(day)) {
      // Remove day
      setState(() {
        _selectedDays.remove(day);
        _selectedDayTimes.remove(day);
      });
      widget.onDaysSelected(_selectedDays);
      if (widget.enableTimeSelection && widget.onDaysWithTimesSelected != null) {
        widget.onDaysWithTimesSelected!(_selectedDayTimes);
      }
    } else {
      // Add day
      if (widget.enableTimeSelection) {
        // Show time selection dialog
        final timeResult = await _showTimeSelectionDialog(day);
        if (timeResult != null) {
          setState(() {
            _selectedDays.add(day);
            _selectedDayTimes[day] = timeResult;
          });
          widget.onDaysSelected(_selectedDays);
          if (widget.onDaysWithTimesSelected != null) {
            widget.onDaysWithTimesSelected!(_selectedDayTimes);
          }
        }
      } else {
        setState(() {
          _selectedDays.add(day);
        });
        widget.onDaysSelected(_selectedDays);
      }
    }
  }

  Future<Map<String, TimeOfDay>?> _showTimeSelectionDialog(DateTime day) async {
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 18, minute: 0);

    return showDialog<Map<String, TimeOfDay>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Set Time for ${DateFormat.MMMd().format(day)}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Start Time'),
                    subtitle: Text(startTime.format(context)),
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: startTime,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          startTime = picked;
                        });
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time_filled),
                    title: const Text('End Time'),
                    subtitle: Text(endTime.format(context)),
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: endTime,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          endTime = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'start': startTime,
                      'end': endTime,
                    });
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editTimeForDay(DateTime day) async {
    final currentTimes = _selectedDayTimes[day];
    if (currentTimes == null) return;

    final timeResult = await _showTimeSelectionDialog(day);
    if (timeResult != null) {
      setState(() {
        _selectedDayTimes[day] = timeResult;
      });
      if (widget.onDaysWithTimesSelected != null) {
        widget.onDaysWithTimesSelected!(_selectedDayTimes);
      }
    }
  }

  List<DateTime> _getDaysInMonth() {
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    
    List<DateTime> days = [];
    for (int i = 1; i <= lastDay.day; i++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month, i));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth();
    final firstWeekday = days.first.weekday % 7; // 0 = Sunday
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title ?? AppLocalizations.of(context)!.selectDays,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Month navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  DateFormat.yMMMM().format(_currentMonth),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Weekday headers
            Row(
              children: [
                for (final weekday in [
                  AppLocalizations.of(context)!.sun,
                  AppLocalizations.of(context)!.mon,
                  AppLocalizations.of(context)!.tue,
                  AppLocalizations.of(context)!.wed,
                  AppLocalizations.of(context)!.thu,
                  AppLocalizations.of(context)!.fri,
                  AppLocalizations.of(context)!.sat,
                ])
                  Expanded(
                    child: Center(
                      child: Text(
                        weekday,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Calendar grid
            Expanded(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                ),
                itemCount: firstWeekday + days.length,
                itemBuilder: (context, index) {
                  if (index < firstWeekday) {
                    return const SizedBox(); // Empty cells for days before month starts
                  }
                  
                  final dayIndex = index - firstWeekday;
                  final day = days[dayIndex];
                  final isSelected = _selectedDays.contains(day);
                  final isToday = DateUtils.isSameDay(day, DateTime.now());
                  
                  return Padding(
                    padding: const EdgeInsets.all(2),
                    child: InkWell(
                      onTap: () => _toggleDay(day),
                      onLongPress: isSelected && widget.enableTimeSelection 
                          ? () => _editTimeForDay(day)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Theme.of(context).primaryColor
                              : isToday 
                                  ? Theme.of(context).primaryColor.withOpacity(0.2)
                                  : null,
                          borderRadius: BorderRadius.circular(8),
                          border: isToday && !isSelected
                              ? Border.all(color: Theme.of(context).primaryColor)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              day.day.toString(),
                              style: TextStyle(
                                color: isSelected 
                                    ? Colors.white
                                    : isToday
                                        ? Theme.of(context).primaryColor
                                        : null,
                                fontWeight: isSelected || isToday 
                                    ? FontWeight.bold 
                                    : null,
                              ),
                            ),
                            if (isSelected && widget.enableTimeSelection && _selectedDayTimes.containsKey(day))
                              Column(
                                children: [
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedDayTimes[day]!['start']!.format(context),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                    ),
                                  ),
                                  Text(
                                    _selectedDayTimes[day]!['end']!.format(context),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Selection summary and actions
            if (_selectedDays.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      AppLocalizations.of(context)!.selectedDaysCount(_selectedDays.length),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (widget.enableTimeSelection && _selectedDayTimes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Long press to edit times',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                    if (_selectedDays.length <= 5) ...[
                      const SizedBox(height: 4),
                      Text(
                        _selectedDays
                            .map((d) => DateFormat.MMMd().format(d))
                            .join(', '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedDays.clear();
                      });
                      widget.onDaysSelected(_selectedDays);
                    },
                    child: Text(AppLocalizations.of(context)!.clearSelection),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_selectedDays),
                    child: Text(AppLocalizations.of(context)!.done),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension AppLocalizationsMonthDayPicker on AppLocalizations {
  String get selectDays => 'Select Days';
  String get sun => 'Sun';
  String get mon => 'Mon';
  String get tue => 'Tue';
  String get wed => 'Wed';
  String get thu => 'Thu';
  String get fri => 'Fri';
  String get sat => 'Sat';
  String selectedDaysCount(int count) => '$count days selected';
  String get clearSelection => 'Clear';
  String get done => 'Done';
}