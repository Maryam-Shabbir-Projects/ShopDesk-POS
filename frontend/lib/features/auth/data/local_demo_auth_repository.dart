import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopdesk/features/auth/domain/app_user.dart';
import 'package:shopdesk/features/auth/domain/auth_failure.dart';
import 'package:shopdesk/features/auth/domain/auth_repository.dart';

class _Pending {
  _Pending(this.salt, this.hash, this.expires);
  final String salt;
  final String hash;
  final DateTime expires;
  int attempts = 0;
}

/// Works with no server so you can build and demo the screens. Nothing is
/// emailed: [onCode] hands the code to the UI, which shows it on screen.
/// It follows the same rules a real backend should: hashed passwords and
/// codes, 10-minute expiry, single use, 5 tries. It is NOT a replacement
/// for a real server: anyone with the phone's files can tamper with it.
class LocalDemoAuthRepository implements AuthRepository {
  LocalDemoAuthRepository(this._prefs, {this.onCode, DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  static const codeLifetime = Duration(minutes: 10);
  static const maxAttempts = 5;
  static const _accountsKey = 'demo_accounts';
  static const _sessionKey = 'demo_session';

  final SharedPreferences _prefs;
  final void Function(String email, String code)? onCode;
  final DateTime Function() _now;
  final Map<String, _Pending> _pending = {};
  final Random _random = Random.secure();
  String? _resetEmail;

  String _norm(String e) => e.trim().toLowerCase();
  String _hash(String value, String salt) => sha256.convert(utf8.encode('$salt:$value')).toString();
  String _newSalt() => base64Url.encode(List<int>.generate(16, (_) => _random.nextInt(256)));
  AppUser _user(String email) => AppUser(id: email, email: email);

  Map<String, dynamic> _accounts() {
    final raw = _prefs.getString(_accountsKey);
    return raw == null ? <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _saveAccounts(Map<String, dynamic> accounts) => _prefs.setString(_accountsKey, jsonEncode(accounts));

  void _issue(String email, String purpose) {
    final code = (100000 + _random.nextInt(900000)).toString();
    final salt = _newSalt();
    _pending['$purpose:$email'] = _Pending(salt, _hash(code, salt), _now().add(codeLifetime));
    onCode?.call(email, code);
  }

  void _check(String email, String purpose, String code) {
    final key = '$purpose:$email';
    final pending = _pending[key];
    if (pending == null) throw const AuthFailure(AuthFailureKind.invalidCode);
    if (_now().isAfter(pending.expires)) {
      _pending.remove(key);
      throw const AuthFailure(AuthFailureKind.codeExpired);
    }
    if (pending.attempts >= maxAttempts) {
      _pending.remove(key);
      throw const AuthFailure(AuthFailureKind.tooManyAttempts);
    }
    pending.attempts++;
    if (_hash(code.trim(), pending.salt) != pending.hash) throw const AuthFailure(AuthFailureKind.invalidCode);
    _pending.remove(key); // single use
  }

  @override
  Future<AppUser?> restore() async {
    final email = _prefs.getString(_sessionKey);
    if (email == null) return null;
    final account = _accounts()[email] as Map<String, dynamic>?;
    return (account != null && account['verified'] == true) ? _user(email) : null;
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    final key = _norm(email);
    final accounts = _accounts();
    final existing = accounts[key] as Map<String, dynamic>?;
    if (existing != null && existing['verified'] == true) return; // never reveal that it exists
    final salt = _newSalt();
    accounts[key] = {'salt': salt, 'hash': _hash(password, salt), 'verified': false};
    await _saveAccounts(accounts);
    _issue(key, 'signup');
  }

  @override
  Future<AppUser> verifySignUp({required String email, required String code}) async {
    final key = _norm(email);
    _check(key, 'signup', code);
    final accounts = _accounts();
    final account = accounts[key] as Map<String, dynamic>?;
    if (account == null) throw const AuthFailure(AuthFailureKind.invalidCode);
    account['verified'] = true;
    await _saveAccounts(accounts);
    await _prefs.setString(_sessionKey, key);
    return _user(key);
  }

  @override
  Future<void> resendSignUpCode(String email) async {
    final key = _norm(email);
    final account = _accounts()[key] as Map<String, dynamic>?;
    if (account != null && account['verified'] != true) _issue(key, 'signup');
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    final key = _norm(email);
    final account = _accounts()[key] as Map<String, dynamic>?;
    if (account == null || _hash(password, account['salt'] as String) != account['hash']) {
      throw const AuthFailure(AuthFailureKind.invalidCredentials);
    }
    if (account['verified'] != true) throw const AuthFailure(AuthFailureKind.emailNotVerified);
    await _prefs.setString(_sessionKey, key);
    return _user(key);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    final key = _norm(email);
    final account = _accounts()[key] as Map<String, dynamic>?;
    if (account != null && account['verified'] == true) _issue(key, 'reset');
  }

  @override
  Future<void> verifyResetCode({required String email, required String code}) async {
    final key = _norm(email);
    _check(key, 'reset', code);
    _resetEmail = key;
  }

  @override
  Future<AppUser> setNewPassword(String newPassword) async {
    final key = _resetEmail;
    if (key == null) {
      throw const AuthFailure(AuthFailureKind.unknown, 'This reset has expired. Please start again.');
    }
    final accounts = _accounts();
    final account = accounts[key] as Map<String, dynamic>;
    final salt = _newSalt();
    account['salt'] = salt;
    account['hash'] = _hash(newPassword, salt);
    await _saveAccounts(accounts);
    _resetEmail = null;
    await _prefs.setString(_sessionKey, key);
    return _user(key);
  }

  @override
  Future<void> signOut() => _prefs.remove(_sessionKey);
}
