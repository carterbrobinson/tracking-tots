import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserState {
    static int? userId;
    static String? name;
    static String? email;
    static String? fcmToken;
    static final _storage = FlutterSecureStorage();

    static Future<void> setUserData(int id, String userName, String userEmail) async {
        userId = id;
        name = userName;
        email = userEmail;
        await _storage.write(key: 'userId', value: id.toString());
        await _storage.write(key: 'name', value: userName);
        await _storage.write(key: 'email', value: userEmail);
    }

    static Future<void> loadUserData() async {
        final id = await _storage.read(key: 'userId');
        final storedName = await _storage.read(key: 'name');
        final storedEmail = await _storage.read(key: 'email');

        if (id != null) {
            userId = int.tryParse(id);
            name = storedName;
            email = storedEmail;
        }
    }

    static Future<void> clear() async {
        userId = null;
        name = null;
        email = null;
        await _storage.deleteAll();
    }
    static bool get isLoggedIn => userId != null;
}