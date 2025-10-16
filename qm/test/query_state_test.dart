import 'package:flutter_test/flutter_test.dart';
import 'package:qm/qm.dart';

void main() {
  group('QueryState', () {
    group('LoadingQueryState', () {
      test('has correct state flags', () {
        final state = LoadingQueryState<int>();

        expect(state.isLoading, isTrue);
        expect(state.hasValue, isFalse);
        expect(state.hasFailed, isFalse);
      });

      test('returns null for value, error, and stackTrace', () {
        final state = LoadingQueryState<int>();

        expect(state.value, isNull);
        expect(state.error, isNull);
        expect(state.stackTrace, isNull);
      });

      test('can have previousState', () {
        final previous = CompletedQueryState<int>(42);
        final state = LoadingQueryState<int>(previous);

        expect(state.previousState, equals(previous));
      });

      test('equals another LoadingQueryState', () {
        final state1 = LoadingQueryState<int>();
        final state2 = LoadingQueryState<int>();

        expect(state1, equals(state2));
      });

      test('clearPreviousState removes previousState', () {
        final previous = CompletedQueryState<int>(42);
        final state = LoadingQueryState<int>(previous);

        expect(state.previousState, isNotNull);

        state.clearPreviousState();

        expect(state.previousState, isNull);
      });
    });

    group('CompletedQueryState', () {
      test('has correct state flags', () {
        final state = CompletedQueryState<int>(42);

        expect(state.isLoading, isFalse);
        expect(state.hasValue, isTrue);
        expect(state.hasFailed, isFalse);
      });

      test('returns correct value', () {
        final state = CompletedQueryState<int>(42);

        expect(state.value, equals(42));
        expect(state.error, isNull);
        expect(state.stackTrace, isNull);
      });

      test('can have previousState', () {
        final previous = LoadingQueryState<int>();
        final state = CompletedQueryState<int>(42, previous);

        expect(state.previousState, equals(previous));
      });

      test('equals another CompletedQueryState with same value', () {
        final state1 = CompletedQueryState<int>(42);
        final state2 = CompletedQueryState<int>(42);

        expect(state1, equals(state2));
      });

      test('does not equal CompletedQueryState with different value', () {
        final state1 = CompletedQueryState<int>(42);
        final state2 = CompletedQueryState<int>(43);

        expect(state1, isNot(equals(state2)));
      });

      test('handles null values', () {
        final state = CompletedQueryState<int?>(null);

        expect(state.hasValue, isTrue);
        expect(state.value, isNull);
      });

      test('clearPreviousState removes previousState', () {
        final previous = LoadingQueryState<int>();
        final state = CompletedQueryState<int>(42, previous);

        expect(state.previousState, isNotNull);

        state.clearPreviousState();

        expect(state.previousState, isNull);
      });
    });

    group('FailedQueryState', () {
      final testError = Exception('Test error');
      final testStackTrace = StackTrace.current;

      test('has correct state flags', () {
        final state = FailedQueryState<int>(testError, testStackTrace);

        expect(state.isLoading, isFalse);
        expect(state.hasValue, isFalse);
        expect(state.hasFailed, isTrue);
      });

      test('returns correct error and stackTrace', () {
        final state = FailedQueryState<int>(testError, testStackTrace);

        expect(state.value, isNull);
        expect(state.error, equals(testError));
        expect(state.stackTrace, equals(testStackTrace));
      });

      test('can have previousState', () {
        final previous = CompletedQueryState<int>(42);
        final state = FailedQueryState<int>(
          testError,
          testStackTrace,
          previous,
        );

        expect(state.previousState, equals(previous));
      });

      test(
        'equals another FailedQueryState with same error and stackTrace',
        () {
          final state1 = FailedQueryState<int>(testError, testStackTrace);
          final state2 = FailedQueryState<int>(testError, testStackTrace);

          expect(state1, equals(state2));
        },
      );

      test('does not equal FailedQueryState with different error', () {
        final state1 = FailedQueryState<int>(testError, testStackTrace);
        final state2 = FailedQueryState<int>(
          Exception('Different error'),
          testStackTrace,
        );

        expect(state1, isNot(equals(state2)));
      });

      test('clearPreviousState removes previousState', () {
        final previous = LoadingQueryState<int>();
        final state = FailedQueryState<int>(
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
      test('calls loading callback for LoadingQueryState', () {
        final state = LoadingQueryState<int>();

        final result = state.map<String>(
          loading: () => 'loading',
          data: (value) => 'data: $value',
          failed: (error, stackTrace) => 'failed',
        );

        expect(result, equals('loading'));
      });

      test('calls data callback for CompletedQueryState', () {
        final state = CompletedQueryState<int>(42);

        final result = state.map<String>(
          loading: () => 'loading',
          data: (value) => 'data: $value',
          failed: (error, stackTrace) => 'failed',
        );

        expect(result, equals('data: 42'));
      });

      test('calls failed callback for FailedQueryState', () {
        final error = Exception('Test error');
        final stackTrace = StackTrace.current;
        final state = FailedQueryState<int>(error, stackTrace);

        final result = state.map<String>(
          loading: () => 'loading',
          data: (value) => 'data: $value',
          failed: (e, st) => 'failed: ${e.toString()}',
        );

        expect(result, equals('failed: Exception: Test error'));
      });
    });

    group('when', () {
      test('calls loading callback for LoadingQueryState without previous', () {
        final state = LoadingQueryState<int>();

        final result = state.when<String>(
          loading: () => 'loading',
          data: (value) => 'data: $value',
          failed: (error, stackTrace) => 'failed',
        );

        expect(result, equals('loading'));
      });

      test('calls data callback for CompletedQueryState', () {
        final state = CompletedQueryState<int>(42);

        final result = state.when<String>(
          loading: () => 'loading',
          data: (value) => 'data: $value',
          failed: (error, stackTrace) => 'failed',
        );

        expect(result, equals('data: 42'));
      });

      test('calls failed callback for FailedQueryState', () {
        final error = Exception('Test error');
        final stackTrace = StackTrace.current;
        final state = FailedQueryState<int>(error, stackTrace);

        final result = state.when<String>(
          loading: () => 'loading',
          data: (value) => 'data: $value',
          failed: (e, st) => 'failed',
        );

        expect(result, equals('failed'));
      });

      test(
        'skipLoadingOnRestartAfterSuccess shows previous data during loading',
        () {
          final previous = CompletedQueryState<int>(42);
          final state = LoadingQueryState<int>(previous);

          final result = state.when<String>(
            skipLoadingOnRestartAfterSuccess: true,
            loading: () => 'loading',
            data: (value) => 'data: $value',
            failed: (error, stackTrace) => 'failed',
          );

          expect(result, equals('data: 42'));
        },
      );

      test(
        'skipLoadingOnRestartAfterSuccess false shows loading during loading',
        () {
          final previous = CompletedQueryState<int>(42);
          final state = LoadingQueryState<int>(previous);

          final result = state.when<String>(
            skipLoadingOnRestartAfterSuccess: false,
            loading: () => 'loading',
            data: (value) => 'data: $value',
            failed: (error, stackTrace) => 'failed',
          );

          expect(result, equals('loading'));
        },
      );

      test(
        'skipLoadingOnRestartAfterFailure false shows loading during loading',
        () {
          final error = Exception('Test error');
          final stackTrace = StackTrace.current;
          final previous = FailedQueryState<int>(error, stackTrace);
          final state = LoadingQueryState<int>(previous);

          final result = state.when<String>(
            loading: () => 'loading',
            data: (value) => 'data: $value',
            failed: (e, st) => 'failed',
          );

          expect(result, equals('loading'));
        },
      );

      test('both skip flags can be used together', () {
        final previous = CompletedQueryState<int>(42);
        final state = LoadingQueryState<int>(previous);

        final result = state.when<String>(
          skipLoadingOnRestartAfterSuccess: true,
          loading: () => 'loading',
          data: (value) => 'data: $value',
          failed: (e, st) => 'failed',
        );

        expect(result, equals('data: 42'));
      });
    });

    group('previousState behavior', () {
      test('LoadingQueryState can chain previousStates', () {
        final first = CompletedQueryState<int>(1);
        final second = LoadingQueryState<int>(first);
        final third = CompletedQueryState<int>(2, second);

        expect(third.previousState, equals(second));
        expect(third.previousState!.previousState, equals(first));
      });

      test('CompletedQueryState can have any previousState', () {
        final loading = LoadingQueryState<int>();
        final state = CompletedQueryState<int>(42, loading);

        expect(state.previousState, equals(loading));
      });

      test('FailedQueryState can have any previousState', () {
        final loading = LoadingQueryState<int>();
        final state = FailedQueryState<int>(
          Exception('error'),
          StackTrace.current,
          loading,
        );

        expect(state.previousState, equals(loading));
      });
    });

    group('Type safety', () {
      test('works with different types', () {
        final intState = CompletedQueryState<int>(42);
        final stringState = CompletedQueryState<String>('hello');
        final listState = CompletedQueryState<List<int>>([1, 2, 3]);

        expect(intState.value, equals(42));
        expect(stringState.value, equals('hello'));
        expect(listState.value, equals([1, 2, 3]));
      });

      test('nullable types work correctly', () {
        final state1 = CompletedQueryState<int?>(null);
        final state2 = CompletedQueryState<int?>(42);

        expect(state1.value, isNull);
        expect(state2.value, equals(42));
      });
    });
  });
}
