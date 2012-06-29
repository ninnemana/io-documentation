// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Mocks of classes and interfaces that Leg cannot read directly.

// TODO(ahe): Remove this file.

class JSSyntaxRegExp implements RegExp {
  final String pattern;
  final bool multiLine;
  final bool ignoreCase;

  const JSSyntaxRegExp(String pattern,
                       [bool multiLine = false, bool ignoreCase = false])
    : this.pattern = pattern,
      this.multiLine = multiLine,
      this.ignoreCase = ignoreCase;

  JSSyntaxRegExp._globalVersionOf(JSSyntaxRegExp other)
      : this.pattern = other.pattern,
        this.multiLine = other.multiLine,
        this.ignoreCase = other.ignoreCase {
    regExpAttachGlobalNative(this);
  }

  Match firstMatch(String str) {
    List<String> m = regExpExec(this, checkString(str));
    if (m === null) return null;
    var matchStart = regExpMatchStart(m);
    // m.lastIndex only works with flag 'g'.
    var matchEnd = matchStart + m[0].length;
    return new MatchImplementation(pattern, str, matchStart, matchEnd, m);
  }

  bool hasMatch(String str) => regExpTest(this, checkString(str));

  String stringMatch(String str) {
    var match = firstMatch(str);
    return match === null ? null : match.group(0);
  }

  Iterable<Match> allMatches(String str) {
    checkString(str);
    return new _AllMatchesIterable(this, str);
  }

  _getNative() => regExpGetNative(this);
}

class MatchImplementation implements Match {
  const MatchImplementation(
      String this.pattern,
      String this.str,
      int this._start,
      int this._end,
      List<String> this._groups);

  final String pattern;
  final String str;
  final int _start;
  final int _end;
  final List<String> _groups;

  int start() => _start;
  int end() => _end;
  String group(int index) => _groups[index];
  String operator [](int index) => group(index);
  int groupCount() => _groups.length - 1;

  List<String> groups(List<int> groups) {
    List<String> out = [];
    for (int i in groups) {
      out.add(group(i));
    }
    return out;
  }
}

class _AllMatchesIterable implements Iterable<Match> {
  final JSSyntaxRegExp _re;
  final String _str;

  const _AllMatchesIterable(this._re, this._str);

  Iterator<Match> iterator() => new _AllMatchesIterator(_re, _str);
}

class _AllMatchesIterator implements Iterator<Match> {
  final RegExp _re;
  final String _str;
  Match _next;
  bool _done;

  _AllMatchesIterator(JSSyntaxRegExp re, String this._str)
    : _done = false, _re = new JSSyntaxRegExp._globalVersionOf(re);

  Match next() {
    if (!hasNext()) {
      throw const NoMoreElementsException();
    }

    // _next is set by #hasNext
    var next = _next;
    _next = null;
    return next;
  }

  bool hasNext() {
    if (_done) {
      return false;
    } else if (_next != null) {
      return true;
    }

    _next = _re.firstMatch(_str);
    if (_next == null) {
      _done = true;
      return false;
    } else {
      return true;
    }
  }
}

class ReceivePortFactory {
  factory ReceivePort() {
    throw 'factory ReceivePort is not implemented';
  }
}

class StringBase {
  static String createFromCharCodes(List<int> charCodes) {
    checkNull(charCodes);
    if (!isJsArray(charCodes)) {
      if (charCodes is !List) throw new IllegalArgumentException(charCodes);
      charCodes = new List.from(charCodes);
    }
    return Primitives.stringFromCharCodes(charCodes);
  }

  static String join(List<String> strings, String separator) {
    checkNull(strings);
    checkNull(separator);
    if (separator is !String) throw new IllegalArgumentException(separator);
    return stringJoinUnchecked(_toJsStringArray(strings), separator);
  }

  static String concatAll(List<String> strings) {
    return stringJoinUnchecked(_toJsStringArray(strings), "");
  }

  static List _toJsStringArray(List<String> strings) {
    checkNull(strings);
    var array;
    final length = strings.length;
    if (isJsArray(strings)) {
      array = strings;
      for (int i = 0; i < length; i++) {
        final string = strings[i];
        checkNull(string);
        if (string is !String) throw new IllegalArgumentException(string);
      }
    } else {
      array = new List(length);
      for (int i = 0; i < length; i++) {
        final string = strings[i];
        checkNull(string);
        if (string is !String) throw new IllegalArgumentException(string);
        array[i] = string;
      }
    }
    return array;
  }
}

class DateImplementation implements Date {
  final int millisecondsSinceEpoch;
  final bool isUtc;

  DateImplementation(int years,
                     [int month = 1,
                      int day = 1,
                      int hour = 0,
                      int minute = 0,
                      int second = 0,
                      int millisecond = 0,
                      bool isUtc = false])
      : this.isUtc = checkNull(isUtc),
        millisecondsSinceEpoch = Primitives.valueFromDecomposedDate(
            years, month, day, hour, minute, second, millisecond, isUtc) {
    _asJs();
  }

  DateImplementation.now()
      : isUtc = false,
        millisecondsSinceEpoch = Primitives.dateNow() {
    _asJs();
  }

  factory DateImplementation.fromString(String formattedString) {
    // Read in (a subset of) ISO 8601.
    // Examples:
    //    - "2012-02-27 13:27:00"
    //    - "2012-02-27 13:27:00.423z"
    //    - "20120227 13:27:00"
    //    - "20120227T132700"
    //    - "20120227"
    //    - "2012-02-27T14Z"
    //    - "-123450101 00:00:00 Z"  // In the year -12345.
    final RegExp re = const RegExp(
        @'^([+-]?\d?\d\d\d\d)-?(\d\d)-?(\d\d)' // The day part.
        @'(?:[ T](\d\d)(?::?(\d\d)(?::?(\d\d)(.\d{1,6})?)?)? ?([zZ])?)?$');
    Match match = re.firstMatch(formattedString);
    if (match !== null) {
      int parseIntOrZero(String matched) {
        // TODO(floitsch): we should not need to test against the empty string.
        if (matched === null || matched == "") return 0;
        return Math.parseInt(matched);
      }

      double parseDoubleOrZero(String matched) {
        // TODO(floitsch): we should not need to test against the empty string.
        if (matched === null || matched == "") return 0.0;
        return Math.parseDouble(matched);
      }

      int years = Math.parseInt(match[1]);
      int month = Math.parseInt(match[2]);
      int day = Math.parseInt(match[3]);
      int hour = parseIntOrZero(match[4]);
      int minute = parseIntOrZero(match[5]);
      int second = parseIntOrZero(match[6]);
      bool addOneMillisecond = false;
      int millisecond = (parseDoubleOrZero(match[7]) * 1000).round().toInt();
      if (millisecond == 1000) {
        addOneMillisecond = true;
        millisecond = 999;
      }
      // TODO(floitsch): we should not need to test against the empty string.
      bool isUtc = (match[8] !== null) && (match[8] != "");
      int millisecondsSinceEpoch = Primitives.valueFromDecomposedDate(
          years, month, day, hour, minute, second, millisecond, isUtc);
      if (millisecondsSinceEpoch === null) {
        throw new IllegalArgumentException(formattedString);
      }
      if (addOneMillisecond) millisecondsSinceEpoch++;
      return new DateImplementation.fromMillisecondsSinceEpoch(
          millisecondsSinceEpoch, isUtc);
    } else {
      throw new IllegalArgumentException(formattedString);
    }
  }

  static final int _MAX_MILLISECONDS_SINCE_EPOCH = 8640000000000000;

  DateImplementation.fromMillisecondsSinceEpoch(this.millisecondsSinceEpoch,
                                                [bool isUtc = false])
      : this.isUtc = checkNull(isUtc) {
    if (millisecondsSinceEpoch.abs() > _MAX_MILLISECONDS_SINCE_EPOCH) {
      throw new IllegalArgumentException(millisecondsSinceEpoch);
    }
  }

  bool operator ==(other) {
    if (!(other is DateImplementation)) return false;
    int ms = millisecondsSinceEpoch;
    int otherMs = other.millisecondsSinceEpoch;
    return (ms == otherMs);
  }

  bool operator <(Date other)
      => millisecondsSinceEpoch < other.millisecondsSinceEpoch;

  bool operator <=(Date other)
      => millisecondsSinceEpoch <= other.millisecondsSinceEpoch;

  bool operator >(Date other)
      => millisecondsSinceEpoch > other.millisecondsSinceEpoch;

  bool operator >=(Date other)
      => millisecondsSinceEpoch >= other.millisecondsSinceEpoch;

  int compareTo(Date other)
      => millisecondsSinceEpoch.compareTo(other.millisecondsSinceEpoch);

  int hashCode() => millisecondsSinceEpoch;

  Date toLocal() {
    if (isUtc) {
      int ms = millisecondsSinceEpoch;
      return new DateImplementation.fromMillisecondsSinceEpoch(ms, false);
    }
    return this;
  }

  Date toUtc() {
    if (isUtc) return this;
    int ms = millisecondsSinceEpoch;
    return new DateImplementation.fromMillisecondsSinceEpoch(ms, true);
  }

  String get timeZoneName() {
    if (isUtc) return "UTC";
    return Primitives.getTimeZoneName(this);
  }

  Duration get timeZoneOffset() {
    if (isUtc) return new Duration(0);
    return new Duration(minutes: Primitives.getTimeZoneOffsetInMinutes(this));
  }

  int get year() => Primitives.getYear(this);

  int get month() => Primitives.getMonth(this);

  int get day() => Primitives.getDay(this);

  int get hour() => Primitives.getHours(this);

  int get minute() => Primitives.getMinutes(this);

  int get second() => Primitives.getSeconds(this);

  int get millisecond() => Primitives.getMilliseconds(this);

  int get weekday() {
    // Adjust by one because JS weeks start on Sunday.
    var day = Primitives.getWeekday(this);
    return (day + 6) % 7 + Date.MON;
  }

  String toString() {
    String fourDigits(int n) {
      int absN = n.abs();
      String sign = n < 0 ? "-" : "";
      if (absN >= 1000) return "$n";
      if (absN >= 100) return "${sign}0$absN";
      if (absN >= 10) return "${sign}00$absN";
      if (absN >= 1) return "${sign}000$absN";
      throw new IllegalArgumentException(n);
    }

    String threeDigits(int n) {
      if (n >= 100) return "${n}";
      if (n >= 10) return "0${n}";
      return "00${n}";
    }

    String twoDigits(int n) {
      if (n >= 10) return "${n}";
      return "0${n}";
    }

    String y = fourDigits(year);
    String m = twoDigits(month);
    String d = twoDigits(day);
    String h = twoDigits(hour);
    String min = twoDigits(minute);
    String sec = twoDigits(second);
    String ms = threeDigits(millisecond);
    if (isUtc) {
      return "$y-$m-$d $h:$min:$sec.${ms}Z";
    } else {
      return "$y-$m-$d $h:$min:$sec.$ms";
    }
  }

  // Adds the [duration] to this Date instance.
  Date add(Duration duration) {
    int ms = millisecondsSinceEpoch;
    return new DateImplementation.fromMillisecondsSinceEpoch(
        ms + duration.inMilliseconds, isUtc);
  }

  // Subtracts the [duration] from this Date instance.
  Date subtract(Duration duration) {
    int ms = millisecondsSinceEpoch;
    return new DateImplementation.fromMillisecondsSinceEpoch(
        ms - duration.inMilliseconds, isUtc);
  }

  // Returns a [Duration] with the difference of [this] and [other].
  Duration difference(Date other) {
    int ms = millisecondsSinceEpoch;
    int otherMs = other.millisecondsSinceEpoch;
    return new DurationImplementation(milliseconds: ms - otherMs);
  }

  // Lazily keep a JS Date stored in the dart object.
  var _asJs() => Primitives.lazyAsJsDate(this);
}

class ListFactory<E> {
  factory List([int length]) => Primitives.newList(length);
  factory List.from(Iterable<E> other) {
    List<E> result = new List<E>();
    // TODO(ahe): Use for-in when it is implemented correctly.
    Iterator<E> iterator = other.iterator();
    while (iterator.hasNext()) {
      result.add(iterator.next());
    }
    return result;
  }
}
