class FirestorePaths {
  static String user(String uid) => 'users/$uid';
  static String student(String studentId) => 'students/$studentId';
  static String sessions(String studentId) => 'students/$studentId/sessions';
  static String messages(String studentId) => 'students/$studentId/messages';
  static String encouragements(String studentId) =>
      'students/$studentId/encouragements';
}
