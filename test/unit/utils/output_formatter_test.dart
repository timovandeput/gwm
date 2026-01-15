import 'dart:convert';

import 'package:test/test.dart';

import 'package:gwm/src/utils/output_formatter.dart';
import 'package:gwm/src/models/worktree.dart';

void main() {
  late OutputFormatter formatter;

  setUp(() {
    formatter = OutputFormatter();
  });

  group('OutputFormatter', () {
    group('formatTable', () {
      test('returns empty message when worktrees list is empty', () {
        final result = formatter.formatTable([], '/current/path');
        expect(result, 'No worktrees found.');
      });

      test('formats single worktree correctly', () {
        final worktrees = [
          Worktree(
            name: 'main',
            branch: 'main',
            path: '/repo/main',
            isMain: true,
            status: WorktreeStatus.clean,
          ),
        ];

        final result = formatter.formatTable(worktrees, '/other/path');
        final lines = result.split('\n');

        expect(lines.length, 4); // header, separator, row, empty line
        expect(lines[0], startsWith('Worktree'));
        expect(lines[0], contains('| Branch'));
        expect(lines[0], contains('| Path'));
        expect(lines[2], contains(' main'));
        expect(lines[2], contains('| main'));
        expect(lines[2], contains('| /repo/main'));
        expect(lines[3], isEmpty);
      });

      test('marks current worktree with asterisk', () {
        final worktrees = [
          Worktree(
            name: 'main',
            branch: 'main',
            path: '/repo/main',
            isMain: true,
            status: WorktreeStatus.clean,
          ),
          Worktree(
            name: 'feature',
            branch: 'feature/branch',
            path: '/repo/feature',
            isMain: false,
            status: WorktreeStatus.modified,
          ),
        ];

        final result = formatter.formatTable(worktrees, '/repo/main');
        final lines = result.split('\n');

        expect(lines[2], startsWith('*main'));
        expect(lines[3], startsWith(' feature'));
      });

      test('calculates column widths correctly', () {
        final worktrees = [
          Worktree(
            name: 'short',
            branch: 'short',
            path: '/short',
            isMain: true,
            status: WorktreeStatus.clean,
          ),
          Worktree(
            name: 'very-long-worktree-name',
            branch: 'very-long-branch-name',
            path: '/very/long/path/to/worktree',
            isMain: false,
            status: WorktreeStatus.clean,
          ),
        ];

        final result = formatter.formatTable(worktrees, '/other/path');
        final lines = result.split('\n');

        // Header should be padded to max length + 1 for marker
        expect(
          lines[0],
          startsWith('Worktree'.padRight(22)),
        ); // 21 chars + 1 space
        expect(lines[0], contains('Branch'.padRight(20))); // 20 chars

        // Rows should be aligned - check that columns are properly padded
        expect(lines[2], contains('short'));
        expect(lines[2], contains('| short'));
        expect(lines[2], contains('| /short'));
        expect(lines[3], contains('very-long-worktree-name'));
        expect(lines[3], contains('| very-long-branch-name'));
        expect(lines[3], contains('| /very/long/path/to/worktree'));

        // Verify that the 'short' entries are padded to match the longer ones
        final shortLine = lines[2];
        final longLine = lines[3];
        // The position of '|' should align
        final shortFirstPipe = shortLine.indexOf('|');
        final longFirstPipe = longLine.indexOf('|');
        expect(shortFirstPipe, longFirstPipe);
        final shortSecondPipe = shortLine.indexOf('|', shortFirstPipe + 1);
        final longSecondPipe = longLine.indexOf('|', longFirstPipe + 1);
        expect(shortSecondPipe, longSecondPipe);
      });

      test('formats verbose table with status and last modified columns', () {
        final now = DateTime.now();
        final worktrees = [
          Worktree(
            name: 'main',
            branch: 'main',
            path: '/repo/main',
            isMain: true,
            status: WorktreeStatus.clean,
            lastModified: now,
          ),
          Worktree(
            name: 'feature',
            branch: 'feature/branch',
            path: '/repo/feature',
            isMain: false,
            status: WorktreeStatus.modified,
            lastModified: null,
          ),
        ];

        final result = formatter.formatTable(
          worktrees,
          '/other/path',
          verbose: true,
        );
        final lines = result.split('\n');

        expect(lines.length, 5); // header, separator, 2 rows, empty line
        expect(lines[0], contains('| Status'));
        expect(lines[0], contains('| Last Modified'));

        // Check status values
        expect(lines[2], contains('| clean'));
        expect(lines[3], contains('| modified'));

        // Check date formatting
        final formattedDate =
            '${now.year.toString().padLeft(4, '0')}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')} '
            '${now.hour.toString().padLeft(2, '0')}:'
            '${now.minute.toString().padLeft(2, '0')}:'
            '${now.second.toString().padLeft(2, '0')}';
        expect(lines[2], contains('| $formattedDate'));
        expect(lines[3], contains('| ')); // empty for null date
      });

      test('handles worktrees with null lastModified in verbose mode', () {
        final worktrees = [
          Worktree(
            name: 'main',
            branch: 'main',
            path: '/repo/main',
            isMain: true,
            status: WorktreeStatus.clean,
            lastModified: null,
          ),
        ];

        final result = formatter.formatTable(
          worktrees,
          '/other/path',
          verbose: true,
        );
        final lines = result.split('\n');

        expect(lines[2], contains('| clean | '));
      });

      test('formats worktrees with special characters in names', () {
        final worktrees = [
          Worktree(
            name: 'feature/test',
            branch: 'feature/test',
            path: '/repo/feature/test',
            isMain: false,
            status: WorktreeStatus.clean,
          ),
        ];

        final result = formatter.formatTable(worktrees, '/other/path');
        final lines = result.split('\n');

        expect(lines[2], contains(' feature/test'));
        expect(lines[2], contains('| feature/test'));
      });
    });

    group('formatJson', () {
      test('formats empty worktrees list as JSON', () {
        final result = formatter.formatJson([], '/current/path');
        expect(result, '[]');
      });

      test('formats single worktree as JSON', () {
        final worktrees = [
          Worktree(
            name: 'main',
            branch: 'main',
            path: '/repo/main',
            isMain: true,
            status: WorktreeStatus.clean,
            lastModified: DateTime(2023, 1, 1, 12, 0, 0),
          ),
        ];

        final result = formatter.formatJson(worktrees, '/other/path');
        final parsed = json.decode(result);

        expect(parsed, isList);
        expect(parsed.length, 1);
        expect(parsed[0]['name'], 'main');
        expect(parsed[0]['branch'], 'main');
        expect(parsed[0]['path'], '/repo/main');
        expect(parsed[0]['isMain'], true);
        expect(parsed[0]['status'], 'clean');
        expect(parsed[0]['lastModified'], '2023-01-01T12:00:00.000');
        expect(parsed[0]['current'], false);
      });

      test('marks current worktree in JSON output', () {
        final worktrees = [
          Worktree(
            name: 'main',
            branch: 'main',
            path: '/repo/main',
            isMain: true,
            status: WorktreeStatus.clean,
          ),
        ];

        final result = formatter.formatJson(worktrees, '/repo/main');
        final parsed = json.decode(result);

        expect(parsed[0]['current'], true);
      });

      test('formats multiple worktrees as JSON array', () {
        final worktrees = [
          Worktree(
            name: 'main',
            branch: 'main',
            path: '/repo/main',
            isMain: true,
            status: WorktreeStatus.clean,
          ),
          Worktree(
            name: 'feature',
            branch: 'feature/branch',
            path: '/repo/feature',
            isMain: false,
            status: WorktreeStatus.modified,
          ),
        ];

        final result = formatter.formatJson(worktrees, '/other/path');
        final parsed = json.decode(result);

        expect(parsed.length, 2);
        expect(parsed[0]['name'], 'main');
        expect(parsed[1]['name'], 'feature');
        expect(parsed[0]['current'], false);
        expect(parsed[1]['current'], false);
      });

      test('handles null lastModified in JSON output', () {
        final worktrees = [
          Worktree(
            name: 'main',
            branch: 'main',
            path: '/repo/main',
            isMain: true,
            status: WorktreeStatus.clean,
            lastModified: null,
          ),
        ];

        final result = formatter.formatJson(worktrees, '/other/path');
        final parsed = json.decode(result);

        expect(parsed[0]['lastModified'], null);
      });

      test('produces properly indented JSON', () {
        final worktrees = [
          Worktree(
            name: 'main',
            branch: 'main',
            path: '/repo/main',
            isMain: true,
            status: WorktreeStatus.clean,
          ),
        ];

        final result = formatter.formatJson(worktrees, '/other/path');
        final lines = result.split('\n');

        expect(lines[0], '[');
        expect(lines[1], '  {');
        expect(lines[2], startsWith('    "'));
        // Should be properly indented
      });
    });

    group('DateTime formatting', () {
      test('formats DateTime correctly in verbose table', () {
        final dateTime = DateTime(2023, 12, 25, 14, 30, 45);
        final worktrees = [
          Worktree(
            name: 'test',
            branch: 'test',
            path: '/test',
            isMain: true,
            status: WorktreeStatus.clean,
            lastModified: dateTime,
          ),
        ];

        final result = formatter.formatTable(
          worktrees,
          '/other/path',
          verbose: true,
        );
        expect(result, contains('2023-12-25 14:30:45'));
      });

      test('handles null DateTime in verbose table', () {
        final worktrees = [
          Worktree(
            name: 'test',
            branch: 'test',
            path: '/test',
            isMain: true,
            status: WorktreeStatus.clean,
            lastModified: null,
          ),
        ];

        final result = formatter.formatTable(
          worktrees,
          '/other/path',
          verbose: true,
        );
        final lines = result.split('\n');
        // Should have padded empty string for last modified column (19 spaces)
        expect(lines[2], endsWith('|                    '));
      });
    });
  });
}
