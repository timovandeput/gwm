import 'package:test/test.dart';
import 'dart:io' as io;

import 'package:gwm/src/infrastructure/platform_detector.dart';

void main() {
  group('PlatformDetector', () {
    test('current returns correct platform for supported platforms', () {
      if (io.Platform.isWindows) {
        expect(PlatformDetector.current, Platform.windows);
      } else if (io.Platform.isMacOS) {
        expect(PlatformDetector.current, Platform.macos);
      } else if (io.Platform.isLinux) {
        expect(PlatformDetector.current, Platform.linux);
      } else {
        // On unsupported platforms, should throw UnsupportedError
        expect(() => PlatformDetector.current, throwsUnsupportedError);
      }
    });

    test('isWindows matches io.Platform.isWindows', () {
      expect(PlatformDetector.isWindows, io.Platform.isWindows);
    });

    test('isMacOS matches io.Platform.isMacOS', () {
      expect(PlatformDetector.isMacOS, io.Platform.isMacOS);
    });

    test('isLinux matches io.Platform.isLinux', () {
      expect(PlatformDetector.isLinux, io.Platform.isLinux);
    });
  });
}
