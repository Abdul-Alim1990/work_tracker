import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const WorkTrackerApp());
}

class WorkTrackerApp extends StatelessWidget {
  const WorkTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'متبع العمل 2026',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      home: const TaskHomeScreen(),
    );
  }
}

class TaskHomeScreen extends StatefulWidget {
  const TaskHomeScreen({super.key});

  @override
  State<TaskHomeScreen> createState() => _TaskHomeScreenState();
}

class _TaskHomeScreenState extends State<TaskHomeScreen> {
  List<Map<String, dynamic>> _tasks = [];
  final TextEditingController _taskController = TextEditingController();
  String _selectedPriority = 'عادي';

  @override
  void initState() {
    super.initState();
    _refreshTasks();
  }

  void _refreshTasks() async {
    final data = await DatabaseHelper.instance.readAllTasks();
    setState(() {
      _tasks = data;
    });
  }

  void _addTask() async {
    if (_taskController.text.isEmpty) return;

    await DatabaseHelper.instance.createTask({
      'title': _taskController.text,
      'isDone': 0,
      'priority': _selectedPriority,
    });

    if (_selectedPriority == 'عاجل') {
      NotificationService().showInstantNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: 'مهمة عاجلة جديدة',
        body: _taskController.text,
      );
    }

    _taskController.clear();
    _refreshTasks();
  }

  void _toggleTask(int id, int currentStatus) async {
    await DatabaseHelper.instance.updateTask({
      'id': id,
      'isDone': currentStatus == 1 ? 0 : 1,
      'title': _tasks.firstWhere((element) => element['id'] == id)['title'],
      'priority': _tasks.firstWhere((element) => element['id'] == id)['priority'],
    });
    _refreshTasks();
  }

  void _deleteTask(int id) async {
    await DatabaseHelper.instance.deleteTask(id);
    _refreshTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('متبع العمل 2026'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: const InputDecoration(
                      labelText: 'إضافة مهمة جديد...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedPriority,
                  items: <String>['عادي', 'عاجل'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedPriority = newValue!;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.teal, size: 36),
                  onPressed: _addTask,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return ListTile(
                  leading: Checkbox(
                    value: task['isDone'] == 1,
                    onChanged: (_) => _toggleTask(task['id'], task['isDone']),
                  ),
                  title: Text(
                    task['title'],
                    style: TextStyle(
                      decoration: task['isDone'] == 1
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  subtitle: Text('الأولوية: ${task['priority']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteTask(task['id']),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
