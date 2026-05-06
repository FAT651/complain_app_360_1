import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class AuthService {
  late FirebaseAuth _auth;
  final FirestoreService _firestoreService = FirestoreService();

  AuthService() {
    // Firebase is not supported on Linux, so don't initialize it there
    if (!Platform.isLinux) {
      _auth = FirebaseAuth.instance;
    }
  }

  Future<UserModel?> restoreSignedInUser() async {
    if (Platform.isLinux) {
      return null; // No restoration on Linux (for testing)
    }
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return _firestoreService.fetchUserByUid(firebaseUser.uid);
  }

  Future<String> _normalizeEmail(String input) async {
    if (input.contains('@')) {
      return input;
    }
    return '${input.trim()}@complaintapp.app';
  }

  String _normalizeStudentId(String input) {
    return input.trim().toLowerCase();
  }

  Future<UserModel> signIn(String emailOrId, String password) async {
    if (Platform.isLinux) {
      // Return a test user for Linux development
      return UserModel(
        uid: 'linux-test-user',
        email: 'test@complaintapp.app',
        studentId: emailOrId.trim(),
        role: emailOrId.trim().toLowerCase().contains('admin')
            ? 'admin'
            : 'student',
        displayName: 'Test User',
      );
    }

    final normalized = emailOrId.trim();
    String email;
    UserModel? user;

    if (normalized.contains('@')) {
      email = normalized;
      user = await _firestoreService.fetchUserByEmail(email);
    } else {
      user = await _firestoreService.fetchUserByStudentId(
        _normalizeStudentId(normalized),
      );
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Student ID not found',
        );
      }
      email = user.email;
    }

    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final currentUser = result.user;
    if (currentUser == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Unable to sign in',
      );
    }

    final profile = await _firestoreService.fetchUserByUid(currentUser.uid);
    if (profile == null) {
      throw FirebaseAuthException(
        code: 'missing-profile',
        message: 'User profile not found',
      );
    }
    return profile;
  }

  Future<UserModel> register(String emailOrId, String password) async {
    if (Platform.isLinux) {
      throw UnsupportedError(
        'User registration is not supported on Linux. This is a desktop testing build.',
      );
    }

    final normalized = emailOrId.trim();
    final email = await _normalizeEmail(normalized);
    final studentId = normalized.contains('@')
        ? normalized.split('@').first
        : _normalizeStudentId(normalized);

    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final currentUser = result.user;
    if (currentUser == null) {
      throw FirebaseAuthException(
        code: 'account-creation-failed',
        message: 'Unable to create account',
      );
    }

    final userModel = UserModel(
      uid: currentUser.uid,
      email: email,
      studentId: studentId,
      role: 'student',
      displayName: studentId,
    );

    await _firestoreService.createUser(userModel);
    return userModel;
  }

  Future<UserModel> createUserAccount({
    required String email,
    required String password,
    required String studentId,
    required String role,
    String? displayName,
  }) async {
    if (Platform.isLinux) {
      throw UnsupportedError(
        'User account creation is not supported on Linux. This is a desktop testing build.',
      );
    }

    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final currentUser = result.user;
    if (currentUser == null) {
      throw FirebaseAuthException(
        code: 'account-creation-failed',
        message: 'Unable to create account',
      );
    }

    final userModel = UserModel(
      uid: currentUser.uid,
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
    if (Platform.isLinux) {
      throw UnsupportedError(
        'Account updates are not supported on Linux. This is a desktop testing build.',
      );
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No authenticated user found.',
      );
    }

    // Update password if provided
    if (newPassword != null && newPassword.isNotEmpty) {
      try {
        await currentUser.updatePassword(newPassword);
      } catch (e) {
        if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
          throw FirebaseAuthException(
            code: 'requires-recent-login',
            message:
                'For security reasons, please sign out and sign back in before changing your password.',
          );
        }
        rethrow;
      }
    }

    // Fetch current profile
    final profile = await _firestoreService.fetchUserByUid(currentUser.uid);
    if (profile == null) {
      throw FirebaseAuthException(
        code: 'missing-profile',
        message: 'User profile not found',
      );
    }

    // Create updated profile
    final updatedProfile = UserModel(
      uid: profile.uid,
      email: profile.email,
      studentId: profile.studentId,
      role: profile.role,
      displayName: displayName?.isNotEmpty == true
          ? displayName!
          : profile.displayName,
    );

    // Update Firestore if display name changed or password was updated
    if ((displayName != null &&
            displayName.isNotEmpty &&
            displayName != profile.displayName) ||
        (newPassword != null && newPassword.isNotEmpty)) {
      await _firestoreService.updateUser(currentUser.uid, updatedProfile);
    }

    return updatedProfile;
  }

  Future<void> signOut() async {
    if (!Platform.isLinux) {
      await _auth.signOut();
    }
  }
}
