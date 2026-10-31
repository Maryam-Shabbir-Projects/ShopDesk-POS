enum ScanOutcome { added, unknown, blocked }

/// What a screen reports back after handling a scanned code.
class ScanResult {
  const ScanResult(this.outcome, this.message, {this.code});
  ScanResult.added(String message) : this(ScanOutcome.added, message);
  ScanResult.blocked(String message) : this(ScanOutcome.blocked, message);
  ScanResult.unknown(String code) : this(ScanOutcome.unknown, 'No product uses $code', code: code);

  final ScanOutcome outcome;
  final String message;
  final String? code;
}
