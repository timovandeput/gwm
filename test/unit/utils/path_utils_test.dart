import 'package:test/test.dart';

import 'package:gwm/src/utils/path_utils.dart';

void main() {
  group('PathUtils', () {
    test('join combines path segments correctly', () {
      expect(PathUtils.join(['a', 'b', 'c']), 'a/b/c');
      expect(PathUtils.join(['a/b', 'c']), 'a/b/c');
    });

    test('separator returns platform separator', () {
      expect(PathUtils.separator, isNotEmpty);
    });

    test('normalize resolves path segments', () {
      expect(PathUtils.normalize('a/../b'), 'b');
      expect(PathUtils.normalize('a/./b'), 'a/b');
    });

    test('isAbsolute checks if path is absolute', () {
      expect(PathUtils.isAbsolute('/absolute'), isTrue);
      expect(PathUtils.isAbsolute('relative'), isFalse);
    });

    test('basename gets last segment', () {
      expect(PathUtils.basename('/path/to/file.txt'), 'file.txt');
      expect(PathUtils.basename('file.txt'), 'file.txt');
    });

    test('dirname gets directory part', () {
      expect(PathUtils.dirname('/path/to/file.txt'), '/path/to');
      expect(PathUtils.dirname('file.txt'), '.');
    });

    test('absolute converts to absolute path', () {
      final abs = PathUtils.absolute('relative');
      expect(PathUtils.isAbsolute(abs), isTrue);
    });

    test('relative gets relative path', () {
      expect(PathUtils.relative('/a/b/c', from: '/a'), 'b/c');
    });

    test('split splits path into segments', () {
      expect(PathUtils.split('/a/b/c'), ['/', 'a', 'b', 'c']);
    });

    test('extension gets file extension', () {
      expect(PathUtils.extension('file.txt'), '.txt');
      expect(PathUtils.extension('file'), '');
    });

    test('withoutExtension removes extension', () {
      expect(PathUtils.withoutExtension('file.txt'), 'file');
      expect(PathUtils.withoutExtension('file.tar.gz'), 'file.tar');
    });
  });
}
