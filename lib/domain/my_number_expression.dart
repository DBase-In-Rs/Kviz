class MyNumberExpressionException implements Exception {
  const MyNumberExpressionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MyNumberExpressionResult {
  const MyNumberExpressionResult({
    required this.value,
    required this.usedNumbers,
  });

  final int value;
  final List<int> usedNumbers;

  int distanceTo(int target) => (value - target).abs();
}

class MyNumberExpressionEvaluator {
  const MyNumberExpressionEvaluator._();

  static MyNumberExpressionResult evaluate(
    String expression,
    List<int> allowedNumbers,
  ) {
    final tokens = _tokenize(expression);
    if (tokens.isEmpty) {
      throw const MyNumberExpressionException('empty_expression');
    }

    final parser = _MyNumberParser(tokens, _countNumbers(allowedNumbers));
    return parser.parse();
  }

  static List<String> _tokenize(String expression) {
    final compact = expression.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return const <String>[];

    final tokenPattern = RegExp(r'\d+|[()+\-*/]');
    final tokens = <String>[];
    var index = 0;
    for (final match in tokenPattern.allMatches(compact)) {
      if (match.start != index) {
        throw const MyNumberExpressionException('invalid_character');
      }
      tokens.add(match.group(0)!);
      index = match.end;
    }
    if (index != compact.length) {
      throw const MyNumberExpressionException('invalid_character');
    }

    return tokens;
  }

  static Map<int, int> _countNumbers(List<int> numbers) {
    final counts = <int, int>{};
    for (final number in numbers) {
      counts[number] = (counts[number] ?? 0) + 1;
    }
    return counts;
  }
}

class _MyNumberParser {
  _MyNumberParser(this._tokens, this._remainingNumbers);

  final List<String> _tokens;
  final Map<int, int> _remainingNumbers;
  final List<int> _usedNumbers = <int>[];
  int _index = 0;

  MyNumberExpressionResult parse() {
    final value = _parseExpression();
    if (_index != _tokens.length) {
      throw const MyNumberExpressionException('unexpected_token');
    }
    if (_usedNumbers.isEmpty) {
      throw const MyNumberExpressionException('number_missing');
    }

    return MyNumberExpressionResult(
      value: value,
      usedNumbers: List<int>.unmodifiable(_usedNumbers),
    );
  }

  int _parseExpression() {
    var value = _parseTerm();
    while (_match('+') || _match('-')) {
      final operator = _previous;
      final right = _parseTerm();
      value = operator == '+' ? value + right : value - right;
      if (value < 0) {
        throw const MyNumberExpressionException('negative_result');
      }
    }
    return value;
  }

  int _parseTerm() {
    var value = _parseFactor();
    while (_match('*') || _match('/')) {
      final operator = _previous;
      final right = _parseFactor();
      if (operator == '*') {
        value *= right;
      } else {
        if (right == 0 || value % right != 0) {
          throw const MyNumberExpressionException('division_not_integer');
        }
        value ~/= right;
      }
    }
    return value;
  }

  int _parseFactor() {
    if (_match('(')) {
      final value = _parseExpression();
      if (!_match(')')) {
        throw const MyNumberExpressionException('missing_parenthesis');
      }
      return value;
    }

    if (_isAtEnd) {
      throw const MyNumberExpressionException('number_expected');
    }

    final token = _advance();
    final value = int.tryParse(token);
    if (value == null) {
      throw const MyNumberExpressionException('number_expected');
    }

    final remaining = _remainingNumbers[value] ?? 0;
    if (remaining <= 0) {
      throw const MyNumberExpressionException('number_not_available');
    }
    _remainingNumbers[value] = remaining - 1;
    _usedNumbers.add(value);
    return value;
  }

  bool _match(String token) {
    if (_isAtEnd || _tokens[_index] != token) {
      return false;
    }
    _index += 1;
    return true;
  }

  String _advance() {
    final token = _tokens[_index];
    _index += 1;
    return token;
  }

  bool get _isAtEnd => _index >= _tokens.length;
  String get _previous => _tokens[_index - 1];
}
