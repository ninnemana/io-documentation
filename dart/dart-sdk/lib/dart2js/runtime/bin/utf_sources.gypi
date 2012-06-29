# Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# This file contains all sources for the dart:utf library.
{
  'sources': [
    # The utf_vm.dart file needs to be the first source file. It contains
    # the library and import directives for the dart:utf library. The
    # dart:utf library is created by concatenating the files listed here
    # in the order they are listed.
    '../../lib/utf/utf_vm.dart',

    '../../lib/utf/utf_core.dart',
    '../../lib/utf/utf8.dart',
    '../../lib/utf/utf16.dart',
    '../../lib/utf/utf32.dart',
  ],
}
