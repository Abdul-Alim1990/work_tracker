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
      title: 'Work Tracker 2026',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
      ),
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  String _priorityFilter = 'الكل';
  String _statusFilter = 'الكل';

  @override
  void initState() {
    super.initState();
    _refreshTasks();
    NotificationService().requestPermissions();
  }

  Future<void> _refreshTasks() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.readAllTasks();
    setState(() {
      _tasks = data;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredTasks {
    return _tasks.where((task) {
      final matchesPriority = _priorityFilter == 'الكل' || task['priority'] == _priorityFilter;
      final matchesStatus = _statusFilter == 'الكل' ||
          (_statusFilter == 'مكتملة' && task['isDone'] == 1) ||
          (_statusFilter == 'مفتوحة' && task['isDone'] == 0);
      return matchesPriority && matchesStatus;
    }).toList();
  }

  Future<void> _toggleTaskStatus(Map<String, dynamic> task) async {
    final updatedTask = {
      'id': task['id'],
      'title': task['title'],
      'isDone': task['isDone'] == 1 ? 0 : 1,
      'priority': task['priority'],
    };
    await DatabaseHelper.instance.updateTask(updatedTask);
    _refreshTasks();
  }

  Future<void> _deleteTask(int id) async {
    await DatabaseHelper.instance.deleteTask(id);
    _refreshTasks();
  }

  Future<void> _showAddTaskDialog() async {
    final TextEditingController titleController = TextEditingController();
    String selectedPriority = 'متوسطة';

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('إضافة مهمة جديدة', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(labelText: 'عنوان المهمة', alignLabelWithHint: true, border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    const Align(alignment: Alignment.centerRight, child: Text('درجة الأهمية (الأولوية):', style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedPriority,
                      alignment: Alignment.centerRight,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'عالية', child: Align(alignment: Alignment.centerRight, child: Text('عالية', style: TextStyle(color: Colors.red)))),
                        DropdownMenuItem(value: 'متوسطة', child: Align(alignment: Alignment.centerRight, child: Text('متوسطة', style: TextStyle(color: Colors.orange)))),
                        DropdownMenuItem(value: 'منخفضة', child: Align(alignment: Alignment.centerRight, child: Text('منخفضة', style: TextStyle(color: Colors.green)))),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedPriority = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(child: const Text('إلغاء'), onPressed: () => Navigator.of(dialogContext).pop()),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primaryContainer),
                  child: const Text('حفظ المهمة'),
                  onPressed: () async {
                    final taskTitle = titleController.text.trim();
                    if (taskTitle.isNotEmpty) {
                      final newTask = {'title': taskTitle, 'isDone': 0, 'priority': selectedPriority};
                      await DatabaseHelper.instance.createTask(newTask);
                      _refreshTasks();
                      if (selectedPriority == 'عالية') {
                        await NotificationService().showInstantNotification(
                          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                          title: 'مهمة عاجلة جديدة مضافة',
                          body: 'تذكير: لديك مهمة جديدة مضافة تحت الأولوية القصوى: $taskTitle',
                        );
                      }
                      if (context.mounted) Navigator.of(dialogContext).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يرجى كتابة عنوان المهمة أولاً', textDirection: TextDirection.rtl)),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'عالية': return Colors.red.shade100;
      case 'متوسطة': return Colors.orange.shade100;
      default: return Colors.green.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredTasks;
    return Scaffold(
      appBar: AppBar(title: const Text('متابعة العمل اليومي', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تصفية المهام:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['الكل', 'عالية', 'متوسطة', 'منخفضة'].map((priority) {
                        final isSelected = _priorityFilter == priority;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: FilterChip(
                            label: Text(priority),
                            selected: isSelected,
                            onSelected: (selected) => setState(() => _priorityFilter = priority),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: filteredList.isEmpty
                        ? const Center(child: Text('لا توجد مهام حالياً', style: TextStyle(color: Colors.grey, fontSize: 16)))
                        : ListView.builder(
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final task = filteredList[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: Checkbox(value: task['isDone'] == 1, onChanged: (_) => _toggleTaskStatus(task)),
                                  title: Text(
                                    task['title'],
                                    style: TextStyle(
                                      decoration: task['isDone'] == 1 ? TextDecoration.lineThrough : TextDecoration.none,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Chip(label: Text(task['priority']), backgroundColor: _getPriorityColor(task['priority'])),
                                      IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _deleteTask(task['id'])),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddTaskDialog, child: const Icon(Icons.add)),
    );
  }
}
