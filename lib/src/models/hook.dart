/// Represents a hook configuration that can be either a simple list of commands
/// or an object with timeout and commands.
///
/// Hooks are executed during various worktree operations (add, switch, clean).
class Hook {
  /// The commands to execute for this hook
  final List<String> commands;

  /// Optional timeout in seconds for this specific hook (overrides global timeout)
  final int? timeout;

  const Hook({required this.commands, this.timeout});

  /// Creates a Hook from a list of command strings.
  factory Hook.fromList(List<String> commands) {
    return Hook(commands: commands);
  }

  /// Creates a Hook from a map with 'commands' and optional 'timeout'.
  factory Hook.fromMap(Map<String, dynamic> map) {
    final commands = map['commands'] as List<dynamic>;
    final timeout = map['timeout'] as int?;
    return Hook(commands: commands.cast<String>(), timeout: timeout);
  }

  /// Creates a copy of this hook with some fields updated.
  Hook copyWith({List<String>? commands, int? timeout}) {
    return Hook(
      commands: commands ?? this.commands,
      timeout: timeout ?? this.timeout,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Hook &&
        _listEquals(other.commands, commands) &&
        other.timeout == timeout;
  }

  @override
  int get hashCode => Object.hashAll([...commands, timeout]);

  @override
  String toString() {
    return 'Hook(commands: $commands, timeout: $timeout)';
  }
}

/// Helper function to compare lists for equality
bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null) return false;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
