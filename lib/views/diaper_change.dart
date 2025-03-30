import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trackingtots/views/widgets/top_navigation_bar.dart';
import 'package:trackingtots/user_state.dart';



class DiaperForm extends StatefulWidget {
  @override
  _DiaperFormState createState() => _DiaperFormState();
}

class _DiaperFormState extends State<DiaperForm> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'Wet';
  DateTime _time = DateTime.now();
  String _notes = '';

  Future<void> _submit() async {
    if (UserState.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add a diaper change.')),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    if (_formKey.currentState!.validate()) {
      final data = {
        'user_id': UserState.userId,
        'type': _type,
        'time': _time.toIso8601String(),
        'notes': _notes,
      };
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/diaper-change'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Diaper added successfully!')),
        );
        _formKey.currentState!.reset();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding Diaper.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopNavigationBar(title: 'Diaper Form'),
      backgroundColor: Colors.purple[50],
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            DropdownButton<String>(
              value: _type,
              onChanged: (value) => setState(() => _type = value!),
              items: ['Mixed', 'Wet', 'Dirty']
                  .map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
                  .toList(),
            ),
            // if (_type == 'Breast') ...[
            //   TextFormField(
            //     decoration: InputDecoration(labelText: 'Left Breast Duration (min)'),
            //     keyboardType: TextInputType.number,
            //     onChanged: (value) => _leftDuration = int.tryParse(value),
            //   ),
            //   TextFormField(
            //     decoration: InputDecoration(labelText: 'Right Breast Duration (min)'),
            //     keyboardType: TextInputType.number,
            //     onChanged: (value) => _rightDuration = int.tryParse(value),
            //   ),
            // ] else
            //   TextFormField(
            //     decoration: InputDecoration(labelText: 'Bottle Amount (ml)'),
            //     keyboardType: TextInputType.number,
            //     onChanged: (value) => _bottleAmount = int.tryParse(value),
            //   ),
            TextFormField(
                decoration: InputDecoration(labelText: 'Notes', border: OutlineInputBorder(), hintText: 'Enter your notes here'),
                onChanged: (value) => setState(() => _notes = value),
            ),
            ElevatedButton(onPressed: _submit, child: Text('Save Diaper')),
          ],
        ),
      ),
    );
  }
}
