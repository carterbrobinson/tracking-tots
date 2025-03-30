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
        return AppBar(
            title: Text(title),
            backgroundColor: Colors.deepPurple[300],
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
                        }else {
                            Navigator.pushNamed(context, '/$value');
                        }
                    },
                    itemBuilder: (BuildContext context) => [
                        const PopupMenuItem(
                            value: 'feeding',
                            child: Text('Feeding'),
                        ),
                        const PopupMenuItem(
                            value: 'sleeping',
                            child: Text('Sleeping'),
                        ),
                        const PopupMenuItem(
                            value: 'diaper',
                            child: Text('Diaper'),
                        ),
                        const PopupMenuItem(
                            value: 'tummy',
                            child: Text('Tummy Time'),
                        ),
                        const PopupMenuItem(
                            value: 'todo',
                            child: Text('Todo'),
                        ),
                        const PopupMenuItem(
                            value: 'chatbot',
                            child: Text('ChatBot'),
                        ),
                        const PopupMenuItem(
                            value: 'signup',
                            child: Text('Signup')
                        ),
                        const PopupMenuItem(
                            value: 'login',
                            child: Text('Login')
                        ),
                        const PopupMenuItem(
                            value: 'logout',
                            child: Text('Logout', style: TextStyle(color: Colors.red)),
                        )
                    ],
                ),
            ],
        );
    }
    @override
    Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}