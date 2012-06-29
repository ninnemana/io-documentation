// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

interface Visitor<R> {
  R visitBlock(Block node);
  R visitBreakStatement(BreakStatement node);
  R visitCascade(Cascade node);
  R visitCascadeReceiver(CascadeReceiver node);
  R visitCaseMatch(CaseMatch node);
  R visitCatchBlock(CatchBlock node);
  R visitClassNode(ClassNode node);
  R visitConditional(Conditional node);
  R visitContinueStatement(ContinueStatement node);
  R visitDoWhile(DoWhile node);
  R visitEmptyStatement(EmptyStatement node);
  R visitExpressionStatement(ExpressionStatement node);
  R visitFor(For node);
  R visitForIn(ForIn node);
  R visitFunctionDeclaration(FunctionDeclaration node);
  R visitFunctionExpression(FunctionExpression node);
  R visitIdentifier(Identifier node);
  R visitIf(If node);
  R visitLabel(Label node);
  R visitLabeledStatement(LabeledStatement node);
  R visitLiteralBool(LiteralBool node);
  R visitLiteralDouble(LiteralDouble node);
  R visitLiteralInt(LiteralInt node);
  R visitLiteralList(LiteralList node);
  R visitLiteralMap(LiteralMap node);
  R visitLiteralMapEntry(LiteralMapEntry node);
  R visitLiteralNull(LiteralNull node);
  R visitLiteralString(LiteralString node);
  R visitModifiers(Modifiers node);
  R visitNamedArgument(NamedArgument node);
  R visitNewExpression(NewExpression node);
  R visitNodeList(NodeList node);
  R visitOperator(Operator node);
  R visitParenthesizedExpression(ParenthesizedExpression node);
  R visitReturn(Return node);
  R visitScriptTag(ScriptTag node);
  R visitSend(Send node);
  R visitSendSet(SendSet node);
  R visitStringInterpolation(StringInterpolation node);
  R visitStringInterpolationPart(StringInterpolationPart node);
  R visitStringJuxtaposition(StringJuxtaposition node);
  R visitSwitchCase(SwitchCase node);
  R visitSwitchStatement(SwitchStatement node);
  R visitThrow(Throw node);
  R visitTryStatement(TryStatement node);
  R visitTypeAnnotation(TypeAnnotation node);
  R visitTypedef(Typedef node);
  R visitTypeVariable(TypeVariable node);
  R visitVariableDefinitions(VariableDefinitions node);
  R visitWhile(While node);
}

Token firstBeginToken(Node first, Node second) {
  if (first !== null) return first.getBeginToken();
  if (second !== null) return second.getBeginToken();
  return null;
}

class NodeAssertionFailure implements Exception {
  final Node node;
  final String message;
  NodeAssertionFailure(this.node, this.message);
}

/**
 * A node in a syntax tree.
 *
 * The abstract part of "abstract syntax tree" is invalidated when
 * supporting tools such as code formatting. These tools need concrete
 * syntax such as parentheses and no constant folding.
 *
 * We support these tools by storing additional references back to the
 * token stream. These references are stored in fields ending with
 * "Token".
 */
class Node implements Hashable {
  final int _hashCode;
  static int _HASH_COUNTER = 0;

  Node() : _hashCode = ++_HASH_COUNTER;

  hashCode() => _hashCode;

  abstract accept(Visitor visitor);

  abstract visitChildren(Visitor visitor);

  /**
   * Returns this node unparsed to Dart source string.
   */
  toString() => unparse();

  /**
   * Returns Xml-like tree representation of this node.
   */
  toDebugString() {
    return PrettyPrinter.prettyPrint(this);
  }

  String getObjectDescription() => super.toString();

  String unparse() {
    Unparser unparser = new Unparser();
    try {
      return unparser.unparse(this);
    } catch (var e, var trace) {
      print(trace);
      return '<<unparse error: ${getObjectDescription()}: ${unparser.sb}>>';
    }
  }

  abstract Token getBeginToken();

  abstract Token getEndToken();

  Block asBlock() => null;
  BreakStatement asBreakStatement() => null;
  Cascade asCascade() => null;
  CascadeReceiver asCascadeReceiver() => null;
  CaseMatch asCaseMatch() => null;
  CatchBlock asCatchBlock() => null;
  ClassNode asClassNode() => null;
  Conditional asConditional() => null;
  ContinueStatement asContinueStatement() => null;
  DoWhile asDoWhile() => null;
  EmptyStatement asEmptyStatement() => null;
  Expression asExpression() => null;
  ExpressionStatement asExpressionStatement() => null;
  For asFor() => null;
  ForIn asForIn() => null;
  FunctionDeclaration asFunctionDeclaration() => null;
  FunctionExpression asFunctionExpression() => null;
  Identifier asIdentifier() => null;
  If asIf() => null;
  Label asLabel() => null;
  LabeledStatement asLabeledStatement() => null;
  LiteralBool asLiteralBool() => null;
  LiteralDouble asLiteralDouble() => null;
  LiteralInt asLiteralInt() => null;
  LiteralList asLiteralList() => null;
  LiteralMap asLiteralMap() => null;
  LiteralMapEntry asLiteralMapEntry() => null;
  LiteralNull asLiteralNull() => null;
  LiteralString asLiteralString() => null;
  Modifiers asModifiers() => null;
  NamedArgument asNamedArgument() => null;
  NodeList asNodeList() => null;
  Operator asOperator() => null;
  ParenthesizedExpression asParenthesizedExpression() => null;
  Return asReturn() => null;
  ScriptTag asScriptTag() => null;
  Send asSend() => null;
  SendSet asSendSet() => null;
  Statement asStatement() => null;
  StringNode asStringNode() => null;
  StringInterpolation asStringInterpolation() => null;
  StringInterpolationPart asStringInterpolationPart() => null;
  StringJuxtaposition asStringJuxtaposition() => null;
  SwitchCase asSwitchCase() => null;
  SwitchStatement asSwitchStatement() => null;
  Throw asThrow() => null;
  TryStatement asTryStatement() => null;
  TypeAnnotation asTypeAnnotation() => null;
  Typedef asTypedef() => null;
  TypeVariable asTypeVariable() => null;
  VariableDefinitions asVariableDefinitions() => null;
  While asWhile() => null;

  bool isValidBreakTarget() => false;
  bool isValidContinueTarget() => false;
}

class ClassNode extends Node {
  final Identifier name;
  final TypeAnnotation superclass;
  final NodeList interfaces;
  final NodeList typeParameters;

  // TODO(ahe, karlklose): the default keyword is not recorded.
  final TypeAnnotation defaultClause;

  final Token beginToken;
  final Token extendsKeyword;
  final Token endToken;

  ClassNode(this.name, this.typeParameters, this.superclass, this.interfaces,
            this.defaultClause, this.beginToken, this.extendsKeyword,
            this.endToken);

  ClassNode asClassNode() => this;

  accept(Visitor visitor) => visitor.visitClassNode(this);

  visitChildren(Visitor visitor) {
    if (name !== null) name.accept(visitor);
    if (superclass !== null) superclass.accept(visitor);
    if (interfaces !== null) interfaces.accept(visitor);
  }

  bool get isInterface() => beginToken.stringValue === 'interface';

  bool get isClass() => !isInterface;

  Token getBeginToken() => beginToken;

  Token getEndToken() => endToken;
}

class Expression extends Node {
  Expression();

  Expression asExpression() => this;

  // TODO(ahe): make class abstract instead of adding an abstract method.
  abstract accept(Visitor visitor);
}

class Statement extends Node {
  Statement();

  Statement asStatement() => this;

  // TODO(ahe): make class abstract instead of adding an abstract method.
  abstract accept(Visitor visitor);

  bool isValidBreakTarget() => true;
}

/**
 * A message send aka method invocation. In Dart, most operations can
 * (and should) be considered as message sends. Getters and setters
 * are just methods with a special syntax. Consequently, we model
 * property access, assignment, operators, and method calls with this
 * one node.
 */
class Send extends Expression {
  final Node receiver;
  final Node selector;
  final NodeList argumentsNode;
  Link<Node> get arguments() => argumentsNode.nodes;

  Send([this.receiver, this.selector, this.argumentsNode]);
  Send.postfix(this.receiver, this.selector, [Node argument = null])
      : argumentsNode = (argument === null)
        ? new Postfix()
        : new Postfix.singleton(argument);
  Send.prefix(this.receiver, this.selector, [Node argument = null])
      : argumentsNode = (argument === null)
        ? new Prefix()
        : new Prefix.singleton(argument);

  Send asSend() => this;

  accept(Visitor visitor) => visitor.visitSend(this);

  visitChildren(Visitor visitor) {
    if (receiver !== null) receiver.accept(visitor);
    if (selector !== null) selector.accept(visitor);
    if (argumentsNode !== null) argumentsNode.accept(visitor);
  }

  int argumentCount() => (argumentsNode === null) ? -1 : argumentsNode.length();

  bool get isSuperCall() {
    return receiver !== null &&
           receiver.asIdentifier() !== null &&
           receiver.asIdentifier().isSuper();
  }
  bool get isOperator() => selector is Operator;
  bool get isPropertyAccess() => argumentsNode === null;
  bool get isFunctionObjectInvocation() => selector === null;
  bool get isPrefix() => argumentsNode is Prefix;
  bool get isPostfix() => argumentsNode is Postfix;
  bool get isIndex() =>
      isOperator && selector.asOperator().source.stringValue === '[]';
  bool get isCall() => !isOperator && !isPropertyAccess;

  Token getBeginToken() {
    if (isPrefix && !isIndex) return selector.getBeginToken();
    return firstBeginToken(receiver, selector);
  }

  Token getEndToken() {
    if (isPrefix) {
      if (receiver !== null) return receiver.getEndToken();
      if (selector !== null) return selector.getEndToken();
      return null;
    }
    if (!isPostfix && argumentsNode !== null) {
      return argumentsNode.getEndToken();
    }
    if (selector !== null) return selector.getEndToken();
    return receiver.getBeginToken();
  }

  Send copyWithReceiver(Node newReceiver) {
    assert(receiver === null);
    return new Send(newReceiver, selector, argumentsNode);
  }
}

class Postfix extends NodeList {
  Postfix() : super(nodes: const EmptyLink<Node>());
  Postfix.singleton(Node argument) : super.singleton(argument);
}

class Prefix extends NodeList {
  Prefix() : super(nodes: const EmptyLink<Node>());
  Prefix.singleton(Node argument) : super.singleton(argument);
}

class SendSet extends Send {
  final Operator assignmentOperator;
  SendSet(receiver, selector, this.assignmentOperator, argumentsNode)
    : super(receiver, selector, argumentsNode);
  SendSet.postfix(receiver,
                  selector,
                  this.assignmentOperator,
                  [Node argument = null])
      : super.postfix(receiver, selector, argument);
  SendSet.prefix(receiver,
                 selector,
                 this.assignmentOperator,
                 [Node argument = null])
      : super.prefix(receiver, selector, argument);

  SendSet asSendSet() => this;

  accept(Visitor visitor) => visitor.visitSendSet(this);

  visitChildren(Visitor visitor) {
    super.visitChildren(visitor);
    if (assignmentOperator !== null) assignmentOperator.accept(visitor);
  }

  Send copyWithReceiver(Node newReceiver) {
    assert(receiver === null);
    return new SendSet(newReceiver, selector, assignmentOperator,
                       argumentsNode);
  }
}

class NewExpression extends Expression {
  /** The token NEW or CONST */
  final Token newToken;

  // Note: we expect that send.receiver is null.
  final Send send;

  NewExpression([this.newToken, this.send]);

  accept(Visitor visitor) => visitor.visitNewExpression(this);

  visitChildren(Visitor visitor) {
    if (send !== null) send.accept(visitor);
  }

  bool isConst() => newToken.stringValue === 'const';

  Token getBeginToken() => newToken;

  Token getEndToken() => send.getEndToken();
}

class NodeList extends Node implements Iterable<Node> {
  final Link<Node> nodes;
  final Token beginToken;
  final Token endToken;
  final SourceString delimiter;
  bool isEmpty() => nodes.isEmpty();

  NodeList([this.beginToken, this.nodes, this.endToken, this.delimiter]);

  Iterator<Node> iterator() => nodes.iterator();

  NodeList.singleton(Node node) : this(null, new Link<Node>(node));
  NodeList.empty() : this(null, const EmptyLink<Node>());

  NodeList asNodeList() => this;

  int length() {
    int result = 0;
    for (Link<Node> cursor = nodes; !cursor.isEmpty(); cursor = cursor.tail) {
      result++;
    }
    return result;
  }

  accept(Visitor visitor) => visitor.visitNodeList(this);

  visitChildren(Visitor visitor) {
    if (nodes === null) return;
    for (Link<Node> link = nodes; !link.isEmpty(); link = link.tail) {
      if (link.head !== null) link.head.accept(visitor);
    }
  }

  Token getBeginToken() {
    if (beginToken !== null) return beginToken;
     if (nodes !== null) {
       for (Link<Node> link = nodes; !link.isEmpty(); link = link.tail) {
         if (link.head.getBeginToken() !== null) {
           return link.head.getBeginToken();
         }
         if (link.head.getEndToken() !== null) {
           return link.head.getEndToken();
         }
       }
     }
    return endToken;
  }

  Token getEndToken() {
    if (endToken !== null) return endToken;
    if (nodes !== null) {
      Link<Node> link = nodes;
      if (link.isEmpty()) return beginToken;
      while (!link.tail.isEmpty()) link = link.tail;
      if (link.head.getEndToken() !== null) return link.head.getEndToken();
      if (link.head.getBeginToken() !== null) return link.head.getBeginToken();
    }
    return beginToken;
  }
}

class Block extends Statement {
  final NodeList statements;

  Block(this.statements);

  Block asBlock() => this;

  accept(Visitor visitor) => visitor.visitBlock(this);

  visitChildren(Visitor visitor) {
    if (statements !== null) statements.accept(visitor);
  }

  Token getBeginToken() => statements.getBeginToken();

  Token getEndToken() => statements.getEndToken();
}

class If extends Statement {
  final ParenthesizedExpression condition;
  final Statement thenPart;
  final Statement elsePart;

  final Token ifToken;
  final Token elseToken;

  If(this.condition, this.thenPart, this.elsePart,
     this.ifToken, this.elseToken);

  If asIf() => this;

  bool get hasElsePart() => elsePart !== null;

  void validate() {
    // TODO(ahe): Check that condition has size one.
  }

  accept(Visitor visitor) => visitor.visitIf(this);

  visitChildren(Visitor visitor) {
    if (condition !== null) condition.accept(visitor);
    if (thenPart !== null) thenPart.accept(visitor);
    if (elsePart !== null) elsePart.accept(visitor);
  }

  Token getBeginToken() => ifToken;

  Token getEndToken() {
    if (elsePart === null) return thenPart.getEndToken();
    return elsePart.getEndToken();
  }
}

class Conditional extends Expression {
  final Expression condition;
  final Expression thenExpression;
  final Expression elseExpression;

  final Token questionToken;
  final Token colonToken;

  Conditional(this.condition, this.thenExpression,
              this.elseExpression, this.questionToken, this.colonToken);

  Conditional asConditional() => this;

  accept(Visitor visitor) => visitor.visitConditional(this);

  visitChildren(Visitor visitor) {
    condition.accept(visitor);
    thenExpression.accept(visitor);
    elseExpression.accept(visitor);
  }

  Token getBeginToken() => condition.getBeginToken();

  Token getEndToken() => elseExpression.getEndToken();
}

class For extends Loop {
  /** Either a variable declaration or an expression. */
  final Node initializer;
  /** Either an expression statement or an empty statement. */
  final Statement conditionStatement;
  final NodeList update;

  final Token forToken;

  For(this.initializer, this.conditionStatement, this.update, body,
      this.forToken) : super(body);

  For asFor() => this;

  Expression get condition() {
    if (conditionStatement is ExpressionStatement) {
      return conditionStatement.asExpressionStatement().expression;
    } else {
      return null;
    }
  }

  accept(Visitor visitor) => visitor.visitFor(this);

  visitChildren(Visitor visitor) {
    if (initializer !== null) initializer.accept(visitor);
    if (conditionStatement !== null) conditionStatement.accept(visitor);
    if (update !== null) update.accept(visitor);
    if (body !== null) body.accept(visitor);
  }

  Token getBeginToken() => forToken;

  Token getEndToken() {
    return body.getEndToken();
  }
}

class FunctionDeclaration extends Statement {
  final FunctionExpression function;

  FunctionDeclaration(this.function);

  FunctionDeclaration asFunctionDeclaration() => this;

  accept(Visitor visitor) => visitor.visitFunctionDeclaration(this);

  visitChildren(Visitor visitor) => function.accept(visitor);

  Token getBeginToken() => function.getBeginToken();
  Token getEndToken() => function.getEndToken();
}

class FunctionExpression extends Expression {
  final Node name;

  /**
   * List of VariableDefinitions or NodeList.
   *
   * A NodeList can only occur at the end and holds named parameters.
   */
  final NodeList parameters;

  final Statement body;
  final TypeAnnotation returnType;
  final Modifiers modifiers;
  final NodeList initializers;

  final Token getOrSet;

  FunctionExpression(this.name, this.parameters, this.body, this.returnType,
                     this.modifiers, this.initializers, this.getOrSet);

  FunctionExpression asFunctionExpression() => this;

  accept(Visitor visitor) => visitor.visitFunctionExpression(this);

  visitChildren(Visitor visitor) {
    if (modifiers !== null) modifiers.accept(visitor);
    if (returnType !== null) returnType.accept(visitor);
    if (name !== null) name.accept(visitor);
    if (parameters !== null) parameters.accept(visitor);
    if (initializers !== null) initializers.accept(visitor);
    if (body !== null) body.accept(visitor);
  }

  bool hasBody() {
    // TODO(karlklose,ahe): refactor AST nodes (issue 1713).
    if (body.asReturn() !== null) return true;
    NodeList statements = body.asBlock().statements;
    return (!statements.nodes.isEmpty() ||
            statements.getBeginToken().kind !== $SEMICOLON);
  }

  Token getBeginToken() {
    Token token = firstBeginToken(modifiers, returnType);
    if (token !== null) return token;
    if (getOrSet !== null) return getOrSet;
    return firstBeginToken(name, parameters);
  }

  Token getEndToken() {
    Token token = (body === null) ? null : body.getEndToken();
    token = (token === null) ? parameters.getEndToken() : token;
    return (token === null) ? name.getEndToken() : token;
  }
}

typedef void DecodeErrorHandler(Token token, var error);

class Literal<T> extends Expression {
  final Token token;
  final DecodeErrorHandler handler;

  Literal(Token this.token, DecodeErrorHandler this.handler);

  abstract T get value();

  visitChildren(Visitor visitor) {}

  Token getBeginToken() => token;

  Token getEndToken() => token;
}

class LiteralInt extends Literal<int> {
  LiteralInt(Token token, DecodeErrorHandler handler) : super(token, handler);

  LiteralInt asLiteralInt() => this;

  int get value() {
    try {
      Token valueToken = token;
      if (valueToken.kind === PLUS_TOKEN) valueToken = valueToken.next;
      return Math.parseInt(valueToken.value.slowToString());
    } catch (BadNumberFormatException ex) {
      (this.handler)(token, ex);
    }
  }

  accept(Visitor visitor) => visitor.visitLiteralInt(this);
}

class LiteralDouble extends Literal<double> {
  LiteralDouble(Token token, DecodeErrorHandler handler)
    : super(token, handler);

  LiteralDouble asLiteralDouble() => this;

  double get value() {
    try {
      Token valueToken = token;
      if (valueToken.kind === PLUS_TOKEN) valueToken = valueToken.next;
      return Math.parseDouble(valueToken.value.slowToString());
    } catch (BadNumberFormatException ex) {
      (this.handler)(token, ex);
    }
  }

  accept(Visitor visitor) => visitor.visitLiteralDouble(this);
}

class LiteralBool extends Literal<bool> {
  LiteralBool(Token token, DecodeErrorHandler handler) : super(token, handler);

  LiteralBool asLiteralBool() => this;

  bool get value() {
    if (token.value == Keyword.TRUE) return true;
    if (token.value == Keyword.FALSE) return false;
    (this.handler)(token, "not a bool ${token.value}");
  }

  accept(Visitor visitor) => visitor.visitLiteralBool(this);
}


class StringQuoting {
  static final StringQuoting SINGLELINE_DQ =
      const StringQuoting($DQ, raw: false, leftQuoteLength: 1);
  static final StringQuoting RAW_SINGLELINE_DQ =
      const StringQuoting($DQ, raw: true, leftQuoteLength: 1);
  static final StringQuoting MULTILINE_DQ =
      const StringQuoting($DQ, raw: false, leftQuoteLength: 3);
  static final StringQuoting RAW_MULTILINE_DQ =
      const StringQuoting($DQ, raw: true, leftQuoteLength: 3);
  static final StringQuoting MULTILINE_NL_DQ =
      const StringQuoting($DQ, raw: false, leftQuoteLength: 4);
  static final StringQuoting RAW_MULTILINE_NL_DQ =
      const StringQuoting($DQ, raw: true, leftQuoteLength: 4);
  static final StringQuoting MULTILINE_NL2_DQ =
      const StringQuoting($DQ, raw: false, leftQuoteLength: 5);
  static final StringQuoting RAW_MULTILINE_NL2_DQ =
      const StringQuoting($DQ, raw: true, leftQuoteLength: 5);
  static final StringQuoting SINGLELINE_SQ =
      const StringQuoting($SQ, raw: false, leftQuoteLength: 1);
  static final StringQuoting RAW_SINGLELINE_SQ =
      const StringQuoting($SQ, raw: true, leftQuoteLength: 1);
  static final StringQuoting MULTILINE_SQ =
      const StringQuoting($SQ, raw: false, leftQuoteLength: 3);
  static final StringQuoting RAW_MULTILINE_SQ =
      const StringQuoting($SQ, raw: true, leftQuoteLength: 3);
  static final StringQuoting MULTILINE_NL_SQ =
      const StringQuoting($SQ, raw: false, leftQuoteLength: 4);
  static final StringQuoting RAW_MULTILINE_NL_SQ =
      const StringQuoting($SQ, raw: true, leftQuoteLength: 4);
  static final StringQuoting MULTILINE_NL2_SQ =
      const StringQuoting($SQ, raw: false, leftQuoteLength: 5);
  static final StringQuoting RAW_MULTILINE_NL2_SQ =
      const StringQuoting($SQ, raw: true, leftQuoteLength: 5);


  static final List<StringQuoting> mapping = const <StringQuoting>[
    SINGLELINE_DQ,
    RAW_SINGLELINE_DQ,
    MULTILINE_DQ,
    RAW_MULTILINE_DQ,
    MULTILINE_NL_DQ,
    RAW_MULTILINE_NL_DQ,
    MULTILINE_NL2_DQ,
    RAW_MULTILINE_NL2_DQ,
    SINGLELINE_SQ,
    RAW_SINGLELINE_SQ,
    MULTILINE_SQ,
    RAW_MULTILINE_SQ,
    MULTILINE_NL_SQ,
    RAW_MULTILINE_NL_SQ,
    MULTILINE_NL2_SQ,
    RAW_MULTILINE_NL2_SQ
  ];
  final bool raw;
  final int leftQuoteCharCount;
  final int quote;
  const StringQuoting(this.quote, [bool raw, int leftQuoteLength])
      : this.raw = raw, this.leftQuoteCharCount = leftQuoteLength;
  String get quoteChar() => quote === $DQ ? '"' : "'";

  int get leftQuoteLength() => (raw ? 1 : 0) + leftQuoteCharCount;
  int get rightQuoteLength() => (leftQuoteCharCount > 2) ? 3 : 1;
  static StringQuoting getQuoting(int quote, bool raw, int quoteLength) {
    int index = quoteLength - 1;
    if (quoteLength > 2) index -= 1;
    return mapping[(raw ? 1 : 0) + index * 2 + (quote === $SQ ? 8 : 0)];
  }
}

/**
  * Superclass for classes representing string literals.
  */
class StringNode extends Expression {
  abstract DartString get dartString();
  abstract bool get isInterpolation();

  StringNode asStringNode() => this;
}

class LiteralString extends StringNode {
  final Token token;
  /** Non-null on validated string literals. */
  final DartString dartString;

  LiteralString(this.token, this.dartString);

  LiteralString asLiteralString() => this;

  void visitChildren(Visitor visitor) {}

  bool get isInterpolation() => false;
  bool isValidated() => dartString !== null;

  Token getBeginToken() => token;
  Token getEndToken() => token;

  accept(Visitor visitor) => visitor.visitLiteralString(this);
}

class LiteralNull extends Literal<SourceString> {
  LiteralNull(Token token) : super(token, null);

  LiteralNull asLiteralNull() => this;

  SourceString get value() => null;

  accept(Visitor visitor) => visitor.visitLiteralNull(this);
}

class LiteralList extends Expression {
  final TypeAnnotation type;
  final NodeList elements;

  final Token constKeyword;

  LiteralList(this.type, this.elements, this.constKeyword);

  bool isConst() => constKeyword !== null;

  LiteralList asLiteralList() => this;
  accept(Visitor visitor) => visitor.visitLiteralList(this);

  visitChildren(Visitor visitor) {
    if (type !== null) type.accept(visitor);
    elements.accept(visitor);
  }

  Token getBeginToken() {
    if (constKeyword !== null) return constKeyword;
    return firstBeginToken(type, elements);
  }

  Token getEndToken() => elements.getEndToken();
}

class Identifier extends Expression {
  final Token token;

  SourceString get source() => token.value;

  Identifier(Token this.token);

  bool isThis() => source.stringValue === 'this';

  bool isSuper() => source.stringValue === 'super';

  Identifier asIdentifier() => this;

  accept(Visitor visitor) => visitor.visitIdentifier(this);

  visitChildren(Visitor visitor) {}

  Token getBeginToken() => token;

  Token getEndToken() => token;
}

class Operator extends Identifier {
  Operator(Token token) : super(token);

  Operator asOperator() => this;

  accept(Visitor visitor) => visitor.visitOperator(this);
}

class Return extends Statement {
  final Expression expression;
  final Token beginToken;
  final Token endToken;

  Return(this.beginToken, this.endToken, this.expression);

  Return asReturn() => this;

  bool get hasExpression() => expression !== null;

  accept(Visitor visitor) => visitor.visitReturn(this);

  visitChildren(Visitor visitor) {
    if (expression !== null) expression.accept(visitor);
  }

  Token getBeginToken() => beginToken;

  Token getEndToken() {
    if (endToken === null) return expression.getEndToken();
    return endToken;
  }
}

class ExpressionStatement extends Statement {
  final Expression expression;
  final Token endToken;

  ExpressionStatement(this.expression, this.endToken);

  ExpressionStatement asExpressionStatement() => this;

  accept(Visitor visitor) => visitor.visitExpressionStatement(this);

  visitChildren(Visitor visitor) {
    if (expression !== null) expression.accept(visitor);
  }

  Token getBeginToken() => expression.getBeginToken();

  Token getEndToken() => endToken;
}

class Throw extends Statement {
  final Expression expression;

  final Token throwToken;
  final Token endToken;

  Throw(this.expression, this.throwToken, this.endToken);

  Throw asThrow() => this;

  accept(Visitor visitor) => visitor.visitThrow(this);

  visitChildren(Visitor visitor) {
    if (expression !== null) expression.accept(visitor);
  }

  Token getBeginToken() => throwToken;

  Token getEndToken() => endToken;
}

class TypeAnnotation extends Node {
  final Expression typeName;
  final NodeList typeArguments;

  TypeAnnotation(Expression this.typeName, NodeList this.typeArguments);

  TypeAnnotation asTypeAnnotation() => this;

  accept(Visitor visitor) => visitor.visitTypeAnnotation(this);

  visitChildren(Visitor visitor) {
    typeName.accept(visitor);
    if (typeArguments !== null) typeArguments.accept(visitor);
  }

  Token getBeginToken() => typeName.getBeginToken();

  Token getEndToken() => typeName.getEndToken();
}

class TypeVariable extends Node {
  final Identifier name;
  final TypeAnnotation bound;
  TypeVariable(Identifier this.name, TypeAnnotation this.bound);

  accept(Visitor visitor) => visitor.visitTypeVariable(this);

  visitChildren(Visitor visitor) {
    name.accept(visitor);
    if (bound !== null) {
      bound.accept(visitor);
    }
  }

  TypeVariable asTypeVariable() => this;

  Token getBeginToken() => name.getBeginToken();

  Token getEndToken() {
    return (bound !== null) ? bound.getEndToken() : name.getEndToken();
  }
}

class VariableDefinitions extends Statement {
  final Token endToken;
  final TypeAnnotation type;
  final Modifiers modifiers;
  final NodeList definitions;
  VariableDefinitions(this.type, this.modifiers, this.definitions,
                      this.endToken);

  VariableDefinitions asVariableDefinitions() => this;

  accept(Visitor visitor) => visitor.visitVariableDefinitions(this);

  visitChildren(Visitor visitor) {
    if (type !== null) type.accept(visitor);
    if (definitions !== null) definitions.accept(visitor);
  }

  Token getBeginToken() {
    return firstBeginToken(type, definitions);
  }

  Token getEndToken() => endToken;
}

class Loop extends Statement {
  abstract Expression get condition();
  final Statement body;

  Loop(this.body);

  bool isValidContinueTarget() => true;
}

class DoWhile extends Loop {
  final Token doKeyword;
  final Token whileKeyword;
  final Token endToken;

  final Expression condition;

  DoWhile(Statement body, Expression this.condition,
          Token this.doKeyword, Token this.whileKeyword, Token this.endToken)
    : super(body);

  DoWhile asDoWhile() => this;

  accept(Visitor visitor) => visitor.visitDoWhile(this);

  visitChildren(Visitor visitor) {
    if (condition !== null) condition.accept(visitor);
    if (body !== null) body.accept(visitor);
  }

  Token getBeginToken() => doKeyword;

  Token getEndToken() => endToken;
}

class While extends Loop {
  final Token whileKeyword;
  final Expression condition;

  While(Expression this.condition, Statement body,
        Token this.whileKeyword) : super(body);

  While asWhile() => this;

  accept(Visitor visitor) => visitor.visitWhile(this);

  visitChildren(Visitor visitor) {
    if (condition !== null) condition.accept(visitor);
    if (body !== null) body.accept(visitor);
  }

  Token getBeginToken() => whileKeyword;

  Token getEndToken() => body.getEndToken();
}

class ParenthesizedExpression extends Expression {
  final Expression expression;
  final BeginGroupToken beginToken;

  ParenthesizedExpression(Expression this.expression,
                          BeginGroupToken this.beginToken);

  ParenthesizedExpression asParenthesizedExpression() => this;

  accept(Visitor visitor) => visitor.visitParenthesizedExpression(this);

  visitChildren(Visitor visitor) {
    if (expression !== null) expression.accept(visitor);
  }

  Token getBeginToken() => beginToken;

  Token getEndToken() => beginToken.endGroup;
}

/** Representation of modifiers such as static, abstract, final, etc. */
class Modifiers extends Node {
  /* TODO(ahe): The following should be validated relating to modifiers:
   * 1. The nodes must come in a certain order.
   * 2. The keywords "var" and "final" may not be used at the same time.
   * 3. The type of an element must be null if isVar() is true.
   */

  final NodeList nodes;
  /** Bit pattern to easy check what modifiers are present. */
  final int flags;

  static final int FLAG_STATIC = 1;
  static final int FLAG_ABSTRACT = FLAG_STATIC << 1;
  static final int FLAG_FINAL = FLAG_ABSTRACT << 1;
  static final int FLAG_VAR = FLAG_FINAL << 1;
  static final int FLAG_CONST = FLAG_VAR << 1;
  static final int FLAG_FACTORY = FLAG_CONST << 1;

  Modifiers(NodeList nodes)
    : this.nodes = nodes, flags = computeFlags(nodes.nodes);

  Modifiers.empty() : this(new NodeList.empty());

  static int computeFlags(Link<Node> nodes) {
    int flags = 0;
    for (; !nodes.isEmpty(); nodes = nodes.tail) {
      String value = nodes.head.asIdentifier().source.stringValue;
      if (value === 'static') flags += FLAG_STATIC;
      else if (value === 'abstract') flags += FLAG_ABSTRACT;
      else if (value === 'final') flags += FLAG_FINAL;
      else if (value === 'var') flags += FLAG_VAR;
      else if (value === 'const') flags += FLAG_CONST;
      else if (value === 'factory') flags += FLAG_FACTORY;
      else throw 'internal error: ${nodes.head}';
    }
    return flags;
  }

  Modifiers asModifiers() => this;
  Token getBeginToken() => nodes.getBeginToken();
  Token getEndToken() => nodes.getEndToken();
  accept(Visitor visitor) => visitor.visitModifiers(this);
  visitChildren(Visitor visitor) => nodes.accept(visitor);

  bool isStatic() => (flags & FLAG_STATIC) != 0;
  bool isAbstract() => (flags & FLAG_ABSTRACT) != 0;
  bool isFinal() => (flags & FLAG_FINAL) != 0;
  bool isVar() => (flags & FLAG_VAR) != 0;
  bool isConst() => (flags & FLAG_CONST) != 0;
  bool isFactory() => (flags & FLAG_FACTORY) != 0;
}

class StringInterpolation extends StringNode {
  final LiteralString string;
  final NodeList parts;

  StringInterpolation(this.string, this.parts);

  StringInterpolation asStringInterpolation() => this;

  DartString get dartString() => null;
  bool get isInterpolation() => true;

  accept(Visitor visitor) => visitor.visitStringInterpolation(this);

  visitChildren(Visitor visitor) {
    string.accept(visitor);
    parts.accept(visitor);
  }

  Token getBeginToken() => string.getBeginToken();
  Token getEndToken() => parts.getEndToken();
}

class StringInterpolationPart extends Node {
  final Expression expression;
  final LiteralString string;

  StringInterpolationPart(this.expression, this.string);

  StringInterpolationPart asStringInterpolationPart() => this;

  accept(Visitor visitor) => visitor.visitStringInterpolationPart(this);

  visitChildren(Visitor visitor) {
    expression.accept(visitor);
    string.accept(visitor);
  }

  Token getBeginToken() => expression.getBeginToken();

  Token getEndToken() => string.getEndToken();
}

/**
 * A class representing juxtaposed string literals.
 * The string literals can be both plain literals and string interpolations.
 */
class StringJuxtaposition extends StringNode {
  final Expression first;
  final Expression second;

  /**
   * Caches the check for whether this juxtaposition contains a string
   * interpolation
   */
  bool isInterpolationCache = null;

  /**
   * Caches a Dart string representation of the entire juxtaposition's
   * content. Only juxtapositions that don't (transitively) contains
   * interpolations have a static representation.
   */
  DartString dartStringCache = null;

  StringJuxtaposition(this.first, this.second);

  StringJuxtaposition asStringJuxtaposition() => this;

  bool get isInterpolation() {
    if (isInterpolationCache === null) {
      isInterpolationCache = (first.accept(const IsInterpolationVisitor()) ||
                          second.accept(const IsInterpolationVisitor()));
    }
    return isInterpolationCache;
  }

  /**
   * Retrieve a single DartString that represents this entire juxtaposition
   * of string literals.
   * Should only be called if [isInterpolation] returns false.
   */
  DartString get dartString() {
    if (isInterpolation) {
      throw new NodeAssertionFailure(this,
                                     "Getting dartString on interpolation;");
    }
    if (dartStringCache === null) {
      DartString firstString = first.accept(const GetDartStringVisitor());
      DartString secondString = second.accept(const GetDartStringVisitor());
      if (firstString === null || secondString === null) {
        return null;
      }
      dartStringCache = new DartString.concat(firstString, secondString);
    }
    return dartStringCache;
  }

  accept(Visitor visitor) => visitor.visitStringJuxtaposition(this);

  void visitChildren(Visitor visitor) {
    first.accept(visitor);
    second.accept(visitor);
  }

  Token getBeginToken() => first.getBeginToken();

  Token getEndToken() => second.getEndToken();
}

class EmptyStatement extends Statement {
  final Token semicolonToken;

  EmptyStatement(this.semicolonToken);

  EmptyStatement asEmptyStatement() => this;

  accept(Visitor visitor) => visitor.visitEmptyStatement(this);

  visitChildren(Visitor visitor) {}

  Token getBeginToken() => semicolonToken;

  Token getEndToken() => semicolonToken;
}

class LiteralMap extends Expression {
  final NodeList typeArguments;
  final NodeList entries;

  final Token constKeyword;

  LiteralMap(this.typeArguments, this.entries, this.constKeyword);

  bool isConst() => constKeyword !== null;

  LiteralMap asLiteralMap() => this;

  accept(Visitor visitor) => visitor.visitLiteralMap(this);

  visitChildren(Visitor visitor) {
    if (typeArguments != null) typeArguments.accept(visitor);
    entries.accept(visitor);
  }

  Token getBeginToken() {
    if (constKeyword !== null) return constKeyword;
    return firstBeginToken(typeArguments, entries);
  }

  Token getEndToken() => entries.getEndToken();
}

class LiteralMapEntry extends Node {
  final Expression key;
  final Expression value;

  final Token colonToken;

  LiteralMapEntry(this.key, this.colonToken, this.value);

  LiteralMapEntry asLiteralMapEntry() => this;

  accept(Visitor visitor) => visitor.visitLiteralMapEntry(this);

  visitChildren(Visitor visitor) {
    key.accept(visitor);
    value.accept(visitor);
  }

  Token getBeginToken() => key.getBeginToken();

  Token getEndToken() => value.getEndToken();
}

class NamedArgument extends Expression {
  final Identifier name;
  final Expression expression;

  final Token colonToken;

  NamedArgument(this.name, this.colonToken, this.expression);

  NamedArgument asNamedArgument() => this;

  accept(Visitor visitor) => visitor.visitNamedArgument(this);

  visitChildren(Visitor visitor) {
    name.accept(visitor);
    expression.accept(visitor);
  }

  Token getBeginToken() => name.getBeginToken();

  Token getEndToken() => expression.getEndToken();
}

class SwitchStatement extends Statement {
  final ParenthesizedExpression parenthesizedExpression;
  final NodeList cases;

  final Token switchKeyword;

  SwitchStatement(this.parenthesizedExpression, this.cases,
                  this.switchKeyword);

  SwitchStatement asSwitchStatement() => this;

  Expression get expression() => parenthesizedExpression.expression;

  accept(Visitor visitor) => visitor.visitSwitchStatement(this);

  visitChildren(Visitor visitor) {
    parenthesizedExpression.accept(visitor);
    cases.accept(visitor);
  }

  Token getBeginToken() => switchKeyword;

  Token getEndToken() => cases.getEndToken();
}

class CaseMatch extends Node {
  final Token caseKeyword;
  final Expression expression;
  final Token colonToken;
  CaseMatch(this.caseKeyword, this.expression, this.colonToken);

  CaseMatch asCaseMatch() => this;
  Token getBeginToken() => caseKeyword;
  Token getEndToken() => colonToken;
  accept(Visitor visitor) => visitor.visitCaseMatch(this);
  visitChildren(Visitor visitor) => expression.accept(visitor);
}

class SwitchCase extends Node {
  // The labels and case patterns are collected in [labelsAndCases].
  // The default keyword, if present, is collected in [defaultKeyword].
  // Any actual switch case must have at least one 'case' or 'default'
  // clause.
  // Notice: The labels and cases can occur interleaved in the source.
  // They are separated here, since the order is irrelevant to the meaning
  // of the switch.

  /** List of [Label] and [CaseMatch] nodes. */
  final NodeList labelsAndCases;
  /** A "default" keyword token, if applicable. */
  final Token defaultKeyword;
  /** List of statements, the body of the case. */
  final NodeList statements;

  final Token startToken;

  SwitchCase(this.labelsAndCases, this.defaultKeyword,
             this.statements, this.startToken);

  SwitchCase asSwitchCase() => this;

  bool get isDefaultCase() => defaultKeyword !== null;

  bool isValidContinueTarget() => true;

  accept(Visitor visitor) => visitor.visitSwitchCase(this);

  visitChildren(Visitor visitor) {
    labelsAndCases.accept(visitor);
    statements.accept(visitor);
  }

  Token getBeginToken() {
    return startToken;
  }

  Token getEndToken() {
    if (statements.nodes.isEmpty()) {
      // All cases must have at least one expression or be the default.
      if (defaultKeyword !== null) {
        // The colon after 'default'.
        return defaultKeyword.next;
      }
      // The colon after the last expression.
      return labelsAndCases.getEndToken();
    } else {
      return statements.getEndToken();
    }
  }
}

class GotoStatement extends Statement {
  final Identifier target;
  final Token keywordToken;
  final Token semicolonToken;

  GotoStatement(this.target, this.keywordToken, this.semicolonToken);

  visitChildren(Visitor visitor) {
    if (target !== null) target.accept(visitor);
  }

  Token getBeginToken() => keywordToken;

  Token getEndToken() => semicolonToken;

  // TODO(ahe): make class abstract instead of adding an abstract method.
  abstract accept(Visitor visitor);
}

class BreakStatement extends GotoStatement {
  BreakStatement(Identifier target, Token keywordToken, Token semicolonToken)
    : super(target, keywordToken, semicolonToken);

  BreakStatement asBreakStatement() => this;

  accept(Visitor visitor) => visitor.visitBreakStatement(this);
}

class ContinueStatement extends GotoStatement {
  ContinueStatement(Identifier target, Token keywordToken, Token semicolonToken)
    : super(target, keywordToken, semicolonToken);

  ContinueStatement asContinueStatement() => this;

  accept(Visitor visitor) => visitor.visitContinueStatement(this);
}

class ForIn extends Loop {
  final Node declaredIdentifier;
  final Expression expression;

  final Token forToken;
  final Token inToken;

  ForIn(this.declaredIdentifier, this.expression,
        Statement body, this.forToken, this.inToken) : super(body);

  Expression get condition() => null;

  ForIn asForIn() => this;

  accept(Visitor visitor) => visitor.visitForIn(this);

  visitChildren(Visitor visitor) {
    declaredIdentifier.accept(visitor);
    expression.accept(visitor);
    body.accept(visitor);
  }

  Token getBeginToken() => forToken;

  Token getEndToken() => body.getEndToken();
}

class Label extends Node {
  final Identifier identifier;
  final Token colonToken;

  Label(this.identifier, this.colonToken);

  String slowToString() => identifier.source.slowToString();

  Label asLabel() => this;

  accept(Visitor visitor) => visitor.visitLabel(this);

  void visitChildren(Visitor visitor) {
    identifier.accept(visitor);
  }

  Token getBeginToken() => identifier.token;
  Token getEndToken() => colonToken;
}

class LabeledStatement extends Statement {
  final NodeList labels;
  final Statement statement;

  LabeledStatement(this.labels, this.statement);

  LabeledStatement asLabeledStatement() => this;

  accept(Visitor visitor) => visitor.visitLabeledStatement(this);

  visitChildren(Visitor visitor) {
    labels.accept(visitor);
    statement.accept(visitor);
  }

  Token getBeginToken() => labels.getBeginToken();

  Token getEndToken() => statement.getEndToken();

  bool isValidContinueTarget() => statement.isValidContinueTarget();

  Node getBody() => statement;
}

class ScriptTag extends Node {
  final Identifier tag;
  final StringNode argument;
  final Identifier prefixIdentifier;
  final StringNode prefix;

  final Token beginToken;
  final Token endToken;

  ScriptTag(this.tag, this.argument, this.prefixIdentifier, this.prefix,
            this.beginToken, this.endToken);

  bool isImport() => tag.source == const SourceString("import");
  bool isSource() => tag.source == const SourceString("source");
  bool isLibrary() => tag.source == const SourceString("library");
  bool isResource() => tag.source == const SourceString("resource");

  ScriptTag asScriptTag() => this;

  accept(Visitor visitor) => visitor.visitScriptTag(this);

  visitChildren(Visitor visitor) {
    tag.accept(visitor);
    argument.accept(visitor);
    if (prefixIdentifier !== null) prefixIdentifier.accept(visitor);
    if (prefix !== null) prefix.accept(visitor);
  }

  Token getBeginToken() => beginToken;

  Token getEndToken() => endToken;
}

class Typedef extends Node {
  final TypeAnnotation returnType;
  final Identifier name;
  final NodeList typeParameters;
  final NodeList formals;

  final Token typedefKeyword;
  final Token endToken;

  Typedef(this.returnType, this.name, this.typeParameters, this.formals,
          this.typedefKeyword, this.endToken);

  Typedef asTypedef() => this;

  accept(Visitor visitor) => visitor.visitTypedef(this);

  visitChildren(Visitor visitor) {
    if (returnType !== null) returnType.accept(visitor);
    name.accept(visitor);
    if (typeParameters !== null) typeParameters.accept(visitor);
    formals.accept(visitor);
  }

  Token getBeginToken() => typedefKeyword;

  Token getEndToken() => endToken;
}

class TryStatement extends Statement {
  final Block tryBlock;
  final NodeList catchBlocks;
  final Block finallyBlock;

  final Token tryKeyword;
  final Token finallyKeyword;

  TryStatement(this.tryBlock, this.catchBlocks, this.finallyBlock,
               this.tryKeyword, this.finallyKeyword);

  TryStatement asTryStatement() => this;

  accept(Visitor visitor) => visitor.visitTryStatement(this);

  visitChildren(Visitor visitor) {
    tryBlock.accept(visitor);
    catchBlocks.accept(visitor);
    if (finallyBlock !== null) finallyBlock.accept(visitor);
  }

  Token getBeginToken() => tryKeyword;

  Token getEndToken() {
    if (finallyBlock !== null) return finallyBlock.getEndToken();
    if (!catchBlocks.isEmpty()) return catchBlocks.getEndToken();
    return tryBlock.getEndToken();
  }
}

class Cascade extends Expression {
  final Expression expression;
  Cascade(this.expression);

  Cascade asCascade() => this;
  accept(Visitor visitor) => visitor.visitCascade(this);

  void visitChildren(Visitor visitor) {
    expression.accept(visitor);
  }

  Token getBeginToken() => expression.getBeginToken();

  Token getEndToken() => expression.getEndToken();
}

class CascadeReceiver extends Expression {
  final Expression expression;
  final Token cascadeOperator;
  CascadeReceiver(this.expression, this.cascadeOperator);

  CascadeReceiver asCascadeReceiver() => this;
  accept(Visitor visitor) => visitor.visitCascadeReceiver(this);

  void visitChildren(Visitor visitor) {
    expression.accept(visitor);
  }

  Token getBeginToken() => expression.getBeginToken();

  Token getEndToken() => expression.getEndToken();
}

class CatchBlock extends Node {
  final NodeList formals;
  final Block block;

  final catchKeyword;

  CatchBlock(this.formals, this.block, this.catchKeyword);

  CatchBlock asCatchBlock() => this;

  accept(Visitor visitor) => visitor.visitCatchBlock(this);

  Node get exception() {
    if (formals.nodes.isEmpty()) return null;
    VariableDefinitions declarations = formals.nodes.head;
    return declarations.definitions.nodes.head;
  }

  Node get trace() {
    if (formals.nodes.isEmpty()) return null;
    Link<Node> declarations = formals.nodes.tail;
    if (declarations.isEmpty()) return null;
    VariableDefinitions head = declarations.head;
    return head.definitions.nodes.head;
  }

  visitChildren(Visitor visitor) {
    formals.accept(visitor);
    block.accept(visitor);
  }

  Token getBeginToken() => catchKeyword;

  Token getEndToken() => block.getEndToken();
}

class Initializers {
  static bool isSuperConstructorCall(Send node) {
    return (node.receiver === null &&
            node.selector.asIdentifier() !== null &&
            node.selector.asIdentifier().isSuper()) ||
           (node.receiver !== null &&
            node.receiver.asIdentifier() !== null &&
            node.receiver.asIdentifier().isSuper() &&
            node.selector.asIdentifier() !== null);
  }

  static bool isConstructorRedirect(Send node) {
    return (node.receiver === null &&
            node.selector.asIdentifier() !== null &&
            node.selector.asIdentifier().isThis()) ||
           (node.receiver !== null &&
            node.receiver.asIdentifier() !== null &&
            node.receiver.asIdentifier().isThis() &&
            node.selector.asIdentifier() !== null);
  }
}

class GetDartStringVisitor extends AbstractVisitor<DartString> {
  const GetDartStringVisitor();
  DartString visitNode(Node node) => null;
  DartString visitStringJuxtaposition(StringJuxtaposition node)
      => node.dartString;
  DartString visitLiteralString(LiteralString node) => node.dartString;
}

class IsInterpolationVisitor extends AbstractVisitor<bool> {
  const IsInterpolationVisitor();
  bool visitNode(Node node) => false;
  bool visitStringInterpolation(StringInterpolation node) => true;
  bool visitStringJuxtaposition(StringJuxtaposition node)
      => node.isInterpolation;
}

/**
 * If the given node is a send set, it visits its initializer (first
 * argument).
 *
 * TODO(ahe): This method is controversial, the team needs to discuss
 * if top-level methods are acceptable and what naming conventions to
 * use.
 */
initializerDo(Node node, f(Node node)) {
  SendSet send = node.asSendSet();
  if (send !== null) return f(send.arguments.head);
}
