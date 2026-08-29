class UserRole {
  static const student = 'student';
  static const parent = 'parent';
}

class UserProfile {
  UserProfile({
    required this.uid,
    required this.email,
    required this.role,
    this.displayName,
    this.linkedStudentIds = const [],
    this.createdAtMs,
  });

  final String uid;
  final String email;
  final String role;
  final String? displayName;
  final List<String> linkedStudentIds;
  final int? createdAtMs;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'role': role,
        'displayName': displayName,
        'linkedStudentIds': linkedStudentIds,
        'createdAtMs': createdAtMs,
      };

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        uid: m['uid'] as String,
        email: (m['email'] ?? '') as String,
        role: (m['role'] ?? UserRole.student) as String,
        displayName: m['displayName'] as String?,
        linkedStudentIds:
            (m['linkedStudentIds'] as List?)?.cast<String>() ?? const [],
        createdAtMs: m['createdAtMs'] as int?,
      );
}
