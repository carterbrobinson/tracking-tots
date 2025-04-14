import 'package:flutter/material.dart';
import 'package:trackingtots/user_state.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchActivities();
    });
  }

  Future<void> _fetchActivities() async {
    if (UserState.userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to view your activities.'))
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:5001/homepage/${UserState.userId}')
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _activities = List<Map<String, dynamic>>.from(data['activities']);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading activities: $e'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF9969C7), Color(0xFF6A359C)],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
          ),
          child: AppBar(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children:[
                Image.asset(
                  "assets/tracking-tots-white.png",
                  width: 40,
                  height: 40,
                ),
                SizedBox(width: 10),
                Text("Tracking Tots", style: TextStyle(color: Colors.white)),
              ],
            ),
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
            elevation: 0,
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'logout') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Logout'),
                        content: Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text("Logout"),
                          )
                        ]
                      )
                    );
                    if (confirmed ?? false) {
                      await UserState.clear();
                      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                    }
                  } else {
                    Navigator.pushNamed(context, '/$value');
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    value: 'feeding',
                    child: ListTile(
                      leading: Icon(Icons.restaurant, color: Color(0xFF6A359C)),
                      title: Text('Feeding'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'sleeping',
                    child: ListTile(
                      leading: Icon(Icons.bedtime, color: Color(0xFF6A359C)),
                      title: Text('Sleeping'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'diaper',
                    child: ListTile(
                      leading: Icon(Icons.baby_changing_station, color: Color(0xFF6A359C)),
                      title: Text('Diaper'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'tummy',
                    child: ListTile(
                      leading: Icon(Icons.child_care, color: Color(0xFF6A359C)),
                      title: Text('Tummy Time'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'todo',
                    child: ListTile(
                      leading: Icon(Icons.checklist, color: Color(0xFF6A359C)),
                      title: Text('To-Do List'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'chatbot',
                    child: ListTile(
                      leading: Icon(Icons.chat, color: Color(0xFF6A359C)),
                      title: Text('ChatBot'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'signup',
                    child: ListTile(
                      leading: Icon(Icons.person_add, color: Color(0xFF6A359C)),
                      title: Text('Signup'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'login',
                    child: ListTile(
                      leading: Icon(Icons.person, color: Color(0xFF6A359C)),
                      title: Text('Login'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.red),
                      title: Text('Logout', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
            ]
          ),
        ),
      ),
      backgroundColor: Colors.purple[50],
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = constraints.maxWidth ~/ 200;
                        crossAxisCount = crossAxisCount.clamp(1, 4);
                        
                        return GridView.count(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 1.2,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          children: [
                            trackerCard(context, 'Feeding', 'assets/feeding-purple.png', '/feeding'),
                            trackerCard(context, 'ChatBot', 'assets/chatbot-purple.png', '/chatbot'),
                            trackerCard(context, 'Sleeping', 'assets/sleep-purple.png', '/sleeping'),
                            trackerCard(context, 'Diaper', 'assets/diaper-purple.png', '/diaper'),
                            trackerCard(context, 'Tummy Time', 'assets/tummy-time-purple.png', '/tummy'),
                            trackerCard(context, 'To-Do List', 'assets/todo-purple.png', '/todo'),
                          ],
                        );
                      },
                    ),
                  ),
                  Container(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _activities.length,
                      padding: EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final activity = _activities[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_getIconForType(activity['type'])),
                                Text(DateFormat('MMM. d - h:mm a').format(DateTime.parse(activity['time'])), style: TextStyle(fontSize: 12),),
                              ],
                            ),
                            title: Text(activity['type']),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(activity['details']),
                                if (activity['notes'] != null)
                                  Text(activity['notes'], style: TextStyle(fontStyle: FontStyle.italic)),
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
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Feeding':
        return Icons.restaurant;
      case 'Sleep':
        return Icons.bedtime;
      case 'Diaper Change':
        return Icons.baby_changing_station;
      case 'Tummy Time':
        return Icons.child_care;
      default:
        return Icons.event_note;
    }
  }

  String _formatDateTime(String dateTimeStr) {
    final dateTime = DateTime.parse(dateTimeStr);
    return DateFormat('MMM. d - h:mm a').format(dateTime);
  }

  Widget trackerCard(BuildContext context, String title, String imagePath, String route) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.pushNamed(context, route),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6A359C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}