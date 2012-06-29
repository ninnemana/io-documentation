// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
// Errors are created and thrown by DartVM only.
// Changes here should also be reflected in corelib/error.dart as well

class AssertionError {
  factory AssertionError._uninstantiable() {
    throw const UnsupportedOperationException(
        "AssertionError can only be allocated by the VM");
  }
  static _throwNew(int assertionStart, int assertionEnd)
      native "AssertionError_throwNew";
  String toString() {
    return "'$url': Failed assertion: line $line pos $column: "
        "'$failedAssertion' is not true.";
  }
  final String failedAssertion;
  final String url;
  final int line;
  final int column;
}

class TypeError extends AssertionError {
  factory TypeError._uninstantiable() {
    throw const UnsupportedOperationException(
        "TypeError can only be allocated by the VM");
  }
  static _throwNew(int location,
                   Object src_value,
                   String dst_type_name,
                   String dst_name,
                   String malformed_error)
      native "TypeError_throwNew";
  String toString() {
    String str = (malformedError != null) ? malformedError : "";
    if ((dstName != null) && (dstName.length > 0)) {
      str = "${str}type '$srcType' is not a subtype of "
            "type '$dstType' of '$dstName'.";
    } else {
      str = "${str}malformed type used.";
    }
    return str;
  }
  final String srcType;
  final String dstType;
  final String dstName;
  final String malformedError;
}

class FallThroughError {
  factory FallThroughError._uninstantiable() {
    throw const UnsupportedOperationException(
        "FallThroughError can only be allocated by the VM");
  }
  static _throwNew(int case_clause_pos) native "FallThroughError_throwNew";
  String toString() {
    return "'$url': Switch case fall-through at line $line.";
  }
  final String url;
  final int line;
}

class InternalError {
  const InternalError(this._msg);
  String toString() => "InternalError: '${_msg}'";
  final String _msg;
}


class StaticResolutionException implements Exception {
  factory StaticResolutionException._uninstantiable() {
    throw const UnsupportedOperationException(
        "StaticResolutionException can only be allocated by the VM");
  }

  String toString() => "Unresolved static method: url '$url' line $line "
      "pos $column\n$failedResolutionLine\n";

  static _throwNew(int token_pos) native "StaticResolutionException_throwNew";

  final String failedResolutionLine;
  final String url;
  final int line;
  final int column;
}
