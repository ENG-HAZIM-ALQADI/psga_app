import '../utils/logger.dart';

class AuthService {
  AuthService._();
  
  static final AuthService _instance = AuthService._();
  static AuthService get instance => _instance;

  bool _isAuthenticated = false;
  String? _userId;
  String? _userEmail;

  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  String? get userEmail => _userEmail;

  Future<void> checkAuthStatus() async {
    AppLogger.info('[AuthService] Checking authentication status', name: 'AuthService');
    await Future.delayed(const Duration(milliseconds: 100));
    AppLogger.info('[AuthService] Auth status: $_isAuthenticated', name: 'AuthService');
  }

  Future<bool> login(String email, String password) async {
    AppLogger.info('[AuthService] Attempting login for: $email', name: 'AuthService');
    await Future.delayed(const Duration(seconds: 1));
    _isAuthenticated = true;
    _userEmail = email;
    _userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    AppLogger.success('[AuthService] Login successful', name: 'AuthService');
    return true;
  }

  Future<void> logout() async {
    AppLogger.info('[AuthService] Logging out', name: 'AuthService');
    _isAuthenticated = false;
    _userId = null;
    _userEmail = null;
    AppLogger.success('[AuthService] Logout successful', name: 'AuthService');
  }

  void setAuthenticated(bool value) {
    _isAuthenticated = value;
  }
}
