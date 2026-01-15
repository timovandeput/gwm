import 'dart:convert';

import '../models/worktree.dart';

/// Formats worktree data for output to the console.
///
/// Supports multiple output formats: table (default), verbose table, and JSON.
class OutputFormatter {
  /// Formats a list of worktrees as a table.
  ///
  /// [worktrees] is the list of worktrees to format.
  /// [currentPath] is the path of the current worktree, which will be marked with "*".
  /// [verbose] determines whether to include status and last modified columns.
  String formatTable(
    List<Worktree> worktrees,
    String currentPath, {
    bool verbose = false,
  }) {
    if (worktrees.isEmpty) {
      return 'No worktrees found.';
    }

    final buffer = StringBuffer();

    // Calculate column widths
    final nameWidth = worktrees
        .map((w) => w.name.length)
        .reduce((a, b) => a > b ? a : b);
    final branchWidth = worktrees
        .map((w) => w.branch.length)
        .reduce((a, b) => a > b ? a : b);
    final pathWidth = worktrees
        .map((w) => w.path.length)
        .reduce((a, b) => a > b ? a : b);
    final statusWidth = verbose
        ? worktrees
              .map((w) => w.status.name.length)
              .reduce((a, b) => a > b ? a : b)
        : 0;
    final modifiedWidth = verbose ? 19 : 0; // "YYYY-MM-DD HH:MM:SS" format

    // Header
    final headerName = 'Worktree'.padRight(nameWidth + 1);
    final headerBranch = 'Branch'.padRight(branchWidth);
    final headerPath = 'Path'.padRight(pathWidth);
    final headerStatus = verbose ? 'Status'.padRight(statusWidth) : '';
    final headerModified = verbose
        ? 'Last Modified'.padRight(modifiedWidth)
        : '';

    buffer.writeln(
      '$headerName | $headerBranch | $headerPath${verbose ? " | $headerStatus | $headerModified" : ""}',
    );
    buffer.writeln(
      '-' *
          ((nameWidth + 1) +
              branchWidth +
              pathWidth +
              (verbose ? statusWidth + modifiedWidth + 9 : 6)),
    );

    // Rows
    for (final worktree in worktrees) {
      final marker = worktree.path == currentPath ? '*' : ' ';
      final name = worktree.name.padRight(nameWidth);
      final branch = worktree.branch.padRight(branchWidth);
      final path = worktree.path.padRight(pathWidth);
      final status = verbose ? worktree.status.name.padRight(statusWidth) : '';
      final modified = verbose
          ? _formatDateTime(worktree.lastModified).padRight(modifiedWidth)
          : '';

      buffer.writeln(
        '$marker$name | $branch | $path${verbose ? " | $status | $modified" : ""}',
      );
    }

    return buffer.toString();
  }

  /// Formats a list of worktrees as JSON.
  ///
  /// [worktrees] is the list of worktrees to format.
  /// [currentPath] is the path of the current worktree, which will have current: true.
  String formatJson(List<Worktree> worktrees, String currentPath) {
    final worktreeMaps = worktrees
        .map(
          (worktree) => {
            'name': worktree.name,
            'branch': worktree.branch,
            'path': worktree.path,
            'isMain': worktree.isMain,
            'status': worktree.status.name,
            'lastModified': worktree.lastModified?.toIso8601String(),
            'current': worktree.path == currentPath,
          },
        )
        .toList();

    return JsonEncoder.withIndent('  ').convert(worktreeMaps);
  }

  /// Formats a DateTime for display.
  ///
  /// Returns an empty string if [dateTime] is null.
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${dateTime.year.toString().padLeft(4, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }
}
