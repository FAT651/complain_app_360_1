import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  Future<UserModel?> restoreSignedInUser() async {
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

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
