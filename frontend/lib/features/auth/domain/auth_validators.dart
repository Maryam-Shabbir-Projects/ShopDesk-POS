/// Quick checks for instant feedback. The server repeats them; never trust
/// only the app.
abstract final class AuthValidators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _letter = RegExp(r'[A-Za-z]');
  static final _digit = RegExp(r'\d');

  static String? email(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Enter your email';
    if (!_email.hasMatch(t)) return 'Enter a valid email, like name@shop.com';
    return null;
  }

  static String? password(String? v) {
    final t = v ?? '';
    if (t.length < 8) return 'Use at least 8 characters';
    if (!_letter.hasMatch(t) || !_digit.hasMatch(t)) return 'Include at least one letter and one number';
    return null;
  }

  static String? Function(String?) matches(String Function() other) =>
      (v) => v == other() ? null : 'The two passwords do not match';
}
