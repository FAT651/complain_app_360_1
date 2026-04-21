import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _keepSignedIn = false;
  UserModel? _currentUser;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get keepSignedIn => _keepSignedIn;
  UserModel? get currentUser => _currentUser;
  String? get role => _currentUser?.role;
  String? get studentId => _currentUser?.studentId;
  bool get isAuthenticated => _currentUser != null;
  String? get errorMessage => _errorMessage;

  void toggleKeepSignedIn(bool value) {
    _keepSignedIn = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _currentUser = await _authService.restoreSignedInUser();
    } catch (e) {
      _errorMessage = 'Failed to restore session. Please sign in again.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> signIn(String emailOrId, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _currentUser = await _authService.signIn(emailOrId, password);
      return _currentUser != null;
    } catch (e) {
      _errorMessage = _getUserFriendlyErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String emailOrId, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _currentUser = await _authService.register(emailOrId, password);
      return _currentUser != null;
    } catch (e) {
      _errorMessage = _getUserFriendlyErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.signOut();
      _currentUser = null;
    } catch (e) {
      _errorMessage = 'Failed to sign out. Please try again.';
    }
    _isLoading = false;
    notifyListeners();
  }

  String _getUserFriendlyErrorMessage(dynamic error) {
    if (error is String) return error;

    // Handle Firebase Auth exceptions
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('user-not-found') ||
        errorString.contains('no user record')) {
      return 'No account found with this student ID or email.';
    }

    if (errorString.contains('wrong-password') ||
        errorString.contains('invalid-credential')) {
      return 'Incorrect password. Please try again.';
    }

    if (errorString.contains('email-already-in-use')) {
      return 'An account with this student ID or email already exists.';
    }

    if (errorString.contains('weak-password')) {
      return 'Password is too weak. Please use at least 6 characters.';
    }

    if (errorString.contains('invalid-email')) {
      return 'Invalid email format.';
    }

    if (errorString.contains('network-request-failed') ||
        errorString.contains('unavailable')) {
      return 'Network error. Please check your internet connection.';
    }

    if (errorString.contains('too-many-requests')) {
      return 'Too many failed attempts. Please try again later.';
    }

    if (errorString.contains('missing-profile')) {
      return 'Account setup incomplete. Please contact support.';
    }

    // Default fallback
    return 'Authentication failed. Please try again.';
  }
}
