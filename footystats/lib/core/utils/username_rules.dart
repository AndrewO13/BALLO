/// Local username / display-name blocklist (instant) plus OpenAI via backend.
class UsernameRules {
  UsernameRules._();

  static final _formatPattern = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  /// Minimal blocklist for common abuse / sexual / hate tokens.
  /// Kept short; OpenAI Moderation handles nuanced cases server-side.
  static const _blockedTokens = <String>{
    'nigger',
    'nigga',
    'faggot',
    'fag',
    'retard',
    'rape',
    'rapist',
    'pedo',
    'paedo',
    'porn',
    'porno',
    'xxx',
    'onlyfans',
    'hitler',
    'nazi',
    'kkk',
    'slut',
    'whore',
    'cock',
    'dick',
    'pussy',
    'cum',
    'anal',
    'fuck',
    'fucker',
    'shit',
    'asshole',
    'bitch',
  };

  static String normalize(String raw) => raw.trim();

  static bool isValidFormat(String username) => _formatPattern.hasMatch(username);

  static String? formatError(String? raw) {
    final value = normalize(raw ?? '');
    if (value.isEmpty) return 'Enter a username';
    if (value.length < 3) return 'At least 3 characters';
    if (value.length > 20) return 'Maximum 20 characters';
    if (!_formatPattern.hasMatch(value)) {
      return 'Use letters, numbers, and underscores only';
    }
    return null;
  }

  /// Returns an error if [raw] contains a blocked token (username or name).
  static String? offensiveContentError(String? raw) {
    final value = normalize(raw ?? '').toLowerCase();
    if (value.isEmpty) return null;
    final compact = value.replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (final token in _blockedTokens) {
      if (compact.contains(token) || value.contains(token)) {
        return 'This name is not allowed. Please choose another.';
      }
    }
    return null;
  }

  static String? usernameError(String? raw) {
    return formatError(raw) ?? offensiveContentError(raw);
  }
}
