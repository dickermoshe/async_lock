/// A class which allows running a task with a lock and cancelling the previous task
/// when a new task is run. Useful for file watching, search-as-you-type, etc.
///
/// Example:
/// ```dart
/// final task = LockedAsync();
///
/// void downloadFile(String url, String filename) {
///   task.run((state) async {
///     state.guard();
///
///     // Download file from internet
///     final response = await state.wait(() => http.get(Uri.parse(url)));
///
///     await File(filename).writeAsString(response.body);
///   });
/// }
///
/// downloadFile('https://example.com/file1.txt', 'file1.txt'); // Starts
/// downloadFile('https://example.com/file2.txt', 'file2.txt'); // Cancels file1, starts file2
/// ```
library;

import 'dart:async';
import 'package:synchronized/synchronized.dart';

/// A lock that ensures only one task runs at a time, automatically cancelling
/// the previous task when a new one is started.
///
/// This is useful for scenarios where you want to ensure that only the most
/// recent operation completes, such as:
/// - Search-as-you-type functionality
/// - File watching and processing
/// - Debouncing expensive operations
/// - Auto-save mechanisms
///
/// When [run] is called, any previously running task is cancelled immediately,
/// and the new task begins execution.
class LockedAsync {
  final Lock _lock = Lock();
  LockedAsyncState? _previousTaskState;

  /// Creates a new [LockedAsync] instance.
  LockedAsync();

  /// Runs the given function [fn], cancelling any previously running task.
  ///
  /// The function receives an [LockedAsyncState] object which can be used to:
  /// - Check if the task has been cancelled via [LockedAsyncState.guard]
  /// - Wait for async operations while checking for cancellation via [LockedAsyncState.wait]
  /// - Register cleanup callbacks via [LockedAsyncState.onCancel]
  ///
  /// Example:
  /// ```dart
  /// final lock = LockedAsync();
  /// lock.run((state) async {
  ///   state.guard(); // Check if cancelled
  ///   final data = await state.wait(() => fetchData());
  ///   processData(data);
  /// });
  /// ```
  Future<T> run<T>(Future<T> Function(LockedAsyncState state) fn) {
    // Cancel the previous task and reset
    _previousTaskState?._cancel();
    final newState = LockedAsyncState();

    final future = _lock.synchronized(() {
      newState.guard();
      return fn(newState);
    });

    newState.onCancel(() {
      future.ignore();
    });

    _previousTaskState = newState;
    return future;
  }
}

/// An exception thrown when a task is cancelled.
///
/// Thrown by [LockedAsyncState.guard] and [LockedAsyncState.wait] when a new
/// task starts and cancels the current one.
final class CancelledException implements Exception {
  /// Creates a new [CancelledException].
  const CancelledException();

  @override
  String toString() => 'CancelledException';
}

/// The state of a task running in an [LockedAsync].
///
/// Provides methods to:
/// - Check if the task has been cancelled ([guard])
/// - Wait for async operations with cancellation checks ([wait])
/// - Register cleanup callbacks ([onCancel])
class LockedAsyncState {
  LockedAsyncState();
  final List<Function> _onCancelled = [];
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  /// Checks if this task has been cancelled and throws [CancelledException] if so.
  ///
  /// You should call this method after any async operations that you want to cancel if the task is cancelled.
  ///
  /// Example:
  /// ```dart
  /// state.guard(); // Throws CancelledError if cancelled
  /// // Safe to proceed if no exception was thrown
  /// final data = await state.wait(() => fetchData());
  /// ```
  void guard() {
    if (_isCancelled) {
      throw const CancelledException();
    }
  }

  /// Executes an async function and throws [CancelledException] if the task
  /// is cancelled before, during, or after execution.
  ///
  /// This is a convenience wrapper around [guard] for async operations.
  ///
  /// Example:
  /// ```dart
  /// final data = await state.wait(() => http.get(url));
  /// // Safe to use data here
  /// ```
  Future<T> wait<T>(Future<T> Function() fn) async {
    guard();
    final result = await fn();
    guard();
    return result;
  }

  /// Registers a callback to be executed when this task is cancelled.
  ///
  /// Useful for cleanup operations such as:
  /// - Closing network connections
  /// - Cancelling HTTP requests
  /// - Releasing resources
  /// - Cleaning up temporary files
  ///
  /// Example:
  /// ```dart
  /// state.onCancel(() {
  ///   connection.close();
  /// });
  /// ```
  void onCancel(Function onCancelled) {
    _onCancelled.add(onCancelled);
  }

  void _cancel() {
    _isCancelled = true;
    for (final onCancelled in _onCancelled) {
      try {
        onCancelled();
      } catch (e) {
        // ignore: empty_catches
      }
    }
  }
}
