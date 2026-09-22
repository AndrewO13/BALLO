import 'dart:math';

/// Generates alternate usernames when the preferred handle is taken.
class UsernameSuggestions {
  UsernameSuggestions._();

  static final _random = Random();

  static List<String> candidates(String base) {
    final clean = base.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    if (clean.length < 3) return [];

    final shortBase = clean.length > 14 ? clean.substring(0, 14) : clean;
    final yearSuffix = DateTime.now().year % 100;
    final randomSuffix = _random.nextInt(900) + 100;

    final seeds = <String>{
      '$shortBase$randomSuffix',
      '${shortBase}_$yearSuffix',
      '${shortBase}_fc',
      'the_$shortBase',
      '$shortBase${_random.nextInt(90) + 10}',
      '${shortBase}_${_random.nextInt(900) + 100}',
    };

    return seeds
        .map((s) => s.length > 20 ? s.substring(0, 20) : s)
        .where((s) => s.length >= 3)
        .take(6)
        .toList();
  }
}
