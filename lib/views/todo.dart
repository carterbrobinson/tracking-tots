import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trackingtots/views/widgets/top_navigation_bar.dart';
import 'package:trackingtots/user_state.dart';



class TodoForm extends StatefulWidget {
  @override
  _TodoFormState createState() => _TodoFormState();
}

class _TodoFormState extends State<TodoForm> {
  final _formKey = GlobalKey<FormState>();
  DateTime _time = DateTime.now();
  String _notes = '';
  List<Map<String, dynamic>> _todos = [];

  Future<void> _fetchTodos() async {
    if (UserState.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to view your todos.'))
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final response = await http.get(Uri.parse('http://127.0.0.1:5000/todo/${UserState.userId}')); // Change when I do user accounts
    if (response.statusCode == 200) {
      setState(() {
        _todos = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      });
    }
  }
  @override
  void initState() {
    super.initState();
    _fetchTodos();
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
        Uri.parse('http://127.0.0.1:5000/todo'),
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
    final response =
        await http.delete(Uri.parse('http://127.0.0.1:5000/todo/$id'));
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Todo deleted')),
      );
      _fetchTodos();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopNavigationBar(title: 'Todo List'),
      backgroundColor: Colors.purple[50],
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Task Notes',
                        hintText: 'Enter your todo',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => _notes = value,
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Enter something' : null,
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _submit,
                      child: Text('Add Todo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 30),
              _todos.isEmpty
                  ? Center(child: Text('No todos yet'))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _todos.length,
                      itemBuilder: (context, index) {
                        final todo = _todos[index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 5),
                          child: ListTile(
                            title: Text(todo['notes'] ?? ''),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteTodos(todo['id']),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
