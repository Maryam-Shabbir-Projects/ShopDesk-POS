enum AuthFailureKind {
  invalidCredentials,
  emailNotVerified,
  invalidCode,
  codeExpired,
  tooManyAttempts,
  rateLimited,
  weakPassword,
  signUpClosed,
  network,
  unknown,
}

/// One error type for every auth backend, with a message safe to show users.
class AuthFailure implements Exception {
  const AuthFailure(this.kind, [this.message]);
  final AuthFailureKind kind;
  final String? message;

  String get text =>
      message ??
      switch (kind) {
        AuthFailureKind.invalidCredentials => 'Email or password is incorrect.',
        AuthFailureKind.emailNotVerified => 'Please verify your email first.',
        AuthFailureKind.invalidCode => 'That code is not correct. Check it and try again.',
        AuthFailureKind.codeExpired => 'That code has expired. Request a new one.',
        AuthFailureKind.tooManyAttempts => 'Too many wrong tries. Request a new code.',
        AuthFailureKind.rateLimited => 'Too many requests. Please wait a minute and try again.',
        AuthFailureKind.weakPassword => 'That password is too weak. Use 8 or more characters with letters and numbers.',
        AuthFailureKind.signUpClosed => 'Creating new accounts is turned off for this shop.',
        AuthFailureKind.network => 'Could not reach the server. Check your internet connection.',
        AuthFailureKind.unknown => 'Something went wrong. Please try again.',
      };

  @override
  String toString() => text;
}
