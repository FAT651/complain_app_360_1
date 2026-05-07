class UserModel {
  final String id;
  final String email;
  final String studentId;
  final String role;
  final String? displayName;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.studentId,
    required this.role,
    this.displayName,
    this.createdAt,
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
      'student_id': studentId,
      'role': _normalizeRole(role),
      'display_name': displayName,
    };
  }

  factory UserModel.fromJson(String id, Map<String, dynamic> json) {
    return UserModel(
      id: id,
      email: json['email'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      role: _normalizeRole(json['role'] as String?),
      displayName: json['display_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}
