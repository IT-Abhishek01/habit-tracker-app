import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const HabitTrackerApp());
}

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFFF7A59);

    return MaterialApp(
      title: 'Habitly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF7F3F0),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Color(0xFFF7F3F0),
          elevation: 0,
          foregroundColor: Color(0xFF211A18),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: seed,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const HabitHomePage(),
    );
  }
}

class HabitHomePage extends StatefulWidget {
  const HabitHomePage({super.key});

  @override
  State<HabitHomePage> createState() => _HabitHomePageState();
}

class _HabitHomePageState extends State<HabitHomePage> {
  static const _storageKey = 'habitly.habits.v2';
  static const _settingsKey = 'habitly.settings.v1';

  final List<Habit> _habits = [];
  final TextEditingController _exploreSearchController =
      TextEditingController();

  bool _isLoading = true;
  bool _dailyReminderEnabled = true;
  bool _celebrationsEnabled = true;
  bool _compactMode = false;
  int _selectedTab = 0;
  int _selectedSlot = 0;
  DateTime _selectedDate = DateTime.now();
  String _exploreQuery = '';

  final List<HabitTemplate> _templates = const [
    HabitTemplate(
      title: 'Drink water',
      note: 'Eight glasses through the day',
      slotIndex: 0,
      colorIndex: 1,
      icon: Icons.water_drop,
    ),
    HabitTemplate(
      title: 'Read 10 pages',
      note: 'Build quiet focus daily',
      slotIndex: 3,
      colorIndex: 4,
      icon: Icons.menu_book,
    ),
    HabitTemplate(
      title: 'Morning walk',
      note: 'Fresh air before work',
      slotIndex: 0,
      colorIndex: 2,
      icon: Icons.directions_walk,
    ),
    HabitTemplate(
      title: 'Deep work',
      note: 'One focused session',
      slotIndex: 1,
      colorIndex: 0,
      icon: Icons.work,
    ),
    HabitTemplate(
      title: 'Stretch',
      note: 'Loosen shoulders and back',
      slotIndex: 2,
      colorIndex: 3,
      icon: Icons.self_improvement,
    ),
    HabitTemplate(
      title: 'Plan tomorrow',
      note: 'Pick the top three tasks',
      slotIndex: 3,
      colorIndex: 5,
      icon: Icons.event_note,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = _today;
    _selectedSlot = _currentSlotIndex();
    _loadState();
  }

  @override
  void dispose() {
    _exploreSearchController.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _weekStart =>
      _today.subtract(Duration(days: _today.weekday - 1));

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  String get _selectedDateKey => _dateKey(_selectedDate);

  List<Habit> get _visibleHabits =>
      _habits
          .where((habit) => habit.slotIndex == _selectedSlot && habit.isActive)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<Habit> get _activeHabits =>
      _habits.where((habit) => habit.isActive).toList();

  int get _completedForSelectedDate => _visibleHabits
      .where((habit) => habit.isCompletedOn(_selectedDateKey))
      .length;

  int get _todayCompleted => _activeHabits
      .where((habit) => habit.isCompletedOn(_dateKey(_today)))
      .length;

  int get _longestStreak {
    if (_activeHabits.isEmpty) return 0;
    return _activeHabits
        .map(_streakFor)
        .fold<int>(0, (best, value) => value > best ? value : best);
  }

  int get _weeklyTarget =>
      _activeHabits.fold<int>(0, (sum, habit) => sum + habit.weeklyGoal);

  int get _weeklyCompleted {
    final keys = List.generate(
      7,
      (index) => _dateKey(_weekStart.add(Duration(days: index))),
    ).toSet();
    return _activeHabits.fold<int>(
      0,
      (sum, habit) =>
          sum +
          habit.completedDates.where((date) => keys.contains(date)).length,
    );
  }

  double get _weeklyProgress {
    if (_weeklyTarget == 0) return 0;
    return (_weeklyCompleted / _weeklyTarget).clamp(0, 1).toDouble();
  }

  Habit? get _bestHabit {
    if (_activeHabits.isEmpty) return null;
    final ranked = [..._activeHabits]
      ..sort((a, b) {
        final weekCompare = _weeklyCountFor(b).compareTo(_weeklyCountFor(a));
        if (weekCompare != 0) return weekCompare;
        return _streakFor(b).compareTo(_streakFor(a));
      });
    return ranked.first;
  }

  String _dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return '${normalized.year}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
  }

  String _shortDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  int _currentSlotIndex() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 0;
    if (hour < 17) return 1;
    if (hour < 21) return 2;
    return 3;
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final rawHabits = prefs.getString(_storageKey);
    final rawSettings = prefs.getString(_settingsKey);

    if (rawHabits != null) {
      try {
        final decoded = jsonDecode(rawHabits) as List<dynamic>;
        _habits
          ..clear()
          ..addAll(
            decoded
                .whereType<Map<String, dynamic>>()
                .map(Habit.fromJson)
                .where((habit) => habit.title.trim().isNotEmpty),
          );
      } on FormatException {
        await prefs.remove(_storageKey);
      } on TypeError {
        await prefs.remove(_storageKey);
      }
    }

    if (rawSettings != null) {
      try {
        final decoded = jsonDecode(rawSettings) as Map<String, dynamic>;
        _dailyReminderEnabled =
            decoded['dailyReminderEnabled'] as bool? ?? true;
        _celebrationsEnabled = decoded['celebrationsEnabled'] as bool? ?? true;
        _compactMode = decoded['compactMode'] as bool? ?? false;
      } on FormatException {
        await prefs.remove(_settingsKey);
      } on TypeError {
        await prefs.remove(_settingsKey);
      }
    }

    for (final habit in _habits) {
      habit.streak = _streakFor(habit);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_habits.map((habit) => habit.toJson()).toList()),
    );
    await prefs.setString(
      _settingsKey,
      jsonEncode({
        'dailyReminderEnabled': _dailyReminderEnabled,
        'celebrationsEnabled': _celebrationsEnabled,
        'compactMode': _compactMode,
      }),
    );
  }

  bool _habitExists(String title, int slotIndex, {String? ignoreId}) {
    final normalized = title.trim().toLowerCase();
    return _habits.any(
      (habit) =>
          habit.id != ignoreId &&
          habit.isActive &&
          habit.slotIndex == slotIndex &&
          habit.title.trim().toLowerCase() == normalized,
    );
  }

  int _streakFor(Habit habit) {
    var streak = 0;
    var date = _today;
    while (habit.isCompletedOn(_dateKey(date))) {
      streak += 1;
      date = date.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _weeklyCountFor(Habit habit) {
    final keys = List.generate(
      7,
      (index) => _dateKey(_weekStart.add(Duration(days: index))),
    ).toSet();
    return habit.completedDates.where((date) => keys.contains(date)).length;
  }

  double _completionRateForDay(DateTime day) {
    if (_activeHabits.isEmpty) return 0;
    final key = _dateKey(day);
    final completed = _activeHabits
        .where((habit) => habit.isCompletedOn(key))
        .length;
    return completed / _activeHabits.length;
  }

  double _completionRateForSlot(int slotIndex) {
    final habits = _activeHabits
        .where((habit) => habit.slotIndex == slotIndex)
        .toList();
    if (habits.isEmpty) return 0;
    final completed = habits
        .where((habit) => habit.isCompletedOn(_selectedDateKey))
        .length;
    return completed / habits.length;
  }

  Future<void> _toggleHabit(Habit habit) async {
    setState(() {
      if (habit.isCompletedOn(_selectedDateKey)) {
        habit.completedDates.remove(_selectedDateKey);
      } else {
        habit.completedDates.add(_selectedDateKey);
      }
      habit.streak = _streakFor(habit);
    });
    await _saveState();
    _showSnack(
      habit.isCompletedOn(_selectedDateKey)
          ? 'Marked "${habit.title}" complete'
          : 'Unchecked "${habit.title}"',
    );
  }

  Future<void> _saveHabit(HabitDraft draft, {Habit? existing}) async {
    if (_habitExists(draft.title, draft.slotIndex, ignoreId: existing?.id)) {
      _showSnack(
        '${draft.title} already exists in ${HabitSlot.label(draft.slotIndex)}',
      );
      return;
    }

    setState(() {
      if (existing == null) {
        _habits.add(Habit.fromDraft(draft));
      } else {
        existing
          ..title = draft.title
          ..note = draft.note
          ..slotIndex = draft.slotIndex
          ..weeklyGoal = draft.weeklyGoal
          ..colorIndex = draft.colorIndex
          ..streak = _streakFor(existing);
      }
      _selectedSlot = draft.slotIndex;
    });
    await _saveState();
    _showSnack(existing == null ? 'Habit added' : 'Habit updated');
  }

  Future<void> _archiveHabit(Habit habit) async {
    setState(() => habit.isActive = false);
    await _saveState();
    _showSnack('${habit.title} archived');
  }

  Future<void> _deleteHabitForever(Habit habit) async {
    setState(() => _habits.removeWhere((item) => item.id == habit.id));
    await _saveState();
    _showSnack('${habit.title} deleted');
  }

  Future<void> _completeNextHabit() async {
    final next = _visibleHabits
        .where((habit) => !habit.isCompletedOn(_selectedDateKey))
        .firstOrNull;
    if (next == null) {
      _showSnack(
        _visibleHabits.isEmpty
            ? 'Add a habit for ${HabitSlot.label(_selectedSlot)} first'
            : 'All ${HabitSlot.label(_selectedSlot)} habits are done',
      );
      return;
    }
    await _toggleHabit(next);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _openHabitSheet({Habit? habit, HabitTemplate? template}) async {
    final titleController = TextEditingController(
      text: habit?.title ?? template?.title ?? '',
    );
    final noteController = TextEditingController(
      text: habit?.note ?? template?.note ?? '',
    );
    var selectedSlot = habit?.slotIndex ?? template?.slotIndex ?? _selectedSlot;
    var selectedColor = habit?.colorIndex ?? template?.colorIndex ?? 0;
    var weeklyGoal = habit?.weeklyGoal ?? 7;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final viewInsets = MediaQuery.of(context).viewInsets.bottom;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, viewInsets + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    habit == null ? 'Create habit' : 'Edit habit',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: titleController,
                    textInputAction: TextInputAction.next,
                    autofocus: habit == null && template == null,
                    decoration: const InputDecoration(
                      labelText: 'Habit name',
                      hintText: 'e.g. Read 10 pages',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: noteController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      hintText: 'Why this habit matters',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Routine time',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(HabitSlot.count, (index) {
                      return ChoiceChip(
                        label: Text(HabitSlot.label(index)),
                        selected: selectedSlot == index,
                        onSelected: (_) =>
                            setSheetState(() => selectedSlot = index),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Weekly goal',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '$weeklyGoal days',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  Slider(
                    value: weeklyGoal.toDouble(),
                    min: 1,
                    max: 7,
                    divisions: 6,
                    label: '$weeklyGoal',
                    onChanged: (value) =>
                        setSheetState(() => weeklyGoal = value.round()),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Color',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: List.generate(Habit.colors.length, (index) {
                      final color = Habit.colors[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => setSheetState(() => selectedColor = index),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedColor == index
                                  ? Colors.black
                                  : Colors.white,
                              width: 3,
                            ),
                          ),
                          child: selectedColor == index
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final title = titleController.text.trim();
                            if (title.isEmpty) {
                              _showSnack('Habit name is required');
                              return;
                            }
                            final draft = HabitDraft(
                              title: title,
                              note: noteController.text.trim(),
                              slotIndex: selectedSlot,
                              weeklyGoal: weeklyGoal,
                              colorIndex: selectedColor,
                            );
                            await _saveHabit(draft, existing: habit);
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                          child: Text(habit == null ? 'Create' : 'Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openHabitDetails(Habit habit) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final color = Habit.colors[habit.colorIndex];
        final weekCount = _weeklyCountFor(habit);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withAlpha(36),
                    child: Icon(Icons.track_changes, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${HabitSlot.label(habit.slotIndex)} - ${habit.weeklyGoal} day weekly goal',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (habit.note.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(habit.note),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Streak',
                      value: '${_streakFor(habit)}',
                      icon: Icons.local_fire_department,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      label: 'This week',
                      value: '$weekCount/${habit.weeklyGoal}',
                      icon: Icons.calendar_month,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await _toggleHabit(habit);
                },
                icon: Icon(
                  habit.isCompletedOn(_selectedDateKey)
                      ? Icons.undo
                      : Icons.check_circle_outline,
                ),
                label: Text(
                  habit.isCompletedOn(_selectedDateKey)
                      ? 'Uncheck selected day'
                      : 'Complete selected day',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _openHabitSheet(habit: habit);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _archiveHabit(habit);
                      },
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Archive'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openManageHabits() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final archived = _habits.where((habit) => !habit.isActive).toList();
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manage habits',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  if (_habits.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No habits yet. Create one from Today.'),
                    )
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          ..._activeHabits.map(
                            (habit) => _ManageHabitTile(
                              habit: habit,
                              onEdit: () {
                                Navigator.of(sheetContext).pop();
                                _openHabitSheet(habit: habit);
                              },
                              onArchive: () async {
                                await _archiveHabit(habit);
                                setSheetState(() {});
                              },
                              onDelete: () async {
                                await _deleteHabitForever(habit);
                                setSheetState(() {});
                              },
                            ),
                          ),
                          if (archived.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.only(top: 16, bottom: 8),
                              child: Text(
                                'Archived',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            ...archived.map(
                              (habit) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(habit.title),
                                subtitle: Text(
                                  HabitSlot.label(habit.slotIndex),
                                ),
                                trailing: TextButton(
                                  onPressed: () async {
                                    setState(() => habit.isActive = true);
                                    await _saveState();
                                    setSheetState(() {});
                                  },
                                  child: const Text('Restore'),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _openHabitSheet();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add habit'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmClearCompletedHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear completion history?'),
        content: const Text(
          'Your habits will stay, but all check marks and streaks will reset.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      for (final habit in _habits) {
        habit.completedDates.clear();
        habit.streak = 0;
      }
    });
    await _saveState();
    _showSnack('Completion history cleared');
  }

  Widget _buildPage() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return switch (_selectedTab) {
      1 => _buildExplorePage(),
      2 => _buildStatsPage(),
      3 => _buildSettingsPage(),
      _ => _buildTodayPage(),
    };
  }

  Widget _buildTodayPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroPanel(
            completed: _todayCompleted,
            total: _activeHabits.length,
            progress: _activeHabits.isEmpty
                ? 0
                : (_todayCompleted / _activeHabits.length).clamp(0, 1),
            onCompleteNext: _completeNextHabit,
            onAddHabit: _openHabitSheet,
          ),
          const SizedBox(height: 16),
          _buildWeekSelector(),
          const SizedBox(height: 16),
          _buildWeeklyProgressCard(),
          const SizedBox(height: 18),
          _buildSlotSelector(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Selected',
                  value: '$_completedForSelectedDate/${_visibleHabits.length}',
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Best streak',
                  value: '$_longestStreak',
                  icon: Icons.local_fire_department,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Habits',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: _openManageHabits,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Manage'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_visibleHabits.isEmpty)
            _EmptyState(onCreate: _openHabitSheet)
          else
            ..._visibleHabits.map(
              (habit) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HabitCard(
                  habit: habit,
                  selectedDateKey: _selectedDateKey,
                  weekCount: _weeklyCountFor(habit),
                  compact: _compactMode,
                  onToggle: () => _toggleHabit(habit),
                  onOpen: () => _openHabitDetails(habit),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeekSelector() {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = _weekStart.add(Duration(days: index));
          final selected = _dateKey(date) == _dateKey(_selectedDate);
          final completed = _completionRateForDay(date);
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 58,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF211A18) : Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    HabitSlot.weekdayLabel(index),
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 22,
                    height: 4,
                    decoration: BoxDecoration(
                      color: completed > 0
                          ? const Color(0xFFFF7A59)
                          : Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeeklyProgressCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Weekly plan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${_shortDate(_weekStart)} - ${_shortDate(_weekEnd)}',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _weeklyProgress,
                minHeight: 12,
                backgroundColor: const Color(0xFFF2E5DF),
                color: const Color(0xFFFF7A59),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$_weeklyCompleted of $_weeklyTarget weekly completions',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(HabitSlot.count, (index) {
          final count = _activeHabits
              .where((habit) => habit.slotIndex == index)
              .length;
          final selected = _selectedSlot == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(HabitSlot.icon(index), size: 17),
                  const SizedBox(width: 6),
                  Text(HabitSlot.label(index)),
                  const SizedBox(width: 6),
                  Text('$count'),
                ],
              ),
              onSelected: (_) => setState(() => _selectedSlot = index),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildExplorePage() {
    final query = _exploreQuery.trim().toLowerCase();
    final templates = _templates.where((template) {
      if (query.isEmpty) return true;
      return template.title.toLowerCase().contains(query) ||
          template.note.toLowerCase().contains(query) ||
          HabitSlot.label(template.slotIndex).toLowerCase().contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _exploreSearchController,
            onChanged: (value) => setState(() => _exploreQuery = value),
            decoration: InputDecoration(
              hintText: 'Search habit templates',
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _exploreQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _exploreSearchController.clear();
                        setState(() => _exploreQuery = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: templates.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              final template = templates[index];
              return _TemplateCard(
                template: template,
                onAdd: () => _openHabitSheet(template: template),
              );
            },
          ),
          if (templates.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.search_off, size: 42),
                      const SizedBox(height: 12),
                      const Text(
                        'No templates found',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          _exploreSearchController.clear();
                          setState(() => _exploreQuery = '');
                        },
                        child: const Text('Clear search'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsPage() {
    final bestHabit = _bestHabit;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Performance',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_shortDate(_weekStart)} - ${_shortDate(_weekEnd)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: 'Weekly',
                          value: '${(_weeklyProgress * 100).round()}%',
                          icon: Icons.insights,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricTile(
                          label: 'Streak',
                          value: '$_longestStreak',
                          icon: Icons.local_fire_department,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ...List.generate(7, (index) {
                    final day = _weekStart.add(Duration(days: index));
                    return Padding(
                      padding: EdgeInsets.only(bottom: index == 6 ? 0 : 12),
                      child: _ProgressRow(
                        label: HabitSlot.weekdayLabel(index),
                        value: _completionRateForDay(day),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Routine balance',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(HabitSlot.count, (index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == HabitSlot.count - 1 ? 0 : 12,
                      ),
                      child: _ProgressRow(
                        label: HabitSlot.label(index),
                        value: _completionRateForSlot(index),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFE3DA),
                child: Icon(Icons.emoji_events, color: Color(0xFFFF7A59)),
              ),
              title: Text(
                bestHabit == null ? 'No leader yet' : bestHabit.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                bestHabit == null
                    ? 'Create and complete habits to see insights.'
                    : 'Leading this week with ${_weeklyCountFor(bestHabit)} completions.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 26,
                        backgroundColor: Color(0xFFFFE3DA),
                        child: Text(
                          'H',
                          style: TextStyle(
                            color: Color(0xFFFF7A59),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Habitly',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Personal habit system',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: _openHabitSheet,
                        child: const Text('New'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Daily reminder'),
                    subtitle: const Text('Keep the reminder setting on'),
                    value: _dailyReminderEnabled,
                    onChanged: (value) async {
                      setState(() => _dailyReminderEnabled = value);
                      await _saveState();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Celebrations'),
                    subtitle: const Text(
                      'Show encouraging completion messages',
                    ),
                    value: _celebrationsEnabled,
                    onChanged: (value) async {
                      setState(() => _celebrationsEnabled = value);
                      await _saveState();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Compact habit cards'),
                    subtitle: const Text('Use denser cards on the Today page'),
                    value: _compactMode,
                    onChanged: (value) async {
                      setState(() => _compactMode = value);
                      await _saveState();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.list_alt),
                  title: const Text('Manage habits'),
                  subtitle: Text('${_habits.length} total habits'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openManageHabits,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: const Text('Clear completion history'),
                  subtitle: const Text('Keep habits, reset completions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _confirmClearCompletedHistory,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Today', 'Explore', 'Stats', 'Settings'];
    final subtitles = [
      'Track the routine in front of you',
      'Start from proven templates',
      'Study your weekly momentum',
      'Tune your habit system',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titles[_selectedTab],
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(
              subtitles[_selectedTab],
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Manage habits',
            onPressed: _openManageHabits,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: _buildPage(),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton.extended(
              onPressed: _openHabitSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add habit'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final int completed;
  final int total;
  final double progress;
  final VoidCallback onCompleteNext;
  final VoidCallback onAddHabit;

  const _HeroPanel({
    required this.completed,
    required this.total,
    required this.progress,
    required this.onCompleteNext,
    required this.onAddHabit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF211A18),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Build a day you can repeat.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              total == 0
                  ? 'Create your first habit and give the day a rhythm.'
                  : '$completed of $total habits completed today.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                color: const Color(0xFFFF7A59),
                backgroundColor: Colors.white12,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: total == 0 ? onAddHabit : onCompleteNext,
                    icon: Icon(total == 0 ? Icons.add : Icons.check),
                    label: Text(total == 0 ? 'Add habit' : 'Complete next'),
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

class _HabitCard extends StatelessWidget {
  final Habit habit;
  final String selectedDateKey;
  final int weekCount;
  final bool compact;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  const _HabitCard({
    required this.habit,
    required this.selectedDateKey,
    required this.weekCount,
    required this.compact,
    required this.onToggle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final color = Habit.colors[habit.colorIndex];
    final done = habit.isCompletedOn(selectedDateKey);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 18),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onToggle,
                child: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 34,
                  color: done ? color : Colors.black26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (!compact && habit.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        habit.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MiniChip(
                          icon: HabitSlot.icon(habit.slotIndex),
                          label: HabitSlot.label(habit.slotIndex),
                          color: color,
                        ),
                        _MiniChip(
                          icon: Icons.calendar_month,
                          label: '$weekCount/${habit.weeklyGoal} week',
                          color: color,
                        ),
                        _MiniChip(
                          icon: Icons.local_fire_department,
                          label: '${habit.streak} streak',
                          color: color,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final HabitTemplate template;
  final VoidCallback onAdd;

  const _TemplateCard({required this.template, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final color = Habit.colors[template.colorIndex];
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onAdd,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withAlpha(32),
                child: Icon(template.icon, color: color),
              ),
              const Spacer(),
              Text(
                template.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                template.note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      HabitSlot.label(template.slotIndex),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.add_circle_outline),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFFF7A59)),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double value;

  const _ProgressRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text('${(value * 100).round()}%'),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 10,
            color: const Color(0xFFFF7A59),
            backgroundColor: const Color(0xFFF2E5DF),
          ),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.self_improvement,
                size: 56,
                color: Color(0xFFFF7A59),
              ),
              const SizedBox(height: 12),
              const Text(
                'No habits in this routine',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create one small action you can repeat.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Create habit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManageHabitTile extends StatelessWidget {
  final Habit habit;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _ManageHabitTile({
    required this.habit,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = Habit.colors[habit.colorIndex];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(32),
        child: Icon(HabitSlot.icon(habit.slotIndex), color: color),
      ),
      title: Text(habit.title),
      subtitle: Text(
        '${HabitSlot.label(habit.slotIndex)} - ${habit.weeklyGoal} days/week',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'edit':
              onEdit();
              break;
            case 'archive':
              onArchive();
              break;
            case 'delete':
              onDelete();
              break;
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'archive', child: Text('Archive')),
          PopupMenuItem(value: 'delete', child: Text('Delete forever')),
        ],
      ),
    );
  }
}

class HabitDraft {
  final String title;
  final String note;
  final int slotIndex;
  final int weeklyGoal;
  final int colorIndex;

  const HabitDraft({
    required this.title,
    required this.note,
    required this.slotIndex,
    required this.weeklyGoal,
    required this.colorIndex,
  });
}

class HabitTemplate {
  final String title;
  final String note;
  final int slotIndex;
  final int colorIndex;
  final IconData icon;

  const HabitTemplate({
    required this.title,
    required this.note,
    required this.slotIndex,
    required this.colorIndex,
    required this.icon,
  });
}

class Habit {
  final String id;
  String title;
  String note;
  int slotIndex;
  int weeklyGoal;
  int colorIndex;
  DateTime createdAt;
  bool isActive;
  int streak;
  final Set<String> completedDates;

  Habit({
    String? id,
    required this.title,
    this.note = '',
    this.slotIndex = 0,
    this.weeklyGoal = 7,
    this.colorIndex = 0,
    DateTime? createdAt,
    this.isActive = true,
    this.streak = 0,
    Set<String>? completedDates,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now(),
       completedDates = completedDates ?? <String>{};

  factory Habit.fromDraft(HabitDraft draft) {
    return Habit(
      title: draft.title,
      note: draft.note,
      slotIndex: draft.slotIndex,
      weeklyGoal: draft.weeklyGoal,
      colorIndex: draft.colorIndex,
    );
  }

  factory Habit.fromJson(Map<String, dynamic> json) {
    final completed =
        (json['completedDates'] as List<dynamic>?)
            ?.whereType<String>()
            .toSet() ??
        <String>{};
    final createdAtRaw = json['createdAt'] as String?;
    final createdAt = createdAtRaw == null
        ? DateTime.now()
        : DateTime.tryParse(createdAtRaw) ?? DateTime.now();

    return Habit(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      note: json['note'] as String? ?? '',
      slotIndex: json['slotIndex'] as int? ?? json['hourIndex'] as int? ?? 0,
      weeklyGoal: (json['weeklyGoal'] as int? ?? 7).clamp(1, 7),
      colorIndex: (json['colorIndex'] as int? ?? 0).clamp(0, colors.length - 1),
      createdAt: createdAt,
      isActive: json['isActive'] as bool? ?? true,
      streak: json['streak'] as int? ?? 0,
      completedDates: completed,
    );
  }

  bool isCompletedOn(String dateKey) => completedDates.contains(dateKey);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'slotIndex': slotIndex,
      'weeklyGoal': weeklyGoal,
      'colorIndex': colorIndex,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'streak': streak,
      'completedDates': completedDates.toList()..sort(),
    };
  }

  static const List<Color> colors = [
    Color(0xFF4F46E5),
    Color(0xFF0F9F8D),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF7C3AED),
    Color(0xFFEF4444),
  ];
}

class HabitSlot {
  static const count = 4;

  static String label(int index) {
    return switch (index.clamp(0, count - 1)) {
      0 => 'Morning',
      1 => 'Afternoon',
      2 => 'Evening',
      _ => 'Night',
    };
  }

  static IconData icon(int index) {
    return switch (index.clamp(0, count - 1)) {
      0 => Icons.wb_sunny_outlined,
      1 => Icons.work_outline,
      2 => Icons.sunny_snowing,
      _ => Icons.dark_mode_outlined,
    };
  }

  static String weekdayLabel(int index) {
    return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][index];
  }
}
