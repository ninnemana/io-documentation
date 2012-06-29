// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.


// Dart isolate's API for the dartc compiler (only used for type checking in the
// dart editor, but not for code generation).
#library("dart:isolate");

#source("isolate_api.dart");

SendPort _spawnFunction(void topLevelFunction()) {
  throw new NotImplementedException();
}

SendPort _spawnUri(String uri) {
  throw new NotImplementedException();
}

ReceivePort _port = null;

class _IsolateNatives {
  static Future<SendPort> spawn(Isolate isolate, bool isLight) {
    throw new NotImplementedException();
  }
}

class _ReceivePortFactory {

  factory ReceivePort() {
    throw new NotImplementedException();
  }
}
