import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopdesk/core/config/app_config.dart';
import 'package:shopdesk/features/auth/data/http_auth_repository.dart';
import 'package:shopdesk/features/auth/data/local_demo_auth_repository.dart';
import 'package:shopdesk/features/auth/data/supabase_auth_repository.dart';
import 'package:shopdesk/features/auth/domain/app_user.dart';
import 'package:shopdesk/features/auth/domain/auth_repository.dart';
import 'package:shopdesk/features/settings/application/settings_controller.dart';

/// The last code the demo backend "sent". Only used in demo mode, to show
/// the code on screen because no email is really sent.
final demoCodeProvider = StateProvider<String?>((ref) => null);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (AppConfig.hasApi) return HttpAuthRepository(baseUrl: AppConfig.apiUrl);
  if (AppConfig.hasSupabase) return SupabaseAuthRepository();
  return LocalDemoAuthRepository(
    ref.watch(sharedPrefsProvider),
    onCode: (email, code) => ref.read(demoCodeProvider.notifier).state = code,
  );
});

const _ownerKey = 'owner_email';

/// True once an owner account exists on this device. Sign-up is hidden after
/// that. To enforce it for real, also turn off public sign-ups on the server.
final ownerRegisteredProvider = StateProvider<bool>(
  (ref) => ref.read(sharedPrefsProvider).getString(_ownerKey) != null,
);

/// Whether to show "Create account". With your own server the SERVER decides
/// (it answers "turned off" once the owner exists), so the button always shows.
/// In demo / Supabase mode it is hidden after the first owner on this device.
final canSignUpProvider = Provider<bool>(
  (ref) => AppConfig.hasApi || !ref.watch(ownerRegisteredProvider),
);

class AuthController extends AsyncNotifier<AppUser?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);
  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  Future<AppUser?> build() => _repo.restore();

  Future<void> _complete(AppUser user) async {
    await _prefs.setString(_ownerKey, user.email);
    ref.read(ownerRegisteredProvider.notifier).state = true;
    state = AsyncData(user);
  }

  Future<void> signUp(String email, String password) => _repo.signUp(email: email, password: password);

  /// Verifies the emailed code, then signs the owner in.
  Future<void> verifySignUp(String email, String code) async =>
      _complete(await _repo.verifySignUp(email: email, code: code));

  Future<void> resendSignUpCode(String email) => _repo.resendSignUpCode(email);

  Future<void> signIn(String email, String password) async =>
      _complete(await _repo.signIn(email: email, password: password));

  Future<void> requestPasswordReset(String email) => _repo.requestPasswordReset(email);

  Future<void> verifyResetCode(String email, String code) => _repo.verifyResetCode(email: email, code: code);

  /// Call only after [verifyResetCode]. Signs the owner in.
  Future<void> setNewPassword(String password) async => _complete(await _repo.setNewPassword(password));

  Future<void> signOut() async {
    await _repo.signOut();
    ref.read(demoCodeProvider.notifier).state = null;
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);
