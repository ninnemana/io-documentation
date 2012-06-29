// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#include "platform/assert.h"
#include "vm/bootstrap_natives.h"
#include "vm/exceptions.h"
#include "vm/native_entry.h"
#include "vm/object.h"

#include "lib/regexp_jsc.h"

namespace dart {

static void CheckAndThrowExceptionIfNull(const Instance& obj) {
  if (obj.IsNull()) {
    GrowableArray<const Object*> args;
    Exceptions::ThrowByType(Exceptions::kNullPointer, args);
  }
}


DEFINE_NATIVE_ENTRY(JSSyntaxRegExp_factory, 4) {
  ASSERT(AbstractTypeArguments::CheckedHandle(arguments->At(0)).IsNull());
  const Instance& arg1 = Instance::CheckedHandle(arguments->At(1));
  CheckAndThrowExceptionIfNull(arg1);
  GET_NATIVE_ARGUMENT(String, pattern, arguments->At(1));
  GET_NATIVE_ARGUMENT(Instance, handle_multi_line, arguments->At(2));
  GET_NATIVE_ARGUMENT(Instance, handle_ignore_case, arguments->At(3));
  bool ignore_case = handle_ignore_case.raw() == Bool::True();
  bool multi_line = handle_multi_line.raw() == Bool::True();
  const JSRegExp& new_regex = JSRegExp::Handle(
      Jscre::Compile(pattern, multi_line, ignore_case));
  arguments->SetReturn(new_regex);
}


DEFINE_NATIVE_ENTRY(JSSyntaxRegExp_getPattern, 1) {
  const JSRegExp& regexp = JSRegExp::CheckedHandle(arguments->At(0));
  ASSERT(!regexp.IsNull());
  const String& result = String::Handle(regexp.pattern());
  arguments->SetReturn(result);
}


DEFINE_NATIVE_ENTRY(JSSyntaxRegExp_multiLine, 1) {
  const JSRegExp& regexp = JSRegExp::CheckedHandle(arguments->At(0));
  ASSERT(!regexp.IsNull());
  const Bool& result = Bool::Handle(Bool::Get(regexp.is_multi_line()));
  arguments->SetReturn(result);
}


DEFINE_NATIVE_ENTRY(JSSyntaxRegExp_ignoreCase, 1) {
  const JSRegExp& regexp = JSRegExp::CheckedHandle(arguments->At(0));
  ASSERT(!regexp.IsNull());
  const Bool& result = Bool::Handle(Bool::Get(regexp.is_ignore_case()));
  arguments->SetReturn(result);
}


DEFINE_NATIVE_ENTRY(JSSyntaxRegExp_getGroupCount, 1) {
  const JSRegExp& regexp = JSRegExp::CheckedHandle(arguments->At(0));
  ASSERT(!regexp.IsNull());
  if (regexp.is_initialized()) {
    const Smi& result = Smi::Handle(regexp.num_bracket_expressions());
    arguments->SetReturn(result);
    return;
  }
  const String& pattern = String::Handle(regexp.pattern());
  const String& errmsg =
      String::Handle(String::New("Regular expression is not initialized yet"));
  GrowableArray<const Object*> args;
  args.Add(&pattern);
  args.Add(&errmsg);
  Exceptions::ThrowByType(Exceptions::kIllegalJSRegExp, args);
}


DEFINE_NATIVE_ENTRY(JSSyntaxRegExp_ExecuteMatch, 3) {
  const JSRegExp& regexp = JSRegExp::CheckedHandle(arguments->At(0));
  ASSERT(!regexp.IsNull());
  const Instance& arg1 = Instance::CheckedHandle(arguments->At(1));
  CheckAndThrowExceptionIfNull(arg1);
  GET_NATIVE_ARGUMENT(String, str, arguments->At(1));
  GET_NATIVE_ARGUMENT(Smi, start_index, arguments->At(2));
  const Array& result =
      Array::Handle(Jscre::Execute(regexp, str, start_index.Value()));
  arguments->SetReturn(result);
}

}  // namespace dart
