import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:trackingtots/views/widgets/top_navigation_bar.dart';
import 'package:trackingtots/user_state.dart';
import 'package:trackingtots/views/widgets/form_builder.dart';
import 'package:trackingtots/views/widgets/modal_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchTodos();
  }

  Future<void> _fetchTodos() async {
    if (UserState.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to view your todos.'))
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
    return Container(
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BaseModalSheet(
        title: 'Add Todo',
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
                    onDateTimeChanged: (newTime) => setState(() => _time = newTime),
                  ),
                ),
                SizedBox(height: 16),
                CommonFormWidgets.buildFormCard(
                  title: 'Task Description',
                  child: TextFormField(
                    decoration: InputDecoration(
                      hintText: 'Enter your todo',
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
    if (_formKey.currentState!.validate()) {
      final data = {
        'user_id': UserState.userId,
        'time': _time.toIso8601String(),
        'notes': _notes,
      };
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5001/todo/${UserState.userId}'),
        // Uri.parse('https://tracking-tots.onrender.com/todo/${UserState.userId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Todo added successfully!')),
        );
        _formKey.currentState!.reset();
        _notes = '';
        _fetchTodos();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding Todo.')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopNavigationBar(title: 'Todo List'),
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
                      'No todos yet',
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
                          ),
                          subtitle: Text(
                            DateFormat('EEE, MMM d - h:mm a').format(todoDate),
                          ),
                          trailing: Row(
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
