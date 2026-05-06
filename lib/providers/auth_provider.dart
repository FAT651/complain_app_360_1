import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _keepSignedIn = false;
  UserModel? _currentUser;
  String? _errorMessage;
  String? _successMessage;

  bool get isLoading => _isLoading;
  bool get keepSignedIn => _keepSignedIn;
  UserModel? get currentUser => _currentUser;
  String? get role => _currentUser?.role;
  String? get studentId => _currentUser?.studentId;
  bool get isAuthenticated => _currentUser != null;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void toggleKeepSignedIn(bool value) {
    _keepSignedIn = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearSuccess() {
    _successMessage = null;
    notifyListeners();
  }

  Future<bool> _checkNetworkConnectivity() async {
    try {
      // Try to reach a reliable host to check connectivity
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
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
    _successMessage = null;
    notifyListeners();

    try {
      // Check network connectivity first
      final hasNetwork = await _checkNetworkConnectivity();
      if (!hasNetwork) {
        _errorMessage =
            'No internet connection. Please check your network and try again.';
        return false;
      }

      // Add timeout to the sign in operation
      _currentUser = await _authService
          .signIn(emailOrId, password)
          .timeout(const Duration(seconds: 30));

      if (_currentUser != null) {
        _successMessage = 'Welcome back, ${_currentUser!.displayName}!';
      }
      return _currentUser != null;
    } on TimeoutException {
      _errorMessage =
          'Connection timeout. Please check your internet connection and try again.';
      return false;
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
    _successMessage = null;
    notifyListeners();

    try {
      // Check network connectivity first
      final hasNetwork = await _checkNetworkConnectivity();
      if (!hasNetwork) {
        _errorMessage =
            'No internet connection. Please check your network and try again.';
        return false;
      }

      // Add timeout to the register operation
      _currentUser = await _authService
          .register(emailOrId, password)
          .timeout(const Duration(seconds: 30));

      if (_currentUser != null) {
        _successMessage = 'Account created successfully! Welcome aboard';
      }
      return _currentUser != null;
    } on TimeoutException {
      _errorMessage =
          'Connection timeout. Please check your internet connection and try again.';
      return false;
    } catch (e) {
      _errorMessage = _getUserFriendlyErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateAccount({
    required String displayName,
    String? newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      if (Platform.isLinux) {
        if (_currentUser == null) {
          throw Exception('No authenticated user.');
        }
        _currentUser = UserModel(
          uid: _currentUser!.uid,
          email: _currentUser!.email,
          studentId: _currentUser!.studentId,
          role: _currentUser!.role,
          displayName: displayName,
        );
      } else {
        // Check network connectivity first
        final hasNetwork = await _checkNetworkConnectivity();
        if (!hasNetwork) {
          _errorMessage =
              'No internet connection. Please check your network and try again.';
          return false;
        }

        // Add timeout to the update operation
        _currentUser = await _authService
            .updateUserAccount(
              displayName: displayName,
              newPassword: newPassword,
            )
            .timeout(const Duration(seconds: 30));
      }
      _successMessage = 'Account updated successfully.';
      return true;
    } on TimeoutException {
      _errorMessage =
          'Connection timeout. Please check your internet connection and try again.';
      return false;
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
    _successMessage = null;
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

    // Check for network-related exceptions first
    if (_isNetworkError(error)) {
      return 'Network connection error. Please check your internet connection and try again.';
    }

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

    if (errorString.contains('too-many-requests')) {
      return 'Too many failed attempts. Please try again later.';
    }

    if (errorString.contains('missing-profile')) {
      return 'Account setup incomplete. Please contact support.';
    }

    // Default fallback
    return 'Authentication failed. Please try again.';
  }

  bool _isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Check for various network error indicators
    return errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('unavailable') ||
        errorString.contains('unrechable') ||
        errorString.contains('unreachable') ||
        errorString.contains('unable to reach') ||
        errorString.contains('failed to connect') ||
        error is SocketException;
  }
}
