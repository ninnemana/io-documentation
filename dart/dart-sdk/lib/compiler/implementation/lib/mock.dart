// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Mocks of things that Leg cannot read directly.

// TODO(ahe): Remove this file.

class AssertionError {}
class TypeError extends AssertionError {
  final String msg;
  const TypeError(String this.msg);
  String toString() => msg;
}

class FallThroughError {
  const FallThroughError();
  String toString() => "Switch case fall-through.";
}

// TODO(ahe): VM specfic exception?
class InternalError {
  const InternalError(this._msg);
  String toString() => "InternalError: '${_msg}'";
  final String _msg;
}

// TODO(ahe): VM specfic exception?
class StaticResolutionException implements Exception {}

void assert(condition) {
  if (condition is Function) condition = condition();
  if (!condition) throw new AssertionError();
}

// TODO(ahe): Not sure ByteArray belongs in the core library.
interface Uint8List extends List default _InternalByteArray {
  Uint8List(int length);
}

class _InternalByteArray {
  factory Uint8List(int length) {
    throw new UnsupportedOperationException("new Uint8List($length)");
  }
}

// TODO(ahe): This definitely does not belong in the core library.
void exit(int exitCode) {
  throw new UnsupportedOperationException("exit($exitCode)");
}

class _Expando<T> implements Expando<T> {

  final String name;

  const _Expando([this.name]);

  T operator[](Object object) {
    var values = Primitives.getProperty(object, EXPANDO_PROPERTY_NAME);
    return (values === null) ? null : Primitives.getProperty(values, _getKey());
  }

  void operator[]=(Object object, T value) {
    var values = Primitives.getProperty(object, EXPANDO_PROPERTY_NAME);
    if (values === null) {
      values = new Object();
      Primitives.setProperty(object, EXPANDO_PROPERTY_NAME, values);
    }
    Primitives.setProperty(values, _getKey(), value);
  }

  String toString() {
    String key = _getKey();
    return (name === null) ? "Expando:${key}" : "Expando:${name}@${key}";
  }

  String _getKey() {
    String key = Primitives.getProperty(this, KEY_PROPERTY_NAME);
    if (key === null) {
      key = "expando\$key\$${keyCount++}";
      Primitives.setProperty(this, KEY_PROPERTY_NAME, key);
    }
    return key;
  }

  static final String KEY_PROPERTY_NAME = 'expando\$key';
  static final String EXPANDO_PROPERTY_NAME = 'expando\$values';
  static int keyCount = 0;

}
