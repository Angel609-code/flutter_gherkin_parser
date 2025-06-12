/// A parsed tag expression that you can evaluate against a set of tags.
abstract class TagExpr {
  bool evaluate(Set<String> tags);
}

class TagAtom extends TagExpr {
  final String tag;
  TagAtom(this.tag);

  @override
  bool evaluate(Set<String> tags) => tags.contains(tag);
}

class NotExpr extends TagExpr {
  final TagExpr inner;
  NotExpr(this.inner);

  @override
  bool evaluate(Set<String> tags) => !inner.evaluate(tags);
}

class AndExpr extends TagExpr {
  final TagExpr left, right;
  AndExpr(this.left, this.right);

  @override
  bool evaluate(Set<String> tags) =>  left.evaluate(tags) && right.evaluate(tags);
}

class OrExpr extends TagExpr {
  final TagExpr left, right;
  OrExpr(this.left, this.right);

  @override
  bool evaluate(Set<String> tags) => left.evaluate(tags) || right.evaluate(tags);
}

/// Parses expressions like `not @a and (@b or @c)`
TagExpr parseTagExpression(String input) {
  final tokens = input
      .replaceAll('(', ' ( ')
      .replaceAll(')', ' ) ')
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  int idx = 0;

  late TagExpr Function() parseOr;
  late TagExpr Function() parseAnd;
  late TagExpr Function() parseAtom;

  parseAtom = () {
    if (idx >= tokens.length) throw 'Unexpected end of tags';
    final t = tokens[idx++];
    if (t == 'not') {
      return NotExpr(parseAtom());
    } else if (t == '(') {
      final expr = parseOr();
      if (idx >= tokens.length || tokens[idx] != ')') {
        throw 'Missing closing parenthesis';
      }
      idx++;
      return expr;
    } else if (t.startsWith('@')) {
      return TagAtom(t.substring(1));
    }
    throw 'Unexpected token $t';
  };

  parseAnd = () {
    var expr = parseAtom();
    while (idx < tokens.length && tokens[idx] == 'and') {
      idx++;
      expr = AndExpr(expr, parseAtom());
    }
    return expr;
  };

  parseOr = () {
    var expr = parseAnd();
    while (idx < tokens.length && tokens[idx] == 'or') {
      idx++;
      expr = OrExpr(expr, parseAnd());
    }
    return expr;
  };

  return parseOr();
}
