import 'dart:io' as io;

/// Represents the supported platforms.
enum Platform {
  /// Windows operating system
  windows,

  /// macOS operating system
  macos,

  /// Linux operating system
  linux,
}

/// Utility for detecting the current platform.
class PlatformDetector {
  /// Gets the current platform.
  ///
  /// Throws [UnsupportedError] if the platform is not supported.
  static Platform get current {
    if (io.Platform.isWindows) return Platform.windows;
    if (io.Platform.isMacOS) return Platform.macos;
    if (io.Platform.isLinux) return Platform.linux;
    throw UnsupportedError(
      'Unsupported platform: ${io.Platform.operatingSystem}',
    );
  }

  /// Checks if the current platform is Windows.
  static bool get isWindows => io.Platform.isWindows;

  /// Checks if the current platform is macOS.
  static bool get isMacOS => io.Platform.isMacOS;

  /// Checks if the current platform is Linux.
  static bool get isLinux => io.Platform.isLinux;
}
