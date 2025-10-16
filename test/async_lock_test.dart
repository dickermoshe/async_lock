import 'dart:async';
import 'package:async_lock/async_lock.dart';
import 'package:test/test.dart';

void main() {
  group('AsyncLock', () {
    late AsyncLock lock;

    setUp(() {
      lock = AsyncLock();
    });

    group('basic functionality', () {
      test('runs a single task successfully', () async {
        var completed = false;
        await lock.run((state) async {
          completed = true;
        });
        expect(completed, isTrue);
      });

      test('returns value from task', () async {
        final result = await lock.run((state) async {
          return 42;
        });
        expect(result, equals(42));
      });

      test('runs task with delay', () async {
        var completed = false;
        await lock.run((state) async {
          await Future.delayed(Duration(milliseconds: 10));
          completed = true;
        });
        expect(completed, isTrue);
      });

      test('allows multiple sequential tasks', () async {
        final results = <int>[];
        await lock.run((state) async {
          results.add(1);
        });
        await lock.run((state) async {
          results.add(2);
        });
        await lock.run((state) async {
          results.add(3);
        });
        expect(results, equals([1, 2, 3]));
      });
    });

    group('cancellation', () {
      test('cancels previous task when new task starts', () async {
        var task1Completed = false;
        var task2Completed = false;

        // Start first task with a delay
        lock.run((state) async {
          await Future.delayed(Duration(milliseconds: 50));
          state.guard(); // Should throw here
          task1Completed = true;
        });

        // Small delay to ensure first task has started
        await Future.delayed(Duration(milliseconds: 10));

        // Start second task
        await lock.run((state) async {
          task2Completed = true;
        });

        expect(task1Completed, isFalse);
        expect(task2Completed, isTrue);
      });

      test('cancels multiple tasks in quick succession', () async {
        final completedTasks = <int>[];

        // Start 10 tasks rapidly
        for (var i = 0; i < 10; i++) {
          lock.run((state) async {
            await Future.delayed(Duration(milliseconds: 20));
            state.guard();
            completedTasks.add(i);
          });
        }

        // Wait for all tasks to potentially complete
        await Future.delayed(Duration(milliseconds: 100));

        // Only the last task should complete
        expect(completedTasks, equals([9]));
      });

      test('immediately cancels long-running task', () async {
        var task1Cancelled = false;
        var task2Completed = false;

        lock.run((state) async {
          state.onCancel(() => task1Cancelled = true);
          await Future.delayed(Duration(seconds: 1));
          state.guard();
        });

        await Future.delayed(Duration(milliseconds: 10));

        await lock.run((state) async {
          task2Completed = true;
        });

        expect(task1Cancelled, isTrue);
        expect(task2Completed, isTrue);
      });

      test('cancellation does not affect new task', () async {
        lock.run((state) async {
          await Future.delayed(Duration(milliseconds: 50));
          state.guard();
        });

        await Future.delayed(Duration(milliseconds: 10));

        var newTaskCompleted = false;
        await lock.run((state) async {
          state.guard(); // Should not throw
          newTaskCompleted = true;
        });

        expect(newTaskCompleted, isTrue);
      });
    });

    group('guard', () {
      test('does not throw when task is not cancelled', () async {
        await lock.run((state) async {
          expect(() => state.guard(), returnsNormally);
          await Future.delayed(Duration(milliseconds: 10));
          expect(() => state.guard(), returnsNormally);
        });
      });

      test('throws CancelledException when cancelled', () async {
        var exceptionThrown = false;

        lock.run((state) async {
          await Future.delayed(Duration(milliseconds: 50));
          try {
            state.guard();
          } on CancelledException {
            exceptionThrown = true;
          }
        });

        await Future.delayed(Duration(milliseconds: 10));
        await lock.run((state) async {});

        await Future.delayed(Duration(milliseconds: 100));
        expect(exceptionThrown, isTrue);
      });

      test('guard at start of task works correctly', () async {
        var completed = false;
        await lock.run((state) async {
          state.guard();
          completed = true;
        });
        expect(completed, isTrue);
      });

      test('guard before expensive operation prevents execution', () async {
        var expensiveOpRan = false;

        lock.run((state) async {
          await Future.delayed(Duration(milliseconds: 50));
          state.guard();
          expensiveOpRan = true; // Should not reach here
        });

        await Future.delayed(Duration(milliseconds: 10));
        await lock.run((state) async {});
        await Future.delayed(Duration(milliseconds: 100));

        expect(expensiveOpRan, isFalse);
      });

      test('multiple guards in same task work correctly', () async {
        var allGuardsPassed = false;
        await lock.run((state) async {
          state.guard();
          await Future.delayed(Duration(milliseconds: 5));
          state.guard();
          await Future.delayed(Duration(milliseconds: 5));
          state.guard();
          allGuardsPassed = true;
        });
        expect(allGuardsPassed, isTrue);
      });
    });

    group('wait', () {
      test('executes function and returns result', () async {
        final result = await lock.run((state) async {
          return await state.wait(() async {
            await Future.delayed(Duration(milliseconds: 10));
            return 'success';
          });
        });
        expect(result, equals('success'));
      });

      test('throws when cancelled before execution', () async {
        var exceptionThrown = false;

        lock.run((state) async {
          await Future.delayed(Duration(milliseconds: 50));
          try {
            await state.wait(() async => 'value');
          } on CancelledException {
            exceptionThrown = true;
          }
        });

        await Future.delayed(Duration(milliseconds: 10));
        await lock.run((state) async {});
        await Future.delayed(Duration(milliseconds: 100));

        expect(exceptionThrown, isTrue);
      });

      test('throws when cancelled during execution', () async {
        var exceptionThrown = false;
        var functionCompleted = false;

        lock.run((state) async {
          try {
            await state.wait(() async {
              await Future.delayed(Duration(milliseconds: 100));
              functionCompleted = true;
              return 'value';
            });
          } on CancelledException {
            exceptionThrown = true;
          }
        });

        await Future.delayed(Duration(milliseconds: 10));
        await lock.run((state) async {});
        await Future.delayed(Duration(milliseconds: 150));

        expect(exceptionThrown, isTrue);
        expect(
          functionCompleted,
          isTrue,
        ); // Function still completes, but guard throws after
      });

      test('works with nested async operations', () async {
        final result = await lock.run((state) async {
          final first = await state.wait(() async {
            await Future.delayed(Duration(milliseconds: 5));
            return 10;
          });
          final second = await state.wait(() async {
            await Future.delayed(Duration(milliseconds: 5));
            return 20;
          });
          return first + second;
        });
        expect(result, equals(30));
      });

      test('handles exceptions from wrapped function', () async {
        expect(
          () => lock.run((state) async {
            await state.wait(() async {
              throw Exception('test error');
            });
          }),
          throwsA(isA<Exception>()),
        );
      });

      test('returns different types correctly', () async {
        final stringResult = await lock.run((state) async {
          return await state.wait(() async => 'text');
        });
        expect(stringResult, isA<String>());

        final intResult = await lock.run((state) async {
          return await state.wait(() async => 42);
        });
        expect(intResult, isA<int>());

        final listResult = await lock.run((state) async {
          return await state.wait(() async => [1, 2, 3]);
        });
        expect(listResult, isA<List<int>>());
      });
    });

    group('onCancel', () {
      test('executes callback when task is cancelled', () async {
        var callbackExecuted = false;

        lock.run((state) async {
          state.onCancel(() {
            callbackExecuted = true;
          });
          await Future.delayed(Duration(milliseconds: 50));
          state.guard();
        });

        await Future.delayed(Duration(milliseconds: 10));
        await lock.run((state) async {});

        expect(callbackExecuted, isTrue);
      });

      test('does not execute callback if task completes normally', () async {
        var callbackExecuted = false;

        await lock.run((state) async {
          state.onCancel(() {
            callbackExecuted = true;
          });
          await Future.delayed(Duration(milliseconds: 10));
        });

        await Future.delayed(Duration(milliseconds: 20));
        expect(callbackExecuted, isFalse);
      });

      test('executes multiple callbacks in order', () async {
        final executionOrder = <int>[];

        lock.run((state) async {
          state.onCancel(() => executionOrder.add(1));
          state.onCancel(() => executionOrder.add(2));
          state.onCancel(() => executionOrder.add(3));
          await Future.delayed(Duration(milliseconds: 50));
          state.guard();
        });

        await Future.delayed(Duration(milliseconds: 10));
        await lock.run((state) async {});

        expect(executionOrder, equals([1, 2, 3]));
      });

      test('silently ignores exceptions in callbacks', () async {
        var callback2Executed = false;

        lock.run((state) async {
          state.onCancel(() {
            throw Exception('callback error');
          });
          state.onCancel(() {
            callback2Executed = true;
          });
          await Future.delayed(Duration(milliseconds: 50));
          state.guard();
        });

        await Future.delayed(Duration(milliseconds: 10));
        await lock.run((state) async {});

        // Second callback should still execute despite first one throwing
        expect(callback2Executed, isTrue);
      });

      test('can register callback at any point during execution', () async {
        var earlyCallback = false;
        var lateCallback = false;

        lock.run((state) async {
          state.onCancel(() => earlyCallback = true);
          await Future.delayed(Duration(milliseconds: 20));
          state.onCancel(() => lateCallback = true);
          await Future.delayed(Duration(milliseconds: 50));
          state.guard();
        });

        await Future.delayed(Duration(milliseconds: 30));
        await lock.run((state) async {});

        expect(earlyCallback, isTrue);
        expect(lateCallback, isTrue);
      });

      test('callback with cleanup resources', () async {
        var resourceClosed = false;
        var resourceUsed = false;

        lock.run((state) async {
          // Simulate resource
          state.onCancel(() {
            resourceClosed = true;
          });

          await Future.delayed(Duration(milliseconds: 50));
          state.guard();
          resourceUsed = true;
        });

        await Future.delayed(Duration(milliseconds: 10));
        await lock.run((state) async {});

        expect(resourceClosed, isTrue);
        expect(resourceUsed, isFalse);
      });
    });

    group('edge cases', () {
      test('handles task that immediately throws', () async {
        expect(
          () => lock.run((state) async {
            throw Exception('immediate error');
          }),
          throwsA(isA<Exception>()),
        );
      });

      test('handles task with no operations', () async {
        await lock.run((state) async {});
        // Should complete without errors
      });

      test('handles rapid fire cancellations', () async {
        final completedTasks = <int>[];

        for (var i = 0; i < 100; i++) {
          lock.run((state) async {
            await Future.delayed(Duration(milliseconds: 10));
            state.guard();
            completedTasks.add(i);
          });
        }

        await Future.delayed(Duration(milliseconds: 100));

        // Only the last task should complete
        expect(completedTasks.length, equals(1));
        expect(completedTasks.last, equals(99));
      });

      test('multiple lock instances are independent', () async {
        final lock1 = AsyncLock();
        final lock2 = AsyncLock();

        var lock1Task1Completed = false;
        var lock1Task2Completed = false;
        var lock2Task1Completed = false;

        lock1.run((state) async {
          await Future.delayed(Duration(milliseconds: 50));
          state.guard();
          lock1Task1Completed = true;
        });

        lock2.run((state) async {
          await Future.delayed(Duration(milliseconds: 30));
          lock2Task1Completed = true;
        });

        await Future.delayed(Duration(milliseconds: 10));

        await lock1.run((state) async {
          lock1Task2Completed = true;
        });

        await Future.delayed(Duration(milliseconds: 50));

        expect(lock1Task1Completed, isFalse); // Cancelled by lock1 task2
        expect(lock1Task2Completed, isTrue);
        expect(lock2Task1Completed, isTrue); // Not affected by lock1
      });

      test('state from cancelled task cannot be reused', () async {
        AsyncLockState? savedState;

        lock.run((state) async {
          savedState = state;
          await Future.delayed(Duration(milliseconds: 50));
          state.guard();
        });

        await Future.delayed(Duration(milliseconds: 10));
        await lock.run((state) async {});
        await Future.delayed(Duration(milliseconds: 100));

        // Trying to use the cancelled state should throw
        expect(() => savedState!.guard(), throwsA(isA<CancelledException>()));
      });

      test('deeply nested async operations', () async {
        final result = await lock.run((state) async {
          return await state.wait(() async {
            await Future.delayed(Duration(milliseconds: 5));
            return await state.wait(() async {
              await Future.delayed(Duration(milliseconds: 5));
              return await state.wait(() async {
                await Future.delayed(Duration(milliseconds: 5));
                return 'deeply nested';
              });
            });
          });
        });
        expect(result, equals('deeply nested'));
      });

      test('task cancelled during guard check', () async {
        var guardThrew = false;

        lock.run((state) async {
          await Future.delayed(Duration(milliseconds: 50));
          try {
            state.guard();
          } on CancelledException {
            guardThrew = true;
            rethrow;
          }
        });

        await Future.delayed(Duration(milliseconds: 10));
        await lock.run((state) async {});
        await Future.delayed(Duration(milliseconds: 100));

        expect(guardThrew, isTrue);
      });

      test('onCancel callback can access external state', () async {
        var counter = 0;

        lock.run((state) async {
          state.onCancel(() {
            counter = 42;
          });
          await Future.delayed(Duration(milliseconds: 50));
          state.guard();
        });

        await Future.delayed(Duration(milliseconds: 10));
        await lock.run((state) async {});

        expect(counter, equals(42));
      });

      test('complex real-world scenario: search as you type', () async {
        final searchResults = <String>[];

        Future<String> fakeSearch(String query) async {
          await Future.delayed(Duration(milliseconds: 50));
          return 'Results for: $query';
        }

        // Simulate typing "hello"
        lock.run((state) async {
          final result = await state.wait(() => fakeSearch('h'));
          searchResults.add(result);
        });

        await Future.delayed(Duration(milliseconds: 10));

        lock.run((state) async {
          final result = await state.wait(() => fakeSearch('he'));
          searchResults.add(result);
        });

        await Future.delayed(Duration(milliseconds: 10));

        await lock.run((state) async {
          final result = await state.wait(() => fakeSearch('hello'));
          searchResults.add(result);
        });

        await Future.delayed(Duration(milliseconds: 100));

        // Only the last search should complete
        expect(searchResults, equals(['Results for: hello']));
      });

      test('handles task returning null', () async {
        final result = await lock.run((state) async {
          return null;
        });
        expect(result, isNull);
      });

      test('handles task returning future of nullable type', () async {
        final result = await lock.run((state) async {
          return await state.wait<String?>(() async => null);
        });
        expect(result, isNull);
      });
    });

    group('CancelledException', () {
      test('has correct toString', () {
        final exception = CancelledException();
        expect(exception.toString(), equals('CancelledException'));
      });

      test('is an Exception', () {
        expect(CancelledException(), isA<Exception>());
      });

      test('can be caught specifically', () async {
        var caughtCorrectException = false;

        lock.run((state) async {
          await Future.delayed(Duration(milliseconds: 50));
          try {
            state.guard();
          } on CancelledException {
            caughtCorrectException = true;
          }
        });

        await Future.delayed(Duration(milliseconds: 10));
        await lock.run((state) async {});
        await Future.delayed(Duration(milliseconds: 100));

        expect(caughtCorrectException, isTrue);
      });
    });

    group('concurrent access', () {
      test('ensures only one task runs at a time', () async {
        var currentlyRunning = 0;
        var maxConcurrent = 0;

        Future<void> task() async {
          currentlyRunning++;
          maxConcurrent = maxConcurrent > currentlyRunning
              ? maxConcurrent
              : currentlyRunning;
          await Future.delayed(Duration(milliseconds: 20));
          currentlyRunning--;
        }

        // Start multiple tasks without await
        final futures = <Future>[];
        for (var i = 0; i < 5; i++) {
          futures.add(
            lock.run<void>((state) async {
              state.onCancel(() => currentlyRunning--);
              await task();
            }),
          );
        }

        await Future.wait(futures.map((f) => f.catchError((_) {})));
        await Future.delayed(Duration(milliseconds: 50));

        // Should never have more than 1 running at a time
        expect(maxConcurrent, equals(1));
      });
    });
  });
}
