// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class StringMatch implements Match {
  const StringMatch(int this._start,
                    String this.str,
                    String this.pattern);

  int start() => _start;
  int end() => _start + pattern.length;
  String operator[](int g) => group(g);
  int groupCount() => 0;

  String group(int group_) {
    if (group_ != 0) {
      throw new IndexOutOfRangeException(group_);
    }
    return pattern;
  }

  List<String> groups(List<int> groups_) {
    List<String> result = new List<String>();
    for (int g in groups_) {
      result.add(group(g));
    }
    return result;
  }

  final int _start;
  final String str;
  final String pattern;
}

List<Match> allMatchesInStringUnchecked(String needle, String haystack) {
  // Copied from StringBase.allMatches in
  // ../../../runtime/lib/string.dart
  List<Match> result = new List<Match>();
  int length = haystack.length;
  int patternLength = needle.length;
  int startIndex = 0;
  while (true) {
    int position = haystack.indexOf(needle, startIndex);
    if (position == -1) {
      break;
    }
    result.add(new StringMatch(position, haystack, needle));
    int endIndex = position + patternLength;
    if (endIndex == length) {
      break;
    } else if (position == endIndex) {
      ++startIndex;  // empty match, advance and restart
    } else {
      startIndex = endIndex;
    }
  }
  return result;
}

stringContainsUnchecked(receiver, other, startIndex) {
  if (other is String) {
    return receiver.indexOf(other, startIndex) !== -1;
  } else if (other is JSSyntaxRegExp) {
    return other.hasMatch(receiver.substring(startIndex));
  } else {
    var substr = receiver.substring(startIndex);
    return other.allMatches(substr).iterator().hasNext();
  }
}

stringReplaceJS(receiver, replacer, to) {
  // The JavaScript String.replace method recognizes replacement
  // patterns in the replacement string. Dart does not have that
  // behavior.
  to = JS('String', @"#.replace('$', '$$$$')", to);
  return JS('String', @'#.replace(#, #)', receiver, replacer, to);
}

stringReplaceAllUnchecked(receiver, from, to) {
  if (from is String) {
    if (from == "") {
      if (receiver == "") {
        return to;
      } else {
        StringBuffer result = new StringBuffer();
        int length = receiver.length;
        result.add(to);
        for (int i = 0; i < length; i++) {
          result.add(receiver[i]);
          result.add(to);
        }
        return result.toString();
      }
    } else {
      RegExp quoteRegExp =
          const JSSyntaxRegExp(@'[-[\]{}()*+?.,\\^$|#\s]', false, false);
      var quoter = regExpMakeNative(quoteRegExp, global: true);
      var quoted = JS('String', @'#.replace(#, "\\$&")', from, quoter);
      RegExp replaceRegExp = new JSSyntaxRegExp(quoted, false, false);
      var replacer = regExpMakeNative(replaceRegExp, global: true);
      return stringReplaceJS(receiver, replacer, to);
    }
  } else if (from is JSSyntaxRegExp) {
    var re = regExpMakeNative(from, global: true);
    return stringReplaceJS(receiver, re, to);
  } else {
    checkNull(from);
    // TODO(floitsch): implement generic String.replace (with patterns).
    throw "StringImplementation.replaceAll(Pattern) UNIMPLEMENTED";
  }
}

stringReplaceFirstUnchecked(receiver, from, to) {
  if (from is String) {
    return stringReplaceJS(receiver, from, to);
  } else if (from is JSSyntaxRegExp) {
    var re = regExpGetNative(from);
    return stringReplaceJS(receiver, re, to);
  } else {
    checkNull(from);
    // TODO(floitsch): implement generic String.replace (with patterns).
    throw "StringImplementation.replace(Pattern) UNIMPLEMENTED";
  }
}

stringSplitUnchecked(receiver, pattern) {
  if (pattern is String) {
    return JS('List', @'#.split(#)', receiver, pattern);
  } else if (pattern is JSSyntaxRegExp) {
    var re = regExpGetNative(pattern);
    return JS('List', @'#.split(#)', receiver, re);
  } else {
    throw "StringImplementation.split(Pattern) UNIMPLEMENTED";
  }
}

stringJoinUnchecked(array, separator) {
  return JS('String', @'#.join(#)', array, separator);
}
