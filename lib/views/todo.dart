import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:trackingtots/views/widgets/top_navigation_bar.dart';
import 'package:trackingtots/user_state.dart';
import 'package:trackingtots/views/widgets/form_builder.dart';
import 'package:trackingtots/views/widgets/modal_sheet.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';

class TodoForm extends StatefulWidget {
  @override
  _TodoFormState createState() => _TodoFormState();
}

class _TodoFormState extends State<TodoForm> {
  final _formKey = GlobalKey<FormState>();
  DateTime _time = DateTime.now();
  String _notes = '';
  List<Map<String, dynamic>> _todos = [];
  int _todayTasks = 0;
  int _completedTasks = 0;
  int _pendingTasks = 0;
  DateTime? _reminderTime;
  int _selectedReminderOffsetIndex = 1;
  final List<int> _reminderOffsets = [0, 10, 20, 30, 60];
  final List<String> _reminderOptions = [
    "At time of task",
    "10 minutes before",
    "20 minutes before",
    "30 minutes before",
    "1 hour before",
  ];
  bool _isSettingReminder = false;

  @override
  void initState() {
    super.initState();
    _fetchTodos();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      if (notification != null && android != null) {
        showDialog(
          context: context,
          builder: (_) {
            return AlertDialog(
              title: Text(notification.title ?? 'Reminder'),
              content: Text(notification.body ?? 'You have a task due soon!'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'),
                )
              ]
            );
          },
        );
      }
    });
  }

  void _showReminderOffsetPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: CupertinoPicker(
          itemExtent: 32,
          scrollController: FixedExtentScrollController(initialItem: _selectedReminderOffsetIndex),
          onSelectedItemChanged: (index) {
            setState(() {
              _selectedReminderOffsetIndex = index;
              _reminderTime = _time.subtract(Duration(minutes: _reminderOffsets[index]));
            });
          },
          children: _reminderOptions.map((option) => Text(option)).toList(),
        ),
      ),
    );
  }

  Future<void> _fetchTodos() async {
    if (UserState.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to view your to-dos.'))
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    // final response = await http.get(Uri.parse('https://tracking-tots.onrender.com/todo/${UserState.userId}'));
    final response = await http.get(Uri.parse('http://127.0.0.1:5001/todo/${UserState.userId}'));
    print('Fetch Response: ${response.body}');
    if (response.statusCode == 200) {
      setState(() {
        _todos = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        _processData();
      });
    }
  }

  void _processData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _todayTasks = _todos.where((todo) {
      final todoDate = DateTime.parse(todo['time']);
      return todoDate.year == today.year &&
             todoDate.month == today.month &&
             todoDate.day == today.day;
    }).length;

    _completedTasks = _todos.where((todo) => todo['completed'] == true).length;
    _pendingTasks = _todos.length - _completedTasks;
  }

  Widget _buildTodoSummaryCards() {
    return SizedBox(
      height: 160,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          CommonFormWidgets.buildSummaryCard(
            'Today Tasks',
            '$_todayTasks',
            Icons.today,
            Colors.indigo,
          ),
          CommonFormWidgets.buildSummaryCard(
            'Completed Tasks',
            '$_completedTasks',
            Icons.check_circle,
            Colors.green,
          ),
          CommonFormWidgets.buildSummaryCard(
            'Pending Tasks',
            '$_pendingTasks',
            Icons.pending,
            Colors.amber,
          ),
        ],
      ),
    );
  }

  void _showAddTodoDialog(BuildContext context) {
    setState(() {
      _reminderTime = _time.subtract(Duration(minutes: _reminderOffsets[_selectedReminderOffsetIndex]));
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BaseModalSheet(
        title: 'Add To-Do',
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                CommonFormWidgets.buildFormCard(
                  title: 'Due Date & Time',
                  child: CommonFormWidgets.buildDateTimePickerForward(
                    initialDateTime: _time,
                    minimumDate: DateTime.now(),
                    onDateTimeChanged: (newTime) {
                      setState(() {
                        _time = newTime;
                        _reminderTime = _time.subtract(Duration(minutes: _reminderOffsets[_selectedReminderOffsetIndex]));
                      });
                    },
                  ),
                ),
                SizedBox(height: 16),
                CommonFormWidgets.buildFormCard(
                  title: 'Task Description',
                  child: TextFormField(
                    decoration: InputDecoration(
                      hintText: 'Enter your task',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    maxLines: 3,
                    onChanged: (value) => _notes = value,
                    validator: (value) => value == null || value.isEmpty ? 'Enter a task description' : null,
                  ),
                ),
                ElevatedButton(
                  onPressed: _showReminderOffsetPicker,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _reminderTime != null ? Colors.deepPurple : Colors.grey[200],
                    foregroundColor: _reminderTime != null ? Colors.white : Colors.grey[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_reminderTime != null ? Icons.notifications_active : Icons.notifications_none),
                      SizedBox(width: 8),
                      Text(_reminderTime != null ? 'Reminder Set' : 'Set Reminder'),
                    ],
                  ),
                ),
                if (_reminderTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reminder: ${_reminderOptions[_selectedReminderOffsetIndex]}',
                          style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '(${DateFormat('EEE, MMM d - h:mm a').format(_reminderTime!)})',
                          style: TextStyle(color: Colors.deepPurple),
                        ),
                      ],
                    ),
                  ),
                ElevatedButton(
                  onPressed: () {
                    // Set reminder to 30 seconds from now
                    setState(() {
                      _time = DateTime.now().add(Duration(minutes: 2));
                      _reminderTime = DateTime.now().add(Duration(seconds: 30));
                      _selectedReminderOffsetIndex = 0; // "At time of task"
                    });
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Reminder set to 30 seconds from now"))
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text("Set Test Reminder (30s)"),
                ),
                SizedBox(height: 24),
                CommonFormWidgets.buildSubmitButton(
                  text: 'Save Task',
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _submit();
                      Navigator.pop(context);
                    }
                  }
                )
              ]
            )
          )
        ]
      )
    );
  }

  Future<void> _submit() async {
    if (UserState.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add a todo.'))
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    
    setState(() {
      _isSettingReminder = true;
    });

    if (_formKey.currentState!.validate()) {
      final data = {
        'user_id': UserState.userId,
        'time': _time.toUtc().toIso8601String(),
        'notes': _notes,
        'reminder_time': _reminderTime?.toUtc().toIso8601String(),
      };

      try {
        final response = await http.post(
          Uri.parse('http://127.0.0.1:5001/todo/${UserState.userId}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        );
        setState(() {
          _isSettingReminder = false;
        });

        if (response.statusCode == 201) {
          String message = 'Todo added successfully!';
          if (_reminderTime != null) {
            message += ' Reminder set for ${DateFormat('h:mm a').format(_reminderTime!)}';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message), 
              duration: Duration(seconds: 5), 
              action: _reminderTime != null ? SnackBarAction(
                label: 'TEST NOW', 
                onPressed: () {
                  _testReminderNotification();
                },
              ) : null,
            ),
          );
          _formKey.currentState!.reset();
          _notes = '';
          _fetchTodos();
          _reminderTime = null;
          _selectedReminderOffsetIndex = 1;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding Todo: ${response.statusCode}')),
          );
        }
      } catch (e) {
        setState(() {
          _isSettingReminder = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding Todo: $e')),
        );
      }
    }
  }

  Future<void> _testReminderNotification() async {
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5001/test-reminders/${UserState.userId}'),
        headers: {'Content-Type': 'application/json'},
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test notification triggered')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending test notification')),
      );
    }
  }

  Future<void> _deleteTodos(int id) async {
    try {
      final response = await http.delete(Uri.parse('http://127.0.0.1:5001/todo/$id'));
      // final response = await http.delete(Uri.parse('https://tracking-tots.onrender.com/todo/$id'));
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Todo deleted')),
        );
        await _fetchTodos();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: Could not delete todo')),
      );
    }
  }

  Future<void> _toggleTodoStatus(int id) async {
    try {
      final response = await http.patch(
        Uri.parse('http://127.0.0.1:5001/todo/$id/toggle'),
        // Uri.parse('https://tracking-tots.onrender.com/todo/$id/toggle'),
        headers: {'Content-Type': 'application/json'},
      );
      print('Toggle Response: ${response.body}');

      if (response.statusCode == 200) {
        await _fetchTodos();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating todo status')),
        );
      }
    } catch (e) {
      print('Toggle Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: Could not update todo status')),
      );
    }
  }

  Widget buildReminderIndicator(Map<String, dynamic> todo) {
    if (todo['reminder_time'] == null) {
      return SizedBox.shrink();
    }
    
    final reminderTime = DateTime.parse(todo['reminder_time']);
    final now = DateTime.now();
    final difference = reminderTime.difference(now);
    
    // For reminders in the past or very soon
    if (difference.inMinutes <= 5) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Due ${difference.inMinutes <= 0 ? 'now' : 'in ${difference.inMinutes}m'}',
          style: TextStyle(color: Colors.white, fontSize: 10),
        ),
      );
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Reminder at ${DateFormat('h:mm a').format(reminderTime)}',
        style: TextStyle(fontSize: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('To-Do List'),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () async {
              if (UserState.userId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please log in first')),
                );
                return;
              }
              
              try {
                final response = await http.post(
                  Uri.parse('http://127.0.0.1:5001/test-user-notification/${UserState.userId}'),
                  headers: {'Content-Type': 'application/json'},
                );
                
                if (response.statusCode == 200) {
                  final data = jsonDecode(response.body);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(data['message'])),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to send test notification')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            tooltip: 'Test Notification',
          ),
        ],
      ),
      backgroundColor: Colors.purple[50],
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTodoSummaryCards(),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: _todos.isEmpty
              ? SliverToBoxAdapter(
                  child: Center(
                    child: Text(
                      'No tasks yet',
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final todo = _todos[index];
                      final todoDate = DateTime.parse(todo['time']);
                      return Card(
                        elevation: 4,
                        margin: EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFF6A359C).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              todo['completed'] == true ? Icons.check_circle : Icons.circle,
                              color: Color(0xFF6A359C),
                            ),
                          ),
                          title: Text(
                            todo['notes'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: todo['completed'] == true 
                                ? TextDecoration.lineThrough 
                                : TextDecoration.none,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(DateFormat('EEE, MMM d - h:mm a').format(todoDate)),
                              SizedBox(height: 4),
                              buildReminderIndicator(todo),
                            ],
                          ),
                          trailing: SizedBox(
                            width: 96,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    todo['completed'] == true 
                                      ? Icons.check_circle 
                                      : Icons.radio_button_unchecked,
                                    color: Colors.green,
                                  ),
                                  onPressed: () => _toggleTodoStatus(todo['id']),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteTodos(todo['id']),            
                              ),
                            ],
                          ),
                          ),
                        ),
                      );
                    },
                    childCount: _todos.length,
                  ),
                ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF9969C7), Color(0xFF6A359C)],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddTodoDialog(context),
          child: Icon(Icons.add),
          backgroundColor: Colors.transparent,
          elevation: 0,
          hoverElevation: 0,
        ),
      ),
    );
  }
}
