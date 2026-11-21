import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';

class TaskRecord {
  const TaskRecord({
    required this.id,
    required this.title,
    required this.timeMinutes,
    required this.colorValue,
    required this.done,
    required this.reminder,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final int timeMinutes;
  final int colorValue;
  final bool done;
  final bool reminder;
  final DateTime createdAt;
  final DateTime? completedAt;

  TimeOfDay get time =>
      TimeOfDay(hour: timeMinutes ~/ 60, minute: timeMinutes % 60);
  Color get color => Color(colorValue);

  factory TaskRecord.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final created = data['createdAt'];
    final completed = data['completedAt'];
    return TaskRecord(
      id: doc.id,
      title: data['title'] as String? ?? '',
      timeMinutes: data['timeMinutes'] as int? ?? 0,
      colorValue: data['colorValue'] as int? ?? 0xff8878e8,
      done: data['done'] as bool? ?? false,
      reminder: data['reminder'] as bool? ?? false,
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
      completedAt: completed is Timestamp ? completed.toDate() : null,
    );
  }
}

class TaskRepository {
  TaskRepository(this.userId);
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _firestore.collection('users').doc(userId).collection('tasks');

  Future<List<TaskRecord>> loadTasks() async {
    final snapshot = await _tasks.get();
    final tasks = snapshot.docs.map(TaskRecord.fromDocument).toList();
    tasks.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return tasks;
  }

  Future<String> addTask({
    required String title,
    required TimeOfDay time,
    required Color color,
    required bool reminder,
  }) async {
    final ref = await _tasks.add({
      'title': title,
      'timeMinutes': time.hour * 60 + time.minute,
      'colorValue': color.toARGB32(),
      'done': false,
      'reminder': reminder,
      'createdAt': FieldValue.serverTimestamp(),
      'completedAt': null,
    });
    return ref.id;
  }

  Future<void> setDone(TaskRecord task, bool done) =>
      _tasks.doc(task.id).update({
        'done': done,
        'completedAt': done
            ? FieldValue.serverTimestamp()
            : FieldValue.delete(),
      });

  Future<void> updateTask({
    required String id,
    required String title,
    required TimeOfDay time,
    required bool reminder,
  }) => _tasks.doc(id).update({
    'title': title,
    'timeMinutes': time.hour * 60 + time.minute,
    'reminder': reminder,
  });

  Future<void> deleteTask(String id) => _tasks.doc(id).delete();
}
