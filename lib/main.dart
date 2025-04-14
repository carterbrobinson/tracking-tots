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
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

final InitializationSettings initializationSettings = InitializationSettings(
  android: initializationSettingsAndroid,
);

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

Future<void> registerFcmToken() async {
  final fcmtoken = await FirebaseMessaging.instance.getToken();
  print('[DEBUG] FCM Token: $fcmtoken');

  if (UserState.isLoggedIn && fcmtoken != null) {
    final response = await http.post(
      Uri.parse('http://127.0.0.1:5001/register-fcm-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': UserState.userId,
        'token': fcmtoken,
        'platform': 'web',
      }),
    );
    print('[DEBUG] Token registration response: ${response.body}');
  }
}

// Add this function to test notification permissions
Future<void> _requestNotificationPermissions() async {
  if (kIsWeb) {
    print("[DEBUG] Checking web notification permissions");
    try {
      final permission = await html.Notification.requestPermission();
      print("[DEBUG] Web notification permission status: $permission");
    } catch (e) {
      print("[ERROR] Error requesting web notification permission: $e");
    }
  }
  
  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('[DEBUG] Firebase notification permission status: ${settings.authorizationStatus}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize local notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Request permission for Firebase notifications
  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('User granted permission: ${settings.authorizationStatus}');

  // Handle foreground notifications
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
  try {
    print("Message received in foreground: ${message.notification?.body}");

    if (message.notification != null && !kIsWeb) {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'reminder_channel',
        'Reminders',
        importance: Importance.max,
        priority: Priority.high,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        message.hashCode,
        message.notification!.title,
        message.notification!.body,
        platformDetails,
      );
    }

    if (kIsWeb && message.notification != null) {
      html.Notification(
        message.notification!.title ?? "Reminder",
        body: message.notification!.body ?? "You have a task due.",
      );
    }
  } catch (e, stack) {
    print("🔥 Notification handling error: $e");
    print(stack);
  }
});


  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("Message opened app: ${message.notification?.body}");
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await UserState.loadUserData();
  await registerFcmToken();

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    print('[DEBUG] Token refreshed: $newToken');
    if (UserState.isLoggedIn) {
      http.post(
        Uri.parse('http://127.0.0.1:5001/register-fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': UserState.userId,
          'token': newToken,
          'platform': 'web',
        }),
      );
    }
  });

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