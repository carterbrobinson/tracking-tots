import 'package:flutter/material.dart';
import 'views/homepage.dart';
import 'views/feeding_form.dart';
import 'views/sleeping_form.dart';
import 'views/chatbot.dart';
import 'views/diaper_change.dart';
import 'views/tummy_time.dart';
import 'views/todo.dart';
import 'views/login_screen.dart';
import 'views/signup_page.dart';
import 'user_state.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await UserState.loadUserData();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tracking Tots',
      initialRoute: UserState.isLoggedIn ? '/' : '/login',
      routes: {
        '/': (context) => HomePage(),
        '/feeding': (context) => FeedingForm(),
        '/chatbot': (context) => Chatbot(),
        '/sleeping': (context) => SleepingForm(),
        '/diaper': (context) => DiaperForm(),
        '/tummy': (context) => TummyTimeForm(),
        '/todo': (context) => TodoForm(),
        '/signup': (context) => SignupPage(),
        '/login': (context) => LoginPage(),
      },
      theme: ThemeData(
        primaryColor: Colors.deepPurple[300],
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: Colors.deepPurple[300],
          secondary: Colors.purpleAccent[100],
        ),
        scaffoldBackgroundColor: Colors.purple[50],
        fontFamily: 'Poppins',
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
        ),
        useMaterial3: true,
      ),
    );
  }
}