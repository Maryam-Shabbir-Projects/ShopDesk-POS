import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shopdesk/features/auth/domain/app_user.dart';
import 'package:shopdesk/features/auth/domain/auth_failure.dart';
import 'package:shopdesk/features/auth/domain/auth_repository.dart';

/// Where the session is kept on the phone. The default is the system keystore
/// (Android Keystore / iOS Keychain). Tests pass an in-memory version.
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureKeyValueStore implements KeyValueStore {
  const SecureKeyValueStore([this._storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class _Reply {
  _Reply(this.status, this.json);
  final int status;
  final Map<String, dynamic> json;
  bool get ok => status >= 200 && status < 300;
}

/// Talks to your own Node.js server (the `shopdesk_server` folder).
/// The server makes and checks the codes and sends the emails; this class only
/// carries what the person types. Passwords and codes go over HTTPS only.
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({
    required String baseUrl,
    http.Client? client,
    KeyValueStore? store,
    this.timeout = const Duration(seconds: 20),
  })  : _base = Uri.parse(baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl),
        _client = client ?? http.Client(),
        _store = store ?? const SecureKeyValueStore();

  static const _refreshKey = 'auth_refresh_token';
  static const _userKey = 'auth_user';

  final Uri _base;
  final http.Client _client;
  final KeyValueStore _store;
  final Duration timeout;

  String? _accessToken;
  String? _resetToken;

  /// Short-lived token for calls to protected server routes (shop sync, later).
  String? get accessToken => _accessToken;

  // ---------------------------------------------------------------- plumbing

  Uri _uri(String path) => _base.replace(path: '${_base.path}$path');

  /// Sends a request. Only throws for "could not reach the server".
  Future<_Reply> _request(String path, Map<String, Object?> body) async {
    final http.Response res;
    try {
      res = await _client
          .post(_uri(path), headers: const {'content-type': 'application/json'}, body: jsonEncode(body))
          .timeout(timeout);
    } catch (_) {
      throw const AuthFailure(AuthFailureKind.network);
    }
    var json = <String, dynamic>{};
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {
        // Not JSON (for example an error page from a proxy). Handled by status below.
      }
    }
    return _Reply(res.statusCode, json);
  }

  /// Like [_request] but turns any error answer into an [AuthFailure].
  Future<Map<String, dynamic>> _post(String path, Map<String, Object?> body) async {
    final reply = await _request(path, body);
    if (reply.ok) return reply.json;
    throw _failure(reply);
  }

  AuthFailure _failure(_Reply reply) {
    if (reply.status == 502 || reply.status == 503 || reply.status == 504) {
      return const AuthFailure(AuthFailureKind.network);
    }
    final error = reply.json['error'];
    final code = error is Map ? error['code'] : null;
    final message = error is Map && error['message'] is String ? error['message'] as String : null;
    return switch (code) {
      'invalid_credentials' => const AuthFailure(AuthFailureKind.invalidCredentials),
      'email_not_verified' => const AuthFailure(AuthFailureKind.emailNotVerified),
      'invalid_code' => const AuthFailure(AuthFailureKind.invalidCode),
      'code_expired' => const AuthFailure(AuthFailureKind.codeExpired),
      'too_many_attempts' => const AuthFailure(AuthFailureKind.tooManyAttempts),
      'rate_limited' => const AuthFailure(AuthFailureKind.rateLimited),
      'weak_password' => const AuthFailure(AuthFailureKind.weakPassword),
      'sign_up_closed' => const AuthFailure(AuthFailureKind.signUpClosed),
      // 'unauthorized', 'invalid_request' and anything else: show the server's own sentence.
      _ => AuthFailure(AuthFailureKind.unknown, message),
    };
  }

  AppUser _readUser(Object? raw) {
    final u = raw as Map<String, dynamic>;
    final role = UserRole.values.where((r) => r.name == u['role']).firstOrNull ?? UserRole.owner;
    return AppUser(id: u['id'] as String, email: u['email'] as String, role: role);
  }

  /// Saves the session from a sign-in / verify / refresh / reset answer.
  Future<AppUser> _startSession(Map<String, dynamic> json) async {
    try {
      final user = _readUser(json['user']);
      final refresh = json['refreshToken'] as String;
      _accessToken = json['accessToken'] as String;
      await _store.write(_refreshKey, refresh);
      await _store.write(_userKey, jsonEncode(json['user']));
      return user;
    } catch (_) {
      throw const AuthFailure(AuthFailureKind.unknown);
    }
  }

  Future<void> _clearSession() async {
    _accessToken = null;
    _resetToken = null;
    await _store.delete(_refreshKey);
    await _store.delete(_userKey);
  }

  Future<AppUser?> _cachedUser() async {
    final raw = await _store.read(_userKey);
    if (raw == null) return null;
    try {
      return _readUser(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------ the API

  /// Opens the app. A shop must keep working with a bad connection, so when the
  /// server cannot be reached the saved owner stays signed in. Only a clear
  /// "this session is over" answer from the server signs the owner out.
  @override
  Future<AppUser?> restore() async {
    final refresh = await _store.read(_refreshKey);
    if (refresh == null) return null;
    try {
      final reply = await _request('/auth/refresh', {'refreshToken': refresh});
      if (reply.ok) return await _startSession(reply.json);
      if (reply.status == 401) {
        await _clearSession();
        return null;
      }
      return _cachedUser(); // server trouble: do not log the shop out
    } on AuthFailure {
      return _cachedUser(); // offline
    }
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    await _post('/auth/signup', {'email': email.trim(), 'password': password});
  }

  @override
  Future<AppUser> verifySignUp({required String email, required String code}) async =>
      _startSession(await _post('/auth/verify-signup', {'email': email.trim(), 'code': code.trim()}));

  @override
  Future<void> resendSignUpCode(String email) async {
    await _post('/auth/resend-signup', {'email': email.trim()});
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) async =>
      _startSession(await _post('/auth/signin', {'email': email.trim(), 'password': password}));

  @override
  Future<void> requestPasswordReset(String email) async {
    await _post('/auth/forgot', {'email': email.trim()});
  }

  @override
  Future<void> verifyResetCode({required String email, required String code}) async {
    final json = await _post('/auth/verify-reset', {'email': email.trim(), 'code': code.trim()});
    final token = json['resetToken'];
    if (token is! String || token.isEmpty) throw const AuthFailure(AuthFailureKind.unknown);
    _resetToken = token;
  }

  @override
  Future<AppUser> setNewPassword(String newPassword) async {
    final token = _resetToken;
    if (token == null) {
      throw const AuthFailure(AuthFailureKind.unknown, 'This reset has expired. Please start again.');
    }
    final user = await _startSession(
      await _post('/auth/reset-password', {'resetToken': token, 'newPassword': newPassword}),
    );
    _resetToken = null;
    return user;
  }

  @override
  Future<void> signOut() async {
    final refresh = await _store.read(_refreshKey);
    if (refresh != null) {
      try {
        await _request('/auth/signout', {'refreshToken': refresh});
      } catch (_) {
        // Offline sign-out still works on this phone. The server session ends when it expires.
      }
    }
    await _clearSession();
  }
}
