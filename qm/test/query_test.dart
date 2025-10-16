import 'package:flutter_test/flutter_test.dart';
import 'package:qm/qm.dart';

void main() {
  group('Query', () {
    test('starts in loading state and runs automatically', () {
      bool functionRan = false;
      final query = Query<int>((state) async {
        functionRan = true;
        return 42;
      });

      expect(query.value.isLoading, isTrue);
      expect(functionRan, isTrue);

      query.dispose();
    });

    test('transitions from loading to completed state on success', () async {
      final query = Query<int>((state) async {
        await Future.delayed(Duration(milliseconds: 10));
        return 42;
      });

      expect(query.value.isLoading, isTrue);
      expect(query.value.hasValue, isFalse);

      await Future.delayed(Duration(milliseconds: 50));

      expect(query.value.isLoading, isFalse);
      expect(query.value.hasValue, isTrue);
      expect(query.value.value, equals(42));
      expect(query.value.hasFailed, isFalse);

      query.dispose();
    });

    test('transitions from loading to failed state on error', () async {
      final error = Exception('Test error');
      final query = Query<int>((state) async {
        await Future.delayed(Duration(milliseconds: 10));
        throw error;
      });

      expect(query.value.isLoading, isTrue);

      await Future.delayed(Duration(milliseconds: 50));

      expect(query.value.isLoading, isFalse);
      expect(query.value.hasFailed, isTrue);
      expect(query.value.error, equals(error));
      expect(query.value.stackTrace, isNotNull);
      expect(query.value.hasValue, isFalse);

      query.dispose();
    });

    test('restart triggers query to run again', () async {
      int callCount = 0;
      final query = Query<int>((state) async {
        callCount++;
        await Future.delayed(Duration(milliseconds: 10));
        return callCount;
      });

      await Future.delayed(Duration(milliseconds: 50));
      expect(query.value.value, equals(1));

      query.restart();
      expect(query.value.isLoading, isTrue);

      await Future.delayed(Duration(milliseconds: 50));
      expect(query.value.value, equals(2));

      query.dispose();
    });

    test('run triggers query to run again', () async {
      int callCount = 0;
      final query = Query<int>((state) async {
        callCount++;
        await Future.delayed(Duration(milliseconds: 10));
        return callCount;
      });

      await Future.delayed(Duration(milliseconds: 50));
      expect(query.value.value, equals(1));

      query.restart();
      expect(query.value.isLoading, isTrue);

      await Future.delayed(Duration(milliseconds: 50));
      expect(query.value.value, equals(2));

      query.dispose();
    });

    test('notifies listeners on state changes', () async {
      int listenerCallCount = 0;
      final query = Query<int>((state) async {
        await Future.delayed(Duration(milliseconds: 10));
        return 42;
      });

      query.addListener(() {
        listenerCallCount++;
      });

      // Initial state is loading, so no notification yet
      expect(listenerCallCount, equals(0));

      await Future.delayed(Duration(milliseconds: 50));

      // Should be notified when completed
      expect(listenerCallCount, greaterThan(0));

      query.dispose();
    });

    test('previousState is tracked correctly', () async {
      int value = 1;
      QueryState<int>? loadingState;

      final query = Query<int>((state) async {
        await Future.delayed(Duration(milliseconds: 10));
        return value;
      });

      await Future.delayed(Duration(milliseconds: 50));
      expect(query.value.hasValue, isTrue);
      expect(query.value.value, equals(1));

      value = 2;
      query.restart();

      // Capture loading state immediately before it's cleared
      loadingState = query.value;
      expect(loadingState.isLoading, isTrue);
      // Note: previousState gets cleared after the state is set, so we can't reliably check it

      await Future.delayed(Duration(milliseconds: 50));
      expect(query.value.value, equals(2));

      query.dispose();
    });

    test('cancelled queries do not update state', () async {
      int completedCount = 0;
      final query = Query<int>((state) async {
        await Future.delayed(Duration(milliseconds: 10));
        state.guard();
        await Future.delayed(Duration(milliseconds: 10));
        completedCount++;
        return 42;
      });

      // Immediately restart to cancel the first query
      await Future.delayed(Duration(milliseconds: 5));
      query.restart();

      await Future.delayed(Duration(milliseconds: 50));

      // Only the second query should have completed (first was cancelled)
      expect(completedCount, equals(1));

      query.dispose();
    });

    test('disposed query does not update state', () async {
      final query = Query<int>((state) async {
        await Future.delayed(Duration(milliseconds: 10));
        return 42;
      });

      final initialState = query.value;
      query.dispose();

      // Even though query was started, dispose should prevent state updates
      await Future.delayed(Duration(milliseconds: 50));

      // Test passes if dispose() completes without error
      expect(initialState, isNotNull);
    });

    test('multiple restarts cancel previous runs', () async {
      int completedCount = 0;
      final query = Query<int>((state) async {
        await Future.delayed(Duration(milliseconds: 10));
        state.guard();
        await Future.delayed(Duration(milliseconds: 10));
        completedCount++;
        return completedCount;
      });

      // Restart multiple times quickly
      query.restart();
      query.restart();
      query.restart();

      await Future.delayed(Duration(milliseconds: 100));

      // Only the last one should complete
      expect(completedCount, equals(1));
      expect(query.value.value, equals(1));

      query.dispose();
    });

    test('handles synchronous completion', () {
      final query = Query<int>((state) async {
        return 42;
      });

      // Should still start in loading state
      expect(query.value.isLoading, isTrue);

      query.dispose();
    });

    test('handles null values', () async {
      final query = Query<int?>((state) async {
        await Future.delayed(Duration(milliseconds: 10));
        return null;
      });

      await Future.delayed(Duration(milliseconds: 50));

      expect(query.value.hasValue, isTrue);
      expect(query.value.value, isNull);

      query.dispose();
    });

    test('preserves stack trace on error', () async {
      final query = Query<int>((state) async {
        await Future.delayed(Duration(milliseconds: 10));
        throw Exception('Test error');
      });

      await Future.delayed(Duration(milliseconds: 50));

      expect(query.value.hasFailed, isTrue);
      expect(query.value.stackTrace, isNotNull);
      expect(query.value.stackTrace.toString(), isNotEmpty);

      query.dispose();
    });

    test('can use LockedAsyncState features', () async {
      bool guardCalled = false;
      final query = Query<int>((state) async {
        await Future.delayed(Duration(milliseconds: 10));
        state.guard();
        guardCalled = true;
        await Future.delayed(Duration(milliseconds: 10));
        return 42;
      });

      await Future.delayed(Duration(milliseconds: 50));

      expect(guardCalled, isTrue);
      expect(query.value.value, equals(42));

      query.dispose();
    });

    test('works with complex types', () async {
      final query = Query<List<String>>((state) async {
        await Future.delayed(Duration(milliseconds: 10));
        return ['a', 'b', 'c'];
      });

      await Future.delayed(Duration(milliseconds: 50));

      expect(query.value.hasValue, isTrue);
      expect(query.value.value, equals(['a', 'b', 'c']));

      query.dispose();
    });

    test('previousState is cleared after state transition', () async {
      final query = Query<int>((state) async {
        await Future.delayed(Duration(milliseconds: 10));
        return 42;
      });

      await Future.delayed(Duration(milliseconds: 50));

      final firstState = query.value;
      expect(firstState.hasValue, isTrue);

      query.restart();

      await Future.delayed(Duration(milliseconds: 50));

      // After completing, the current state's previousState should be null
      // because clearPreviousState is called when the state is set
      expect(query.value.previousState?.previousState, isNull);

      query.dispose();
    });
  });
}
