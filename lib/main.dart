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
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
        '/signup': (context) => AuthenticationWrapper(child: SignupPage()),
        '/login': (context) => AuthenticationWrapper(child: LoginPage()),
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: Color(0xFF6A359C),
          secondary: Color(0xFF9969C7),
        ),
        scaffoldBackgroundColor: Color(0xFFF3E5F5),
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            color: Colors.black, 
            fontWeight: FontWeight.w800,
          ),
        ),
        useMaterial3: true,
      ),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  final Widget child;

  const AuthenticationWrapper({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (UserState.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Already Logged In'),
            content: Text('You are already logged in as ${UserState.name}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Go back to previous screen
                },
                child: Text('Go Back'),
              ),
              TextButton(
                onPressed: () {
                  UserState.clear(); // Log out
                  Navigator.of(context).pop(); // Close dialog
                  // Stay on login/signup page
                },
                child: Text('Log Out'),
              ),
            ],
          ),
        );
      });
    }
    return child;
  }
}