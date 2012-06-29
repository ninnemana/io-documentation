// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Translates a string of characters into a YAML serialization tree.
 *
 * This parser is designed to closely follow the spec. All productions in the
 * spec are numbered, and the corresponding methods in the parser have the same
 * numbers. This is certainly not the most efficient way of parsing YAML, but it
 * is the easiest to write and read in the context of the spec.
 *
 * Methods corresponding to productions are also named as in the spec,
 * translating the name of the method (although not the annotation characters)
 * into camel-case for dart style.. For example, the spec has a production named
 * `nb-ns-plain-in-line`, and the method implementing it is named
 * `nb_ns_plainInLine`. The exception to that rule is methods that just
 * recognize character classes; these are named `is*`.
 */
class _Parser {
  static final TAB = 0x9;
  static final LF = 0xA;
  static final CR = 0xD;
  static final SP = 0x20;
  static final TILDE = 0x7E;
  static final NEL = 0x85;
  static final PLUS = 0x2B;
  static final HYPHEN = 0x2D;
  static final QUESTION_MARK = 0x3F;
  static final COLON = 0x3A;
  static final COMMA = 0x2C;
  static final LEFT_BRACKET = 0x5B;
  static final RIGHT_BRACKET = 0x5D;
  static final LEFT_BRACE = 0x7B;
  static final RIGHT_BRACE = 0x7D;
  static final HASH = 0x23;
  static final AMPERSAND = 0x26;
  static final ASTERISK = 0x2A;
  static final EXCLAMATION = 0x21;
  static final VERTICAL_BAR = 0x7C;
  static final GREATER_THAN = 0x3E;
  static final SINGLE_QUOTE = 0x27;
  static final DOUBLE_QUOTE = 0x22;
  static final PERCENT = 0x25;
  static final AT = 0x40;
  static final GRAVE_ACCENT = 0x60;

  static final NULL = 0x0;
  static final BELL = 0x7;
  static final BACKSPACE = 0x8;
  static final VERTICAL_TAB = 0xB;
  static final FORM_FEED = 0xC;
  static final ESCAPE = 0x1B;
  static final SLASH = 0x2F;
  static final BACKSLASH = 0x5C;
  static final UNDERSCORE = 0x5F;
  static final NBSP = 0xA0;
  static final LINE_SEPARATOR = 0x2028;
  static final PARAGRAPH_SEPARATOR = 0x2029;

  static final NUMBER_0 = 0x30;
  static final NUMBER_9 = 0x39;

  static final LETTER_A = 0x61;
  static final LETTER_B = 0x62;
  static final LETTER_E = 0x65;
  static final LETTER_F = 0x66;
  static final LETTER_N = 0x6E;
  static final LETTER_R = 0x72;
  static final LETTER_T = 0x74;
  static final LETTER_U = 0x75;
  static final LETTER_V = 0x76;
  static final LETTER_X = 0x78;

  static final LETTER_CAP_A = 0x41;
  static final LETTER_CAP_F = 0x46;
  static final LETTER_CAP_L = 0x4C;
  static final LETTER_CAP_N = 0x4E;
  static final LETTER_CAP_P = 0x50;
  static final LETTER_CAP_U = 0x55;
  static final LETTER_CAP_X = 0x58;

  static final C_SEQUENCE_ENTRY = 4;
  static final C_MAPPING_KEY = 5;
  static final C_MAPPING_VALUE = 6;
  static final C_COLLECT_ENTRY = 7;
  static final C_SEQUENCE_START = 8;
  static final C_SEQUENCE_END = 9;
  static final C_MAPPING_START = 10;
  static final C_MAPPING_END = 11;
  static final C_COMMENT = 12;
  static final C_ANCHOR = 13;
  static final C_ALIAS = 14;
  static final C_TAG = 15;
  static final C_LITERAL = 16;
  static final C_FOLDED = 17;
  static final C_SINGLE_QUOTE = 18;
  static final C_DOUBLE_QUOTE = 19;
  static final C_DIRECTIVE = 20;
  static final C_RESERVED = 21;

  static final BLOCK_OUT = 0;
  static final BLOCK_IN = 1;
  static final FLOW_OUT = 2;
  static final FLOW_IN = 3;
  static final BLOCK_KEY = 4;
  static final FLOW_KEY = 5;

  static final CHOMPING_STRIP = 0;
  static final CHOMPING_KEEP = 1;
  static final CHOMPING_CLIP = 2;

  /** The source string being parsed. */
  final String s;

  /** The current position in the source string. */
  int pos = 0;

  /** The length of the string being parsed. */
  final int len;

  /** The current (0-based) line in the source string. */
  int line = 0;

  /** The current (0-based) column in the source string. */
  int column = 0;

  /**
   * Whether we're parsing a bare document (that is, one that doesn't begin with
   * `---`). Bare documents don't allow `%` immediately following newlines.
   */
  bool inBareDocument = false;

  /**
   * The line number of the farthest position that has been parsed successfully
   * before backtracking. Used for error reporting.
   */
  int farthestLine = 0;

  /**
   * The column number of the farthest position that has been parsed
   * successfully before backtracking. Used for error reporting.
   */
  int farthestColumn = 0;

  /**
   * The name of the context of the farthest position that has been parsed
   * successfully before backtracking. Used for error reporting.
   */
  String farthestContext = "document";

  /** A stack of the names of parse contexts. Used for error reporting. */
  List<String> contextStack;

  /**
   * The buffer containing the string currently being captured.
   */
  StringBuffer capturedString;

  /**
   * The beginning of the current section of the captured string.
   */
  int captureStart;

  /**
   * Whether the current string capture is being overridden.
   */
  bool capturingAs = false;

  _Parser(String s)
    : this.s = s,
      len = s.length,
      contextStack = <String>["document"];

  /**
   * Return the character at the current position, then move that position
   * forward one character. Also updates the current line and column numbers.
   */
  int next() {
    if (pos == len) return -1;
    var char = s.charCodeAt(pos++);
    if (isBreak(char)) {
      line++;
      column = 0;
    } else {
      column++;
    }

    if (farthestLine < line) {
      farthestLine = line;
      farthestColumn = column;
      farthestContext = contextStack.last();
    } else if (farthestLine == line && farthestColumn < column) {
      farthestColumn = column;
      farthestContext = contextStack.last();
    }

    return char;
  }

  /**
   * Returns the character at the current position, or the character [i]
   * characters after the current position.
   *
   * Returns -1 if this would return a character after the end or before the
   * beginning of the input string.
   */
  int peek([int i = 0]) {
    var peekPos = pos + i;
    return (peekPos >= len || peekPos < 0) ? -1 : s.charCodeAt(peekPos);
  }

  /**
   * The truthiness operator. Returns `false` if [obj] is `null` or `false`,
   * `true` otherwise.
   */
  bool truth(obj) => obj != null && obj != false;

  /**
   * Consumes the current character if it matches [matcher]. Returns the result
   * of [matcher].
   */
  bool consume(bool matcher(int)) {
    if (matcher(peek())) {
      next();
      return true;
    }
    return false;
  }

  /**
   * Consumes the current character if it equals [char].
   */
  bool consumeChar(int char) => consume((c) => c == char);

  /**
   * Calls [consumer] until it returns a falsey value. Returns a list of all
   * truthy return values of [consumer], or null if it didn't consume anything.
   *
   * Conceptually, repeats a production one or more times.
   */
  List oneOrMore(consumer()) {
    var first = consumer();
    if (!truth(first)) return null;
    var out = [first];
    while (true) {
      var el = consumer();
      if (!truth(el)) return out;
      out.add(el);
    }
    return null; // Unreachable.
  }

  /**
   * Calls [consumer] until it returns a falsey value. Returns a list of all
   * truthy return values of [consumer], or the empty list if it didn't consume
   * anything.
   *
   * Conceptually, repeats a production any number of times.
   */
  List zeroOrMore(consumer()) {
    var out = [];
    var oldPos = pos;
    while (true) {
      var el = consumer();
      if (!truth(el) || oldPos == pos) return out;
      oldPos = pos;
      out.add(el);
    }
    return null; // Unreachable.
  }

  /**
   * Just calls [consumer] and returns its result. Used to make it explicit that
   * a production is intended to be optional.
   */
  zeroOrOne(consumer()) => consumer();

  /**
   * Calls each function in [consumers] until one returns a truthy value, then
   * returns that.
   */
  or(List<Function> consumers) {
    for (var c in consumers) {
      var res = c();
      if (truth(res)) return res;
    }
    return null;
  }

  /**
   * Calls [consumer] and returns its result, but rolls back the parser state if
   * [consumer] returns a falsey value.
   */
  transaction(consumer()) {
    var oldPos = pos;
    var oldLine = line;
    var oldColumn = column;
    var oldCaptureStart = captureStart;
    String capturedSoFar = capturedString == null ? null :
      capturedString.toString();
    var res = consumer();
    if (truth(res)) return res;

    pos = oldPos;
    line = oldLine;
    column = oldColumn;
    captureStart = oldCaptureStart;
    capturedString = capturedSoFar == null ? null :
      new StringBuffer(capturedSoFar);
    return res;
  }

  /**
   * Consumes [n] characters matching [matcher], or none if there isn't a
   * complete match. The first argument to [matcher] is the character code, the
   * second is the index (from 0 to [n] - 1).
   *
   * Returns whether or not the characters were consumed.
   */
  bool nAtOnce(int n, bool matcher(int c, int i)) => transaction(() {
    for (int i = 0; i < n; i++) {
      if (!consume((c) => matcher(c, i))) return false;
    }
    return true;
  });

  /**
   * Consumes the exact characters in [str], or nothing.
   *
   * Returns whether or not the string was consumed.
   */
  bool rawString(String str) =>
    nAtOnce(str.length, (c, i) => str.charCodeAt(i) == c);

  /**
   * Consumes and returns a string of characters matching [matcher], or null if
   * there are no such characters.
   */
  String stringOf(bool matcher(int)) =>
    captureString(() => oneOrMore(() => consume(matcher)));

  /**
   * Calls [consumer] and returns the string that was consumed while doing so,
   * or null if [consumer] returned a falsey value. Automatically wraps
   * [consumer] in `transaction`.
   */
  String captureString(consumer()) {
    // captureString calls may not be nested
    assert(capturedString == null);

    captureStart = pos;
    capturedString = new StringBuffer();
    var res = transaction(consumer);
    if (!truth(res)) {
      captureStart = null;
      capturedString = null;
      return null;
    }

    flushCapture();
    var result = capturedString.toString();
    captureStart = null;
    capturedString = null;
    return result;
  }

  captureAs(String replacement, consumer()) =>
      captureAndTransform(consumer, (_) => replacement);

  captureAndTransform(consumer(), String transformation(String captured)) {
    if (capturedString == null) return consumer();
    if (capturingAs) return consumer();

    flushCapture();
    capturingAs = true;
    var res = consumer();
    capturingAs = false;
    if (!truth(res)) return res;

    capturedString.add(transformation(s.substring(captureStart, pos)));
    captureStart = pos;
    return res;
  }

  void flushCapture() {
    capturedString.add(s.substring(captureStart, pos));
    captureStart = pos;
  }

  /**
   * Adds a tag and an anchor to [node], if they're defined.
   */
  _Node addProps(_Node node, _Pair<_Tag, String> props) {
    if (props == null || node == null) return node;
    if (truth(props.first)) node.tag = props.first;
    if (truth(props.last)) node.anchor = props.last;
    return node;
  }

  /** Creates a MappingNode from [pairs]. */
  _MappingNode map(List<_Pair<_Node, _Node>> pairs) {
    var content = new Map<_Node, _Node>();
    pairs.forEach((pair) => content[pair.first] = pair.last);
    return new _MappingNode("?", content);
  }

  /** Runs [fn] in a context named [name]. Used for error reporting. */
  context(String name, fn()) {
    try {
      contextStack.add(name);
      return fn();
    } finally {
      var popped = contextStack.removeLast();
      assert(popped == name);
    }
  }

  /** Throws an error with additional context information. */
  error(String message) {
    // Line and column should be one-based.
    throw new SyntaxError(line + 1, column + 1,
        "$message (in $farthestContext)");
  }

  /**
   * If [result] is falsey, throws an error saying that [expected] was
   * expected.
   */
  expect(result, String expected) {
    if (truth(result)) return result;
    error("expected $expected");
  }

  /**
   * Throws an error saying that the parse failed. Uses [farthestLine],
   * [farthestColumn], and [farthestContext] to provide additional information.
   */
  parseFailed() {
    throw new SyntaxError(farthestLine + 1, farthestColumn + 1,
        "invalid YAML in $farthestContext");
  }

  /** Returns the number of spaces after the current position. */ 
  int countIndentation() {
    var i = 0;
    while (peek(i) == SP) i++;
    return i;
  }

  /** Returns the indentation for a block scalar. */
  int blockScalarAdditionalIndentation(_BlockHeader header, int indent) {
    if (!header.autoDetectIndent) return header.additionalIndent;

    var maxSpaces = 0;
    var maxSpacesLine = 0;
    var spaces = 0;
    transaction(() {
      do {
        spaces = captureString(() => zeroOrMore(() => consumeChar(SP))).length;
        if (spaces > maxSpaces) {
          maxSpaces = spaces;
          maxSpacesLine = line;
        }
      } while (b_break());
      return false;
    });

    // If the next non-empty line isn't indented further than the start of the
    // block scalar, that means the scalar is going to be empty. Returning any
    // value > 0 will cause the parser not to consume any text.
    if (spaces <= indent) return 1;

    // It's an error for a leading empty line to be indented more than the first
    // non-empty line.
    if (maxSpaces > spaces) {
      throw new SyntaxError(maxSpacesLine + 1, maxSpaces,
          "Leading empty lines may not be indented more than the first "
          "non-empty line.");
    }

    return spaces - indent;
  }

  /** Returns whether the current position is at the beginning of a line. */
  bool get atStartOfLine() => column == 0;

  /** Returns whether the current position is at the end of the input. */
  bool get atEndOfFile() => pos == len;

  /**
   * Given an indicator character, returns the type of that indicator (or null
   * if the indicator isn't found.
   */
  int indicatorType(int char) {
    switch (char) {
    case HYPHEN: return C_SEQUENCE_ENTRY;
    case QUESTION_MARK: return C_MAPPING_KEY;
    case COLON: return C_MAPPING_VALUE;
    case COMMA: return C_COLLECT_ENTRY;
    case LEFT_BRACKET: return C_SEQUENCE_START;
    case RIGHT_BRACKET: return C_SEQUENCE_END;
    case LEFT_BRACE: return C_MAPPING_START;
    case RIGHT_BRACE: return C_MAPPING_END;
    case HASH: return C_COMMENT;
    case AMPERSAND: return C_ANCHOR;
    case ASTERISK: return C_ALIAS;
    case EXCLAMATION: return C_TAG;
    case VERTICAL_BAR: return C_LITERAL;
    case GREATER_THAN: return C_FOLDED;
    case SINGLE_QUOTE: return C_SINGLE_QUOTE;
    case DOUBLE_QUOTE: return C_DOUBLE_QUOTE;
    case PERCENT: return C_DIRECTIVE;
    case AT:
    case GRAVE_ACCENT:
      return C_RESERVED;
    default: return null;
    }
  }

  // 1
  bool isPrintable(int char) {
    return char == TAB ||
      char == LF ||
      char == CR ||
      (char >= SP && char <= TILDE) ||
      char == NEL ||
      (char >= 0xA0 && char <= 0xD7FF) ||
      (char >= 0xE000 && char <= 0xFFFD) ||
      (char >= 0x10000 && char <= 0x10FFFF);
  }

  // 2
  bool isJson(int char) => char == TAB || (char >= SP && char <= 0x10FFFF);

  // 22
  bool c_indicator(int type) => consume((c) => indicatorType(c) == type);

  // 23
  bool isFlowIndicator(int char) {
    var indicator = indicatorType(char);
    return indicator == C_COLLECT_ENTRY ||
      indicator == C_SEQUENCE_START ||
      indicator == C_SEQUENCE_END ||
      indicator == C_MAPPING_START ||
      indicator == C_MAPPING_END;
  }

  // 26
  bool isBreak(int char) => char == LF || char == CR;

  // 27
  bool isNonBreak(int char) => isPrintable(char) && !isBreak(char);

  // 28
  bool b_break() {
    if (consumeChar(CR)) {
      zeroOrOne(() => consumeChar(LF));
      return true;
    }
    return consumeChar(LF);
  }

  // 29
  bool b_asLineFeed() => captureAs("\n", () => b_break());

  // 30
  bool b_nonContent() => captureAs("", () => b_break());

  // 33
  bool isSpace(int char) => char == SP || char == TAB;

  // 34
  bool isNonSpace(int char) => isNonBreak(char) && !isSpace(char);

  // 35
  bool isDecDigit(int char) => char >= NUMBER_0 && char <= NUMBER_9;

  // 36
  bool isHexDigit(int char) {
    return isDecDigit(char) ||
      (char >= LETTER_A && char <= LETTER_F) ||
      (char >= LETTER_CAP_A && char <= LETTER_CAP_F);
  }

  // 41
  bool c_escape() => captureAs("", () => consumeChar(BACKSLASH));

  // 42
  bool ns_escNull() => captureAs("\x00", () => consumeChar(NUMBER_0));

  // 43
  bool ns_escBell() => captureAs("\x07", () => consumeChar(LETTER_A));

  // 44
  bool ns_escBackspace() => captureAs("\b", () => consumeChar(LETTER_B));

  // 45
  bool ns_escHorizontalTab() => captureAs("\t", () {
    return consume((c) => c == LETTER_T || c == TAB);
  });

  // 46
  bool ns_escLineFeed() => captureAs("\n", () => consumeChar(LETTER_N));

  // 47
  bool ns_escVerticalTab() => captureAs("\v", () => consumeChar(LETTER_V));

  // 48
  bool ns_escFormFeed() => captureAs("\f", () => consumeChar(LETTER_F));

  // 49
  bool ns_escCarriageReturn() => captureAs("\r", () => consumeChar(LETTER_R));

  // 50
  bool ns_escEscape() => captureAs("\x1B", () => consumeChar(LETTER_E));

  // 51
  bool ns_escSpace() => consumeChar(SP);

  // 52
  bool ns_escDoubleQuote() => consumeChar(DOUBLE_QUOTE);

  // 53
  bool ns_escSlash() => consumeChar(SLASH);

  // 54
  bool ns_escBackslash() => consumeChar(BACKSLASH);

  // 55
  bool ns_escNextLine() => captureAs("\x85", () => consumeChar(LETTER_CAP_N));

  // 56
  bool ns_escNonBreakingSpace() =>
    captureAs("\xA0", () => consumeChar(UNDERSCORE));

  // 57
  bool ns_escLineSeparator() =>
    captureAs("\u2028", () => consumeChar(LETTER_CAP_L));

  // 58
  bool ns_escParagraphSeparator() =>
    captureAs("\u2029", () => consumeChar(LETTER_CAP_P));

  // 59
  bool ns_esc8Bit() => ns_escNBit(LETTER_X, 2);

  // 60
  bool ns_esc16Bit() => ns_escNBit(LETTER_U, 4);

  // 61
  bool ns_esc32Bit() => ns_escNBit(LETTER_CAP_U, 8);

  // Helper method for 59 - 61
  bool ns_escNBit(int char, int digits) {
    if (!captureAs('', () => consumeChar(char))) return false;
    var captured = captureAndTransform(
        () => nAtOnce(digits, (c, _) => isHexDigit(c)),
        (hex) => new String.fromCharCodes([Math.parseInt("0x$hex")]));
    return expect(captured, "$digits hexidecimal digits");
  }

  // 62
  bool c_ns_escChar() => context('escape sequence', () => transaction(() {
      if (!truth(c_escape())) return false;
      return truth(or([
        ns_escNull, ns_escBell, ns_escBackspace, ns_escHorizontalTab,
        ns_escLineFeed, ns_escVerticalTab, ns_escFormFeed, ns_escCarriageReturn,
        ns_escEscape, ns_escSpace, ns_escDoubleQuote, ns_escSlash,
        ns_escBackslash, ns_escNextLine, ns_escNonBreakingSpace,
        ns_escLineSeparator, ns_escParagraphSeparator, ns_esc8Bit, ns_esc16Bit,
        ns_esc32Bit
      ]));
    }));

  // 63
  bool s_indent(int indent) => nAtOnce(indent, (c, i) => c == SP);

  // 64
  bool s_indentLessThan(int indent) {
    for (int i = 0; i < indent - 1; i++) {
      if (!consumeChar(SP)) break;
    }
    return true;
  }

  // 65
  bool s_indentLessThanOrEqualTo(int indent) => s_indentLessThan(indent + 1);

  // 66
  bool s_separateInLine() => transaction(() {
    return captureAs('', () =>
        truth(oneOrMore(() => consume(isSpace))) || atStartOfLine);
  });

  // 67
  bool s_linePrefix(int indent, int ctx) => captureAs("", () {
    switch (ctx) {
    case BLOCK_OUT:
    case BLOCK_IN:
      return s_blockLinePrefix(indent);
    case FLOW_OUT:
    case FLOW_IN:
      return s_flowLinePrefix(indent);
    }
  });

  // 68
  bool s_blockLinePrefix(int indent) => s_indent(indent);

  // 69
  bool s_flowLinePrefix(int indent) => captureAs('', () {
    if (!truth(s_indent(indent))) return false;
    zeroOrOne(s_separateInLine);
    return true;
  });

  // 70
  bool l_empty(int indent, int ctx) => transaction(() {
    var start = or([
      () => s_linePrefix(indent, ctx),
      () => s_indentLessThan(indent)
    ]);
    if (!truth(start)) return false;
    return b_asLineFeed();
  });

  // 71
  bool b_asSpace() => captureAs(" ", () => consume(isBreak));

  // 72
  bool b_l_trimmed(int indent, int ctx) => transaction(() {
    if (!truth(b_nonContent())) return false;
    return truth(oneOrMore(() => captureAs("\n", () => l_empty(indent, ctx))));
  });

  // 73
  bool b_l_folded(int indent, int ctx) =>
    or([() => b_l_trimmed(indent, ctx), b_asSpace]);

  // 74
  bool s_flowFolded(int indent) => transaction(() {
    zeroOrOne(s_separateInLine);
    if (!truth(b_l_folded(indent, FLOW_IN))) return false;
    return s_flowLinePrefix(indent);
  });

  // 75
  bool c_nb_commentText() {
    if (!truth(c_indicator(C_COMMENT))) return false;
    zeroOrMore(() => consume(isNonBreak));
    return true;
  }

  // 76
  bool b_comment() => atEndOfFile || b_nonContent();

  // 77
  bool s_b_comment() {
    if (truth(s_separateInLine())) {
      zeroOrOne(c_nb_commentText);
    }
    return b_comment();
  }

  // 78
  bool l_comment() => transaction(() {
    if (!truth(s_separateInLine())) return false;
    zeroOrOne(c_nb_commentText);
    return b_comment();
  });

  // 79
  bool s_l_comments() {
    if (!truth(s_b_comment()) && !atStartOfLine) return false;
    zeroOrMore(l_comment);
    return true;
  }

  // 80
  bool s_separate(int indent, int ctx) {
    switch (ctx) {
    case BLOCK_OUT:
    case BLOCK_IN:
    case FLOW_OUT:
    case FLOW_IN:
      return s_separateLines(indent);
    case BLOCK_KEY:
    case FLOW_KEY:
      return s_separateInLine();
    default: throw 'invalid context "$ctx"';
    }
  }

  // 81
  bool s_separateLines(int indent) {
    return transaction(() => s_l_comments() && s_flowLinePrefix(indent)) ||
      s_separateInLine();
  }

  // 82
  bool l_directive() => false; // TODO(nweiz): implement

  // 96
  _Pair<_Tag, String> c_ns_properties(int indent, int ctx) {
    var tag, anchor;
    tag = c_ns_tagProperty();
    if (truth(tag)) {
      anchor = transaction(() {
        if (!truth(s_separate(indent, ctx))) return null;
        return c_ns_anchorProperty();
      });
      return new _Pair<_Tag, String>(tag, anchor);
    }

    anchor = c_ns_anchorProperty();
    if (truth(anchor)) {
      tag = transaction(() {
        if (!truth(s_separate(indent, ctx))) return null;
        return c_ns_tagProperty();
      });
      return new _Pair<_Tag, String>(tag, anchor);
    }

    return null;
  }

  // 97
  _Tag c_ns_tagProperty() => null; // TODO(nweiz): implement

  // 101
  String c_ns_anchorProperty() => null; // TODO(nweiz): implement

  // 102
  bool isAnchorChar(int char) => isNonSpace(char) && !isFlowIndicator(char);

  // 103
  String ns_anchorName() =>
    captureString(() => oneOrMore(() => consume(isAnchorChar)));

  // 104
  _Node c_ns_aliasNode() {
    if (!truth(c_indicator(C_ALIAS))) return null;
    var name = expect(ns_anchorName(), 'anchor name');
    return new _AliasNode(name);
  }

  // 105
  _ScalarNode e_scalar() => new _ScalarNode("?", content: "");

  // 106
  _ScalarNode e_node() => e_scalar();

  // 107
  bool nb_doubleChar() => or([
    c_ns_escChar,
    () => consume((c) => isJson(c) && c != BACKSLASH && c != DOUBLE_QUOTE)
  ]);

  // 108
  bool ns_doubleChar() => !isSpace(peek()) && truth(nb_doubleChar());

  // 109
  _Node c_doubleQuoted(int indent, int ctx) => context('string', () {
    return transaction(() {
      if (!truth(c_indicator(C_DOUBLE_QUOTE))) return null;
      var contents = nb_doubleText(indent, ctx);
      if (!truth(c_indicator(C_DOUBLE_QUOTE))) return null;
      return new _ScalarNode("!", contents);
    });
  });

  // 110
  String nb_doubleText(int indent, int ctx) => captureString(() {
    switch (ctx) {
    case FLOW_OUT:
    case FLOW_IN:
      nb_doubleMultiLine(indent);
      break;
    case BLOCK_KEY:
    case FLOW_KEY:
      nb_doubleOneLine();
      break;
    }
    return true;
  });

  // 111
  void nb_doubleOneLine() {
    zeroOrMore(nb_doubleChar);
  }

  // 112
  bool s_doubleEscaped(int indent) => transaction(() {
    zeroOrMore(() => consume(isSpace));
    if (!captureAs("", () => consumeChar(BACKSLASH))) return false;
    if (!truth(b_nonContent())) return false;
    zeroOrMore(() => captureAs("\n", () => l_empty(indent, FLOW_IN)));
    return s_flowLinePrefix(indent);
  });

  // 113
  bool s_doubleBreak(int indent) => or([
    () => s_doubleEscaped(indent),
    () => s_flowFolded(indent)
  ]);

  // 114
  void nb_ns_doubleInLine() {
    zeroOrMore(() => transaction(() {
        zeroOrMore(() => consume(isSpace));
        return ns_doubleChar();
      }));
  }

  // 115
  bool s_doubleNextLine(int indent) {
    if (!truth(s_doubleBreak(indent))) return false;
    zeroOrOne(() {
      if (!truth(ns_doubleChar())) return;
      nb_ns_doubleInLine();
      or([
        () => s_doubleNextLine(indent),
        () => zeroOrMore(() => consume(isSpace))
      ]);
    });
    return true;
  }

  // 116
  void nb_doubleMultiLine(int indent) {
    nb_ns_doubleInLine();
    or([
      () => s_doubleNextLine(indent),
      () => zeroOrMore(() => consume(isSpace))
    ]);
  }

  // 117
  bool c_quotedQuote() => captureAs("'", () => rawString("''"));

  // 118
  bool nb_singleChar() => or([
    c_quotedQuote,
    () => consume((c) => isJson(c) && c != SINGLE_QUOTE)
  ]);

  // 119
  bool ns_singleChar() => !isSpace(peek()) && truth(nb_singleChar());

  // 120
  _Node c_singleQuoted(int indent, int ctx) => context('string', () {
    return transaction(() {
      if (!truth(c_indicator(C_SINGLE_QUOTE))) return null;
      var contents = nb_singleText(indent, ctx);
      if (!truth(c_indicator(C_SINGLE_QUOTE))) return null;
      return new _ScalarNode("!", contents);
    });
  });

  // 121
  String nb_singleText(int indent, int ctx) => captureString(() {
    switch (ctx) {
    case FLOW_OUT:
    case FLOW_IN:
      nb_singleMultiLine(indent);
      break;
    case BLOCK_KEY:
    case FLOW_KEY:
      nb_singleOneLine(indent);
      break;
    }
    return true;
  });

  // 122
  void nb_singleOneLine(int indent) {
    zeroOrMore(nb_singleChar);
  }

  // 123
  void nb_ns_singleInLine() {
    zeroOrMore(() => transaction(() {
      zeroOrMore(() => consume(isSpace));
      return ns_singleChar();
    }));
  }

  // 124
  bool s_singleNextLine(int indent) {
    if (!truth(s_flowFolded(indent))) return false;
    zeroOrOne(() {
      if (!truth(ns_singleChar())) return;
      nb_ns_singleInLine();
      or([
        () => s_singleNextLine(indent),
        () => zeroOrMore(() => consume(isSpace))
      ]);
    });
    return true;
  }

  // 125
  void nb_singleMultiLine(int indent) {
    nb_ns_singleInLine();
    or([
      () => s_singleNextLine(indent),
      () => zeroOrMore(() => consume(isSpace))
    ]);
  }

  // 126
  bool ns_plainFirst(int ctx) {
    var char = peek();
    var indicator = indicatorType(char);
    if (indicator == C_RESERVED) {
      error("reserved indicators can't start a plain scalar");
    }
    var match = (isNonSpace(char) && indicator == null) ||
      ((indicator == C_MAPPING_KEY ||
        indicator == C_MAPPING_VALUE ||
        indicator == C_SEQUENCE_ENTRY) &&
       isPlainSafe(ctx, peek(1)));

    if (match) next();
    return match;
  }

  // 127
  bool isPlainSafe(int ctx, int char) {
    switch (ctx) {
    case FLOW_OUT:
    case BLOCK_KEY:
      // 128
      return isNonSpace(char);
    case FLOW_IN:
    case FLOW_KEY:
      // 129
      return isNonSpace(char) && !isFlowIndicator(char);
    default: throw 'invalid context "$ctx"';
    }
  }

  // 130
  bool ns_plainChar(int ctx) {
    var char = peek();
    var indicator = indicatorType(char);
    var safeChar = isPlainSafe(ctx, char) && indicator != C_MAPPING_VALUE &&
      indicator != C_COMMENT;
    var nonCommentHash = isNonSpace(peek(-1)) && indicator == C_COMMENT;
    var nonMappingColon = indicator == C_MAPPING_VALUE &&
      isPlainSafe(ctx, peek(1));
    var match = safeChar || nonCommentHash || nonMappingColon;

    if (match) next();
    return match;
  }

  // 131
  String ns_plain(int indent, int ctx) => context('plain scalar', () {
    return captureString(() {
      switch (ctx) {
      case FLOW_OUT:
      case FLOW_IN:
        return ns_plainMultiLine(indent, ctx);
      case BLOCK_KEY:
      case FLOW_KEY:
        return ns_plainOneLine(ctx);
      default: throw 'invalid context "$ctx"';
      }
    });
  });

  // 132
  void nb_ns_plainInLine(int ctx) {
    zeroOrMore(() => transaction(() {
      zeroOrMore(() => consume(isSpace));
      return ns_plainChar(ctx);
    }));
  }

  // 133
  bool ns_plainOneLine(int ctx) {
    if (truth(c_forbidden())) return false;
    if (!truth(ns_plainFirst(ctx))) return false;
    nb_ns_plainInLine(ctx);
    return true;
  }

  // 134
  bool s_ns_plainNextLine(int indent, int ctx) => transaction(() {
    if (!truth(s_flowFolded(indent))) return false;
    if (truth(c_forbidden())) return false;
    if (!truth(ns_plainChar(ctx))) return false;
    nb_ns_plainInLine(ctx);
    return true;
  });

  // 135
  bool ns_plainMultiLine(int indent, int ctx) {
    if (!truth(ns_plainOneLine(ctx))) return false;
    zeroOrMore(() => s_ns_plainNextLine(indent, ctx));
    return true;
  }

  // 136
  int inFlow(int ctx) {
    switch (ctx) {
    case FLOW_OUT:
    case FLOW_IN:
      return FLOW_IN;
    case BLOCK_KEY:
    case FLOW_KEY:
      return FLOW_KEY;
    }
  }

  // 137
  _SequenceNode c_flowSequence(int indent, int ctx) => transaction(() {
    if (!truth(c_indicator(C_SEQUENCE_START))) return null;
    zeroOrOne(() => s_separate(indent, ctx));
    var content = zeroOrOne(() => ns_s_flowSeqEntries(indent, inFlow(ctx)));
    if (!truth(c_indicator(C_SEQUENCE_END))) return null;
    return new _SequenceNode("?", new List<_Node>.from(content));
  });

  // 138
  Collection<_Node> ns_s_flowSeqEntries(int indent, int ctx) {
    var first = ns_flowSeqEntry(indent, ctx);
    if (!truth(first)) return new Queue<_Node>();
    zeroOrOne(() => s_separate(indent, ctx));

    var rest;
    if (truth(c_indicator(C_COLLECT_ENTRY))) {
      zeroOrOne(() => s_separate(indent, ctx));
      rest = zeroOrOne(() => ns_s_flowSeqEntries(indent, ctx));
    }

    if (rest == null) rest = new Queue<_Node>();
    rest.addFirst(first);

    return rest;
  }

  // 139
  _Node ns_flowSeqEntry(int indent, int ctx) => or([
    () => ns_flowPair(indent, ctx),
    () => ns_flowNode(indent, ctx)
  ]);

  // 140
  _Node c_flowMapping(int indent, int ctx) {
    if (!truth(c_indicator(C_MAPPING_START))) return null;
    zeroOrOne(() => s_separate(indent, ctx));
    var content = zeroOrOne(() => ns_s_flowMapEntries(indent, inFlow(ctx)));
    if (!truth(c_indicator(C_MAPPING_END))) return null;
    return new _MappingNode("?", content);
  }

  // 141
  YamlMap ns_s_flowMapEntries(int indent, int ctx) {
    var first = ns_flowMapEntry(indent, ctx);
    if (!truth(first)) return new YamlMap();
    zeroOrOne(() => s_separate(indent, ctx));

    var rest;
    if (truth(c_indicator(C_COLLECT_ENTRY))) {
      zeroOrOne(() => s_separate(indent, ctx));
      rest = ns_s_flowMapEntries(indent, ctx);
    }

    if (rest == null) rest = new YamlMap();

    // TODO(nweiz): Duplicate keys should be an error. This includes keys with
    // different representations but the same value (e.g. 10 vs 0xa). To make
    // this user-friendly we'll probably also want to associate nodes with a
    // source range.
    if (!rest.containsKey(first.first)) rest[first.first] = first.last;

    return rest;
  }

  // 142
  _Pair<_Node, _Node> ns_flowMapEntry(int indent, int ctx) => or([
    () => transaction(() {
      if (!truth(c_indicator(C_MAPPING_KEY))) return false;
      if (!truth(s_separate(indent, ctx))) return false;
      return ns_flowMapExplicitEntry(indent, ctx);
    }),
    () => ns_flowMapImplicitEntry(indent, ctx)
  ]);

  // 143
  _Pair<_Node, _Node> ns_flowMapExplicitEntry(int indent, int ctx) => or([
    () => ns_flowMapImplicitEntry(indent, ctx),
    () => new _Pair<_Node, _Node>(e_node(), e_node())
  ]);

  // 144
  _Pair<_Node, _Node> ns_flowMapImplicitEntry(int indent, int ctx) => or([
    () => ns_flowMapYamlKeyEntry(indent, ctx),
    () => c_ns_flowMapEmptyKeyEntry(indent, ctx),
    () => c_ns_flowMapJsonKeyEntry(indent, ctx)
  ]);

  // 145
  _Pair<_Node, _Node> ns_flowMapYamlKeyEntry(int indent, int ctx) {
    var key = ns_flowYamlNode(indent, ctx);
    if (!truth(key)) return null;
    var value = or([
      () => transaction(() {
        zeroOrOne(() => s_separate(indent, ctx));
        return c_ns_flowMapSeparateValue(indent, ctx);
      }),
      e_node
    ]);
    return new _Pair<_Node, _Node>(key, value);
  }

  // 146
  _Pair<_Node, _Node> c_ns_flowMapEmptyKeyEntry(int indent, int ctx) {
    var value = c_ns_flowMapSeparateValue(indent, ctx);
    if (!truth(value)) return null;
    return new _Pair<_Node, _Node>(e_node(), value);
  }

  // 147
  _Node c_ns_flowMapSeparateValue(int indent, int ctx) => transaction(() {
    if (!truth(c_indicator(C_MAPPING_VALUE))) return null;
    if (isPlainSafe(ctx, peek())) return null;

    return or([
      () => transaction(() {
        if (!s_separate(indent, ctx)) return null;
        return ns_flowNode(indent, ctx);
      }),
      e_node
    ]);
  });

  // 148
  _Pair<_Node, _Node> c_ns_flowMapJsonKeyEntry(int indent, int ctx) {
    var key = c_flowJsonNode(indent, ctx);
    if (!truth(key)) return null;
    var value = or([
      () => transaction(() {
        zeroOrOne(() => s_separate(indent, ctx));
        return c_ns_flowMapAdjacentValue(indent, ctx);
      }),
      e_node
    ]);
    return new _Pair<_Node, _Node>(key, value);
  }

  // 149
  _Node c_ns_flowMapAdjacentValue(int indent, int ctx) {
    if (!truth(c_indicator(C_MAPPING_VALUE))) return null;
    return or([
      () => transaction(() {
        zeroOrOne(() => s_separate(indent, ctx));
        return ns_flowNode(indent, ctx);
      }),
      e_node
    ]);
  }

  // 150
  _Node ns_flowPair(int indent, int ctx) {
    var pair = or([
      () => transaction(() {
        if (!truth(c_indicator(C_MAPPING_KEY))) return null;
        if (!truth(s_separate(indent, ctx))) return null;
        return ns_flowMapExplicitEntry(indent, ctx);
      }),
      () => ns_flowPairEntry(indent, ctx)
    ]);
    if (!truth(pair)) return null;

    return map([pair]);
  }

  // 151
  _Pair<_Node, _Node> ns_flowPairEntry(int indent, int ctx) => or([
    () => ns_flowPairYamlKeyEntry(indent, ctx),
    () => c_ns_flowMapEmptyKeyEntry(indent, ctx),
    () => c_ns_flowPairJsonKeyEntry(indent, ctx)
  ]);

  // 152
  _Pair<_Node, _Node> ns_flowPairYamlKeyEntry(int indent, int ctx) =>
    transaction(() {
      var key = ns_s_implicitYamlKey(FLOW_KEY);
      if (!truth(key)) return null;
      var value = c_ns_flowMapSeparateValue(indent, ctx);
      if (!truth(value)) return null;
      return new _Pair<_Node, _Node>(key, value);
    });

  // 153
  _Pair<_Node, _Node> c_ns_flowPairJsonKeyEntry(int indent, int ctx) =>
    transaction(() {
      var key = c_s_implicitJsonKey(FLOW_KEY);
      if (!truth(key)) return null;
      var value = c_ns_flowMapAdjacentValue(indent, ctx);
      if (!truth(value)) return null;
      return new _Pair<_Node, _Node>(key, value);
    });

  // 154
  _Node ns_s_implicitYamlKey(int ctx) => transaction(() {
    // TODO(nweiz): this is supposed to be limited to 1024 characters.

    // The indentation parameter is "null" since it's unused in this path
    var node = ns_flowYamlNode(null, ctx);
    if (!truth(node)) return null;
    zeroOrOne(s_separateInLine);
    return node;
  });

  // 155
  _Node c_s_implicitJsonKey(int ctx) => transaction(() {
    // TODO(nweiz): this is supposed to be limited to 1024 characters.

    // The indentation parameter is "null" since it's unused in this path
    var node = c_flowJsonNode(null, ctx);
    if (!truth(node)) return null;
    zeroOrOne(s_separateInLine);
    return node;
  });

  // 156
  _Node ns_flowYamlContent(int indent, int ctx) {
    var str = ns_plain(indent, ctx);
    if (!truth(str)) return null;
    return new _ScalarNode("?", content: str);
  }

  // 157
  _Node c_flowJsonContent(int indent, int ctx) => or([
    () => c_flowSequence(indent, ctx),
    () => c_flowMapping(indent, ctx),
    () => c_singleQuoted(indent, ctx),
    () => c_doubleQuoted(indent, ctx)
  ]);

  // 158
  _Node ns_flowContent(int indent, int ctx) => or([
    () => ns_flowYamlContent(indent, ctx),
    () => c_flowJsonContent(indent, ctx)
  ]);

  // 159
  _Node ns_flowYamlNode(int indent, int ctx) => or([
    c_ns_aliasNode,
    () => ns_flowYamlContent(indent, ctx),
    () {
      var props = c_ns_properties(indent, ctx);
      if (!truth(props)) return null;
      var node = or([
        () => transaction(() {
          if (!truth(s_separate(indent, ctx))) return null;
          return ns_flowYamlContent(indent, ctx);
        }),
        e_scalar
      ]);
      return addProps(node, props);
    }
  ]);

  // 160
  _Node c_flowJsonNode(int indent, int ctx) => transaction(() {
    var props;
    zeroOrOne(() => transaction(() {
        props = c_ns_properties(indent, ctx);
        if (!truth(props)) return null;
        return s_separate(indent, ctx);
      }));

    return addProps(c_flowJsonContent(indent, ctx), props);
  });

  // 161
  _Node ns_flowNode(int indent, int ctx) => or([
    c_ns_aliasNode,
    () => ns_flowContent(indent, ctx),
    () => transaction(() {
      var props = c_ns_properties(indent, ctx);
      if (!truth(props)) return null;
      var node = or([
        () => transaction(() => s_separate(indent, ctx) ?
            ns_flowContent(indent, ctx) : null),
        e_scalar]);
      return addProps(node, props);
    })
  ]);

  // 162
  _BlockHeader c_b_blockHeader() => transaction(() {
    var indentation = c_indentationIndicator();
    var chomping = c_chompingIndicator();
    if (!truth(indentation)) indentation = c_indentationIndicator();
    if (!truth(s_b_comment())) return null;

    return new _BlockHeader(indentation, chomping);
  });

  // 163
  int c_indentationIndicator() {
    if (!isDecDigit(peek())) return null;
    return next() - NUMBER_0;
  }

  // 164
  int c_chompingIndicator() {
    switch (peek()) {
    case HYPHEN:
      next();
      return CHOMPING_STRIP;
    case PLUS:
      next();
      return CHOMPING_KEEP;
    default:
      return CHOMPING_CLIP;
    }
  }

  // 165
  bool b_chompedLast(int chomping) {
    if (atEndOfFile) return true;
    switch (chomping) {
    case CHOMPING_STRIP:
      return b_nonContent();
    case CHOMPING_CLIP:
    case CHOMPING_KEEP:
      return b_asLineFeed();
    }
  }

  // 166
  void l_chompedEmpty(int indent, int chomping) {
    switch (chomping) {
    case CHOMPING_STRIP:
    case CHOMPING_CLIP:
      l_stripEmpty(indent);
      break;
    case CHOMPING_KEEP:
      l_keepEmpty(indent);
      break;
    }
  }

  // 167
  void l_stripEmpty(int indent) {
    captureAs('', () {
      zeroOrMore(() => transaction(() {
          if (!truth(s_indentLessThanOrEqualTo(indent))) return false;
          return b_nonContent();
        }));
      zeroOrOne(() => l_trailComments(indent));
      return true;
    });
  }

  // 168
  void l_keepEmpty(int indent) {
    zeroOrMore(() => captureAs('\n', () => l_empty(indent, BLOCK_IN)));
    zeroOrOne(() => captureAs('', () => l_trailComments(indent)));
  }

  // 169
  bool l_trailComments(int indent) => transaction(() {
    if (!truth(s_indentLessThanOrEqualTo(indent))) return false;
    if (!truth(c_nb_commentText())) return false;
    if (!truth(b_comment())) return false;
    zeroOrMore(l_comment);
    return true;
  });

  // 170
  _Node c_l_literal(int indent) => transaction(() {
    if (!truth(c_indicator(C_LITERAL))) return null;
    var header = c_b_blockHeader();
    if (!truth(header)) return null;

    var additionalIndent = blockScalarAdditionalIndentation(header, indent);
    var content = l_literalContent(indent + additionalIndent, header.chomping);
    if (!truth(content)) return null;

    return new _ScalarNode("!", content);
  });

  // 171
  bool l_nb_literalText(int indent) => transaction(() {
    zeroOrMore(() => captureAs("\n", () => l_empty(indent, BLOCK_IN)));
    if (!truth(captureAs("", () => s_indent(indent)))) return false;
    return truth(oneOrMore(() => consume(isNonBreak)));
  });

  // 172
  bool b_nb_literalNext(int indent) => transaction(() {
    if (!truth(b_asLineFeed())) return false;
    return l_nb_literalText(indent);
  });

  // 173
  String l_literalContent(int indent, int chomping) => captureString(() {
    transaction(() {
      if (!truth(l_nb_literalText(indent))) return false;
      zeroOrMore(() => b_nb_literalNext(indent));
      return b_chompedLast(chomping);
    });
    l_chompedEmpty(indent, chomping);
    return true;
  });

  // 174
  _Node c_l_folded(int indent) => transaction(() {
    if (!truth(c_indicator(C_FOLDED))) return null;
    var header = c_b_blockHeader();
    if (!truth(header)) return null;

    var additionalIndent = blockScalarAdditionalIndentation(header, indent);
    var content = l_foldedContent(indent + additionalIndent, header.chomping);
    if (!truth(content)) return null;

    return new _ScalarNode("!", content);
  });

  // 175
  bool s_nb_foldedText(int indent) => transaction(() {
    if (!truth(captureAs('', () => s_indent(indent)))) return false;
    if (!truth(consume(isNonSpace))) return false;
    zeroOrMore(() => consume(isNonBreak));
    return true;
  });

  // 176
  bool l_nb_foldedLines(int indent) {
    if (!truth(s_nb_foldedText(indent))) return false;
    zeroOrMore(() => transaction(() {
        if (!truth(b_l_folded(indent, BLOCK_IN))) return false;
        return s_nb_foldedText(indent);
      }));
    return true;
  }

  // 177
  bool s_nb_spacedText(int indent) => transaction(() {
    if (!truth(captureAs('', () => s_indent(indent)))) return false;
    if (!truth(consume(isSpace))) return false;
    zeroOrMore(() => consume(isNonBreak));
    return true;
  });

  // 178
  bool b_l_spaced(int indent) {
    if (!truth(b_asLineFeed())) return false;
    zeroOrMore(() => captureAs("\n", () => l_empty(indent, BLOCK_IN)));
    return true;
  }

  // 179
  bool l_nb_spacedLines(int indent) {
    if (!truth(s_nb_spacedText(indent))) return false;
    zeroOrMore(() => transaction(() {
        if (!truth(b_l_spaced(indent))) return false;
        return s_nb_spacedText(indent);
      }));
    return true;
  }

  // 180
  bool l_nb_sameLines(int indent) => transaction(() {
    zeroOrMore(() => captureAs('\n', () => l_empty(indent, BLOCK_IN)));
    return or([
      () => l_nb_foldedLines(indent),
      () => l_nb_spacedLines(indent)
    ]);
  });

  // 181
  bool l_nb_diffLines(int indent) {
    if (!truth(l_nb_sameLines(indent))) return false;
    zeroOrMore(() => transaction(() {
        if (!truth(b_asLineFeed())) return false;
        return l_nb_sameLines(indent);
      }));
    return true;
  }

  // 182
  String l_foldedContent(int indent, int chomping) => captureString(() {
    transaction(() {
      if (!truth(l_nb_diffLines(indent))) return false;
      return b_chompedLast(chomping);
    });
    l_chompedEmpty(indent, chomping);
    return true;
  });

  // 183
  _SequenceNode l_blockSequence(int indent) => context('sequence', () {
    var additionalIndent = countIndentation() - indent;
    if (additionalIndent <= 0) return null;

    var content = oneOrMore(() => transaction(() {
      if (!truth(s_indent(indent + additionalIndent))) return null;
      return c_l_blockSeqEntry(indent + additionalIndent);
    }));
    if (!truth(content)) return null;

    return new _SequenceNode("?", content);
  });

  // 184
  _Node c_l_blockSeqEntry(int indent) => transaction(() {
    if (!truth(c_indicator(C_SEQUENCE_ENTRY))) return null;
    if (isNonSpace(peek())) return null;

    return s_l_blockIndented(indent, BLOCK_IN);
  });

  // 185
  _Node s_l_blockIndented(int indent, int ctx) {
    var additionalIndent = countIndentation();
    return or([
      () => transaction(() {
        if (!truth(s_indent(additionalIndent))) return null;
        return or([
          () => ns_l_compactSequence(indent + 1 + additionalIndent),
          () => ns_l_compactMapping(indent + 1 + additionalIndent)]);
      }),
      () => s_l_blockNode(indent, ctx),
      () => s_l_comments() ? e_node() : null]);
  }

  // 186
  _Node ns_l_compactSequence(int indent) => context('sequence', () {
    var first = c_l_blockSeqEntry(indent);
    if (!truth(first)) return null;

    var content = zeroOrMore(() => transaction(() {
        if (!truth(s_indent(indent))) return null;
        return c_l_blockSeqEntry(indent);
      }));
    content.insertRange(0, 1, first);

    return new _SequenceNode("?", content);
  });

  // 187
  _Node l_blockMapping(int indent) => context('mapping', () {
    var additionalIndent = countIndentation() - indent;
    if (additionalIndent <= 0) return null;

    var pairs = oneOrMore(() => transaction(() {
      if (!truth(s_indent(indent + additionalIndent))) return null;
      return ns_l_blockMapEntry(indent + additionalIndent);
    }));
    if (!truth(pairs)) return null;

    return map(pairs);
  });

  // 188
  _Pair<_Node, _Node> ns_l_blockMapEntry(int indent) => or([
    () => c_l_blockMapExplicitEntry(indent),
    () => ns_l_blockMapImplicitEntry(indent)
  ]);

  // 189
  _Pair<_Node, _Node> c_l_blockMapExplicitEntry(int indent) {
    var key = c_l_blockMapExplicitKey(indent);
    if (!truth(key)) return null;

    var value = or([
      () => l_blockMapExplicitValue(indent),
      e_node
    ]);

    return new _Pair<_Node, _Node>(key, value);
  }

  // 190
  _Node c_l_blockMapExplicitKey(int indent) => transaction(() {
    if (!truth(c_indicator(C_MAPPING_KEY))) return null;
    return s_l_blockIndented(indent, BLOCK_OUT);
  });

  // 191
  _Node l_blockMapExplicitValue(int indent) => transaction(() {
    if (!truth(s_indent(indent))) return null;
    if (!truth(c_indicator(C_MAPPING_VALUE))) return null;
    return s_l_blockIndented(indent, BLOCK_OUT);
  });

  // 192
  _Pair<_Node, _Node> ns_l_blockMapImplicitEntry(int indent) => transaction(() {
    var key = or([ns_s_blockMapImplicitKey, e_node]);
    var value = c_l_blockMapImplicitValue(indent);
    return truth(value) ? new _Pair<_Node, _Node>(key, value) : null;
  });

  // 193
  _Node ns_s_blockMapImplicitKey() => context('mapping key', () => or([
    () => c_s_implicitJsonKey(BLOCK_KEY),
    () => ns_s_implicitYamlKey(BLOCK_KEY)
  ]));

  // 194
  _Node c_l_blockMapImplicitValue(int indent) => context('mapping value', () =>
    transaction(() {
      if (!truth(c_indicator(C_MAPPING_VALUE))) return null;
      return or([
        () => s_l_blockNode(indent, BLOCK_OUT),
        () => s_l_comments() ? e_node() : null
      ]);
    }));

  // 195
  _Node ns_l_compactMapping(int indent) => context('mapping', () {
    var first = ns_l_blockMapEntry(indent);
    if (!truth(first)) return null;

    var pairs = zeroOrMore(() => transaction(() {
        if (!truth(s_indent(indent))) return null;
        return ns_l_blockMapEntry(indent);
      }));
    pairs.insertRange(0, 1, first);

    return map(pairs);
  });

  // 196
  _Node s_l_blockNode(int indent, int ctx) => or([
    () => s_l_blockInBlock(indent, ctx),
    () => s_l_flowInBlock(indent)
  ]);

  // 197
  _Node s_l_flowInBlock(int indent) => transaction(() {
    if (!truth(s_separate(indent + 1, FLOW_OUT))) return null;
    var node = ns_flowNode(indent + 1, FLOW_OUT);
    if (!truth(node)) return null;
    if (!truth(s_l_comments())) return null;
    return node;
  });

  // 198
  _Node s_l_blockInBlock(int indent, int ctx) => or([
    () => s_l_blockScalar(indent, ctx),
    () => s_l_blockCollection(indent, ctx)
  ]);

  // 199
  _Node s_l_blockScalar(int indent, int ctx) => transaction(() {
    if (!truth(s_separate(indent + 1, ctx))) return null;
    var props = transaction(() {
      var props = c_ns_properties(indent + 1, ctx);
      if (!truth(props)) return null;
      if (!truth(s_separate(indent + 1, ctx))) return null;
      return props;
    });

    var node = or([() => c_l_literal(indent), () => c_l_folded(indent)]);
    if (!truth(node)) return null;
    return addProps(node, props);
  });

  // 200
  _Node s_l_blockCollection(int indent, int ctx) => transaction(() {
    var props = transaction(() {
      if (!truth(s_separate(indent + 1, ctx))) return null;
      return c_ns_properties(indent + 1, ctx);
    });

    if (!truth(s_l_comments())) return null;
    return or([
      () => l_blockSequence(seqSpaces(indent, ctx)),
      () => l_blockMapping(indent)]);
  });

  // 201
  int seqSpaces(int indent, int ctx) => ctx == BLOCK_OUT ? indent - 1 : indent;

  // 202
  void l_documentPrefix() {
    zeroOrMore(l_comment);
  }

  // 203
  bool c_directivesEnd() => rawString("---");

  // 204
  bool c_documentEnd() => rawString("...");

  // 205
  bool l_documentSuffix() => transaction(() {
    if (!truth(c_documentEnd())) return false;
    return s_l_comments();
  });

  // 206
  bool c_forbidden() {
    if (!inBareDocument || !atStartOfLine) return false;
    var forbidden = false;
    transaction(() {
      if (!truth(or([c_directivesEnd, c_documentEnd]))) return;
      var char = peek();
      forbidden = isBreak(char) || isSpace(char) || atEndOfFile;
      return;
    });
    return forbidden;
  }

  // 207
  _Node l_bareDocument() {
    try {
      inBareDocument = true;
      return s_l_blockNode(-1, BLOCK_IN);
    } finally {
      inBareDocument = false;
    }
  }

  // 208
  _Node l_explicitDocument() {
    if (!truth(c_directivesEnd())) return null;
    var doc = l_bareDocument();
    if (truth(doc)) return doc;

    doc = e_node();
    s_l_comments();
    return doc;
  }

  // 209
  _Node l_directiveDocument() {
    if (!truth(oneOrMore(l_directive))) return null;
    var doc = l_explicitDocument();
    if (doc != null) return doc;
    parseFailed();
    return null; // Unreachable.
  }

  // 210
  _Node l_anyDocument() =>
    or([l_directiveDocument, l_explicitDocument, l_bareDocument]);

  // 211
  List<_Node> l_yamlStream() {
    var docs = [];
    zeroOrMore(l_documentPrefix);
    var first = zeroOrOne(l_anyDocument);
    if (!truth(first)) first = e_node();
    docs.add(first);

    zeroOrMore(() {
      var doc;
      if (truth(oneOrMore(l_documentSuffix))) {
        zeroOrMore(l_documentPrefix);
        doc = zeroOrOne(l_anyDocument);
      } else {
        zeroOrMore(l_documentPrefix);
        doc = zeroOrOne(l_explicitDocument);
      }
      if (truth(doc)) docs.add(doc);
      return doc;
    });

    if (!atEndOfFile) parseFailed();
    return docs;
  }
}

class SyntaxError extends YamlException {
  final int line;
  final int column;

  SyntaxError(this.line, this.column, String msg) : super(msg);

  String toString() => "Syntax error on line $line, column $column: $msg";
}

/** A pair of values. */
class _Pair<E, F> {
  E first;
  F last;

  _Pair(this.first, this.last);

  String toString() => '($first, $last)';
}

/** The information in the header for a block scalar. */
class _BlockHeader {
  final int additionalIndent;
  final int chomping;

  _BlockHeader(this.additionalIndent, this.chomping);

  bool get autoDetectIndent() => additionalIndent == null;
}
