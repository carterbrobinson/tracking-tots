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

Future<bool> _isServiceWorkerRegistered() async {
  if (!kIsWeb) return true;
  
  try {
    if (html.window.navigator.serviceWorker == null) {
      print("[DEBUG] Service Worker API not available");
      return false;
    }
    
    final registrations = await html.window.navigator.serviceWorker?.getRegistrations();
    if (registrations == null || registrations.isEmpty) {
      print("[DEBUG] No service worker registrations found");
      return false;
    }
    
    // Check if the service worker is actually active
    final registration = registrations.first;
    if (registration.active == null) {
      print("[DEBUG] Service worker exists but is not active");
      return false;
    }
    
    print("[DEBUG] Service worker is registered and active");
    return true;
  } catch (e) {
    print("[ERROR] Error checking service worker registration: $e");
    return false;
  }
}

Future<void> _waitForServiceWorker({int maxAttempts = 5, int delaySeconds = 2}) async {
  if (!kIsWeb) return;
  
  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    print("[DEBUG] Checking service worker status (attempt $attempt/$maxAttempts)");
    if (await _isServiceWorkerRegistered()) {
      print("[DEBUG] Service worker is ready");
      return;
    }
    
    if (attempt < maxAttempts) {
      print("[DEBUG] Waiting ${delaySeconds}s before next attempt...");
      await Future.delayed(Duration(seconds: delaySeconds));
    }
  }
  
  print("[ERROR] Service worker failed to become active after $maxAttempts attempts");
}

Future<void> registerFcmToken() async {
  if (!kIsWeb) return;
  
  try {
    // Wait for service worker to be ready
    await _waitForServiceWorker();
    
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
  } catch (e) {
    print('[ERROR] Error registering FCM token: $e');
    // Retry after a delay if there's an error
    await Future.delayed(Duration(seconds: 5));
    await registerFcmToken();
  }
}

// Add this function to test notification permissions
Future<void> _showNotificationPermissionDialog(BuildContext context) async {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Enable Notifications'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notifications are important for:'),
            SizedBox(height: 8),
            Text('• Task reminders'),
            Text('• Feeding schedules'),
            Text('• Sleep tracking alerts'),
            SizedBox(height: 16),
            Text('To enable notifications:'),
            SizedBox(height: 8),
            Text('1. Click the lock icon in your browser\'s address bar'),
            Text('2. Find "Notifications" in the list'),
            Text('3. Change the setting to "Allow"'),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Dismiss'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('Try Again'),
            onPressed: () async {
              Navigator.of(context).pop();
              await _requestNotificationPermissions();
            },
          ),
        ],
      );
    },
  );
}

Future<void> _requestNotificationPermissions() async {
  if (kIsWeb) {
    print("[DEBUG] Checking web notification permissions");
    try {
      // First check if service worker is registered
      if (!await _isServiceWorkerRegistered()) {
        print("[DEBUG] Service worker not registered, waiting for registration...");
        await Future.delayed(Duration(seconds: 2)); // Give time for registration
        if (!await _isServiceWorkerRegistered()) {
          print("[ERROR] Service worker still not registered after delay");
          return;
        }
      }

      final permission = await html.Notification.requestPermission();
      print("[DEBUG] Web notification permission status: $permission");
      
      if (permission == 'denied') {
        print("[DEBUG] Web notification permission was denied");
        if (navigatorKey.currentContext != null) {
          await _showNotificationPermissionDialog(navigatorKey.currentContext!);
        }
        return;
      }
    } catch (e) {
      print("[ERROR] Error requesting web notification permission: $e");
    }
  }
  
  try {
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('[DEBUG] Firebase notification permission status: ${settings.authorizationStatus}');
    
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('[DEBUG] Firebase notification permission was denied');
      if (navigatorKey.currentContext != null) {
        await _showNotificationPermissionDialog(navigatorKey.currentContext!);
      }
    }
  } catch (e) {
    print('[ERROR] Error requesting Firebase notification permission: $e');
  }
}

// Add this at the top of the file with other global variables
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

  // Wait for service worker to be ready
  await _waitForServiceWorker();

  // Request permission for Firebase notifications
  await _requestNotificationPermissions();

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
        try {
          html.Notification(
            message.notification!.title ?? "Reminder",
            body: message.notification!.body ?? "You have a task due.",
          );
        } catch (e) {
          print("[ERROR] Error showing web notification: $e");
          // If notification fails, try to reinitialize the service worker
          await _waitForServiceWorker();
        }
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
      navigatorKey: navigatorKey,
      initialRoute: '/',
      routes: {
        '/': (context) => UserState.isLoggedIn ? HomePage() : LoginPage(),
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignupPage(),
        '/home': (context) => HomePage(),
        '/feeding': (context) => FeedingForm(),
        '/sleeping': (context) => SleepingForm(),
        '/diaper': (context) => DiaperForm(),
        '/tummy': (context) => TummyTimeForm(),
        '/todo': (context) => TodoForm(),
        '/chatbot': (context) => Chatbot(),
      },
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