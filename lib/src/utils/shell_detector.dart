import 'dart:io' as io;

import '../infrastructure/platform_detector.dart';

/// Represents detected shell type.
enum Shell {
  /// Bash shell
  bash,

  /// Zsh shell
  zsh,

  /// Fish shell
  fish,

  /// PowerShell shell
  powershell,

  /// Nushell shell
  nushell,

  /// Unknown shell type
  unknown,
}

/// Utility for detecting current shell environment.
class ShellDetector {
  /// Detects current shell based on environment variables and platform.
  static Shell detect() {
    if (PlatformDetector.isWindows) {
      return _detectWindowsShell();
    } else {
      return _detectUnixShell();
    }
  }

  /// Returns shell wrapper installation command for detected shell.
  static String getWrapperInstallationInstructions() {
    final shell = detect();
    switch (shell) {
      case Shell.bash:
        return r'''
Add to ~/.bashrc:
    gwt() { eval "$(command gwt "$@")"; }
Then restart your shell or run: source ~/.bashrc''';
      case Shell.zsh:
        return r'''
Add to ~/.zshrc:
    gwt() { eval "$(command gwt "$@")" }
Then restart your shell or run: source ~/.zshrc''';
      case Shell.fish:
        return r'''
Add to ~/.config/fish/config.fish:
    function gwt
        eval (command gwt $argv)
    end
Then restart your shell or run: source ~/.config/fish/config.fish''';
      case Shell.powershell:
        return r'''
Add to your PowerShell profile:
    function gwt { Invoke-Expression (& gwt $args) }
To find your profile path, run: $PROFILE
Then restart your shell or run: . $PROFILE''';
      case Shell.nushell:
        return r'''
Add to ~/.config/nushell/config.nu:
    def --env gwt [...args] {
        ^gwt ...$args | lines | each { |line| nu -c $line }
    }
Then restart your shell or run: source ~/.config/nushell/config.nu''';
      case Shell.unknown:
        return r'''
Ensure GWT is invoked with eval to enable automatic directory switching.
For Unix-like shells, wrap GWT: eval "$(gwt "$@")"
For PowerShell: Invoke-Expression (& gwt $args)''';
    }
  }

  /// Detects shell on Unix-like systems (Linux, macOS).
  static Shell _detectUnixShell() {
    final shellPath = io.Platform.environment['SHELL'];
    if (shellPath == null) return Shell.unknown;

    final lowerPath = shellPath.toLowerCase();
    if (lowerPath.contains('zsh')) return Shell.zsh;
    if (lowerPath.contains('bash')) return Shell.bash;
    if (lowerPath.contains('fish')) return Shell.fish;

    return Shell.unknown;
  }

  /// Detects shell on Windows.
  static Shell _detectWindowsShell() {
    // Check for PowerShell-specific environment variables
    if (io.Platform.environment['PSModulePath'] != null) {
      return Shell.powershell;
    }

    // Check for Nushell (may set different environment variables)
    final nuEnv = io.Platform.environment['NU_LIB_DIRS'];
    if (nuEnv != null) return Shell.nushell;

    // Default to unknown if no specific indicators found
    return Shell.unknown;
  }
}
