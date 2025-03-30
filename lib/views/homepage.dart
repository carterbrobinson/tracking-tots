import 'package:flutter/material.dart';
import 'package:trackingtots/user_state.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking Tots'),
        backgroundColor: Colors.deepPurple[300],
        automaticallyImplyLeading: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
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
            },
          )
        ]
      ),
      backgroundColor: Colors.purple[50],
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: GridView.count(
          crossAxisCount: 4,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          children: [
            trackerCard(context, 'Feeding', 'assets/feeding.png', '/feeding'),
            trackerCard(context, 'ChatBot', 'assets/chatbot.png', '/chatbot'),
            trackerCard(context, 'Sleeping', 'assets/sleeping.png', '/sleeping'),
            trackerCard(context, 'Diaper', 'assets/diaper.png', '/diaper'),
            trackerCard(context, 'Tummy Time', 'assets/tummytime.png', '/tummy'),
            trackerCard(context, 'Todo', 'assets/todo.png', '/todo'),
          ],
        ),
      ),
    );
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
              Image.asset(imagePath, width: 80, height: 80, fit: BoxFit.cover),
              SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}