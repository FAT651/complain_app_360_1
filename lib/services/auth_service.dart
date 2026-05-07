import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FirestoreService _firestoreService = FirestoreService();

  Future<UserModel?> restoreSignedInUser() async {
    final supabaseUser = _supabase.auth.currentUser;
    if (supabaseUser == null) return null;
    return _firestoreService.fetchUserByUid(supabaseUser.id);
  }

  Future<String> _normalizeEmail(String input) async {
    final trimmed = input.trim().toLowerCase();
    if (trimmed.contains('@')) {
      return trimmed;
    }
    return '$trimmed@complaintapp.app';
  }

  String _normalizeStudentId(String input) {
    return input.trim().toLowerCase();
  }

  Future<UserModel> signIn(String emailOrId, String password) async {
    final normalized = emailOrId.trim().toLowerCase();
    final email = await _normalizeEmail(normalized);

    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final currentUser = response.user;
    if (currentUser == null) {
      throw Exception('user-not-found');
    }

    final profile = await _firestoreService.fetchUserByUid(currentUser.id);
    if (profile == null) {
      throw Exception('missing-profile');
    }
    return profile;
  }

  Future<UserModel> register(String emailOrId, String password) async {
    try {
      final normalized = emailOrId.trim().toLowerCase();
      final email = await _normalizeEmail(normalized);
      final studentId = normalized.contains('@')
          ? normalized.split('@').first
          : _normalizeStudentId(normalized);

      print('🔐 Registration attempt: email=$email, studentId=$studentId');

      final signUpResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      final authUser = signUpResponse.user;
      if (authUser == null) {
        print('❌ Auth user is null after signup');
        throw Exception('account-creation-failed');
      }

      print('✅ Supabase auth signup successful: userId=${authUser.id}');

      final userModel = UserModel(
        id: authUser.id,
        email: email,
        studentId: studentId,
        role: 'student',
        displayName: studentId,
      );

      print('📝 Creating user profile in database...');
      await _firestoreService.createUser(userModel);
      print('✅ User profile created successfully');
      return userModel;
    } catch (e, stackTrace) {
      print('❌ Registration error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<UserModel> createUserAccount({
    required String email,
    required String password,
    required String studentId,
    required String role,
    String? displayName,
  }) async {
    final signUpResponse = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    final authUser = signUpResponse.user;
    if (authUser == null) {
      throw Exception('account-creation-failed');
    }

    final userModel = UserModel(
      id: authUser.id,
      email: email,
      studentId: studentId.trim().toLowerCase(),
      role: role,
      displayName: displayName?.isNotEmpty == true ? displayName : studentId,
    );

    await _firestoreService.createUser(userModel);
    return userModel;
  }

  Future<UserModel> updateUserAccount({
    String? displayName,
    String? newPassword,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('user-not-found');
    }

    if (newPassword != null && newPassword.isNotEmpty) {
      final updateResponse = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      if (updateResponse.user == null) {
        throw Exception('password-update-failed');
      }
    }

    final profile = await _firestoreService.fetchUserByUid(currentUser.id);
    if (profile == null) {
      throw Exception('missing-profile');
    }

    final updatedProfile = UserModel(
      id: profile.id,
      email: profile.email,
      studentId: profile.studentId,
      role: profile.role,
      displayName: displayName?.isNotEmpty == true
          ? displayName!
          : profile.displayName,
    );

    if ((displayName != null &&
            displayName.isNotEmpty &&
            displayName != profile.displayName) ||
        (newPassword != null && newPassword.isNotEmpty)) {
      await _firestoreService.updateUser(currentUser.id, updatedProfile);
    }

    return updatedProfile;
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
