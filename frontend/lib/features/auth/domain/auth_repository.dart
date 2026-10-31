import 'package:shopdesk/features/auth/domain/app_user.dart';

/// Everything the screens need from an auth backend. Codes are always sent
/// by the backend to the person's email; the app only collects them.
/// Implementations: LocalDemoAuthRepository (no server) and
/// SupabaseAuthRepository. A Laravel version would implement the same.
abstract interface class AuthRepository {
  Future<AppUser?> restore();

  /// Creates an unverified account and emails a 6-digit code.
  Future<void> signUp({required String email, required String password});

  /// Checks the sign-up code. On success the account is verified and signed in.
  Future<AppUser> verifySignUp({required String email, required String code});

  Future<void> resendSignUpCode(String email);

  /// Throws AuthFailure with kind `emailNotVerified` for unverified accounts.
  Future<AppUser> signIn({required String email, required String password});

  /// Emails a reset code. Must behave the same whether or not the account exists.
  Future<void> requestPasswordReset(String email);

  /// Checks the reset code and opens a short reset session.
  Future<void> verifyResetCode({required String email, required String code});

  /// Only allowed after [verifyResetCode]. Signs the person in on success.
  Future<AppUser> setNewPassword(String newPassword);

  Future<void> signOut();
}
