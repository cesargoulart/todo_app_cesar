import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app_cesar/screens/todo_list_screen.dart';

void main() {
  group('isDailyTaskVisibleInShowAll', () {
    test('is visible one hour before the due time on the same day', () {
      final dueDate = DateTime(2026, 8, 14, 9, 0);
      final now = DateTime(2026, 8, 14, 8, 0);

      expect(isDailyTaskVisibleInShowAll(dueDate: dueDate, now: now), isTrue);
    });

    test('stays visible for the rest of the day after the due time', () {
      final dueDate = DateTime(2026, 8, 14, 9, 0);
      final now = DateTime(2026, 8, 14, 23, 59);

      expect(isDailyTaskVisibleInShowAll(dueDate: dueDate, now: now), isTrue);
    });

    test('is hidden more than an hour before the due time', () {
      final dueDate = DateTime(2026, 8, 14, 9, 0);
      final now = DateTime(2026, 8, 14, 7, 30);

      expect(isDailyTaskVisibleInShowAll(dueDate: dueDate, now: now), isFalse);
    });

    test('is hidden when due date is a future day', () {
      final dueDate = DateTime(2026, 8, 14, 9, 0);
      final now = DateTime(2026, 8, 13, 8, 30);

      expect(isDailyTaskVisibleInShowAll(dueDate: dueDate, now: now), isFalse);
    });

    test('stays visible when overdue (due day already passed and still pending)', () {
      final dueDate = DateTime(2026, 8, 14, 9, 0);
      final now = DateTime(2026, 8, 15, 8, 30);

      expect(isDailyTaskVisibleInShowAll(dueDate: dueDate, now: now), isTrue);
    });

    test('stays visible when overdue by several days', () {
      final dueDate = DateTime(2026, 8, 14, 9, 0);
      final now = DateTime(2026, 8, 22, 12, 0);

      expect(isDailyTaskVisibleInShowAll(dueDate: dueDate, now: now), isTrue);
    });
  });
}
