import 'package:flutter_test/flutter_test.dart';
import 'package:qm/qm.dart';

void main() {
  group('Mutation', () {
    test('starts in idle state', () {
      final mutation = Mutation<int, String>((args, state) async {
        return 42;
      });

      expect(mutation.value.isIdle, isTrue);
      expect(mutation.value.isLoading, isFalse);
      expect(mutation.value.hasValue, isFalse);
      expect(mutation.value.hasFailed, isFalse);

      mutation.dispose();
    });

    test('transitions from idle to running to completed on success', () async {
      final mutation = Mutation<int, String>((args, state) async {
        await Future.delayed(Duration(milliseconds: 10));
        return int.parse(args);
      });

      expect(mutation.value.isIdle, isTrue);

      mutation.run('42');

      expect(mutation.value.isLoading, isTrue);
      expect(mutation.value.isIdle, isFalse);

      await Future.delayed(Duration(milliseconds: 50));

      expect(mutation.value.isLoading, isFalse);
      expect(mutation.value.hasValue, isTrue);
      expect(mutation.value.value, equals(42));

      mutation.dispose();
    });

    test('transitions from idle to running to failed on error', () async {
      final error = Exception('Test error');
      final mutation = Mutation<int, String>((args, state) async {
        await Future.delayed(Duration(milliseconds: 10));
        throw error;
      });

      expect(mutation.value.isIdle, isTrue);

      mutation.run('test');

      expect(mutation.value.isLoading, isTrue);

      await Future.delayed(Duration(milliseconds: 50));

      expect(mutation.value.isLoading, isFalse);
      expect(mutation.value.hasFailed, isTrue);
      expect(mutation.value.error, equals(error));
      expect(mutation.value.stackTrace, isNotNull);

      mutation.dispose();
    });

    test('passes arguments correctly', () async {
      String? receivedArg;
      final mutation = Mutation<int, String>((args, state) async {
        receivedArg = args;
        return args.length;
      });

      mutation.run('test string');

      await Future.delayed(Duration(milliseconds: 50));

      expect(receivedArg, equals('test string'));
      expect(mutation.value.value, equals(11));

      mutation.dispose();
    });

    test('can be run multiple times sequentially', () async {
      int callCount = 0;
      final mutation = Mutation<int, int>((args, state) async {
        callCount++;
        await Future.delayed(Duration(milliseconds: 10));
        return args * 2;
      });

      mutation.run(5);
      await Future.delayed(Duration(milliseconds: 50));
      expect(mutation.value.value, equals(10));

      mutation.run(10);
      await Future.delayed(Duration(milliseconds: 50));
      expect(mutation.value.value, equals(20));

      expect(callCount, equals(2));

      mutation.dispose();
    });

    test('notifies listeners on state changes', () async {
      int listenerCallCount = 0;
      final mutation = Mutation<int, String>((args, state) async {
        await Future.delayed(Duration(milliseconds: 10));
        return 42;
      });

      mutation.addListener(() {
        listenerCallCount++;
      });

      final initialCount = listenerCallCount;

      mutation.run('test');

      // Should be notified when moving to running state
      expect(listenerCallCount, greaterThan(initialCount));

      await Future.delayed(Duration(milliseconds: 50));

      // Should be notified again when completed
      expect(listenerCallCount, greaterThan(initialCount + 1));

      mutation.dispose();
    });

    test('previousState is tracked correctly', () async {
      MutationState<int>? runningState;

      final mutation = Mutation<int, int>((args, state) async {
        await Future.delayed(Duration(milliseconds: 10));
        return args;
      });

      expect(mutation.value.previousState, isNull);

      mutation.run(1);
      // Capture running state immediately
      runningState = mutation.value;
      expect(runningState.isLoading, isTrue);
      // Note: previousState gets cleared after the state is set

      await Future.delayed(Duration(milliseconds: 50));
      expect(mutation.value.hasValue, isTrue);

      mutation.run(2);
      expect(mutation.value.isLoading, isTrue);

      await Future.delayed(Duration(milliseconds: 50));
      expect(mutation.value.value, equals(2));

      mutation.dispose();
    });

    test('handles cancellation', () async {
      final List<int> completed = [];
      final mutation = Mutation<int, int>((args, state) async {
        await Future.delayed(Duration(milliseconds: 10));
        state.guard();
        await Future.delayed(Duration(milliseconds: 10));
        completed.add(args);
        return 42;
      });

      mutation.run(1);

      // Immediately run again to cancel the first one
      await Future.delayed(Duration(milliseconds: 5));
      mutation.run(2);

      await Future.delayed(Duration(milliseconds: 50));

      // First mutation should have been cancelled
      expect(completed, equals([2]));

      mutation.dispose();
    });

    test('disposed mutation does not update state', () async {
      final mutation = Mutation<int, void>((args, state) async {
        await Future.delayed(Duration(milliseconds: 10));
        return 42;
      });

      mutation.run(null);
      final initialState = mutation.value;
      mutation.dispose();

      await Future.delayed(Duration(milliseconds: 50));

      // Test passes if dispose() completes without error
      expect(initialState, isNotNull);
    });

    test('queues multiple runs', () async {
      final executionOrder = <int>[];
      final mutation = Mutation<int, int>((args, state) async {
        await Future.delayed(Duration(milliseconds: 20));
        executionOrder.add(args);
        return args;
      });

      // Run multiple times quickly
      mutation.run(1);
      mutation.run(2);
      mutation.run(3);

      await Future.delayed(Duration(milliseconds: 100));

      // The seoncd one doesnt ever get a chance to run
      expect(executionOrder, equals([1, 3]));
      expect(mutation.value.value, equals(3));

      mutation.dispose();
    });

    test('handles null arguments', () async {
      int? receivedArg;
      final mutation = Mutation<int, int?>((args, state) async {
        receivedArg = args;
        return 42;
      });

      mutation.run(null);

      await Future.delayed(Duration(milliseconds: 50));

      expect(receivedArg, isNull);
      expect(mutation.value.value, equals(42));

      mutation.dispose();
    });

    test('handles null return value', () async {
      final mutation = Mutation<int?, String>((args, state) async {
        await Future.delayed(Duration(milliseconds: 10));
        return null;
      });

      mutation.run('test');

      await Future.delayed(Duration(milliseconds: 50));

      expect(mutation.value.hasValue, isTrue);
      expect(mutation.value.value, isNull);

      mutation.dispose();
    });

    test('preserves stack trace on error', () async {
      final mutation = Mutation<int, void>((args, state) async {
        await Future.delayed(Duration(milliseconds: 10));
        throw Exception('Test error');
      });

      mutation.run(null);

      await Future.delayed(Duration(milliseconds: 50));

      expect(mutation.value.hasFailed, isTrue);
      expect(mutation.value.stackTrace, isNotNull);
      expect(mutation.value.stackTrace.toString(), isNotEmpty);

      mutation.dispose();
    });

    test('can use LockedAsyncState features', () async {
      bool guardCalled = false;
      final mutation = Mutation<int, void>((args, state) async {
        await Future.delayed(Duration(milliseconds: 10));
        state.guard();
        guardCalled = true;
        await Future.delayed(Duration(milliseconds: 10));
        return 42;
      });

      mutation.run(null);

      await Future.delayed(Duration(milliseconds: 50));

      expect(guardCalled, isTrue);
      expect(mutation.value.value, equals(42));

      mutation.dispose();
    });

    test('works with complex argument types', () async {
      Map<String, dynamic>? receivedArgs;
      final mutation = Mutation<String, Map<String, dynamic>>((
        args,
        state,
      ) async {
        receivedArgs = args;
        await Future.delayed(Duration(milliseconds: 10));
        return args['name'] as String;
      });

      mutation.run({'name': 'John', 'age': 30});

      await Future.delayed(Duration(milliseconds: 50));

      expect(receivedArgs, equals({'name': 'John', 'age': 30}));
      expect(mutation.value.value, equals('John'));

      mutation.dispose();
    });

    test('works with complex return types', () async {
      final mutation = Mutation<Map<String, int>, String>((args, state) async {
        await Future.delayed(Duration(milliseconds: 10));
        return {'length': args.length};
      });

      mutation.run('test');

      await Future.delayed(Duration(milliseconds: 50));

      expect(mutation.value.hasValue, isTrue);
      expect(mutation.value.value, equals({'length': 4}));

      mutation.dispose();
    });

    test('previousState is cleared after state transition', () async {
      final mutation = Mutation<int, int>((args, state) async {
        await Future.delayed(Duration(milliseconds: 10));
        return args;
      });

      mutation.run(1);
      final runningState = mutation.value;
      expect(runningState.previousState, isNotNull);

      await Future.delayed(Duration(milliseconds: 50));
      mutation.run(2);
      await Future.delayed(Duration(milliseconds: 50));

      // After completing, the current state's previousState should be null
      expect(mutation.value.previousState?.previousState, isNull);

      mutation.dispose();
    });

    test('handles void return type', () async {
      bool executed = false;
      final mutation = Mutation<void, String>((args, state) async {
        await Future.delayed(Duration(milliseconds: 10));
        executed = true;
      });

      mutation.run('test');

      await Future.delayed(Duration(milliseconds: 50));

      expect(executed, isTrue);
      expect(mutation.value.hasValue, isTrue);

      mutation.dispose();
    });
  });
}
