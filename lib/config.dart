class Config {
  static const String baseUrl = 'http://192.168.1.XXX:5001';  // Replace with your IP address
  
  // API endpoints
  static String todoEndpoint(int userId) => '$baseUrl/todo/$userId';
  static String todoToggleEndpoint(int todoId) => '$baseUrl/todo/$todoId/toggle';
  static String testRemindersEndpoint(int userId) => '$baseUrl/test-reminders/$userId';
  static String testUserNotificationEndpoint(int userId) => '$baseUrl/test-user-notification/$userId';
} 