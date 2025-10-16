import 'package:flutter/foundation.dart';
import 'package:locked_async/locked_async.dart';

abstract class BaseStateInterface<T> {
  void clearPreviousState();
}

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

  void _safeSetState(StateType state) {
    if (_isDisposed) {
      return;
    }
    // Remove the previous state from the previous state
    state.clearPreviousState();
    value = state;
  }

  StateType buildLoading(StateType previousState);
  StateType buildCompleted(StateType previousState, ReturnType value);
  StateType buildFailed(
    StateType previousState,
    Object error,
    StackTrace stackTrace,
  );
  Future<ReturnType> fn(LockedAsyncState state, ArgsType args);

  void internalRun(ArgsType args) {
    if (_isDisposed) {
      return;
    }

    _lockedAsync.run((state) async {
      state.guard();
      _safeSetState(buildLoading(value));
      try {
        final result = await state.wait(() => fn(state, args));
        _safeSetState(buildCompleted(value, result));
      } catch (e, stackTrace) {
        if (e is CancelledException) {
          return;
        }
        _safeSetState(buildFailed(value, e, stackTrace));
      }
    });
  }
}
