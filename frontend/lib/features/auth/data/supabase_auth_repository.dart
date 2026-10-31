import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:shopdesk/features/auth/domain/app_user.dart';
import 'package:shopdesk/features/auth/domain/auth_failure.dart';
import 'package:shopdesk/features/auth/domain/auth_repository.dart';

/// Real accounts and real emails through Supabase Auth. Supabase creates the
/// codes, hashes them, sends the emails, and enforces expiry and rate limits.
/// Setup steps (email templates, SMTP, closing sign-ups) are in docs/AUTH_SETUP.md.
class SupabaseAuthRepository implements AuthRepository {
  sb.GoTrueClient get _auth => sb.Supabase.instance.client.auth;

  /// The role comes from app_metadata, which only the server can change.
  /// Never read it from user_metadata: the user can edit that themselves.
  AppUser _toUser(sb.User u) {
    final raw = u.appMetadata['role'];
    final role = UserRole.values.where((r) => r.name == raw).firstOrNull ?? UserRole.owner;
    return AppUser(id: u.id, email: u.email ?? '', role: role);
  }

  AuthFailure _fail(Object e) {
    if (e is sb.AuthException) {
      final code = (e.code ?? '').toLowerCase();
      final msg = e.message.toLowerCase();
      if (code == 'email_not_confirmed' || msg.contains('not confirmed')) {
        return const AuthFailure(AuthFailureKind.emailNotVerified);
      }
      if (code == 'invalid_credentials' || msg.contains('invalid login')) {
        return const AuthFailure(AuthFailureKind.invalidCredentials);
      }
      if (code == 'otp_expired' || msg.contains('expired')) return const AuthFailure(AuthFailureKind.codeExpired);
      if (code.contains('rate_limit') || e.statusCode == '429') return const AuthFailure(AuthFailureKind.rateLimited);
      if (code == 'weak_password') return const AuthFailure(AuthFailureKind.weakPassword);
      if (code == 'signup_disabled') return const AuthFailure(AuthFailureKind.signUpClosed);
      if (msg.contains('token') || msg.contains('otp') || msg.contains('invalid')) {
        return const AuthFailure(AuthFailureKind.invalidCode);
      }
      return AuthFailure(AuthFailureKind.unknown, e.message);
    }
    return const AuthFailure(AuthFailureKind.network);
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on AuthFailure {
      rethrow;
    } catch (e) {
      throw _fail(e);
    }
  }

  @override
  Future<AppUser?> restore() async {
    final user = _auth.currentUser;
    return user == null ? null : _toUser(user);
  }

  @override
  Future<void> signUp({required String email, required String password}) =>
      _guard(() => _auth.signUp(email: email.trim(), password: password));

  @override
  Future<AppUser> verifySignUp({required String email, required String code}) => _guard(() async {
        final res = await _auth.verifyOTP(type: sb.OtpType.signup, email: email.trim(), token: code.trim());
        final user = res.user;
        if (user == null) throw const AuthFailure(AuthFailureKind.invalidCode);
        return _toUser(user);
      });

  @override
  Future<void> resendSignUpCode(String email) =>
      _guard(() => _auth.resend(type: sb.OtpType.signup, email: email.trim()));

  @override
  Future<AppUser> signIn({required String email, required String password}) => _guard(() async {
        final res = await _auth.signInWithPassword(email: email.trim(), password: password);
        final user = res.user;
        if (user == null) throw const AuthFailure(AuthFailureKind.invalidCredentials);
        return _toUser(user);
      });

  @override
  Future<void> requestPasswordReset(String email) =>
      _guard(() => _auth.resetPasswordForEmail(email.trim()));

  @override
  Future<void> verifyResetCode({required String email, required String code}) =>
      _guard(() => _auth.verifyOTP(type: sb.OtpType.recovery, email: email.trim(), token: code.trim()));

  @override
  Future<AppUser> setNewPassword(String newPassword) => _guard(() async {
        final res = await _auth.updateUser(sb.UserAttributes(password: newPassword));
        final user = res.user;
        if (user == null) throw const AuthFailure(AuthFailureKind.unknown);
        return _toUser(user);
      });

  @override
  Future<void> signOut() => _guard(() => _auth.signOut());
}
