import 'package:flutter_test/flutter_test.dart';
import 'package:qm/qm.dart';

void main() {
  group('MutationState', () {
    group('IdleMutationState', () {
      test('has correct state flags', () {
        final state = IdleMutationState<int>();

        expect(state.isIdle, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.hasValue, isFalse);
        expect(state.hasFailed, isFalse);
      });

      test('returns null for value, error, and stackTrace', () {
        final state = IdleMutationState<int>();

        expect(state.value, isNull);
        expect(state.error, isNull);
        expect(state.stackTrace, isNull);
      });

      test('can have previousState', () {
        final previous = CompletedMutationState<int>(42);
        final state = IdleMutationState<int>(previous);

        expect(state.previousState, equals(previous));
      });

      test('equals another IdleMutationState', () {
        final state1 = IdleMutationState<int>();
        final state2 = IdleMutationState<int>();

        expect(state1, equals(state2));
      });

      test('clearPreviousState removes previousState', () {
        final previous = CompletedMutationState<int>(42);
        final state = IdleMutationState<int>(previous);

        expect(state.previousState, isNotNull);

        state.clearPreviousState();

        expect(state.previousState, isNull);
      });
    });

    group('RunningMutationState', () {
      test('has correct state flags', () {
        final state = RunningMutationState<int>();

        expect(state.isIdle, isFalse);
        expect(state.isLoading, isTrue);
        expect(state.hasValue, isFalse);
        expect(state.hasFailed, isFalse);
      });

      test('returns null for value, error, and stackTrace', () {
        final state = RunningMutationState<int>();

        expect(state.value, isNull);
        expect(state.error, isNull);
        expect(state.stackTrace, isNull);
      });

      test('can have previousState', () {
        final previous = IdleMutationState<int>();
        final state = RunningMutationState<int>(previous);

        expect(state.previousState, equals(previous));
      });

      test('equals another RunningMutationState', () {
        final state1 = RunningMutationState<int>();
        final state2 = RunningMutationState<int>();

        expect(state1, equals(state2));
      });

      test('clearPreviousState removes previousState', () {
        final previous = IdleMutationState<int>();
        final state = RunningMutationState<int>(previous);

        expect(state.previousState, isNotNull);

        state.clearPreviousState();

        expect(state.previousState, isNull);
      });
    });

    group('CompletedMutationState', () {
      test('has correct state flags', () {
        final state = CompletedMutationState<int>(42);

        expect(state.isIdle, isFalse);
        expect(state.isLoading, isFalse);
        expect(state.hasValue, isTrue);
        expect(state.hasFailed, isFalse);
      });

      test('returns correct value', () {
        final state = CompletedMutationState<int>(42);

        expect(state.value, equals(42));
        expect(state.error, isNull);
        expect(state.stackTrace, isNull);
      });

      test('can have previousState', () {
        final previous = RunningMutationState<int>();
        final state = CompletedMutationState<int>(42, previous);

        expect(state.previousState, equals(previous));
      });

      test('equals another CompletedMutationState with same value', () {
        final state1 = CompletedMutationState<int>(42);
        final state2 = CompletedMutationState<int>(42);

        expect(state1, equals(state2));
      });

      test('does not equal CompletedMutationState with different value', () {
        final state1 = CompletedMutationState<int>(42);
        final state2 = CompletedMutationState<int>(43);

        expect(state1, isNot(equals(state2)));
      });

      test('handles null values', () {
        final state = CompletedMutationState<int?>(null);

        expect(state.hasValue, isTrue);
        expect(state.value, isNull);
      });

      test('clearPreviousState removes previousState', () {
        final previous = RunningMutationState<int>();
        final state = CompletedMutationState<int>(42, previous);

        expect(state.previousState, isNotNull);

        state.clearPreviousState();

        expect(state.previousState, isNull);
      });
    });

    group('FailedMutationState', () {
      final testError = Exception('Test error');
      final testStackTrace = StackTrace.current;

      test('has correct state flags', () {
        final state = FailedMutationState<int>(testError, testStackTrace);

        expect(state.isIdle, isFalse);
        expect(state.isLoading, isFalse);
        expect(state.hasValue, isFalse);
        expect(state.hasFailed, isTrue);
      });

      test('returns correct error and stackTrace', () {
        final state = FailedMutationState<int>(testError, testStackTrace);

        expect(state.value, isNull);
        expect(state.error, equals(testError));
        expect(state.stackTrace, equals(testStackTrace));
      });

      test('can have previousState', () {
        final previous = RunningMutationState<int>();
        final state = FailedMutationState<int>(
          testError,
          testStackTrace,
          previous,
        );

        expect(state.previousState, equals(previous));
      });

      test(
        'equals another FailedMutationState with same error and stackTrace',
        () {
          final state1 = FailedMutationState<int>(testError, testStackTrace);
          final state2 = FailedMutationState<int>(testError, testStackTrace);

          expect(state1, equals(state2));
        },
      );

      test('does not equal FailedMutationState with different error', () {
        final state1 = FailedMutationState<int>(testError, testStackTrace);
        final state2 = FailedMutationState<int>(
          Exception('Different error'),
          testStackTrace,
        );

        expect(state1, isNot(equals(state2)));
      });

      test('clearPreviousState removes previousState', () {
        final previous = RunningMutationState<int>();
        final state = FailedMutationState<int>(
          testError,
          testStackTrace,
          previous,
        );

        expect(state.previousState, isNotNull);

        state.clearPreviousState();

        expect(state.previousState, isNull);
      });
    });

    group('map', () {
      test('calls idle callback for IdleMutationState', () {
        final state = IdleMutationState<int>();

        final result = state.map<String>(
          idle: () => 'idle',
          running: () => 'running',
          data: (value) => 'data: $value',
          failed: (error, stackTrace) => 'failed',
        );

        expect(result, equals('idle'));
      });

      test('calls running callback for RunningMutationState', () {
        final state = RunningMutationState<int>();

        final result = state.map<String>(
          idle: () => 'idle',
          running: () => 'running',
          data: (value) => 'data: $value',
          failed: (error, stackTrace) => 'failed',
        );

        expect(result, equals('running'));
      });

      test('calls data callback for CompletedMutationState', () {
        final state = CompletedMutationState<int>(42);

        final result = state.map<String>(
          idle: () => 'idle',
          running: () => 'running',
          data: (value) => 'data: $value',
          failed: (error, stackTrace) => 'failed',
        );

        expect(result, equals('data: 42'));
      });

      test('calls failed callback for FailedMutationState', () {
        final error = Exception('Test error');
        final stackTrace = StackTrace.current;
        final state = FailedMutationState<int>(error, stackTrace);

        final result = state.map<String>(
          idle: () => 'idle',
          running: () => 'running',
          data: (value) => 'data: $value',
          failed: (e, st) => 'failed: ${e.toString()}',
        );

        expect(result, equals('failed: Exception: Test error'));
      });
    });

    group('previousState behavior', () {
      test('RunningMutationState can have IdleMutationState as previous', () {
        final idle = IdleMutationState<int>();
        final running = RunningMutationState<int>(idle);

        expect(running.previousState, equals(idle));
      });

      test(
        'CompletedMutationState can have RunningMutationState as previous',
        () {
          final running = RunningMutationState<int>();
          final completed = CompletedMutationState<int>(42, running);

          expect(completed.previousState, equals(running));
        },
      );

      test('FailedMutationState can have RunningMutationState as previous', () {
        final running = RunningMutationState<int>();
        final failed = FailedMutationState<int>(
          Exception('error'),
          StackTrace.current,
          running,
        );

        expect(failed.previousState, equals(running));
      });

      test('can chain multiple previousStates', () {
        final idle = IdleMutationState<int>();
        final running = RunningMutationState<int>(idle);
        final completed = CompletedMutationState<int>(42, running);

        expect(completed.previousState, equals(running));
        expect(completed.previousState!.previousState, equals(idle));
      });

      test(
        'RunningMutationState can have CompletedMutationState as previous',
        () {
          final completed = CompletedMutationState<int>(42);
          final running = RunningMutationState<int>(completed);

          expect(running.previousState, equals(completed));
        },
      );
    });

    group('Type safety', () {
      test('works with different types', () {
        final intState = CompletedMutationState<int>(42);
        final stringState = CompletedMutationState<String>('hello');
        final listState = CompletedMutationState<List<int>>([1, 2, 3]);

        expect(intState.value, equals(42));
        expect(stringState.value, equals('hello'));
        expect(listState.value, equals([1, 2, 3]));
      });

      test('nullable types work correctly', () {
        final state1 = CompletedMutationState<int?>(null);
        final state2 = CompletedMutationState<int?>(42);

        expect(state1.value, isNull);
        expect(state2.value, equals(42));
      });

      test('void type works correctly', () {
        final state = CompletedMutationState<void>(null);

        expect(state.hasValue, isTrue);
      });
    });

    group('State transitions', () {
      test('typical success flow', () {
        final idle = IdleMutationState<int>();
        final running = RunningMutationState<int>(idle);
        final completed = CompletedMutationState<int>(42, running);

        expect(idle.isIdle, isTrue);
        expect(running.isLoading, isTrue);
        expect(completed.hasValue, isTrue);
        expect(completed.value, equals(42));
      });

      test('typical failure flow', () {
        final error = Exception('Test error');
        final stackTrace = StackTrace.current;

        final idle = IdleMutationState<int>();
        final running = RunningMutationState<int>(idle);
        final failed = FailedMutationState<int>(error, stackTrace, running);

        expect(idle.isIdle, isTrue);
        expect(running.isLoading, isTrue);
        expect(failed.hasFailed, isTrue);
        expect(failed.error, equals(error));
      });

      test('multiple runs flow', () {
        final idle = IdleMutationState<int>();
        final running1 = RunningMutationState<int>(idle);
        final completed1 = CompletedMutationState<int>(1, running1);
        final running2 = RunningMutationState<int>(completed1);
        final completed2 = CompletedMutationState<int>(2, running2);

        expect(completed2.value, equals(2));
        expect(completed2.previousState, equals(running2));
        expect(running2.previousState, equals(completed1));
        expect(completed1.value, equals(1));
      });
    });
  });
}
