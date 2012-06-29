// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class _Path implements Path {
  final String path;

  const _Path(String source) : path = source;
  _Path.fromNative(String source) : path = _clean(source);

  static String _clean(String source) {
    switch (Platform.operatingSystem) {
      case 'windows':
        return _cleanWindows(source);
      default:
        return source;
    }
  }

  static String _cleanWindows(source) {
    // Change \ to /.
    var clean = source.replaceAll('\\', '/');
    // Add / before intial [Drive letter]:
    if (clean.length >= 2 && clean[1] == ':') {
      clean = '/$clean';
    }
    return clean;
  }

  bool get isEmpty() => path.isEmpty();
  bool get isAbsolute() => path.startsWith('/');
  bool get hasTrailingSeparator() => path.endsWith('/');

  String toString() => path;

  Path relativeTo(Path base) {
    // Throws exception if an unimplemented or impossible case is reached.
    // Returns a path "relative" such that
    //    base.join(relative) == this.canonlicalize.
    // Throws an exception if no such path exists, or the case is not
    // implemented yet.
    if (base.isAbsolute && path.startsWith(base.path)) {
      if (path == base.path) return new Path('.');
      if (path[base.path.length] == '/') {
        return new Path(path.substring(base.path.length + 1));
      }
    }
    throw new NotImplementedException(
      "Unimplemented case of Path.relativeTo(base):\n"
      "  Only absolute paths with strict containment are handled at present.\n"
      "  Arguments: $path.relativeTo($base)");
  }

  Path join(Path further) {
    if (further.isAbsolute) {
      throw new IllegalArgumentException(
          "Path.join called with absolute Path as argument.");
    }
    if (isEmpty) {
      return further.canonicalize();
    }
    if (hasTrailingSeparator) {
      return new Path('$path${further.path}').canonicalize();
    }
    return new Path('$path/${further.path}').canonicalize();
  }

  // Note: The URI RFC names for these operations are normalize, resolve, and
  // relativize.
  Path canonicalize() {
    if (isCanonical) return this;
    return makeCanonical();
  }

  bool get isCanonical() {
    // Contains no consecutive path separators.
    // Contains no segments that are '.'.
    // Absolute paths have no segments that are '..'.
    // All '..' segments of a relative path are at the beginning.
    if (isEmpty) return false;  // The canonical form of '' is '.'.
    if (path == '.') return true;
    List segs = path.split('/');  // Don't mask the getter 'segments'.
    if (segs[0] == '') {  // Absolute path
      segs[0] = null;  // Faster than removeRange().
    } else {  // A canonical relative path may start with .. segments.
      for (int pos = 0;
           pos < segs.length && segs[pos] == '..';
           ++pos) {
        segs[pos] = null;
      }
    }
    if (segs.last() == '') segs.removeLast();  // Path ends with /.
    // No remaining segments can be ., .., or empty.
    return !segs.some((s) => s == '' || s == '.' || s == '..');
  }

  Path makeCanonical() {
    bool isAbs = isAbsolute;
    List segs = segments();
    String drive;
    if (isAbs &&
        !segs.isEmpty() &&
        segs[0].length == 2 &&
        segs[0][1] == ':') {
      drive = segs[0];
      segs.removeRange(0, 1);
    }
    List newSegs = [];
    for (String segment in segs) {
      switch (segment) {
        case '..':
          // Absolute paths drop leading .. markers, including after a drive.
          if (newSegs.isEmpty()) {
            if (isAbs) {
              // Do nothing: drop the segment.
            } else {
              newSegs.add('..');
            }
          } else if (newSegs.last() == '..') {
            newSegs.add('..');
          } else {
            newSegs.removeLast();
          }
          break;
        case '.':
        case '':
          // Do nothing - drop the segment.
          break;
        default:
          newSegs.add(segment);
          break;
      }
    }

    List segmentsToJoin = [];
    if (isAbs) {
      segmentsToJoin.add('');
      if (drive != null) {
        segmentsToJoin.add(drive);
      }
    }

    if (newSegs.isEmpty()) {
      if (isAbs) {
        segmentsToJoin.add('');
      } else {
        segmentsToJoin.add('.');
      }
    } else {
      segmentsToJoin.addAll(newSegs);
      if (hasTrailingSeparator) {
        segmentsToJoin.add('');
      }
    }
    return new Path(Strings.join(segmentsToJoin, '/'));
  }


  String toNativePath() {
    if (Platform.operatingSystem == 'windows') {
      String nativePath = path;
      // Drop '/' before a drive letter.
      if (nativePath.startsWith('/') && nativePath[2] == ':') {
        nativePath = nativePath.substring(1);
      }
      nativePath = nativePath.replaceAll('/', '\\');
      return nativePath;
    }
    return path;
  }

  List<String> segments() {
    List result = path.split('/');
    if (isAbsolute) result.removeRange(0, 1);
    if (hasTrailingSeparator) result.removeLast();
    return result;
  }

  String get filenameWithoutExtension() {
    var name = filename;
    int pos = name.lastIndexOf('.');
    return (pos < 0) ? name : name.substring(0, pos);
  }

  String get extension() {
    var name = filename;
    int pos = name.lastIndexOf('.');
    return (pos < 0) ? '' : name.substring(pos + 1);
  }

  Path get directoryPath() {
    int pos = path.lastIndexOf('/');
    if (pos < 0) return new Path('');
    while (pos > 0 && path[pos - 1] == '/') --pos;
    return new Path((pos > 0) ? path.substring(0, pos) : '/');
  }

  String get filename() {
    int pos = path.lastIndexOf('/');
    return path.substring(pos + 1);
  }
}
