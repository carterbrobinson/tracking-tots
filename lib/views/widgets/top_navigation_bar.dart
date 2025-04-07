import 'package:flutter/material.dart';
import 'package:trackingtots/user_state.dart';

class TopNavigationBar extends StatelessWidget implements PreferredSizeWidget {
    final String title;

    const TopNavigationBar({
        Key? key,
        required this.title,
    }) : super(key: key);

    @override
    Widget build(BuildContext context) {
        return Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF9969C7), Color(0xFF6A359C)],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                ),
            ),
            child: AppBar(
                title: Text(title),
                centerTitle: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: [
                    IconButton(
                        icon: const Icon(Icons.home),
                        onPressed: () {
                            if (Navigator.canPop(context)) {
                                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                            }
                        },
                    ),
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
                                                child: Text("Cancel"),
                                            ),
                                            TextButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                child: Text("Logout"),
                                            ),
                                        ],
                                    ),
                                );
                                if (confirmed ?? false) {
                                    await UserState.clear();
                                    Navigator.pushReplacementNamed(context, '/login');
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
                                    title: Text('Todo'),
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
                ],
            ),
        );
    }
    @override
    Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}