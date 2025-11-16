import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

/// Authentication provider for managing user auth state
///
/// Provides authentication state, user info, and auth methods
/// Uses ChangeNotifier for state management with Provider package
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  String? get userId => _user?.uid;
  String? get userEmail => _user?.email;
  String? get userName => _user?.displayName;

  AuthProvider() {
    // Listen to authentication state changes
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Register new user
  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    required String phoneNumber,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final user = await _authService.registerWithEmailPassword(
        email: email,
        password: password,
        displayName: displayName,
        phoneNumber: phoneNumber,
      );

      _user = user;
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Sign in existing user
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final user = await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );

      _user = user;
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      _setLoading(true);
      _setError(null);

      await _authService.signOut();
      
      _user = null;
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  /// Send password reset email
  Future<bool> sendPasswordReset(String email) async {
    try {
      _setLoading(true);
      _setError(null);

      await _authService.sendPasswordResetEmail(email);
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Update display name
  Future<bool> updateDisplayName(String displayName) async {
    try {
      _setLoading(true);
      _setError(null);

      await _authService.updateDisplayName(displayName);
      
      // Reload user to get updated data
      _user = _authService.currentUser;
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Update email
  Future<bool> updateEmail(String newEmail) async {
    try {
      _setLoading(true);
      _setError(null);

      await _authService.updateEmail(newEmail);
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Update password
  Future<bool> updatePassword(String newPassword) async {
    try {
      _setLoading(true);
      _setError(null);

      await _authService.updatePassword(newPassword);
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Reauthenticate user
  Future<bool> reauthenticate(String email, String password) async {
    try {
      _setLoading(true);
      _setError(null);

      await _authService.reauthenticate(email, password);
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Delete user account
  Future<bool> deleteAccount() async {
    try {
      _setLoading(true);
      _setError(null);

      await _authService.deleteAccount();
      
      _user = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
}
