class UserModel {
  final String uid;
  final String email;
  final String studentId;
  final String role;
  final String? displayName;

  UserModel({
    required this.uid,
    required this.email,
    required this.studentId,
    required this.role,
    this.displayName,
  });

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isStudent => !isAdmin;
  String get formattedRole => isAdmin ? 'Admin' : 'Student';

  static String _normalizeRole(String? value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized == 'admin') return 'admin';
    return 'student';
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'studentId': studentId,
      'role': _normalizeRole(role),
      'displayName': displayName,
    };
  }

  factory UserModel.fromJson(String uid, Map<String, dynamic> json) {
    return UserModel(
      uid: uid,
      email: json['email'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      role: _normalizeRole(json['role'] as String?),
      displayName: json['displayName'] as String?,
    );
  }
}
