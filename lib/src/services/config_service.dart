import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import '../models/config.dart';
import '../models/hook.dart';
import '../exceptions.dart';
import '../utils/validation.dart';

/// Service for loading and managing GWM configuration from multiple sources.
///
/// Supports loading configuration from three tiers with proper merging:
/// 1. Global config (~/.config/gwm/config.{json,yaml})
/// 2. Repository config (.gwm.{json,yaml} in repo root)
/// 3. Local config (.gwm.local.{json,yaml} in repo root)
///
/// Configurations are merged with local > repo > global priority.
class ConfigService {
  /// Loads configuration from all three tiers and merges them.
  ///
  /// [repoRoot] is the root directory of the Git repository.
  /// If null, only global configuration is loaded.
  Future<Config> loadConfig({String? repoRoot}) async {
    // Load configurations from all tiers
    final globalConfig = await _loadGlobalConfig();
    final repoConfig = repoRoot != null
        ? await _loadRepoConfig(repoRoot)
        : null;
    final localConfig = repoRoot != null
        ? await _loadLocalConfig(repoRoot)
        : null;

    // Merge configurations with proper priority
    return _mergeConfigs(globalConfig, repoConfig, localConfig);
  }

  /// Loads global configuration from ~/.config/gwm/config.{json,yaml}
  Future<Map<String, dynamic>?> _loadGlobalConfig() async {
    final homeDir = Platform.environment['HOME'];
    if (homeDir == null) return null;

    final configDir = Directory('$homeDir/.config/gwm');
    final jsonFile = File('${configDir.path}/config.json');
    final yamlFile = File('${configDir.path}/config.yaml');

    if (await jsonFile.exists()) {
      return _loadJsonFile(jsonFile.path);
    } else if (await yamlFile.exists()) {
      return _loadYamlFile(yamlFile.path);
    }

    return null;
  }

  /// Loads repository configuration from .gwm.{json,yaml} in repo root
  Future<Map<String, dynamic>?> _loadRepoConfig(String repoRoot) async {
    final jsonFile = File('$repoRoot/.gwm.json');
    final yamlFile = File('$repoRoot/.gwm.yaml');

    if (await jsonFile.exists()) {
      return _loadJsonFile(jsonFile.path);
    } else if (await yamlFile.exists()) {
      return _loadYamlFile(yamlFile.path);
    }

    return null;
  }

  /// Loads local configuration from .gwm.local.{json,yaml} in repo root
  Future<Map<String, dynamic>?> _loadLocalConfig(String repoRoot) async {
    final jsonFile = File('$repoRoot/.gwm.local.json');
    final yamlFile = File('$repoRoot/.gwm.local.yaml');

    if (await jsonFile.exists()) {
      return _loadJsonFile(jsonFile.path);
    } else if (await yamlFile.exists()) {
      return _loadYamlFile(yamlFile.path);
    }

    return null;
  }

  /// Loads and parses a JSON configuration file
  Future<Map<String, dynamic>> _loadJsonFile(String path) async {
    try {
      final content = await File(path).readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      validateConfigFile(data, path);
      return data;
    } catch (e) {
      throw ConfigException(path, 'Invalid JSON format: $e');
    }
  }

  /// Loads and parses a YAML configuration file
  Future<Map<String, dynamic>> _loadYamlFile(String path) async {
    try {
      final content = await File(path).readAsString();
      final data = loadYaml(content);
      // Convert to Map<String, dynamic> recursively
      final result = _convertToMapStringDynamic(data);
      validateConfigFile(result, path);
      return result;
    } catch (e) {
      throw ConfigException(path, 'Invalid YAML format: $e');
    }
  }

  /// Recursively converts dynamic maps to Map&lt;String, dynamic&gt;
  dynamic _convertToMapStringDynamic(dynamic value) {
    if (value is Map) {
      final result = <String, dynamic>{};
      value.forEach((key, val) {
        result[key.toString()] = _convertToMapStringDynamic(val);
      });
      return result;
    } else if (value is List) {
      return value.map(_convertToMapStringDynamic).toList();
    } else {
      return value;
    }
  }

  /// Merges configurations from three tiers with proper priority and override strategies
  Config _mergeConfigs(
    Map<String, dynamic>? global,
    Map<String, dynamic>? repo,
    Map<String, dynamic>? local,
  ) {
    // Start with defaults
    final merged = _createDefaultConfig();

    // Apply global config
    if (global != null) {
      merged.addAll(global);
    }

    // Apply repo config with merging
    if (repo != null) {
      merged.addAll(_mergeMap(merged, repo));
    }

    // Apply local config with merging (highest priority)
    if (local != null) {
      merged.addAll(_mergeMap(merged, local));
    }

    // Convert to Config object
    return _mapToConfig(merged);
  }

  /// Creates default configuration values
  Map<String, dynamic> _createDefaultConfig() {
    return {
      'version': '1.0',
      'copy': {'files': <String>[], 'directories': <String>[]},
      'hooks': {'timeout': 30},
      'shellIntegration': {
        'enableEvalOutput': Platform.environment['GWM_EVAL'] != null,
      },
    };
  }

  /// Merges two configuration maps with special handling for hooks
  Map<String, dynamic> _mergeMap(
    Map<String, dynamic> base,
    Map<String, dynamic> overlay,
  ) {
    final result = Map<String, dynamic>.from(base);

    overlay.forEach((key, value) {
      if (key == 'hooks' && value is Map<String, dynamic>) {
        result[key] = _mergeHooksConfig(
          result[key] as Map<String, dynamic>?,
          value,
        );
      } else {
        result[key] = value;
      }
    });

    return result;
  }

  /// Merges hooks configuration with prepend/append logic
  Map<String, dynamic> _mergeHooksConfig(
    Map<String, dynamic>? base,
    Map<String, dynamic> overlay,
  ) {
    final result = Map<String, dynamic>.from(base ?? {});

    overlay.forEach((key, value) {
      if (key.endsWith('_prepend') && value is List) {
        final hookName = key.substring(0, key.length - 8); // Remove '_prepend'
        result[hookName] = _prependToHook(result[hookName], value);
      } else if (key.endsWith('_append') && value is List) {
        final hookName = key.substring(0, key.length - 7); // Remove '_append'
        result[hookName] = _appendToHook(result[hookName], value);
      } else {
        result[key] = value;
      }
    });

    return result;
  }

  /// Prepends commands to an existing hook
  dynamic _prependToHook(dynamic existingHook, List<dynamic> prependCommands) {
    if (existingHook == null) {
      return prependCommands;
    }

    if (existingHook is List) {
      return [...prependCommands, ...existingHook];
    }

    if (existingHook is Map<String, dynamic> &&
        existingHook.containsKey('commands')) {
      final commands = List<String>.from(existingHook['commands']);
      return {
        ...existingHook,
        'commands': [...prependCommands, ...commands],
      };
    }

    return prependCommands;
  }

  /// Appends commands to an existing hook
  dynamic _appendToHook(dynamic existingHook, List<dynamic> appendCommands) {
    if (existingHook == null) {
      return appendCommands;
    }

    if (existingHook is List) {
      return [...existingHook, ...appendCommands];
    }

    if (existingHook is Map<String, dynamic> &&
        existingHook.containsKey('commands')) {
      final commands = List<String>.from(existingHook['commands']);
      return {
        ...existingHook,
        'commands': [...commands, ...appendCommands],
      };
    }

    return appendCommands;
  }

  /// Converts a merged configuration map to a Config object
  Config _mapToConfig(Map<String, dynamic> map) {
    final version = map['version'] as String? ?? '1.0';

    final copy = map['copy'] as Map<String, dynamic>? ?? {};
    final copyConfig = CopyConfig(
      files: List<String>.from(copy['files'] ?? []),
      directories: List<String>.from(copy['directories'] ?? []),
    );

    final hooks = map['hooks'] as Map<String, dynamic>? ?? {};
    final hooksConfig = _parseHooksConfig(hooks);

    final shellIntegration =
        map['shellIntegration'] as Map<String, dynamic>? ?? {};
    final shellIntegrationConfig = ShellIntegrationConfig(
      enableEvalOutput: shellIntegration['enableEvalOutput'] as bool? ?? false,
    );

    return Config(
      version: version,
      copy: copyConfig,
      hooks: hooksConfig,
      shellIntegration: shellIntegrationConfig,
    );
  }

  /// Parses hooks configuration from map
  HooksConfig _parseHooksConfig(Map<String, dynamic> hooks) {
    final timeout = hooks['timeout'] as int? ?? 30;

    return HooksConfig(
      timeout: timeout,
      preAdd: _parseHook(hooks['preAdd']),
      postAdd: _parseHook(hooks['postAdd']),
      preSwitch: _parseHook(hooks['preSwitch']),
      postSwitch: _parseHook(hooks['postSwitch']),
      preDelete: _parseHook(hooks['preDelete']),
      postDelete: _parseHook(hooks['postDelete']),
    );
  }

  /// Parses a single hook from various formats
  Hook? _parseHook(dynamic hookData) {
    if (hookData == null) return null;

    if (hookData is String) {
      return Hook.fromList([hookData]);
    }

    if (hookData is List) {
      return Hook.fromList(List<String>.from(hookData));
    }

    if (hookData is Map<String, dynamic>) {
      return Hook.fromMap(hookData);
    }

    return null;
  }
}
