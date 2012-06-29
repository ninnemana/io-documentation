// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library('ssa');

#import('../leg.dart');
#import('../native_handler.dart', prefix: 'native');
#import('../elements/elements.dart');
#import('../scanner/scannerlib.dart');
#import('../tree/tree.dart');
#import('../util/util.dart');
#import('../util/characters.dart');

#source('bailout.dart');
#source('builder.dart');
#source('closure.dart');
#source('codegen.dart');
#source('codegen_helpers.dart');
#source('js_names.dart');
#source('nodes.dart');
#source('optimize.dart');
#source('types.dart');
#source('types_propagation.dart');
#source('validate.dart');
#source('variable_allocator.dart');
#source('value_set.dart');

class RuntimeTypeInformation {
  String asJsString(InterfaceType type) {
    ClassElement element = type.element;
    StringBuffer buffer = new StringBuffer();
    Link<Type> arguments = type.arguments;
    int index = 0;
    element.typeParameters.forEach((name, _) {
      buffer.add("${name.slowToString()}: '${arguments.head}'");
      if (++index < element.typeParameters.length) {
        buffer.add(', ');
      }
    });
    return "{$buffer}";
  }

  bool hasTypeArguments(Type type) {
    if (type is InterfaceType) {
      InterfaceType interfaceType = type;
      return (!interfaceType.arguments.isEmpty() &&
              interfaceType.arguments.tail.isEmpty());
    }
    return false;
  }
}
