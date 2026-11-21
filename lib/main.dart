import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'auth_gate.dart';
import 'firebase_options.dart';
import 'task_repository.dart';

final notifications = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  var firebaseReady = false;
  String? firebaseSetupError;
  if (Platform.isAndroid) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await notifications.initialize(
        const InitializationSettings(android: android),
      );
      firebaseReady = true;
    } catch (error) {
      firebaseSetupError = error.toString();
    }
  }
  runApp(
    DayflowApp(firebaseReady: firebaseReady, setupError: firebaseSetupError),
  );
}

class DayflowApp extends StatelessWidget {
  const DayflowApp({super.key, this.firebaseReady = false, this.setupError});
  final bool firebaseReady;
  final String? setupError;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Dayflow',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xfff7f7fb),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff6658e8)),
      fontFamily: 'Roboto',
    ),
    home: firebaseReady ? const AuthGate() : TodoHome(setupError: setupError),
  );
}

class TodoHome extends StatefulWidget {
  const TodoHome({super.key, this.userId, this.user, this.setupError});
  final String? userId;
  final User? user;
  final String? setupError;
  @override
  State<TodoHome> createState() => _TodoHomeState();
}

class _TodoHomeState extends State<TodoHome> with TickerProviderStateMixin {
  late final TaskRepository? _repository = widget.userId == null
      ? null
      : TaskRepository(widget.userId!);
  late final List<TaskRecord> items = widget.userId == null
      ? _sampleTasks()
      : <TaskRecord>[];
  bool _loadingTasks = false;
  int selected = 0;

  List<TaskRecord> _sampleTasks() => [
    TaskRecord(
      id: 'water',
      title: 'Drink a glass of water',
      timeMinutes: 630,
      colorValue: 0xff66b9e8,
      done: false,
      reminder: false,
      createdAt: DateTime(2026, 1, 1),
    ),
    TaskRecord(
      id: 'plan',
      title: 'Plan the week ahead',
      timeMinutes: 660,
      colorValue: 0xfff3b45d,
      done: false,
      reminder: false,
      createdAt: DateTime(2026, 1, 2),
    ),
    TaskRecord(
      id: 'break',
      title: 'Take a mindful break',
      timeMinutes: 735,
      colorValue: 0xffe782a8,
      done: false,
      reminder: false,
      createdAt: DateTime(2026, 1, 3),
    ),
    TaskRecord(
      id: 'proposal',
      title: 'Finish project proposal',
      timeMinutes: 840,
      colorValue: 0xff8878e8,
      done: false,
      reminder: false,
      createdAt: DateTime(2026, 1, 4),
    ),
  ];
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  int get completed => items.where((e) => e.done).length;

  @override
  void initState() {
    super.initState();
    if (_repository != null) _loadTasks();
  }

  Future<void> _loadTasks() async {
    final repository = _repository;
    if (repository == null) return;
    setState(() => _loadingTasks = true);
    try {
      final saved = await repository.loadTasks();
      if (mounted)
        setState(() {
          items
            ..clear()
            ..addAll(saved);
          _loadingTasks = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingTasks = false);
    }
  }

  Future<void> _toggleTask(TaskRecord item) async {
    final updatedDone = !item.done;
    final updated = TaskRecord(
      id: item.id,
      title: item.title,
      timeMinutes: item.timeMinutes,
      colorValue: item.colorValue,
      done: updatedDone,
      reminder: item.reminder,
      createdAt: item.createdAt,
      completedAt: updatedDone ? DateTime.now() : null,
    );
    setState(() {
      final index = items.indexWhere((task) => task.id == item.id);
      if (index >= 0) items[index] = updated;
    });
    final repository = _repository;
    if (repository != null) {
      try {
        await repository.setDone(item, updatedDone);
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not save this change. Check your connection.',
              ),
            ),
          );
      }
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  String get dateLabel {
    final now = tz.TZDateTime.now(tz.local);
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  Future<void> _schedule(TaskRecord item, int id) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      item.time.hour,
      item.time.minute,
    );
    if (!scheduled.isAfter(now))
      scheduled = scheduled.add(const Duration(days: 1));
    await notifications.zonedSchedule(
      id,
      'A little reminder 🌿',
      item.title,
      tz.TZDateTime.from(scheduled, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'todo_reminders',
          'To do reminders',
          channelDescription: 'Gentle reminders for your tasks',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> _addTask() => _editTask();

  Future<void> _editTask([TaskRecord? existing]) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final nowIst = tz.TZDateTime.now(tz.local);
    var time = existing?.time ?? TimeOfDay.fromDateTime(nowIst);
    var reminder = existing?.reminder ?? false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refresh) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  existing == null ? 'Make it happen' : 'Edit task',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: title,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'What would you like to do?',
                    filled: true,
                    fillColor: const Color(0xfff5f5f9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.schedule_rounded,
                    color: Color(0xff6658e8),
                  ),
                  title: const Text('Choose a time · IST'),
                  trailing: Text(
                    time.format(context),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: time,
                    );
                    if (picked != null) refresh(() => time = picked);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Remind me with vibration'),
                  value: reminder,
                  onChanged: (value) => refresh(() => reminder = value),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final taskTitle = title.text.trim();
                      if (taskTitle.isEmpty) return;
                      final canRemind = reminder && Platform.isAndroid;
                      try {
                        final repository = _repository;
                        final id =
                            existing?.id ??
                            (repository == null
                                ? DateTime.now().microsecondsSinceEpoch
                                      .toString()
                                : await repository.addTask(
                                    title: taskTitle,
                                    time: time,
                                    color: const Color(0xff8878e8),
                                    reminder: canRemind,
                                  ));
                        if (!mounted) return;
                        final item = TaskRecord(
                          id: id,
                          title: taskTitle,
                          timeMinutes: time.hour * 60 + time.minute,
                          colorValue: existing?.colorValue ?? 0xff8878e8,
                          done: existing?.done ?? false,
                          reminder: canRemind,
                          createdAt: existing?.createdAt ?? DateTime.now(),
                          completedAt: existing?.completedAt,
                        );
                        if (existing == null) {
                          setState(() => items.add(item));
                        } else {
                          if (repository != null)
                            await repository.updateTask(
                              id: id,
                              title: taskTitle,
                              time: time,
                              reminder: canRemind,
                            );
                          setState(() {
                            final index = items.indexWhere(
                              (task) => task.id == id,
                            );
                            if (index >= 0) items[index] = item;
                          });
                        }
                        if (canRemind) {
                          final androidPlugin = notifications
                              .resolvePlatformSpecificImplementation<
                                AndroidFlutterLocalNotificationsPlugin
                              >();
                          await androidPlugin?.requestNotificationsPermission();
                          await androidPlugin?.requestExactAlarmsPermission();
                          await _schedule(item, id.hashCode & 0x7fffffff);
                        } else if (existing?.reminder == true &&
                            Platform.isAndroid) {
                          await notifications.cancel(id.hashCode & 0x7fffffff);
                        } else if (reminder) {
                          if (sheetContext.mounted)
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Vibrating reminders are available on Android.',
                                ),
                              ),
                            );
                        }
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      } catch (_) {
                        if (sheetContext.mounted)
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not save this task. Check your connection and Firebase setup.',
                              ),
                            ),
                          );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff6658e8),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      existing == null ? 'Add to my day' : 'Save changes',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    title.dispose();
  }

  Future<void> _deleteTask(TaskRecord item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this task?'),
        content: Text('“${item.title}” will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repository?.deleteTask(item.id);
      if (Platform.isAndroid && item.reminder) {
        await notifications.cancel(item.id.hashCode & 0x7fffffff);
      }
      if (mounted)
        setState(() => items.removeWhere((task) => task.id == item.id));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete this task. Check your connection.'),
          ),
        );
    }
  }

  Future<void> _showTaskActions(TaskRecord item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit task'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete task',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') await _editTask(item);
    if (action == 'delete') await _deleteTask(item);
  }

  @override
  Widget build(BuildContext context) {
    final progress = items.isEmpty ? 0.0 : completed / items.length;
    final visibleItems =
        items
            .where(
              (item) =>
                  selected == 0 ||
                  (selected == 1 && !item.done) ||
                  (selected == 2 && item.done),
            )
            .toList()
          ..sort(
            (a, b) => selected == 2
                ? (b.completedAt ?? b.createdAt).compareTo(
                    a.completedAt ?? a.createdAt,
                  )
                : a.createdAt.compareTo(b.createdAt),
          );

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _intro, curve: Curves.easeOut),
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, .04),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic),
                ),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 110),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Row(
                        children: [
                          Container(
                            height: 42,
                            width: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xff6658e8),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 11),
                          const Text(
                            'dayflow',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.6,
                            ),
                          ),
                          const Spacer(),
                          if (widget.user != null)
                            AccountButton(user: widget.user!)
                          else
                            IconButton(
                              tooltip: 'Account sign-in',
                              onPressed: _showAccountSetup,
                              icon: const CircleAvatar(
                                backgroundColor: Color(0xffeceaff),
                                child: Icon(
                                  Icons.person_outline_rounded,
                                  color: Color(0xff6658e8),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          color: Color(0xff8d8c9b),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Make today\ncount.',
                        style: TextStyle(
                          fontSize: 36,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _progressCard(progress),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Text(
                            selected == 2
                                ? 'Completed history'
                                : 'Today’s tasks',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.4,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${items.length - completed} left',
                            style: const TextStyle(
                              color: Color(0xff9392a0),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          for (int i = 0; i < 3; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(['All', 'Upcoming', 'History'][i]),
                                selected: selected == i,
                                onSelected: (_) => setState(() => selected = i),
                                selectedColor: const Color(0xffe9e6ff),
                                backgroundColor: Colors.white,
                                side: BorderSide.none,
                                labelStyle: TextStyle(
                                  color: selected == i
                                      ? const Color(0xff6658e8)
                                      : const Color(0xff858492),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_loadingTasks)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (visibleItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 50),
                          child: Center(
                            child: Text(
                              selected == 2
                                  ? 'Completed tasks will appear here.'
                                  : 'A clear day. Add your first task ✨',
                            ),
                          ),
                        )
                      else
                        for (final item in visibleItems) _taskCard(item),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTask,
        backgroundColor: const Color(0xff6658e8),
        foregroundColor: Colors.white,
        elevation: 5,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New task',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _progressCard(double progress) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xff7163ec), Color(0xff9285f4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: const Color(0xff6658e8).withValues(alpha: .2),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR DAILY PROGRESS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                '$completed of ${items.length} tasks done',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                completed == items.length
                    ? 'You did it! Take a bow ✨'
                    : 'You’re doing great. Keep going ✨',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 66,
          width: 66,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            builder: (context, value, _) => Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: value,
                  strokeWidth: 6,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
                Text(
                  '${(value * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  void _showAccountSetup() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign in to sync'),
        content: Text(
          widget.setupError == null
              ? 'Sign-in and cloud history are available after Firebase is configured on Android.'
              : 'Finish Firebase setup to turn on Google/email sign-in and cloud history.\n\n${widget.setupError}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _taskCard(TaskRecord item) => AnimatedSize(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: item.done ? .62 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff29264b).withValues(alpha: .035),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: () => _toggleTask(item),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 24,
                  width: 24,
                  decoration: BoxDecoration(
                    color: item.done ? item.color : Colors.transparent,
                    border: Border.all(
                      color: item.done ? item.color : const Color(0xffd7d6e0),
                      width: 1.7,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: item.done
                      ? const Icon(
                          Icons.check_rounded,
                          size: 17,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          decoration: item.done
                              ? TextDecoration.lineThrough
                              : null,
                          color: const Color(0xff2e2d3a),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            item.done
                                ? Icons.check_circle_outline_rounded
                                : Icons.access_time_rounded,
                            size: 13,
                            color: item.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.done
                                ? 'Completed'
                                : '${item.time.format(context)} · IST',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xff92919e),
                            ),
                          ),
                          if (item.reminder && !item.done) ...[
                            const SizedBox(width: 9),
                            const Icon(
                              Icons.notifications_active_rounded,
                              size: 13,
                              color: Color(0xff6658e8),
                            ),
                            const SizedBox(width: 3),
                            const Text(
                              'Reminder on',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xff6658e8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Task actions',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showTaskActions(item),
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Color(0xffb3b2bf),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
