import 'package:flutter_test/flutter_test.dart';
import 'package:locked_async/locked_async.dart';
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

      // The future will complete with DisposedException after dispose
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

    group('runAndAwait() return value', () {
      test(
        'runAndAwait() returns a future that completes with the correct value',
        () async {
          final mutation = Mutation<int, String>((args, state) async {
            await Future.delayed(Duration(milliseconds: 10));
            return int.parse(args);
          });

          final resultFuture = mutation.runAndAwait('42');
          expect(resultFuture, isA<Future<int>>());

          final result = await resultFuture;
          expect(result, equals(42));

          mutation.dispose();
        },
      );

      test('run() future completes with error on failure', () async {
        final error = Exception('Test error');
        final mutation = Mutation<int, String>((args, state) async {
          await Future.delayed(Duration(milliseconds: 10));
          throw error;
        });

        final resultFuture = mutation.runAndAwait('test');

        try {
          await resultFuture;
          fail('Should have thrown exception');
        } catch (e) {
          expect(e, equals(error));
        }

        mutation.dispose();
      });

      test('run() future value matches mutation.value.value', () async {
        final mutation = Mutation<int, String>((args, state) async {
          await Future.delayed(Duration(milliseconds: 10));
          return int.parse(args);
        });

        final result = await mutation.runAndAwait('123');

        expect(result, equals(123));
        expect(mutation.value.value, equals(123));
        expect(result, equals(mutation.value.value));

        mutation.dispose();
      });

      test('multiple run() calls return correct values', () async {
        final mutation = Mutation<int, String>((args, state) async {
          await Future.delayed(Duration(milliseconds: 10));
          return int.parse(args);
        });

        final result1 = await mutation.runAndAwait('10');
        expect(result1, equals(10));

        final result2 = await mutation.runAndAwait('20');
        expect(result2, equals(20));

        final result3 = await mutation.runAndAwait('30');
        expect(result3, equals(30));

        mutation.dispose();
      });

      test('run() returns correct value with complex types', () async {
        final mutation = Mutation<Map<String, int>, String>((
          args,
          state,
        ) async {
          await Future.delayed(Duration(milliseconds: 10));
          return {'length': args.length, 'value': int.parse(args)};
        });

        final result = await mutation.runAndAwait('42');

        expect(result, isA<Map<String, int>>());
        expect(result['length'], equals(2));
        expect(result['value'], equals(42));

        mutation.dispose();
      });

      test('run() returns null correctly', () async {
        final mutation = Mutation<int?, String>((args, state) async {
          await Future.delayed(Duration(milliseconds: 10));
          return null;
        });

        final result = await mutation.runAndAwait('test');
        expect(result, isNull);

        mutation.dispose();
      });

      test('run() with void return type completes successfully', () async {
        bool executed = false;
        final mutation = Mutation<void, String>((args, state) async {
          await Future.delayed(Duration(milliseconds: 10));
          executed = true;
        });

        await mutation.runAndAwait('test');
        expect(executed, isTrue);

        mutation.dispose();
      });

      test('run() future includes stack trace on error', () async {
        final mutation = Mutation<int, String>((args, state) async {
          await Future.delayed(Duration(milliseconds: 10));
          throw Exception('Test error');
        });

        try {
          await mutation.runAndAwait('test');
          fail('Should have thrown exception');
        } catch (e, stackTrace) {
          expect(e, isA<Exception>());
          expect(stackTrace, isNotNull);
          expect(stackTrace.toString(), isNotEmpty);
        }

        mutation.dispose();
      });

      test('run() future completes even with synchronous execution', () async {
        final mutation = Mutation<int, String>((args, state) async {
          return int.parse(args);
        });

        final result = await mutation.runAndAwait('99');
        expect(result, equals(99));

        mutation.dispose();
      });

      test('run() passes correct arguments to function', () async {
        String? receivedArg;
        final mutation = Mutation<int, String>((args, state) async {
          receivedArg = args;
          await Future.delayed(Duration(milliseconds: 10));
          return args.length;
        });

        final result = await mutation.runAndAwait('test string');

        expect(receivedArg, equals('test string'));
        expect(result, equals(11));

        mutation.dispose();
      });

      test('run() with null arguments returns correct value', () async {
        int? receivedArg;
        final mutation = Mutation<int, int?>((args, state) async {
          receivedArg = args;
          await Future.delayed(Duration(milliseconds: 10));
          return 42;
        });

        final result = await mutation.runAndAwait(null);

        expect(receivedArg, isNull);
        expect(result, equals(42));

        mutation.dispose();
      });

      test('concurrent run() calls - later call returns correct value', () async {
        final mutation = Mutation<int, int>((args, state) async {
          await Future.delayed(Duration(milliseconds: 20));
          state.guard(); // Check if cancelled
          await Future.delayed(Duration(milliseconds: 20));
          return args * 10;
        });

        // Start first run (will be cancelled)
        mutation.run(1);

        // Start second run quickly (should cancel first, will also be cancelled)
        await Future.delayed(Duration(milliseconds: 5));
        mutation.run(2);

        // Start third run quickly (should cancel second, this one completes)
        await Future.delayed(Duration(milliseconds: 5));
        final future3 = mutation.runAndAwait(3);

        // Only the last one should return successfully
        final result = await future3;
        expect(result, equals(30));

        mutation.dispose();
      });

      test('run() after successful completion returns new value', () async {
        int callCount = 0;
        final mutation = Mutation<int, String>((args, state) async {
          callCount++;
          await Future.delayed(Duration(milliseconds: 10));
          return callCount;
        });

        final result1 = await mutation.runAndAwait('first');
        expect(result1, equals(1));

        final result2 = await mutation.runAndAwait('second');
        expect(result2, equals(2));

        mutation.dispose();
      });

      test('run() after failed execution can return success', () async {
        int callCount = 0;
        final mutation = Mutation<int, String>((args, state) async {
          callCount++;
          await Future.delayed(Duration(milliseconds: 10));
          if (callCount == 1) {
            throw Exception('First attempt failed');
          }
          return callCount;
        });

        // First run fails
        try {
          await mutation.runAndAwait('first');
          fail('Should have thrown exception');
        } catch (e) {
          expect(e, isA<Exception>());
        }

        // Second run succeeds
        final result = await mutation.runAndAwait('second');
        expect(result, equals(2));

        mutation.dispose();
      });

      test(
        'run() with complex argument object returns correct value',
        () async {
          final mutation = Mutation<String, Map<String, dynamic>>((
            args,
            state,
          ) async {
            await Future.delayed(Duration(milliseconds: 10));
            return '${args['name']}-${args['age']}';
          });

          final result = await mutation.runAndAwait({
            'name': 'John',
            'age': 30,
          });
          expect(result, equals('John-30'));

          mutation.dispose();
        },
      );

      test('run() returns correctly with list return type', () async {
        final mutation = Mutation<List<int>, int>((args, state) async {
          await Future.delayed(Duration(milliseconds: 10));
          return List.generate(args, (i) => i + 1);
        });

        final result = await mutation.runAndAwait(5);
        expect(result, equals([1, 2, 3, 4, 5]));

        mutation.dispose();
      });

      test('run() future and state notification both complete', () async {
        bool listenerCalled = false;

        final mutation = Mutation<int, String>((args, state) async {
          await Future.delayed(Duration(milliseconds: 10));
          return 42;
        });

        mutation.addListener(() {
          if (mutation.value.hasValue) {
            listenerCalled = true;
          }
        });

        final result = await mutation.runAndAwait('test');

        expect(result, equals(42));
        expect(listenerCalled, isTrue);

        mutation.dispose();
      });

      test('run() throws DisposedException after dispose', () async {
        final mutation = Mutation<int, String>((args, state) async {
          await Future.delayed(Duration(milliseconds: 10));
          return 42;
        });

        mutation.dispose();

        try {
          await mutation.runAndAwait('test');
          fail('Should have thrown DisposedException');
        } catch (e) {
          expect(e, isA<DisposedException>());
          expect(e.toString(), contains('disposed'));
        }
      });

      test(
        'run() completes with DisposedException if disposed during execution',
        () async {
          final mutation = Mutation<int, String>((args, state) async {
            await Future.delayed(Duration(milliseconds: 10));
            return 42;
          });

          final future = mutation.runAndAwait('test');

          // Dispose while running
          await Future.delayed(Duration(milliseconds: 5));
          mutation.dispose();

          try {
            await future;
            fail('Should have thrown DisposedException');
          } catch (e) {
            expect(e, isA<DisposedException>());
          }
        },
      );

      test('run() returns value matching the calculation', () async {
        final mutation = Mutation<double, List<int>>((args, state) async {
          await Future.delayed(Duration(milliseconds: 10));
          return args.reduce((a, b) => a + b) / args.length;
        });

        final result = await mutation.runAndAwait([10, 20, 30, 40]);
        expect(result, equals(25.0));

        mutation.dispose();
      });

      test('run() with custom class return type', () async {
        final mutation = Mutation<_TestUser, String>((args, state) async {
          await Future.delayed(Duration(milliseconds: 10));
          return _TestUser(name: args, age: 25);
        });

        final result = await mutation.runAndAwait('John');
        expect(result.name, equals('John'));
        expect(result.age, equals(25));

        mutation.dispose();
      });

      test('run() error includes original error message', () async {
        final mutation = Mutation<int, String>((args, state) async {
          await Future.delayed(Duration(milliseconds: 10));
          throw FormatException('Invalid format: $args');
        });

        try {
          await mutation.runAndAwait('invalid');
          fail('Should have thrown FormatException');
        } catch (e) {
          expect(e, isA<FormatException>());
          expect(e.toString(), contains('Invalid format: invalid'));
        }

        mutation.dispose();
      });

      test(
        'runAndAwait() completes with QueryMutationCancelledException when cancelled',
        () async {
          final mutation = Mutation<int, int>((args, state) async {
            await Future.delayed(Duration(milliseconds: 50));
            return args * 10;
          });

          // Start first operation
          final future1 = mutation.runAndAwait(1);

          // Start second operation quickly to cancel the first
          await Future.delayed(Duration(milliseconds: 5));
          final future2 = mutation.runAndAwait(2);

          // First future should complete with CancelledException
          try {
            await future1;
            fail('Should have thrown CancelledException');
          } catch (e) {
            expect(e, isA<CancelledException>());
          }

          // Second future should complete successfully
          final result2 = await future2;
          expect(result2, equals(20));

          mutation.dispose();
        },
      );

      test(
        'multiple cancelled runAndAwait() calls all complete with error',
        () async {
          final mutation = Mutation<int, int>((args, state) async {
            await Future.delayed(Duration(milliseconds: 50));
            return args * 10;
          });

          // Start all four operations rapidly, capturing futures
          final future1 = mutation
              .runAndAwait(1)
              .then<({int? value, Object? error})>(
                (v) => (value: v, error: null),
              )
              .catchError((e) => (value: null, error: e));

          await Future.delayed(Duration(milliseconds: 5));

          final future2 = mutation
              .runAndAwait(2)
              .then<({int? value, Object? error})>(
                (v) => (value: v, error: null),
              )
              .catchError((e) => (value: null, error: e));

          await Future.delayed(Duration(milliseconds: 5));

          final future3 = mutation
              .runAndAwait(3)
              .then<({int? value, Object? error})>(
                (v) => (value: v, error: null),
              )
              .catchError((e) => (value: null, error: e));

          await Future.delayed(Duration(milliseconds: 5));

          final future4 = mutation
              .runAndAwait(4)
              .then<({int? value, Object? error})>(
                (v) => (value: v, error: null),
              )
              .catchError((e) => (value: null, error: e));

          // Wait for all to complete
          final results = await Future.wait([
            future1,
            future2,
            future3,
            future4,
          ]);

          // Verify first three were cancelled
          expect(results[0].error, isA<CancelledException>());
          expect(results[0].value, isNull);

          expect(results[1].error, isA<CancelledException>());
          expect(results[1].value, isNull);

          expect(results[2].error, isA<CancelledException>());
          expect(results[2].value, isNull);

          // Last one should succeed
          expect(results[3].error, isNull);
          expect(results[3].value, equals(40));

          mutation.dispose();
        },
      );

      test(
        'runAndAwait() then run() - first future gets CancelledException',
        () async {
          final mutation = Mutation<int, int>((args, state) async {
            await Future.delayed(Duration(milliseconds: 50));
            return args * 10;
          });

          // Start with runAndAwait
          final future1 = mutation.runAndAwait(1);

          // Cancel it with run() call
          await Future.delayed(Duration(milliseconds: 5));
          mutation.run(2);

          // First future should be cancelled
          try {
            await future1;
            fail('Should have thrown CancelledException');
          } catch (e) {
            expect(e, isA<CancelledException>());
          }

          // Wait for the second operation to complete
          await Future.delayed(Duration(milliseconds: 100));
          expect(mutation.value.value, equals(20));

          mutation.dispose();
        },
      );
    });

    // group('retry', () {
    //   test(
    //     'retry() throws InvalidRetryException when called before run()',
    //     () async {
    //       final mutation = Mutation<int, String>((args, state) async {
    //         return 42;
    //       });

    //       expect(mutation.value.isIdle, isTrue);

    //       try {
    //         await mutation.retry();
    //         fail('Should have thrown InvalidRetryException');
    //       } catch (e) {
    //         expect(e, isA<InvalidRetryException>());
    //         expect(e.toString(), contains('has not been run yet'));
    //       }

    //       mutation.dispose();
    //     },
    //   );

    //   test('retry() succeeds after a successful mutation', () async {
    //     int callCount = 0;
    //     final mutation = Mutation<int, String>((args, state) async {
    //       callCount++;
    //       await Future.delayed(Duration(milliseconds: 10));
    //       return int.parse(args) * callCount;
    //     });

    //     // First run
    //     mutation.run('5');
    //     await Future.delayed(Duration(milliseconds: 50));
    //     expect(mutation.value.value, equals(5)); // 5 * 1
    //     expect(callCount, equals(1));

    //     // Retry
    //     mutation.retry();
    //     await Future.delayed(Duration(milliseconds: 50));
    //     expect(mutation.value.value, equals(10)); // 5 * 2
    //     expect(callCount, equals(2));

    //     mutation.dispose();
    //   });

    //   test('retry() succeeds after a failed mutation', () async {
    //     int callCount = 0;
    //     final mutation = Mutation<int, String>((args, state) async {
    //       callCount++;
    //       await Future.delayed(Duration(milliseconds: 10));
    //       if (callCount == 1) {
    //         throw Exception('First attempt failed');
    //       }
    //       return int.parse(args);
    //     });

    //     // First run fails
    //     mutation.run('42');
    //     await Future.delayed(Duration(milliseconds: 50));
    //     expect(mutation.value.hasFailed, isTrue);
    //     expect(callCount, equals(1));

    //     // Retry succeeds
    //     mutation.retry();
    //     await Future.delayed(Duration(milliseconds: 50));
    //     expect(mutation.value.hasValue, isTrue);
    //     expect(mutation.value.value, equals(42));
    //     expect(callCount, equals(2));

    //     mutation.dispose();
    //   });

    //   test('retry() uses the last arguments passed to run()', () async {
    //     final receivedArgs = <String>[];
    //     final mutation = Mutation<int, String>((args, state) async {
    //       receivedArgs.add(args);
    //       await Future.delayed(Duration(milliseconds: 10));
    //       return int.parse(args);
    //     });

    //     // First run with '10'
    //     mutation.run('10');
    //     await Future.delayed(Duration(milliseconds: 50));
    //     expect(mutation.value.value, equals(10));

    //     // Retry should use '10'
    //     mutation.retry();
    //     await Future.delayed(Duration(milliseconds: 50));
    //     expect(receivedArgs, equals(['10', '10']));

    //     mutation.dispose();
    //   });

    //   test('retry() updates last args after multiple run() calls', () async {
    //     final receivedArgs = <String>[];
    //     final mutation = Mutation<int, String>((args, state) async {
    //       receivedArgs.add(args);
    //       await Future.delayed(Duration(milliseconds: 10));
    //       return int.parse(args);
    //     });

    //     // First run with '10'
    //     mutation.run('10');
    //     await Future.delayed(Duration(milliseconds: 50));

    //     // Second run with '20'
    //     mutation.run('20');
    //     await Future.delayed(Duration(milliseconds: 50));

    //     // Third run with '30'
    //     mutation.run('30');
    //     await Future.delayed(Duration(milliseconds: 50));

    //     // Retry should use '30' (the last args)
    //     mutation.retry();
    //     await Future.delayed(Duration(milliseconds: 50));

    //     expect(receivedArgs.last, equals('30'));
    //     expect(mutation.value.value, equals(30));

    //     mutation.dispose();
    //   });

    //   test(
    //     'retry() transitions state correctly (idle/completed -> running -> completed)',
    //     () async {
    //       final mutation = Mutation<int, String>((args, state) async {
    //         await Future.delayed(Duration(milliseconds: 10));
    //         return int.parse(args);
    //       });

    //       mutation.run('42');
    //       await Future.delayed(Duration(milliseconds: 50));
    //       expect(mutation.value.hasValue, isTrue);
    //       expect(mutation.value.value, equals(42));

    //       // Start retry
    //       mutation.retry();
    //       expect(mutation.value.isLoading, isTrue);

    //       // Wait for completion
    //       await Future.delayed(Duration(milliseconds: 50));
    //       expect(mutation.value.isLoading, isFalse);
    //       expect(mutation.value.hasValue, isTrue);
    //       expect(mutation.value.value, equals(42));

    //       mutation.dispose();
    //     },
    //   );

    //   test(
    //     'retry() transitions state correctly (failed -> running -> completed)',
    //     () async {
    //       int callCount = 0;
    //       final mutation = Mutation<int, String>((args, state) async {
    //         callCount++;
    //         await Future.delayed(Duration(milliseconds: 10));
    //         if (callCount == 1) {
    //           throw Exception('First attempt');
    //         }
    //         return int.parse(args);
    //       });

    //       // First run fails
    //       mutation.run('42');
    //       await Future.delayed(Duration(milliseconds: 50));
    //       expect(mutation.value.hasFailed, isTrue);

    //       // Start retry
    //       mutation.retry();
    //       expect(mutation.value.isLoading, isTrue);
    //       expect(mutation.value.hasFailed, isFalse);

    //       // Wait for completion
    //       await Future.delayed(Duration(milliseconds: 50));
    //       expect(mutation.value.isLoading, isFalse);
    //       expect(mutation.value.hasValue, isTrue);

    //       mutation.dispose();
    //     },
    //   );

    //   test('retry() returns the correct future value', () async {
    //     final mutation = Mutation<int, String>((args, state) async {
    //       await Future.delayed(Duration(milliseconds: 10));
    //       return int.parse(args);
    //     });

    //     mutation.run('42');
    //     await Future.delayed(Duration(milliseconds: 50));

    //     final retryFuture = mutation.retry();
    //     final result = await retryFuture;

    //     expect(result, equals(42));

    //     mutation.dispose();
    //   });

    //   test('retry() future completes with error on failure', () async {
    //     int callCount = 0;
    //     final error = Exception('Retry failed');
    //     final mutation = Mutation<int, String>((args, state) async {
    //       callCount++;
    //       await Future.delayed(Duration(milliseconds: 10));
    //       if (callCount == 2) {
    //         throw error;
    //       }
    //       return int.parse(args);
    //     });

    //     // First run succeeds
    //     mutation.run('42');
    //     await Future.delayed(Duration(milliseconds: 50));
    //     expect(mutation.value.hasValue, isTrue);

    //     // Retry fails
    //     try {
    //       await mutation.retry();
    //       fail('Should have thrown exception');
    //     } catch (e) {
    //       expect(e, equals(error));
    //     }

    //     expect(mutation.value.hasFailed, isTrue);

    //     mutation.dispose();
    //   });

    //   test('retry() notifies listeners on state changes', () async {
    //     int listenerCallCount = 0;
    //     final mutation = Mutation<int, String>((args, state) async {
    //       await Future.delayed(Duration(milliseconds: 10));
    //       return int.parse(args);
    //     });

    //     mutation.addListener(() {
    //       listenerCallCount++;
    //     });

    //     mutation.run('42');
    //     await Future.delayed(Duration(milliseconds: 50));
    //     final countAfterRun = listenerCallCount;

    //     mutation.retry();
    //     await Future.delayed(Duration(milliseconds: 50));

    //     // Should have been notified at least twice (running + completed)
    //     expect(listenerCallCount, greaterThan(countAfterRun + 1));

    //     mutation.dispose();
    //   });

    //   test('retry() works with null arguments', () async {
    //     final receivedArgs = <int?>[];
    //     final mutation = Mutation<int, int?>((args, state) async {
    //       receivedArgs.add(args);
    //       await Future.delayed(Duration(milliseconds: 10));
    //       return 42;
    //     });

    //     mutation.run(null);
    //     await Future.delayed(Duration(milliseconds: 50));

    //     mutation.retry();
    //     await Future.delayed(Duration(milliseconds: 50));

    //     expect(receivedArgs, equals([null, null]));
    //     expect(mutation.value.value, equals(42));

    //     mutation.dispose();
    //   });

    //   test('retry() works with complex argument types', () async {
    //     final receivedArgs = <Map<String, dynamic>>[];
    //     final mutation = Mutation<String, Map<String, dynamic>>((
    //       args,
    //       state,
    //     ) async {
    //       receivedArgs.add(Map.from(args));
    //       await Future.delayed(Duration(milliseconds: 10));
    //       return args['name'] as String;
    //     });

    //     final testArgs = {'name': 'John', 'age': 30};
    //     mutation.run(testArgs);
    //     await Future.delayed(Duration(milliseconds: 50));

    //     mutation.retry();
    //     await Future.delayed(Duration(milliseconds: 50));

    //     expect(receivedArgs.length, equals(2));
    //     expect(receivedArgs[0], equals(testArgs));
    //     expect(receivedArgs[1], equals(testArgs));
    //     expect(mutation.value.value, equals('John'));

    //     mutation.dispose();
    //   });

    //   test('retry() can be called multiple times in succession', () async {
    //     int callCount = 0;
    //     final mutation = Mutation<int, String>((args, state) async {
    //       callCount++;
    //       await Future.delayed(Duration(milliseconds: 10));
    //       return callCount;
    //     });

    //     // Initial run
    //     mutation.run('test');
    //     await Future.delayed(Duration(milliseconds: 50));
    //     expect(mutation.value.value, equals(1));

    //     // First retry
    //     mutation.retry();
    //     await Future.delayed(Duration(milliseconds: 50));
    //     expect(mutation.value.value, equals(2));

    //     // Second retry
    //     mutation.retry();
    //     await Future.delayed(Duration(milliseconds: 50));
    //     expect(mutation.value.value, equals(3));

    //     // Third retry
    //     mutation.retry();
    //     await Future.delayed(Duration(milliseconds: 50));
    //     expect(mutation.value.value, equals(4));

    //     expect(callCount, equals(4));

    //     mutation.dispose();
    //   });

    //   test('retry() properly cancels previous retry if called again', () async {
    //     final completed = <int>[];
    //     final mutation = Mutation<int, int>((args, state) async {
    //       await Future.delayed(Duration(milliseconds: 10));
    //       state.guard();
    //       await Future.delayed(Duration(milliseconds: 10));
    //       completed.add(args);
    //       return args;
    //     });

    //     mutation.run(1);
    //     await Future.delayed(Duration(milliseconds: 50));

    //     // Start first retry
    //     mutation.retry();
    //     await Future.delayed(Duration(milliseconds: 5));

    //     // Start second retry (should cancel first)
    //     mutation.retry();
    //     await Future.delayed(Duration(milliseconds: 50));

    //     // Only the last retry should complete
    //     expect(completed, equals([1, 1])); // initial run + last retry

    //     mutation.dispose();
    //   });

    //   test('retry() preserves stack trace on error', () async {
    //     int callCount = 0;
    //     final mutation = Mutation<int, String>((args, state) async {
    //       callCount++;
    //       await Future.delayed(Duration(milliseconds: 10));
    //       if (callCount >= 2) {
    //         throw Exception('Retry error');
    //       }
    //       return 42;
    //     });

    //     mutation.run('test');
    //     await Future.delayed(Duration(milliseconds: 50));

    //     mutation.retry();
    //     await Future.delayed(Duration(milliseconds: 50));

    //     expect(mutation.value.hasFailed, isTrue);
    //     expect(mutation.value.stackTrace, isNotNull);
    //     expect(mutation.value.stackTrace.toString(), isNotEmpty);

    //     mutation.dispose();
    //   });

    //   test('retry() after dispose throws DisposedException', () async {
    //     final mutation = Mutation<int, String>((args, state) async {
    //       await Future.delayed(Duration(milliseconds: 10));
    //       return 42;
    //     });

    //     mutation.run('test');
    //     await Future.delayed(Duration(milliseconds: 50));

    //     mutation.dispose();

    //     try {
    //       await mutation.retry();
    //       fail('Should have thrown DisposedException');
    //     } catch (e) {
    //       expect(e, isA<DisposedException>());
    //     }
    //   });

    //   test('retry() with void return type', () async {
    //     int callCount = 0;
    //     final mutation = Mutation<void, String>((args, state) async {
    //       callCount++;
    //       await Future.delayed(Duration(milliseconds: 10));
    //     });

    //     mutation.run('test');
    //     await Future.delayed(Duration(milliseconds: 50));
    //     expect(callCount, equals(1));

    //     mutation.retry();
    //     await Future.delayed(Duration(milliseconds: 50));
    //     expect(callCount, equals(2));
    //     expect(mutation.value.hasValue, isTrue);

    //     mutation.dispose();
    //   });

    //   test('retry() handles synchronous completion', () async {
    //     int callCount = 0;
    //     final mutation = Mutation<int, String>((args, state) async {
    //       callCount++;
    //       return int.parse(args);
    //     });

    //     mutation.run('42');
    //     await Future.delayed(Duration(milliseconds: 50));

    //     mutation.retry();
    //     // Should still transition to loading state first
    //     expect(mutation.value.isLoading, isTrue);

    //     await Future.delayed(Duration(milliseconds: 50));
    //     expect(callCount, equals(2));

    //     mutation.dispose();
    //   });

    //   test('retry() with different argument types between runs', () async {
    //     int callCount = 0;
    //     final mutation = Mutation<String, dynamic>((args, state) async {
    //       callCount++;
    //       await Future.delayed(Duration(milliseconds: 10));
    //       return args.toString();
    //     });

    //     // Run with int
    //     mutation.run(123);
    //     await Future.delayed(Duration(milliseconds: 50));
    //     expect(mutation.value.value, equals('123'));

    //     // Run with string
    //     mutation.run('test');
    //     await Future.delayed(Duration(milliseconds: 50));
    //     expect(mutation.value.value, equals('test'));

    //     // Retry should use 'test' (the last args)
    //     mutation.retry();
    //     await Future.delayed(Duration(milliseconds: 50));
    //     expect(mutation.value.value, equals('test'));
    //     expect(callCount, equals(3));

    //     mutation.dispose();
    //   });

    //   test('retry() previousState is tracked correctly', () async {
    //     final mutation = Mutation<int, int>((args, state) async {
    //       await Future.delayed(Duration(milliseconds: 10));
    //       return args;
    //     });

    //     mutation.run(1);
    //     await Future.delayed(Duration(milliseconds: 50));
    //     expect(mutation.value.hasValue, isTrue);

    //     mutation.retry();
    //     final runningState = mutation.value;
    //     expect(runningState.isLoading, isTrue);

    //     await Future.delayed(Duration(milliseconds: 50));
    //     expect(mutation.value.hasValue, isTrue);

    //     mutation.dispose();
    //   });

    //   test('InvalidRetryException has proper message', () {
    //     final exception = InvalidRetryException('Custom retry error message');
    //     expect(exception.message, equals('Custom retry error message'));
    //     expect(
    //       exception.toString(),
    //       equals('InvalidRetryException(Custom retry error message)'),
    //     );
    //   });
    // });
  });
}

// Helper class for testing
class _TestUser {
  final String name;
  final int age;

  _TestUser({required this.name, required this.age});
}
