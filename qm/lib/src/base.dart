import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:locked_async/locked_async.dart'
    as locked_async
    show LockedAsync, LockedAsyncState;
import 'package:locked_async/locked_async.dart' show CancelledException;

@internal
abstract class BaseStateInterface<T> {
  void clearPreviousState();
  T? get value;
  Object? get error;
  StackTrace? get stackTrace;
  bool get hasValue;
  bool get hasFailed;
}

@internal
abstract class Base<
  ReturnType,
  ArgsType,
  StateType extends BaseStateInterface<ReturnType>
>
    extends ValueNotifier<StateType> {
  Base(super._value);
  final locked_async.LockedAsync _lockedAsync = locked_async.LockedAsync();

  bool _isDisposed = false;

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    super.dispose();
  }

  void guardedSetState(
    locked_async.LockedAsyncState lockState,
    StateType newState,
  ) {
    if (_isDisposed || lockState.isCancelled) {
      return;
    }
    // Remove the previous state from the previous state
    // We only want to keep a single previous state, nothing deeper.
    value.clearPreviousState();
    value = newState;
  }

  StateType buildLoading({required StateType previousState});
  StateType buildCompleted({
    required StateType previousState,
    required ReturnType value,
  });
  StateType buildFailed({
    required StateType previousState,
    required Object error,
    required StackTrace stackTrace,
  });
  Future<ReturnType> fn(locked_async.LockedAsyncState state, ArgsType args);

  Future<ReturnType> internalRun(ArgsType args) async {
    if (_isDisposed) {
      return Future.error(
        DisposedException(
          'This Mutation/Query has been disposed before it could run.',
        ),
      );
    }

    final completer = Completer<ReturnType>();

    late VoidCallback listener;
    listener = () {
      if (value.hasValue) {
        removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete(value.value);
        }
        return;
      }
      if (value.hasFailed) {
        removeListener(listener);
        if (!completer.isCompleted) {
          completer.completeError(value.error!, value.stackTrace!);
        }
        return;
      }
    };
    addListener(listener);

    try {
      await _lockedAsync.run((state) async {
        guardedSetState(state, buildLoading(previousState: value));
        try {
          final result = await fn(state, args);
          guardedSetState(
            state,
            buildCompleted(previousState: value, value: result),
          );
        } catch (e, stackTrace) {
          // Convert locked_async.CancelledException to our own type
          if (e is CancelledException) {
            rethrow;
          }
          guardedSetState(
            state,
            buildFailed(previousState: value, error: e, stackTrace: stackTrace),
          );
        }
      });
    } catch (e, stackTrace) {
      // Catch any exceptions that escaped the inner try-catch
      removeListener(listener);
      if (!completer.isCompleted) {
        completer.completeError(e, stackTrace);
      }
      return completer.future;
    }

    // If the completer hasn't been completed by now, check why
    removeListener(listener);
    if (!completer.isCompleted) {
      if (_isDisposed) {
        completer.completeError(
          DisposedException(
            'This Mutation/Query has been disposed before it could complete.',
          ),
        );
      } else {
        completer.completeError(CancelledException());
      }
    }

    return completer.future;
  }
}

class DisposedException implements Exception {
  final String message;
  const DisposedException(this.message);

  @override
  String toString() => 'DisposedException($message)';
}
