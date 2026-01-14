import '../exceptions.dart';

/// Validates a configuration file map for required fields and correct types.
///
/// Throws [ConfigException] if validation fails.
void validateConfigFile(Map<String, dynamic> config, String configPath) {
  // Validate version
  if (config.containsKey('version')) {
    final version = config['version'];
    if (version is! String) {
      throw ConfigException(configPath, 'version must be a string');
    }
    // Basic semantic version validation
    if (!RegExp(r'^\d+\.\d+$').hasMatch(version)) {
      throw ConfigException(
        configPath,
        'version must be in format "major.minor" (e.g., "1.0")',
      );
    }
  }

  // Validate copy section
  if (config.containsKey('copy')) {
    final copy = config['copy'];
    if (copy is! Map<String, dynamic>) {
      throw ConfigException(configPath, 'copy must be an object');
    }

    if (copy.containsKey('files')) {
      final files = copy['files'];
      if (files is! List) {
        throw ConfigException(configPath, 'copy.files must be an array');
      }
      for (final file in files) {
        if (file is! String) {
          throw ConfigException(
            configPath,
            'copy.files must contain only strings',
          );
        }
        _validateGlobPattern(file, configPath, 'copy.files');
      }
    }

    if (copy.containsKey('directories')) {
      final directories = copy['directories'];
      if (directories is! List) {
        throw ConfigException(configPath, 'copy.directories must be an array');
      }
      for (final dir in directories) {
        if (dir is! String) {
          throw ConfigException(
            configPath,
            'copy.directories must contain only strings',
          );
        }
        _validateGlobPattern(dir, configPath, 'copy.directories');
      }
    }
  }

  // Validate hooks section
  if (config.containsKey('hooks')) {
    final hooks = config['hooks'];
    if (hooks is! Map<String, dynamic>) {
      throw ConfigException(configPath, 'hooks must be an object');
    }

    if (hooks.containsKey('timeout')) {
      final timeout = hooks['timeout'];
      if (timeout is! int) {
        throw ConfigException(configPath, 'hooks.timeout must be an integer');
      }
      if (timeout < 1 || timeout > 3600) {
        throw ConfigException(
          configPath,
          'hooks.timeout must be between 1 and 3600 seconds',
        );
      }
    }

    // Validate individual hooks
    final hookNames = [
      'preAdd',
      'postAdd',
      'preSwitch',
      'postSwitch',
      'preClean',
      'postClean',
    ];
    for (final hookName in hookNames) {
      if (hooks.containsKey(hookName)) {
        _validateHook(hooks[hookName], configPath, 'hooks.$hookName');
      }

      // Validate prepend/append variants
      if (hooks.containsKey('${hookName}_prepend')) {
        final prepend = hooks['${hookName}_prepend'];
        if (prepend is! List) {
          throw ConfigException(
            configPath,
            'hooks.${hookName}_prepend must be an array',
          );
        }
        for (final cmd in prepend) {
          if (cmd is! String) {
            throw ConfigException(
              configPath,
              'hooks.${hookName}_prepend must contain only strings',
            );
          }
        }
      }

      if (hooks.containsKey('${hookName}_append')) {
        final append = hooks['${hookName}_append'];
        if (append is! List) {
          throw ConfigException(
            configPath,
            'hooks.${hookName}_append must be an array',
          );
        }
        for (final cmd in append) {
          if (cmd is! String) {
            throw ConfigException(
              configPath,
              'hooks.${hookName}_append must contain only strings',
            );
          }
        }
      }
    }
  }

  // Validate shellIntegration section
  if (config.containsKey('shellIntegration')) {
    final shellIntegration = config['shellIntegration'];
    if (shellIntegration is! Map<String, dynamic>) {
      throw ConfigException(configPath, 'shellIntegration must be an object');
    }

    if (shellIntegration.containsKey('enableEvalOutput')) {
      final enableEvalOutput = shellIntegration['enableEvalOutput'];
      if (enableEvalOutput is! bool) {
        throw ConfigException(
          configPath,
          'shellIntegration.enableEvalOutput must be a boolean',
        );
      }
    }
  }
}

/// Validates a single hook configuration
void _validateHook(dynamic hook, String configPath, String fieldPath) {
  if (hook == null) return;

  if (hook is String) {
    // Single string command is valid
    return;
  }

  if (hook is List) {
    for (final cmd in hook) {
      if (cmd is! String) {
        throw ConfigException(
          configPath,
          '$fieldPath array must contain only strings',
        );
      }
    }
  } else if (hook is Map<String, dynamic>) {
    if (!hook.containsKey('commands')) {
      throw ConfigException(
        configPath,
        '$fieldPath object must contain "commands" field',
      );
    }

    final commands = hook['commands'];
    if (commands is! List) {
      throw ConfigException(configPath, '$fieldPath.commands must be an array');
    }

    for (final cmd in commands) {
      if (cmd is! String) {
        throw ConfigException(
          configPath,
          '$fieldPath.commands must contain only strings',
        );
      }
    }

    if (hook.containsKey('timeout')) {
      final timeout = hook['timeout'];
      if (timeout is! int) {
        throw ConfigException(
          configPath,
          '$fieldPath.timeout must be an integer',
        );
      }
      if (timeout < 1 || timeout > 3600) {
        throw ConfigException(
          configPath,
          '$fieldPath.timeout must be between 1 and 3600 seconds',
        );
      }
    }
  } else {
    throw ConfigException(
      configPath,
      '$fieldPath must be a string, array, or object',
    );
  }
}

/// Validates a glob pattern for safety
void _validateGlobPattern(String pattern, String configPath, String fieldPath) {
  // Check for potentially dangerous patterns
  if (pattern.contains('..') || pattern.startsWith('/')) {
    throw ConfigException(
      configPath,
      '$fieldPath contains potentially unsafe pattern: $pattern',
    );
  }

  // Basic length check
  if (pattern.length > 256) {
    throw ConfigException(
      configPath,
      '$fieldPath pattern is too long: $pattern',
    );
  }
}
