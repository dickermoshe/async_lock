import 'package:flutter_test/flutter_test.dart';
import 'package:qm/qm.dart';

void main() {
  group('Integration Tests', () {
    group('Query + Mutation workflow', () {
      test('mutation can trigger query restart', () async {
        // Simulate a list that can be fetched and modified
        final items = [1, 2, 3];

        final query = Query<List<int>>((state) async {
          await Future.delayed(Duration(milliseconds: 10));
          return List.from(items);
        });

        await Future.delayed(Duration(milliseconds: 50));
        expect(query.value.value, equals([1, 2, 3]));

        final mutation = Mutation<void, int>((newItem, state) async {
          await Future.delayed(Duration(milliseconds: 10));
          items.add(newItem);
        });

        mutation.run(4);
        await Future.delayed(Duration(milliseconds: 50));
        expect(mutation.value.hasValue, isTrue);

        // Restart query to fetch updated data
        query.restart();
        await Future.delayed(Duration(milliseconds: 50));
        expect(query.value.value, equals([1, 2, 3, 4]));

        query.dispose();
        mutation.dispose();
      });

      test('multiple mutations can be chained', () async {
        int counter = 0;

        final mutation = Mutation<int, int>((increment, state) async {
          await Future.delayed(Duration(milliseconds: 10));
          counter += increment;
          return counter;
        });

        mutation.run(1);
        await Future.delayed(Duration(milliseconds: 50));
        expect(mutation.value.value, equals(1));

        mutation.run(5);
        await Future.delayed(Duration(milliseconds: 50));
        expect(mutation.value.value, equals(6));

        mutation.run(10);
        await Future.delayed(Duration(milliseconds: 50));
        expect(mutation.value.value, equals(16));

        mutation.dispose();
      });
    });

    group('Error handling', () {
      test('query can recover from error', () async {
        int attemptCount = 0;

        final query = Query<int>((state) async {
          attemptCount++;
          await Future.delayed(Duration(milliseconds: 10));
          if (attemptCount == 1) {
            throw Exception('First attempt failed');
          }
          return 42;
        });

        await Future.delayed(Duration(milliseconds: 50));
        expect(query.value.hasFailed, isTrue);

        query.restart();
        await Future.delayed(Duration(milliseconds: 50));
        expect(query.value.hasValue, isTrue);
        expect(query.value.value, equals(42));

        query.dispose();
      });

      test('mutation can recover from error', () async {
        int attemptCount = 0;

        final mutation = Mutation<int, void>((args, state) async {
          attemptCount++;
          await Future.delayed(Duration(milliseconds: 10));
          if (attemptCount == 1) {
            throw Exception('First attempt failed');
          }
          return 42;
        });

        mutation.run(null);
        await Future.delayed(Duration(milliseconds: 50));
        expect(mutation.value.hasFailed, isTrue);

        mutation.run(null);
        await Future.delayed(Duration(milliseconds: 50));
        expect(mutation.value.hasValue, isTrue);
        expect(mutation.value.value, equals(42));

        mutation.dispose();
      });
    });

    group('Cancellation scenarios', () {
      test('query cancellation prevents stale data', () async {
        int completedCount = 0;
        int requestNumber = 0;

        final query = Query<int>((state) async {
          final myRequest = ++requestNumber;
          await Future.delayed(Duration(milliseconds: myRequest * 10));
          state.guard();
          completedCount++;
          return myRequest;
        });

        // Quickly restart to cancel first query
        await Future.delayed(Duration(milliseconds: 5));
        query.restart();

        await Future.delayed(Duration(milliseconds: 100));

        // First query should have been cancelled
        expect(completedCount, equals(1));
        expect(query.value.value, equals(2));

        query.dispose();
      });

      test('mutation cancellation prevents stale updates', () async {
        int completedCount = 0;
        int requestNumber = 0;

        final mutation = Mutation<int, void>((args, state) async {
          final myRequest = ++requestNumber;
          await Future.delayed(Duration(milliseconds: myRequest * 10));
          state.guard();
          completedCount++;
          return myRequest;
        });

        mutation.run(null);

        // Quickly run again to cancel first mutation
        await Future.delayed(Duration(milliseconds: 5));
        mutation.run(null);

        await Future.delayed(Duration(milliseconds: 100));

        // First mutation should have been cancelled
        expect(completedCount, equals(1));
        expect(mutation.value.value, equals(2));

        mutation.dispose();
      });
    });

    group('State persistence', () {
      test('query when() shows previous data during reload', () async {
        int value = 1;
        final query = Query<int>((state) async {
          await Future.delayed(Duration(milliseconds: 10));
          return value;
        });

        await Future.delayed(Duration(milliseconds: 50));
        expect(query.value.value, equals(1));

        value = 2;
        query.restart();

        // During loading, when() with skip flag should show previous data
        final result = query.value.when<String>(
          skipLoadingOnRestartAfterSuccess: true,
          loading: () => 'loading',
          data: (v) => 'data: $v',
          failed: (e, st) => 'failed',
        );

        expect(result, equals('data: 1'));

        await Future.delayed(Duration(milliseconds: 50));
        expect(query.value.value, equals(2));

        query.dispose();
      });

      test('mutation tracks previous results', () async {
        final mutation = Mutation<int, int>((value, state) async {
          await Future.delayed(Duration(milliseconds: 10));
          return value;
        });

        mutation.run(1);
        await Future.delayed(Duration(milliseconds: 50));
        expect(mutation.value.value, equals(1));

        mutation.run(2);
        final runningState = mutation.value;
        expect(runningState.isLoading, isTrue);
        expect(runningState.previousState?.value, equals(1));

        await Future.delayed(Duration(milliseconds: 50));
        expect(mutation.value.value, equals(2));

        mutation.dispose();
      });
    });

    group('Complex data types', () {
      test('query with custom class', () async {
        final query = Query<User>((state) async {
          await Future.delayed(Duration(milliseconds: 10));
          return User(id: 1, name: 'John Doe');
        });

        await Future.delayed(Duration(milliseconds: 50));

        expect(query.value.hasValue, isTrue);
        expect(query.value.value?.id, equals(1));
        expect(query.value.value?.name, equals('John Doe'));

        query.dispose();
      });

      test('mutation with custom class', () async {
        final mutation = Mutation<User, String>((name, state) async {
          await Future.delayed(Duration(milliseconds: 10));
          return User(id: 1, name: name);
        });

        mutation.run('Jane Doe');

        await Future.delayed(Duration(milliseconds: 50));

        expect(mutation.value.hasValue, isTrue);
        expect(mutation.value.value?.name, equals('Jane Doe'));

        mutation.dispose();
      });

      test('query with nested data structures', () async {
        final query = Query<Map<String, List<int>>>((state) async {
          await Future.delayed(Duration(milliseconds: 10));
          return {
            'group1': [1, 2, 3],
            'group2': [4, 5, 6],
          };
        });

        await Future.delayed(Duration(milliseconds: 50));

        expect(query.value.hasValue, isTrue);
        expect(query.value.value?['group1'], equals([1, 2, 3]));
        expect(query.value.value?['group2'], equals([4, 5, 6]));

        query.dispose();
      });
    });

    group('Listener notifications', () {
      test('query notifies correct number of times', () async {
        int notificationCount = 0;
        final states = <QueryState<int>>[];

        final query = Query<int>((state) async {
          await Future.delayed(Duration(milliseconds: 10));
          return 42;
        });

        query.addListener(() {
          notificationCount++;
          states.add(query.value);
        });

        await Future.delayed(Duration(milliseconds: 50));

        // Should have notified at least once (when completed)
        expect(notificationCount, greaterThan(0));
        expect(states.last.hasValue, isTrue);

        query.dispose();
      });

      test('mutation notifies correct number of times', () async {
        int notificationCount = 0;
        final states = <MutationState<int>>[];

        final mutation = Mutation<int, void>((args, state) async {
          await Future.delayed(Duration(milliseconds: 10));
          return 42;
        });

        mutation.addListener(() {
          notificationCount++;
          states.add(mutation.value);
        });

        mutation.run(null);

        await Future.delayed(Duration(milliseconds: 50));

        // Should have notified at least twice (running and completed)
        expect(notificationCount, greaterThanOrEqualTo(2));
        expect(states.last.hasValue, isTrue);

        mutation.dispose();
      });
    });

    group('Edge cases', () {
      test('query with immediate synchronous return', () async {
        final query = Query<int>((state) async {
          return 42;
        });

        // Give some time for async operations
        await Future.delayed(Duration(milliseconds: 50));

        expect(query.value.hasValue, isTrue);
        expect(query.value.value, equals(42));

        query.dispose();
      });

      test('mutation with immediate synchronous return', () async {
        final mutation = Mutation<int, void>((args, state) async {
          return 42;
        });

        mutation.run(null);

        await Future.delayed(Duration(milliseconds: 50));

        expect(mutation.value.hasValue, isTrue);
        expect(mutation.value.value, equals(42));

        mutation.dispose();
      });

      test('query with very long running task', () async {
        final query = Query<int>((state) async {
          await Future.delayed(Duration(milliseconds: 100));
          return 42;
        });

        expect(query.value.isLoading, isTrue);

        await Future.delayed(Duration(milliseconds: 50));
        expect(query.value.isLoading, isTrue);

        await Future.delayed(Duration(milliseconds: 100));
        expect(query.value.hasValue, isTrue);

        query.dispose();
      });

      test('disposed query/mutation prevents multiple dispose calls', () {
        final query = Query<int>((state) async => 42);
        final mutation = Mutation<int, void>((args, state) async => 42);

        query.dispose();
        query.dispose(); // Should not throw

        mutation.dispose();
        mutation.dispose(); // Should not throw

        // Test passes if no exception is thrown
        expect(true, isTrue);
      });
    });

    group('LockedAsync integration', () {
      test('query uses LockedAsync for serialization', () async {
        final executionOrder = <int>[];

        final query = Query<int>((state) async {
          executionOrder.add(1);
          await Future.delayed(Duration(milliseconds: 20));
          executionOrder.add(2);
          return 42;
        });

        // Restart immediately
        query.restart();

        await Future.delayed(Duration(milliseconds: 100));

        // Second query should start after first completes or is cancelled
        expect(executionOrder.length, greaterThanOrEqualTo(2));

        query.dispose();
      });

      test('mutation uses LockedAsync for serialization', () async {
        final executionOrder = <int>[];

        final mutation = Mutation<int, int>((value, state) async {
          executionOrder.add(value);
          await Future.delayed(Duration(milliseconds: 20));
          executionOrder.add(value);
          return value;
        });

        mutation.run(1);
        mutation.run(2);
        mutation.run(3);

        await Future.delayed(Duration(milliseconds: 200));

        // The 2nd invocation should not have a chance to run
        expect(executionOrder, equals([1, 1, 3, 3]));

        mutation.dispose();
      });
    });
  });
}

// Helper class for testing
class User {
  final int id;
  final String name;

  User({required this.id, required this.name});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
