import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:trackingtots/views/widgets/top_navigation_bar.dart';
import 'dart:convert';
import 'dart:async';
import 'package:trackingtots/user_state.dart';

class TummyTimeForm extends StatefulWidget {
  @override
  _TummyTimeFormState createState() => _TummyTimeFormState();
}

class _TummyTimeFormState extends State<TummyTimeForm> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _startTime;
  DateTime? _endTime;
  String _notes = '';
  Timer? _timer;
  Duration _duration = Duration();
  Duration _elapsed = Duration();
  bool _isRunning = false;
  List<Map<String, dynamic>> _tummyTime = [];

  Future<void> _fetchTummyTime() async {
    if (UserState.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to view your tummy time.'))
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final response = await http.get(Uri.parse('http://127.0.0.1:5000/tummy-time/${UserState.userId}')); 
    if (response.statusCode == 200) {
      setState(() {
        _tummyTime = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchTummyTime();
  }

  void _startTimer() {
    setState(() {
      _startTime = DateTime.now();
      _elapsed = Duration();
      _isRunning = true;
    });
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _duration = DateTime.now().difference(_startTime!) + _elapsed;
      });
    });
  }

  void _stopTimer() {
    if (_timer != null) {
      _timer!.cancel();
    }
    setState(() {
      _endTime = DateTime.now();
      _isRunning = false;
    });
  }

  void _pauseTimer() {
    if (_timer != null) {
      _timer!.cancel();
    }
    setState(() {
      _elapsed = _duration;
      _isRunning = false;
    });
  }

  void _resumeTimer() {
    if (!_isRunning) {
      setState(() {
        _startTime = DateTime.now();
        _isRunning = true;
      });
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _duration = DateTime.now().difference(_startTime!) + _elapsed;
        });
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _startTime != null && _endTime != null) {
      final data = {
        'user_id': UserState.userId, 
        'start_time': _startTime!.toIso8601String(),
        'end_time': _endTime!.toIso8601String(),
        'notes': _notes,
      };
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/tummy-time'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tummy Time added successfully!')),
        );
        _formKey.currentState!.reset();
        setState(() {
          _duration = Duration();
          _startTime = null;
          _endTime = null;
          _elapsed = Duration();
        });
        await _fetchTummyTime();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding Tummy Time.')),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    if (!UserState.isLoggedIn) {
      Future.microtask(() {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return SizedBox();
    }
    return Scaffold(
      appBar: TopNavigationBar(title: 'Tummy Time'),
      backgroundColor: Colors.purple[50],
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Timer Display Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        'Timer',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple[400],
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple[400],
                        ),
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
                            label: Text(_isRunning ? 'Stop' : 'Start'),
                            onPressed: _isRunning ? _stopTimer : _startTimer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRunning ? Colors.red : Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow,
                            color: _isRunning ? Colors.deepPurple[400] : Colors.white),
                            label: Text(_isRunning ? 'Pause' : 'Resume'),
                            onPressed: _isRunning ? _pauseTimer : _resumeTimer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRunning ? Colors.deepPurple[50] : Colors.deepPurple[300],
                              foregroundColor: _isRunning? Colors.deepPurple[400] : Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Notes Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Notes',
                          labelStyle: TextStyle(color: Colors.deepPurple),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.deepPurple),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.deepPurple, width: 2),
                          ),
                          hintText: 'Enter notes about tummy time here...',
                          prefixIcon: Icon(Icons.note, color: Colors.deepPurple),
                        ),
                        maxLines: 3,
                        onChanged: (value) => _notes = value,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple[300],
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text('Save Tummy Time', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Previous Sessions Card
              Expanded(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Previous Sessions',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple[400],
                          ),
                        ),
                        SizedBox(height: 8),
                        Expanded(
                          child: _tummyTime.isEmpty
                              ? Center(
                                  child: Text(
                                    'No previous sessions yet.',
                                    style: TextStyle(fontSize: 16, color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _tummyTime.length,
                                  itemBuilder: (context, index) {
                                    final entry = _tummyTime[index];
                                    final start = DateTime.parse(entry['start_time']);
                                    final end = DateTime.parse(entry['end_time']);
                                    final duration = end.difference(start);
                                    final notes = entry['notes'] ?? '';
                                    return Card(
                                      margin: EdgeInsets.symmetric(vertical: 8),
                                      child: ListTile(
                                        leading: Icon(Icons.timer, color: Colors.deepPurple),
                                        title: Text(
                                          _formatDuration(duration),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepPurple,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Started: ${start.toLocal().toString().substring(0, 16)}',
                                              style: TextStyle(color: Colors.grey),
                                            ),
                                            if (notes.isNotEmpty)
                                              Text(
                                                'Notes: $notes',
                                                style: TextStyle(color: Colors.grey),
                                              ),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}   