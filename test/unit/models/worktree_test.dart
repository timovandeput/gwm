import 'package:test/test.dart';
import 'package:gwt/src/models/worktree.dart';

void main() {
  group('Worktree', () {
    const worktree = Worktree(
      name: 'feature-auth',
      branch: 'feature/auth',
      path: '/path/to/worktree',
      isMain: false,
      status: WorktreeStatus.modified,
      lastModified: null,
    );

    test('creates worktree with correct properties', () {
      expect(worktree.name, equals('feature-auth'));
      expect(worktree.branch, equals('feature/auth'));
      expect(worktree.path, equals('/path/to/worktree'));
      expect(worktree.isMain, isFalse);
      expect(worktree.status, equals(WorktreeStatus.modified));
      expect(worktree.lastModified, isNull);
    });

    test('copyWith updates specified fields', () {
      final updated = worktree.copyWith(
        name: 'new-name',
        status: WorktreeStatus.clean,
      );

      expect(updated.name, equals('new-name'));
      expect(updated.branch, equals(worktree.branch));
      expect(updated.status, equals(WorktreeStatus.clean));
      expect(updated.isMain, equals(worktree.isMain));
    });

    test('copyWith with null values keeps original', () {
      final updated = worktree.copyWith();

      expect(updated, equals(worktree));
    });

    test('equality works correctly', () {
      const sameWorktree = Worktree(
        name: 'feature-auth',
        branch: 'feature/auth',
        path: '/path/to/worktree',
        isMain: false,
        status: WorktreeStatus.modified,
        lastModified: null,
      );

      const differentWorktree = Worktree(
        name: 'different',
        branch: 'feature/auth',
        path: '/path/to/worktree',
        isMain: false,
        status: WorktreeStatus.modified,
        lastModified: null,
      );

      expect(worktree, equals(sameWorktree));
      expect(worktree, isNot(equals(differentWorktree)));
    });

    test('hashCode is consistent', () {
      const sameWorktree = Worktree(
        name: 'feature-auth',
        branch: 'feature/auth',
        path: '/path/to/worktree',
        isMain: false,
        status: WorktreeStatus.modified,
        lastModified: null,
      );

      expect(worktree.hashCode, equals(sameWorktree.hashCode));
    });

    test('toString provides useful representation', () {
      final result = worktree.toString();
      expect(result, contains('Worktree'));
      expect(result, contains('feature-auth'));
      expect(result, contains('feature/auth'));
      expect(result, contains('/path/to/worktree'));
      expect(result, contains('false'));
      expect(result, contains('WorktreeStatus.modified'));
    });
  });

  group('WorktreeStatus', () {
    test('has all expected values', () {
      expect(WorktreeStatus.clean, equals(WorktreeStatus.clean));
      expect(WorktreeStatus.modified, equals(WorktreeStatus.modified));
      expect(WorktreeStatus.ahead, equals(WorktreeStatus.ahead));
      expect(WorktreeStatus.detached, equals(WorktreeStatus.detached));
    });
  });
}
