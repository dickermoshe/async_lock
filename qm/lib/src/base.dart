import 'package:flutter/foundation.dart';
import 'package:locked_async/locked_async.dart';

@internal
abstract class BaseStateInterface<T> {
  void clearPreviousState();
}

@internal
abstract class Base<
  ReturnType,
  ArgsType,
  StateType extends BaseStateInterface<ReturnType>
>
    extends ValueNotifier<StateType> {
  Base(super._value);
  final LockedAsync _lockedAsync = LockedAsync();

  bool _isDisposed = false;

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    super.dispose();
  }

  void guardedSetState(LockedAsyncState lockState, StateType newState) {
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
  Future<ReturnType> fn(LockedAsyncState state, ArgsType args);

  void internalRun(ArgsType args) {
    if (_isDisposed) {
      return;
    }

    _lockedAsync.run((state) async {
      guardedSetState(state, buildLoading(previousState: value));
      try {
        final result = await fn(state, args);
        guardedSetState(
          state,
          buildCompleted(previousState: value, value: result),
        );
      } catch (e, stackTrace) {
        guardedSetState(
          state,
          buildFailed(previousState: value, error: e, stackTrace: stackTrace),
        );
      }
    });
  }
}
