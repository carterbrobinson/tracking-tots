import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trackingtots/views/widgets/top_navigation_bar.dart';
import 'package:trackingtots/user_state.dart';



class FeedingForm extends StatefulWidget {
  @override
  _FeedingFormState createState() => _FeedingFormState();
}

class _FeedingFormState extends State<FeedingForm> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'Breast';
  int? _leftDuration, _rightDuration, _bottleAmount;
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now();

  Future<void> _submit() async {
    if (UserState.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to add a feeding.')),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final data = {
      'user_id': UserState.userId,
      'type': _type,
      'left_breast_duration': _leftDuration,
      'right_breast_duration': _rightDuration,
      'bottle_amount': _bottleAmount,
      'start_time': _startTime.toIso8601String(),
      'end_time': _endTime.toIso8601String(),
    };
    final response = await http.post(
      Uri.parse('http://127.0.0.1:5000/feeding'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Feeding added successfully!')),
      );
      _formKey.currentState!.reset();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding feeding.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopNavigationBar(title: 'Feeding Form'),
      backgroundColor: Colors.purple[50],
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            DropdownButton<String>(
              value: _type,
              onChanged: (value) => setState(() => _type = value!),
              items: ['Breast', 'Bottle']
                  .map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
                  .toList(),
            ),
            if (_type == 'Breast') ...[
              TextFormField(
                decoration: InputDecoration(labelText: 'Left Breast Duration (min)', border: OutlineInputBorder(), hintText: 'Enter duration in minutes'),
                keyboardType: TextInputType.number,
                onChanged: (value) => _leftDuration = int.tryParse(value),
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Right Breast Duration (min)', border: OutlineInputBorder(), hintText: 'Enter duration in minutes'),
                keyboardType: TextInputType.number,
                onChanged: (value) => _rightDuration = int.tryParse(value),
              ),
            ] else
              TextFormField(
                decoration: InputDecoration(labelText: 'Bottle Amount (ml)', border: OutlineInputBorder(), hintText: 'Enter amount in ml'),
                keyboardType: TextInputType.number,
                onChanged: (value) => _bottleAmount = int.tryParse(value),
              ),
            ElevatedButton(onPressed: _submit, child: Text('Save Feeding')),
          ],
        ),
      ),
    );
  }
}