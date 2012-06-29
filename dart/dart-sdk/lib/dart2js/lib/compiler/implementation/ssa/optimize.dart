// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

interface OptimizationPhase {
  String get name();
  void visitGraph(HGraph graph);
}

class SsaOptimizerTask extends CompilerTask {
  final JavaScriptBackend backend;
  SsaOptimizerTask(JavaScriptBackend backend)
    : this.backend = backend,
      super(backend.compiler);
  String get name() => 'SSA optimizer';
  Compiler get compiler() => backend.compiler;

  void runPhases(HGraph graph, List<OptimizationPhase> phases) {
    for (OptimizationPhase phase in phases) {
      phase.visitGraph(graph);
      compiler.tracer.traceGraph(phase.name, graph);
    }
  }

  void optimize(WorkItem work, HGraph graph) {
    measure(() {
      List<OptimizationPhase> phases = <OptimizationPhase>[
          // Run trivial constant folding first to optimize
          // some patterns useful for type conversion.
          new SsaConstantFolder(backend, work),
          new SsaTypeConversionInserter(compiler),
          new SsaTypePropagator(compiler),
          new SsaCheckInserter(backend),
          new SsaConstantFolder(backend, work),
          new SsaRedundantPhiEliminator(),
          new SsaDeadPhiEliminator(),
          new SsaGlobalValueNumberer(compiler),
          new SsaCodeMotion(),
          new SsaDeadCodeEliminator(),
          new SsaProcessRecompileCandidates(backend, work)];
      runPhases(graph, phases);
    });
  }

  bool trySpeculativeOptimizations(WorkItem work, HGraph graph) {
    return measure(() {
      // Run the phases that will generate type guards.
      List<OptimizationPhase> phases = <OptimizationPhase>[
          new SsaSpeculativeTypePropagator(compiler),
          new SsaTypeGuardInserter(compiler, work),
          new SsaEnvironmentBuilder(compiler),
          // Change the propagated types back to what they were before we
          // speculatively propagated, so that we can generate the bailout
          // version.
          // Note that we do this even if there were no guards inserted. If a
          // guard is not beneficial enough we don't emit one, but there might
          // still be speculative types on the instructions.
          new SsaTypePropagator(compiler),
          // Then run the [SsaCheckInserter] because the type propagator also
          // propagated types non-speculatively. For example, it might have
          // propagated the type array for a call to the List constructor.
          new SsaCheckInserter(backend)];
      runPhases(graph, phases);
      return !work.guards.isEmpty();
    });
  }

  void prepareForSpeculativeOptimizations(WorkItem work, HGraph graph) {
    measure(() {
      // In order to generate correct code for the bailout version, we did not
      // propagate types from the instruction to the type guard. We do it
      // now to be able to optimize further.
      work.guards.forEach((HTypeGuard guard) { guard.isOn = true; });
      // We also need to insert range and integer checks for the type
      // guards. Now that they claim to have a certain type, some
      // depending instructions might become builtin (like native array
      // accesses) and need to be checked.
      // Also run the type propagator, to please the codegen in case
      // no other optimization is run.
      runPhases(graph,
        <OptimizationPhase>[new SsaCheckInserter(backend),
                            new SsaTypePropagator(compiler)]);
    });
  }
}

/**
 * If both inputs to known operations are available execute the operation at
 * compile-time.
 */
class SsaConstantFolder extends HBaseVisitor implements OptimizationPhase {
  final String name = "SsaConstantFolder";
  final JavaScriptBackend backend;
  final WorkItem work;
  HGraph graph;
  Compiler get compiler() => backend.compiler;

  SsaConstantFolder(this.backend, this.work);

  void visitGraph(HGraph visitee) {
    graph = visitee;
    visitDominatorTree(visitee);
  }

  visitBasicBlock(HBasicBlock block) {
    HInstruction instruction = block.first;
    while (instruction !== null) {
      HInstruction next = instruction.next;
      HInstruction replacement = instruction.accept(this);
      if (replacement !== instruction) {
        if (!replacement.isInBasicBlock()) {
          // The constant folding can return an instruction that is already
          // part of the graph (like an input), so we only add the replacement
          // if necessary.
          block.addAfter(instruction, replacement);
        }
        block.rewrite(instruction, replacement);
        block.remove(instruction);
        // If the replacement instruction does not know its type or
        // source element yet, use the type and source element of the
        // instruction.
        if (!replacement.propagatedType.isUseful()) {
          replacement.propagatedType = instruction.propagatedType;
        }
        if (replacement.sourceElement === null) {
          replacement.sourceElement = instruction.sourceElement;
        }
      }
      instruction = next;
    }
  }

  HInstruction visitInstruction(HInstruction node) {
    return node;
  }

  HInstruction visitBoolify(HBoolify node) {
    List<HInstruction> inputs = node.inputs;
    assert(inputs.length == 1);
    HInstruction input = inputs[0];
    if (input.isBoolean()) return input;
    // All values !== true are boolified to false.
    Type type = input.propagatedType.computeType(compiler);
    if (type !== null && type.element !== compiler.boolClass) {
      return graph.addConstantBool(false);
    }
    return node;
  }

  HInstruction visitNot(HNot node) {
    List<HInstruction> inputs = node.inputs;
    assert(inputs.length == 1);
    HInstruction input = inputs[0];
    if (input is HConstant) {
      HConstant constant = input;
      bool isTrue = constant.constant.isTrue();
      return graph.addConstantBool(!isTrue);
    } else if (input is HNot) {
      return input.inputs[0];
    }
    return node;
  }

  HInstruction visitInvokeUnary(HInvokeUnary node) {
    HInstruction operand = node.operand;
    if (operand is HConstant) {
      UnaryOperation operation = node.operation;
      HConstant receiver = operand;
      Constant folded = operation.fold(receiver.constant);
      if (folded !== null) return graph.addConstant(folded);
    }
    return node;
  }

  HInstruction visitInvokeInterceptor(HInvokeInterceptor node) {
    HInstruction input = node.inputs[1];
    if (node.isLengthGetter()) {
      if (input.isConstantString()) {
        HConstant constantInput = input;
        StringConstant constant = constantInput.constant;
        return graph.addConstantInt(constant.length);
      } else if (input.isConstantList()) {
        HConstant constantInput = input;
        ListConstant constant = constantInput.constant;
        return graph.addConstantInt(constant.length);
      } else if (input.isConstantMap()) {
        HConstant constantInput = input;
        MapConstant constant = constantInput.constant;
        return graph.addConstantInt(constant.length);
      }
    }

    if (input.isString()
        && node.name == const SourceString('toString')) {
      return node.inputs[1];
    }

    if (!input.canBePrimitive() && !node.getter && !node.setter) {
      return fromInterceptorToDynamicInvocation(node, node.name);
    }

    return node;
  }

  HInstruction visitInvokeDynamic(HInvokeDynamic node) {
    HType receiverType = node.receiver.propagatedType;
    if (receiverType.isExact()) {
      HBoundedType type = receiverType;
      Element element = type.lookupMember(node.name);
      // TODO(ngeoffray): Also fold if it's a getter or variable.
      if (element != null && element.isFunction()) {
        if (node.selector.applies(element, compiler)) {
          FunctionElement method = element;
          FunctionSignature parameters = method.computeSignature(compiler);
          if (parameters.optionalParameterCount == 0) {
            node.element = element;
          }
          // TODO(ngeoffray): If the method has optional parameters,
          // we should pass the default values here.
        }
      }
    }
    return node;
  }

  HInstruction fromInterceptorToDynamicInvocation(
      HInvokeStatic node, SourceString methodName) {
    HBoundedType type = node.inputs[1].propagatedType;
    HInvokeDynamicMethod result = new HInvokeDynamicMethod(
        node.selector,
        methodName,
        node.inputs.getRange(1, node.inputs.length - 1));
    if (type.isExact()) {
      HBoundedType concrete = type;
      result.element = concrete.lookupMember(methodName);
    }
    return result;
  }

  HInstruction visitBoundsCheck(HBoundsCheck node) {
    int tryGetIntConstantValue(HInstruction instruction, String errorMessage) {
      // Tests whether an [HInstruction] is a constant.
      // If it is a constant, and not an int constant, it fails.
      // If it's an int constant it returns the value.
      // Otherwise it's not a constant, and this function returns null.
      if (!instruction.isConstant()) return null;
      HConstant constantInstruction = instruction;
      Constant constant = constantInstruction.constant;
      if (!constant.isInt()) {
        compiler.internalError(errorMessage, instruction: instruction);
      }
      IntConstant intConstant = constant;
      return intConstant.value;
    }
    int index = tryGetIntConstantValue(node.index,
                                       'String or List index not a number');
    if (index !== null) {
      if (index < 0) {
        node.staticChecks = HBoundsCheck.ALWAYS_FALSE;
        return node;
      }
      int length = tryGetIntConstantValue(node.length,
                                          'String or List length not a number');
      if (length !== null) {
        if (index >= length) {
          node.staticChecks = HBoundsCheck.ALWAYS_FALSE;
        } else {
          // Could have set the staticChecks to ALWAYS_TRUE instead.
          return node.index;
        }
        return node;
      }
      node.staticChecks = HBoundsCheck.ALWAYS_ABOVE_ZERO;
    }
    return node;
  }

  HInstruction visitIntegerCheck(HIntegerCheck node) {
    HInstruction value = node.value;
    if (value.isInteger()) return value;
    if (value.isConstant()) {
      assert((){
        HConstant constantInstruction = value;
        return !constantInstruction.constant.isInt();
      });
      node.alwaysFalse = true;
    }
    return node;
  }


  HInstruction visitIndex(HIndex node) {
    if (!node.receiver.canBePrimitive()) {
      SourceString methodName = Elements.constructOperatorName(
          const SourceString('operator'), const SourceString('[]'));
      return fromInterceptorToDynamicInvocation(node, methodName);
    }
    return node;
  }

  HInstruction visitIndexAssign(HIndexAssign node) {
    if (!node.receiver.canBePrimitive()) {
      SourceString methodName = Elements.constructOperatorName(
          const SourceString('operator'), const SourceString('[]='));
      return fromInterceptorToDynamicInvocation(node, methodName);
    }
    return node;
  }

  HInstruction visitInvokeBinary(HInvokeBinary node) {
    HInstruction left = node.left;
    HInstruction right = node.right;
    if (left is HConstant && right is HConstant) {
      BinaryOperation operation = node.operation;
      HConstant op1 = left;
      HConstant op2 = right;
      Constant folded = operation.fold(op1.constant, op2.constant);
      if (folded !== null) return graph.addConstant(folded);
    }

    if (!left.canBePrimitive()
        && node.operation.isUserDefinable()
        // The equals operation is being optimized in visitEquals.
        && node.operation !== const EqualsOperation()) {
      SourceString methodName = Elements.constructOperatorName(
          const SourceString('operator'), node.operation.name);
      return fromInterceptorToDynamicInvocation(node, methodName);
    }
    return node;
  }

  bool allUsersAreBoolifies(HInstruction instruction) {
    List<HInstruction> users = instruction.usedBy;
    int length = users.length;
    for (int i = 0; i < length; i++) {
      if (users[i] is! HBoolify) return false;
    }
    return true;
  }

  HInstruction visitRelational(HRelational node) {
    if (allUsersAreBoolifies(node)) {
      Interceptors interceptors = backend.builder.interceptors;
      HStatic oldTarget = node.target;
      Element boolifiedInterceptor =
          interceptors.getBoolifiedVersionOf(oldTarget.element);
      if (boolifiedInterceptor !== null) {
        HStatic boolifiedTarget = new HStatic(boolifiedInterceptor);
        // We don't remove the [oldTarget] in case it is used by other
        // instructions. If it is unused it will be treated as dead code and
        // discarded.
        oldTarget.block.addAfter(oldTarget, boolifiedTarget);
        // Remove us as user from the [oldTarget].
        oldTarget.removeUser(node);
        // Replace old target with boolified target.
        assert(node.target == node.inputs[0]);
        node.inputs[0] = boolifiedTarget;
        boolifiedTarget.usedBy.add(node);
        node.usesBoolifiedInterceptor = true;
        node.propagatedType = HType.BOOLEAN;
      }
      // This node stays the same, but the Boolify node will go away.
    }
    // Note that we still have to call [super] to make sure that we end up
    // in the remaining optimizations.
    return super.visitRelational(node);
  }

  HInstruction handleIdentityCheck(HInvokeBinary node) {
    HInstruction left = node.left;
    HInstruction right = node.right;
    HType leftType = left.propagatedType;
    HType rightType = right.propagatedType;
    assert(!leftType.isConflicting() && !rightType.isConflicting());

    // We don't optimize on numbers to preserve the runtime semantics.
    if (!(left.isNumber() && right.isNumber()) &&
        leftType.intersection(rightType).isConflicting()) {
      return graph.addConstantBool(false);
    }

    if (left.isConstantBoolean() && right.isBoolean()) {
      HConstant constant = left;
      if (constant.constant.isTrue()) {
        return right;
      } else {
        return new HNot(right);
      }
    }

    if (right.isConstantBoolean() && left.isBoolean()) {
      HConstant constant = right;
      if (constant.constant.isTrue()) {
        return left;
      } else {
        return new HNot(left);
      }
    }

    return null;
  }

  HInstruction visitIdentity(HIdentity node) {
    HInstruction newInstruction = handleIdentityCheck(node);
    return newInstruction === null ? super.visitIdentity(node) : newInstruction;
  }

  HInstruction foldBuiltinEqualsCheck(HEquals node) {
    // TODO(floitsch): cache interceptors.
    HInstruction newInstruction = handleIdentityCheck(node);
    if (newInstruction === null) {
      HStatic target = new HStatic(
          backend.builder.interceptors.getTripleEqualsInterceptor());
      node.block.addBefore(node, target);
      return new HIdentity(target, node.left, node.right);
    } else {
      return newInstruction;
    }
  }

  HInstruction visitEquals(HEquals node) {
    HInstruction left = node.left;
    HInstruction right = node.right;

    if (node.builtin) {
      return foldBuiltinEqualsCheck(node);
    }

    if (left.isConstant() && right.isConstant()) {
      return super.visitEquals(node);
    }

    if (left.propagatedType.isExact()) {
      HBoundedType type = left.propagatedType;
      Element element = type.lookupMember(Namer.OPERATOR_EQUALS);
      if (element !== null) {
        // If the left-hand side is guaranteed to be a non-primitive
        // type and and it defines operator==, we emit a call to that
        // operator.
        return super.visitEquals(node);
      } else if (right.isConstantNull()) {
        return graph.addConstantBool(false);
      } else {
        // We can just emit an identity check because the type does
        // not implement operator=.
        return foldBuiltinEqualsCheck(node);
      }
    }

    if (right.isConstantNull()) {
      if (left.propagatedType.isPrimitive()) {
        return graph.addConstantBool(false);
      } else {
        // TODO(floitsch): cache interceptors.
        Interceptors interceptors = backend.builder.interceptors;
        Element equalsElement = interceptors.getEqualsInterceptor();
        // If we have a different element than [equalsElement], we
        // don't need to optimize this instruction to use another
        // element: we know the element is either eqNull or eqNullB.
        if (node.element === equalsElement) {
          Element targetElement = interceptors.getEqualsNullInterceptor();
          bool onlyUsedInBoolify = allUsersAreBoolifies(node);
          if (onlyUsedInBoolify) {
            targetElement = interceptors.getBoolifiedVersionOf(targetElement);
          }
          HStatic target = new HStatic(targetElement);
          node.block.addBefore(node, target);
          HEquals result = new HEquals(target, node.left, node.right);
          if (onlyUsedInBoolify) {
            result.usesBoolifiedInterceptor = true;
            result.propagatedType = HType.BOOLEAN;
          }
          return result;
        }
      }
    }

    // All other cases are dealt with by the [visitRelational] and
    // [visitInvokeBinary], which are visited by invoking the [super]'s
    // visit method.
    return super.visitEquals(node);
  }

  HInstruction visitTypeGuard(HTypeGuard node) {
    HInstruction value = node.guarded;
    // If the intersection of the types is still the incoming type then
    // the incoming type was a subtype of the guarded type, and no check
    // is required.
    HType combinedType = value.propagatedType.intersection(node.guardedType);
    return (combinedType == value.propagatedType) ? value : node;
  }

  HInstruction visitIs(HIs node) {
    Type type = node.typeExpression;
    Element element = type.element;
    if (element.kind === ElementKind.TYPE_VARIABLE) {
      compiler.unimplemented("visitIs for type variables");
    }

    HType expressionType = node.expression.propagatedType;
    if (element === compiler.objectClass
        || element === compiler.dynamicClass) {
      return graph.addConstantBool(true);
    } else if (expressionType.isInteger()) {
      if (element === compiler.intClass || element === compiler.numClass) {
        return graph.addConstantBool(true);
      } else if (element === compiler.doubleClass) {
        // We let the JS semantics decide for that check. Currently
        // the code we emit will always return true.
        return node;
      } else {
        return graph.addConstantBool(false);
      }
    } else if (expressionType.isDouble()) {
      if (element === compiler.doubleClass || element === compiler.numClass) {
        return graph.addConstantBool(true);
      } else if (element === compiler.intClass) {
        // We let the JS semantics decide for that check. Currently
        // the code we emit will return true for a double that can be
        // represented as a 31-bit integer.
        return node;
      } else {
        return graph.addConstantBool(false);
      }
    } else if (expressionType.isNumber()) {
      if (element === compiler.numClass) {
        return graph.addConstantBool(true);
      }
      // We cannot just return false, because the expression may be of
      // type int or double.
    } else if (expressionType.isString()) {
      if (element === compiler.stringClass
               || Elements.isStringSupertype(element, compiler)) {
        return graph.addConstantBool(true);
      } else {
        return graph.addConstantBool(false);
      }
    } else if (expressionType.isArray()) {
      if (element === compiler.listClass
          || Elements.isListSupertype(element, compiler)) {
        return graph.addConstantBool(true);
      } else {
        return graph.addConstantBool(false);
      }
    // TODO(karlklose): remove the hasTypeArguments check.
    } else if (expressionType.isUseful()
               && !expressionType.canBeNull()
               && !compiler.codegenWorld.rti.hasTypeArguments(type)) {
      Type receiverType = expressionType.computeType(compiler);
      if (receiverType !== null) {
        if (compiler.types.isSubtype(receiverType, type)) {
          return graph.addConstantBool(true);
        } else if (expressionType.isExact()) {
          return graph.addConstantBool(false);
        }
      }
    }
    return node;
  }

  HInstruction visitTypeConversion(HTypeConversion node) {
    HInstruction value = node.inputs[0];
    Type type = node.propagatedType.computeType(compiler);
    if (type.element === compiler.dynamicClass
        || type.element === compiler.objectClass) {
      return value;
    }
    HType combinedType = value.propagatedType.intersection(node.propagatedType);
    return (combinedType == value.propagatedType) ? value : node;
  }

  HInstruction visitInvokeDynamicGetter(HInvokeDynamicGetter node) {
    HInstruction receiver = node.inputs[0];
    if (!receiver.propagatedType.isUseful()) return node;
    if (receiver.propagatedType.canBeNull()) return node;
    Type type = receiver.propagatedType.computeType(compiler);
    if (type === null) return node;
    Element field = compiler.world.locateSingleField(type, node.name);
    if (field === null) return node;
    Modifiers modifiers = field.modifiers;
    bool isFinalOrConst = false;
    if (modifiers != null) {
      isFinalOrConst = modifiers.isFinal() || modifiers.isConst();
    }
    if (!compiler.resolverWorld.hasInvokedSetter(field, compiler)) {
      // If no setter is ever used for this field it is only initialized in the
      // initializer list.
      isFinalOrConst = true;
    }
    if (!isFinalOrConst &&
        !compiler.codegenWorld.hasInvokedSetter(field, compiler) &&
        !compiler.codegenWorld.hasFieldSetter(field, compiler)) {
      switch (compiler.phase) {
        case Compiler.PHASE_COMPILING:
          compiler.enqueuer.codegen.registerRecompilationCandidate(
              work.element);
          break;
        case Compiler.PHASE_RECOMPILING:
          // If field is not final or const but no setters are used then the
          // field might be considered final anyway as it will be either
          // un-initialized or initialized in the constructor initializer list.
          isFinalOrConst = true;
          break;
      }
    }
    return new HFieldGet(field, node.inputs[0], isFinalOrConst: isFinalOrConst);
  }

  HInstruction visitInvokeDynamicSetter(HInvokeDynamicSetter node) {
    HInstruction receiver = node.inputs[0];
    if (!receiver.propagatedType.isUseful()) return node;
    if (receiver.propagatedType.canBeNull()) return node;
    Type type = receiver.propagatedType.computeType(compiler);
    if (type === null) return node;
    Element field = compiler.world.locateSingleField(type, node.name);
    if (field === null) return node;
    return new HFieldSet(field, node.inputs[0], node.inputs[1]);
  }

  HInstruction visitStringConcat(HStringConcat node) {
    DartString folded = const LiteralDartString("");
    for (int i = 0; i < node.inputs.length; i++) {
      HInstruction part = node.inputs[i];
      if (!part.isConstant()) return node;
      HConstant constant = part;
      if (!constant.constant.isPrimitive()) return node;
      PrimitiveConstant primitive = constant.constant;
      folded = new DartString.concat(folded, primitive.toDartString());
    }
    return graph.addConstantString(folded, node.node);
  }
}

class SsaCheckInserter extends HBaseVisitor implements OptimizationPhase {
  final String name = "SsaCheckInserter";
  Element lengthInterceptor;

  SsaCheckInserter(JavaScriptBackend backend) {
    SourceString lengthString = const SourceString('length');
    lengthInterceptor =
        backend.builder.interceptors.getStaticGetInterceptor(lengthString);
  }

  void visitGraph(HGraph graph) {
    visitDominatorTree(graph);
  }

  void visitBasicBlock(HBasicBlock block) {
    HInstruction instruction = block.first;
    while (instruction !== null) {
      HInstruction next = instruction.next;
      instruction = instruction.accept(this);
      instruction = next;
    }
  }

  HBoundsCheck insertBoundsCheck(HInstruction node,
                                 HInstruction receiver,
                                 HInstruction index) {
    HStatic interceptor = new HStatic(lengthInterceptor);
    node.block.addBefore(node, interceptor);
    HInvokeInterceptor length = new HInvokeInterceptor(
        Selector.INVOCATION_0,
        const SourceString("length"),
        <HInstruction>[interceptor, receiver],
        getter: true);
    length.propagatedType = HType.INTEGER;
    node.block.addBefore(node, length);

    HBoundsCheck check = new HBoundsCheck(index, length);
    node.block.addBefore(node, check);
    return check;
  }

  HIntegerCheck insertIntegerCheck(HInstruction node, HInstruction value) {
    HIntegerCheck check = new HIntegerCheck(value);
    node.block.addBefore(node, check);
    return check;
  }

  void visitIndex(HIndex node) {
    if (!node.receiver.isIndexablePrimitive()) return;
    HInstruction index = node.index;
    if (index is HBoundsCheck) return;
    if (!node.index.isInteger()) {
      index = insertIntegerCheck(node, index);
    }
    index = insertBoundsCheck(node, node.receiver, index);
    HIndex newInstruction = new HIndex(node.target, node.receiver, index);
    node.block.addBefore(node, newInstruction);
    node.block.rewrite(node, newInstruction);
    node.block.remove(node);
  }

  void visitIndexAssign(HIndexAssign node) {
    if (!node.receiver.isMutableArray()) return;
    HInstruction index = node.index;
    if (index is HBoundsCheck) return;
    if (!node.index.isInteger()) {
      index = insertIntegerCheck(node, index);
    }
    index = insertBoundsCheck(node, node.receiver, index);
    HIndexAssign newInstruction =
        new HIndexAssign(node.target, node.receiver, index, node.value);
    node.block.addBefore(node, newInstruction);
    node.block.rewrite(node, newInstruction);
    node.block.remove(node);
  }
}

class SsaDeadCodeEliminator extends HGraphVisitor implements OptimizationPhase {
  final String name = "SsaDeadCodeEliminator";

  static bool isDeadCode(HInstruction instruction) {
    return !instruction.hasSideEffects()
           && instruction.usedBy.isEmpty()
           && instruction is !HCheck
           && instruction is !HTypeGuard
           && !instruction.isControlFlow();
  }

  void visitGraph(HGraph graph) {
    visitPostDominatorTree(graph);
  }

  void visitBasicBlock(HBasicBlock block) {
    HInstruction instruction = block.last;
    while (instruction !== null) {
      var previous = instruction.previous;
      if (isDeadCode(instruction)) block.remove(instruction);
      instruction = previous;
    }
  }
}

class SsaDeadPhiEliminator implements OptimizationPhase {
  final String name = "SsaDeadPhiEliminator";

  void visitGraph(HGraph graph) {
    final List<HPhi> worklist = <HPhi>[];
    // A set to keep track of the live phis that we found.
    final Set<HPhi> livePhis = new Set<HPhi>();

    // Add to the worklist all live phis: phis referenced by non-phi
    // instructions.
    for (final block in graph.blocks) {
      block.forEachPhi((HPhi phi) {
        for (final user in phi.usedBy) {
          if (user is !HPhi) {
            worklist.add(phi);
            livePhis.add(phi);
            break;
          }
        }
      });
    }

    // Process the worklist by propagating liveness to phi inputs.
    while (!worklist.isEmpty()) {
      HPhi phi = worklist.removeLast();
      for (final input in phi.inputs) {
        if (input is HPhi && !livePhis.contains(input)) {
          worklist.add(input);
          livePhis.add(input);
        }
      }
    }

    // Remove phis that are not live.
    // Traverse in reverse order to remove phis with no uses before the
    // phis that they might use.
    // NOTICE: Doesn't handle circular references, but we don't currently
    // create any.
    List<HBasicBlock> blocks = graph.blocks;
    for (int i = blocks.length - 1; i >= 0; i--) {
      HBasicBlock block = blocks[i];
      HPhi current = block.phis.first;
      HPhi next = null;
      while (current != null) {
        next = current.next;
        if (!livePhis.contains(current)
            // TODO(ahe): Not sure the following is correct.
            && current.usedBy.isEmpty()) {
          block.removePhi(current);
        }
        current = next;
      }
    }
  }
}

class SsaRedundantPhiEliminator implements OptimizationPhase {
  final String name = "SsaRedundantPhiEliminator";

  void visitGraph(HGraph graph) {
    final List<HPhi> worklist = <HPhi>[];

    // Add all phis in the worklist.
    for (final block in graph.blocks) {
      block.forEachPhi((HPhi phi) => worklist.add(phi));
    }

    while (!worklist.isEmpty()) {
      HPhi phi = worklist.removeLast();

      // If the phi has already been processed, continue.
      if (!phi.isInBasicBlock()) continue;

      // Find if the inputs of the phi are the same instruction.
      // The builder ensures that phi.inputs[0] cannot be the phi
      // itself.
      assert(phi.inputs[0] !== phi);
      HInstruction candidate = phi.inputs[0];
      for (int i = 1; i < phi.inputs.length; i++) {
        HInstruction input = phi.inputs[i];
        // If the input is the phi, the phi is still candidate for
        // elimination.
        if (input !== candidate && input !== phi) {
          candidate = null;
          break;
        }
      }

      // If the inputs are not the same, continue.
      if (candidate == null) continue;

      // Because we're updating the users of this phi, we may have new
      // phis candidate for elimination. Add phis that used this phi
      // to the worklist.
      for (final user in phi.usedBy) {
        if (user is HPhi) worklist.add(user);
      }
      phi.block.rewrite(phi, candidate);
      phi.block.removePhi(phi);
    }
  }
}

class SsaGlobalValueNumberer implements OptimizationPhase {
  final String name = "SsaGlobalValueNumberer";
  final Compiler compiler;
  final Set<int> visited;

  List<int> blockChangesFlags;
  List<int> loopChangesFlags;

  SsaGlobalValueNumberer(this.compiler) : visited = new Set<int>();

  void visitGraph(HGraph graph) {
    computeChangesFlags(graph);
    moveLoopInvariantCode(graph);
    visitBasicBlock(graph.entry, new ValueSet());
  }

  void moveLoopInvariantCode(HGraph graph) {
    for (int i = graph.blocks.length - 1; i >= 0; i--) {
      HBasicBlock block = graph.blocks[i];
      if (block.isLoopHeader()) {
        int changesFlags = loopChangesFlags[block.id];
        HLoopInformation info = block.loopInformation;
        HBasicBlock last = info.getLastBackEdge();
        for (int j = block.id; j <= last.id; j++) {
          moveLoopInvariantCodeFromBlock(graph.blocks[j], block, changesFlags);
        }
      }
    }
  }

  void moveLoopInvariantCodeFromBlock(HBasicBlock block,
                                      HBasicBlock loopHeader,
                                      int changesFlags) {
    HBasicBlock preheader = loopHeader.predecessors[0];
    int dependsFlags = HInstruction.computeDependsOnFlags(changesFlags);
    HInstruction instruction = block.first;
    while (instruction != null) {
      HInstruction next = instruction.next;
      if (instruction.useGvn()
          && (instruction is !HCheck)
          && (instruction.flags & dependsFlags) == 0) {
        bool loopInvariantInputs = true;
        List<HInstruction> inputs = instruction.inputs;
        for (int i = 0, length = inputs.length; i < length; i++) {
          if (isInputDefinedAfterDominator(inputs[i], preheader)) {
            loopInvariantInputs = false;
            break;
          }
        }

        // If the inputs are loop invariant, we can move the
        // instruction from the current block to the pre-header block.
        if (loopInvariantInputs) {
          block.detach(instruction);
          preheader.moveAtExit(instruction);
        }
      }
      instruction = next;
    }
  }

  bool isInputDefinedAfterDominator(HInstruction input,
                                    HBasicBlock dominator) {
    return input.block.id > dominator.id;
  }

  void visitBasicBlock(HBasicBlock block, ValueSet values) {
    HInstruction instruction = block.first;
    if (block.isLoopHeader()) {
      int flags = loopChangesFlags[block.id];
      values.kill(flags);
    }
    while (instruction !== null) {
      HInstruction next = instruction.next;
      int flags = instruction.getChangesFlags();
      assert(flags == 0 || !instruction.useGvn());
      values.kill(flags);
      if (instruction.useGvn()) {
        HInstruction other = values.lookup(instruction);
        if (other !== null) {
          assert(other.gvnEquals(instruction) && instruction.gvnEquals(other));
          block.rewrite(instruction, other);
          block.remove(instruction);
        } else {
          values.add(instruction);
        }
      }
      instruction = next;
    }

    List<HBasicBlock> dominatedBlocks = block.dominatedBlocks;
    for (int i = 0, length = dominatedBlocks.length; i < length; i++) {
      HBasicBlock dominated = dominatedBlocks[i];
      // No need to copy the value set for the last child.
      ValueSet successorValues = (i == length - 1) ? values : values.copy();
      // If we have no values in our set, we do not have to kill
      // anything. Also, if the range of block ids from the current
      // block to the dominated block is empty, there is no blocks on
      // any path from the current block to the dominated block so we
      // don't have to do anything either.
      assert(block.id < dominated.id);
      if (!successorValues.isEmpty() && block.id + 1 < dominated.id) {
        visited.clear();
        int changesFlags = getChangesFlagsForDominatedBlock(block, dominated);
        successorValues.kill(changesFlags);
      }
      visitBasicBlock(dominated, successorValues);
    }
  }

  void computeChangesFlags(HGraph graph) {
    // Create the changes flags lists. Make sure to initialize the
    // loop changes flags list to zero so we can use bitwise or when
    // propagating loop changes upwards.
    final int length = graph.blocks.length;
    blockChangesFlags = new List<int>(length);
    loopChangesFlags = new List<int>(length);
    for (int i = 0; i < length; i++) loopChangesFlags[i] = 0;

    // Run through all the basic blocks in the graph and fill in the
    // changes flags lists.
    for (int i = length - 1; i >= 0; i--) {
      final HBasicBlock block = graph.blocks[i];
      final int id = block.id;

      // Compute block changes flags for the block.
      int changesFlags = 0;
      HInstruction instruction = block.first;
      while (instruction !== null) {
        instruction.prepareGvn();
        changesFlags |= instruction.getChangesFlags();
        instruction = instruction.next;
      }
      assert(blockChangesFlags[id] === null);
      blockChangesFlags[id] = changesFlags;

      // Loop headers are part of their loop, so update the loop
      // changes flags accordingly.
      if (block.isLoopHeader()) {
        loopChangesFlags[id] |= changesFlags;
      }

      // Propagate loop changes flags upwards.
      HBasicBlock parentLoopHeader = block.parentLoopHeader;
      if (parentLoopHeader !== null) {
        loopChangesFlags[parentLoopHeader.id] |= (block.isLoopHeader())
            ? loopChangesFlags[id]
            : changesFlags;
      }
    }
  }

  int getChangesFlagsForDominatedBlock(HBasicBlock dominator,
                                       HBasicBlock dominated) {
    int changesFlags = 0;
    List<HBasicBlock> predecessors = dominated.predecessors;
    for (int i = 0, length = predecessors.length; i < length; i++) {
      HBasicBlock block = predecessors[i];
      int id = block.id;
      // If the current predecessor block is on the path from the
      // dominator to the dominated, it must have an id that is in the
      // range from the dominator to the dominated.
      if (dominator.id < id && id < dominated.id && !visited.contains(id)) {
        visited.add(id);
        changesFlags |= blockChangesFlags[id];
        changesFlags |= getChangesFlagsForDominatedBlock(dominator, block);
      }
    }
    return changesFlags;
  }
}

// This phase merges equivalent instructions on different paths into
// one instruction in a dominator block. It runs through the graph
// post dominator order and computes a ValueSet for each block of
// instructions that can be moved to a dominator block. These
// instructions are the ones that:
// 1) can be used for GVN, and
// 2) do not use definitions of their own block.
//
// A basic block looks at its sucessors and finds the intersection of
// these computed ValueSet. It moves all instructions of the
// intersection into its own list of instructions.
class SsaCodeMotion extends HBaseVisitor implements OptimizationPhase {
  final String name = "SsaCodeMotion";

  List<ValueSet> values;

  void visitGraph(HGraph graph) {
    values = new List<ValueSet>(graph.blocks.length);
    for (int i = 0; i < graph.blocks.length; i++) {
      values[graph.blocks[i].id] = new ValueSet();
    }
    visitPostDominatorTree(graph);
  }

  void visitBasicBlock(HBasicBlock block) {
    List<HBasicBlock> successors = block.successors;

    // Phase 1: get the ValueSet of all successors (if there are more than one),
    // compute the intersection and move the instructions of the intersection
    // into this block.
    if (successors.length > 1) {
      ValueSet instructions = values[successors[0].id];
      for (int i = 1; i < successors.length; i++) {
        ValueSet other = values[successors[i].id];
        instructions = instructions.intersection(other);
      }

      if (!instructions.isEmpty()) {
        List<HInstruction> list = instructions.toList();
        for (HInstruction instruction in list) {
          // Move the instruction to the current block.
          instruction.block.detach(instruction);
          block.moveAtExit(instruction);
          // Go through all successors and rewrite their instruction
          // to the shared one.
          for (final successor in successors) {
            HInstruction toRewrite = values[successor.id].lookup(instruction);
            if (toRewrite != instruction) {
              successor.rewrite(toRewrite, instruction);
              successor.remove(toRewrite);
            }
          }
        }
      }
    }

    // Don't try to merge instructions to a dominator if we have
    // multiple predecessors.
    if (block.predecessors.length != 1) return;

    // Phase 2: Go through all instructions of this block and find
    // which instructions can be moved to a dominator block.
    ValueSet set_ = values[block.id];
    HInstruction instruction = block.first;
    int flags = 0;
    while (instruction !== null) {
      int dependsFlags = HInstruction.computeDependsOnFlags(flags);
      flags |= instruction.getChangesFlags();

      HInstruction current = instruction;
      instruction = instruction.next;

      // TODO(ngeoffray): this check is needed because we currently do
      // not have flags to express 'Gvn'able', but not movable.
      if (current is HCheck) continue;
      if (!current.useGvn()) continue;
      if ((current.flags & dependsFlags) != 0) continue;

      bool canBeMoved = true;
      for (final HInstruction input in current.inputs) {
        if (input.block == block) {
          canBeMoved = false;
          break;
        }
      }
      if (!canBeMoved) continue;

      // This is safe because we are running after GVN.
      // TODO(ngeoffray): ensure GVN has been run.
      set_.add(current);
    }
  }
}

class SsaTypeConversionInserter extends HBaseVisitor
    implements OptimizationPhase {
  final String name = "SsaTypeconversionInserter";
  final Compiler compiler;

  SsaTypeConversionInserter(this.compiler);

  void visitGraph(HGraph graph) {
    visitDominatorTree(graph);
  }

  void changeUsesDominatedBy(HBasicBlock dominator,
                             HInstruction input,
                             HType convertedType) {
    HTypeConversion newInput;

    // Update users of [input] that are dominated by [dominator] to
    // use [newInput] instead.
    for (HInstruction user in input.usedBy) {
      if (dominator.dominates(user.block)) {
        if (newInput === null) {
          newInput = new HTypeConversion(convertedType, input);
          dominator.addBefore(dominator.first, newInput);
        }
        user.changeUse(input, newInput);
      }
    }
  }

  void visitIs(HIs instruction) {
    HInstruction input = instruction.expression;
    HType convertedType =
        new HType.fromBoundedType(instruction.typeExpression, compiler);

    List<HInstruction> ifUsers = <HInstruction>[];
    List<HInstruction> notIfUsers = <HInstruction>[];

    for (HInstruction user in instruction.usedBy) {
      if (user is HIf) {
        ifUsers.add(user);
      } else if (user is HNot) {
        for (HInstruction notUser in user.usedBy) {
          if (notUser is HIf) notIfUsers.add(notUser);
        }
      }
    }

    if (ifUsers.isEmpty() && notIfUsers.isEmpty()) return;

    for (HIf ifUser in ifUsers) {
      changeUsesDominatedBy(ifUser.thenBlock, input, convertedType);
      // TODO(ngeoffray): Also change uses for the else block on a HType
      // that knows it is not of a specific Type.
    }

    for (HIf ifUser in notIfUsers) {
      if (ifUser.hasElse) {
        changeUsesDominatedBy(ifUser.elseBlock, input, convertedType);
      } else if (ifUser.joinBlock.predecessors.length == 1) {
        // If the join block has only one predecessor, then we know
        // the if block terminates. So any use of the instruction
        // after the join block should be changed to the new
        // instruction.
        changeUsesDominatedBy(ifUser.joinBlock, input, convertedType);
      }
      // TODO(ngeoffray): Also change uses for the then block on a HType
      // that knows it is not of a specific Type.
    }
  }
}

class SsaProcessRecompileCandidates
      extends HBaseVisitor implements OptimizationPhase {
  final String name = "SsaProcessRecompileCandidates";
  final JavaScriptBackend backend;
  final WorkItem work;
  HGraph graph;
  Compiler get compiler() => backend.compiler;

  SsaProcessRecompileCandidates(this.backend, this.work);

  void visitGraph(HGraph visitee) {
    graph = visitee;
    visitDominatorTree(visitee);
  }

  HInstruction visitEquals(HEquals node) {
    // Try to optimize the case where a field which is known to always be an
    // integer is compared with a constant integer literal.
    if (node.left is HFieldGet &&
        node.right is HConstant &&
        node.right.isInteger()) {
      HFieldGet left = node.left;
      HConstant right = node.right;
      if (left.element != null) {
        Type type = left.receiver.propagatedType.computeType(compiler);
        switch (compiler.phase) {
          case Compiler.PHASE_COMPILING:
            if (compiler.codegenWorld.couldHaveFieldOnlyIntegerSetters(
                    type, left.element.name) &&
                compiler.codegenWorld.hasFieldOnlyIntegerInitializers(
                    type, left.element.name)) {
              compiler.enqueuer.codegen.registerRecompilationCandidate(
                  work.element);
            }
            break;
          case Compiler.PHASE_RECOMPILING:
            if (compiler.codegenWorld.hasFieldOnlyIntegerSetters(
                    type, left.element.name) &&
                compiler.codegenWorld.hasFieldOnlyIntegerInitializers(
                    type, left.element.name)) {
              if (compiler.codegenWorld.hasInvokedSetter(left.element,
                                                         compiler)) {
                // If there are invoked setters we don't know for sure that the
                // field will hold an integer, but the fact that the class
                // itself always sets an integer in the fiels is still a strong
                // signal to indiate the expected type of the field.
                left.propagatedType = HType.INTEGER;
                graph.highTypeLikelyhood = true;
              } else {
                // If there are no invoked setters we know the type of this
                // field for sure.
                left.guaranteedType = HType.INTEGER;
              }
            }
            break;
          default:
            assert(false);
            break;
        }
      }
    }
  }
}
