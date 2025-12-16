import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  AuthController() {
    // Listen to auth state changes (UserModel)
    _authService.authStateChanges.listen((UserModel? user) async {
      if (user != null) {
        _currentUser = await _authService.getUserData(user.uid);
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });
  }

  Future<String?> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _authService.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      _isLoading = false;
      notifyListeners();
      return null; // Success
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _authService.login(
        email: email,
        password: password,
      );
      _isLoading = false;
      notifyListeners();
      return null; // Success
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }
}