/// Picks a sensible default icon from a product name or category.
abstract final class EmojiGuess {
  static const palette = <String>[
    '💊', '🩹', '🧴', '🧼', '🪥', '🥛', '🥚', '🍞', '🥐', '🍌', '🍎', '🍅',
    '🥔', '🥦', '🍚', '🫒', '🧂', '🍫', '🍪', '🧃', '🥤', '☕', '💧', '🍗',
    '🥩', '🐟', '🧀', '🍦', '🍼', '🔋', '💡', '🖊️', '📓', '📱', '🔌', '🧽',
    '🍿', '🛒', '📦',
  ];

  static final List<(RegExp, String)> _rules = [
    (RegExp(r'tablet|pill|capsule|medic|panadol|paracetamol|vitamin|pharma|health'), '💊'),
    (RegExp(r'syrup|lotion|cream|shampoo|\bbottle'), '🧴'),
    (RegExp(r'\bpads?\b|napkin|sanitary|bandage|plaster'), '🩹'),
    (RegExp(r'soap|detergent|wash|clean'), '🧼'),
    (RegExp(r'tooth'), '🪥'),
    (RegExp(r'milk|dairy'), '🥛'),
    (RegExp(r'\begg'), '🥚'),
    (RegExp(r'croissant'), '🥐'),
    (RegExp(r'bread|loaf|\bbun\b|bakery|cake'), '🍞'),
    (RegExp(r'banana'), '🍌'),
    (RegExp(r'apple|fruit'), '🍎'),
    (RegExp(r'tomato'), '🍅'),
    (RegExp(r'potato|crisp|chips?\b'), '🥔'),
    (RegExp(r'vegetable|spinach|onion|carrot|produce'), '🥦'),
    (RegExp(r'\brice\b|\batta\b|flour|wheat|grain'), '🍚'),
    (RegExp(r'\boil\b|ghee'), '🫒'),
    (RegExp(r'\bsalt\b|sugar|spice'), '🧂'),
    (RegExp(r'chocolate|candy|sweet'), '🍫'),
    (RegExp(r'biscuit|cookie'), '🍪'),
    (RegExp(r'juice'), '🧃'),
    (RegExp(r'cola|soda|drink|pepsi|beverage'), '🥤'),
    (RegExp(r'\btea\b|coffee'), '☕'),
    (RegExp(r'water'), '💧'),
    (RegExp(r'chicken'), '🍗'),
    (RegExp(r'meat|beef|mutton'), '🥩'),
    (RegExp(r'\bfish\b'), '🐟'),
    (RegExp(r'cheese'), '🧀'),
    (RegExp(r'ice cream'), '🍦'),
    (RegExp(r'baby|diaper'), '🍼'),
    (RegExp(r'battery'), '🔋'),
    (RegExp(r'bulb|\blight'), '💡'),
    (RegExp(r'\bpen(cil)?s?\b|stationery'), '🖊️'),
    (RegExp(r'book|\bcopy\b|notebook'), '📓'),
    (RegExp(r'phone|mobile'), '📱'),
    (RegExp(r'charger|cable'), '🔌'),
    (RegExp(r'snack'), '🍿'),
    (RegExp(r'grocery'), '🛒'),
  ];

  static String forProduct(String name, String category) {
    String? find(String text) {
      final t = text.toLowerCase();
      for (final (pattern, emoji) in _rules) {
        if (pattern.hasMatch(t)) return emoji;
      }
      return null;
    }

    return find(name) ?? find(category) ?? '📦';
  }
}
