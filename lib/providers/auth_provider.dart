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
        print('⚠️ Registration failed: No network connection');
        return false;
      }

      print('🚀 Starting registration for: $emailOrId');

      // Add timeout to the register operation
      _currentUser = await _authService
          .register(emailOrId, password)
          .timeout(const Duration(seconds: 30));

      if (_currentUser != null) {
        _successMessage = 'Account created successfully! Welcome aboard';
        print('✅ Registration successful');
      }
      return _currentUser != null;
    } on TimeoutException {
      _errorMessage =
          'Connection timeout. Please check your internet connection and try again.';
      print('⏱️ Registration timeout after 30 seconds');
      return false;
    } catch (e) {
      print('❌ Registration exception: $e');
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
      // Check network connectivity first
      final hasNetwork = await _checkNetworkConnectivity();
      if (!hasNetwork) {
        _errorMessage =
            'No internet connection. Please check your network and try again.';
        return false;
      }

      // Add timeout to the update operation
      _currentUser = await _authService
          .updateUserAccount(displayName: displayName, newPassword: newPassword)
          .timeout(const Duration(seconds: 30));

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

    if (error is UnsupportedError) {
      return error.message ?? 'This operation is not supported.';
    }

    // Handle Supabase Auth exceptions
    final errorString = error.toString().toLowerCase();

    print('📋 Error details for mapping: $errorString');

    if (errorString.contains('user-not-found') ||
        errorString.contains('no user record')) {
      return 'No account found with this student ID or email.';
    }

    if (errorString.contains('wrong-password') ||
        errorString.contains('invalid-credential')) {
      return 'Incorrect password. Please try again.';
    }

    if (errorString.contains('email-already-in-use') ||
        errorString.contains('user already exists')) {
      return 'An account with this student ID or email already exists.';
    }

    if (errorString.contains('weak-password')) {
      return 'Password is too weak. Please use at least 6 characters.';
    }

    if (errorString.contains('invalid-email') ||
        errorString.contains('invalid email')) {
      return 'Invalid email format.';
    }

    if (errorString.contains('over_email_send_rate_limit') ||
        errorString.contains('email rate limit exceeded')) {
      return 'Too many verification emails have been sent. Please wait a few minutes and try again.';
    }

    if (errorString.contains('too-many-requests')) {
      return 'Too many failed attempts. Please try again later.';
    }

    if (errorString.contains('new row violates row-level security policy') ||
        errorString.contains('row-level security policy for table "users"') ||
        errorString.contains('42501')) {
      return 'Unable to create the user profile because the database row-level policy is blocking writes. Update your Supabase users table policy to allow inserts for the authenticated user.';
    }

    if (errorString.contains('missing-profile')) {
      return 'Account setup incomplete. Please contact support.';
    }

    if (errorString.contains('connection') || errorString.contains('timeout')) {
      return 'Network error. Please check your connection and try again.';
    }

    // Default fallback - show raw error in debug
    print('⚠️ Unhandled error type: $error');
    return error is Exception
        ? error.toString()
        : 'Authentication failed. Please try again.';
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
