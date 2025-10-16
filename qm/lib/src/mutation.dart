import 'package:flutter/foundation.dart';
import 'package:locked_async/locked_async.dart';
import 'package:qm/src/base.dart';
import 'package:qm/src/mutation_state.dart';

abstract class Mutation<Result, Args>
    implements ValueNotifier<MutationState<Result>> {
  factory Mutation(
    Future<Result> Function(Args args, LockedAsyncState state) fn,
  ) {
    return MutationImpl<Result, Args>(fn);
  }
  void run(Args args);
}

@internal
class MutationImpl<Result, Args>
    extends Base<Result, Args, MutationState<Result>>
    implements Mutation<Result, Args> {
  final Future<Result> Function(Args args, LockedAsyncState state) _fn;
  MutationImpl(this._fn) : super(IdleMutationState<Result>());

  @override
  buildCompleted(previousState, value) {
    return CompletedMutationState<Result>(value, previousState);
  }

  @override
  buildFailed(previousState, Object error, StackTrace stackTrace) {
    return FailedMutationState<Result>(error, stackTrace, previousState);
  }

  @override
  buildLoading(previousState) {
    return RunningMutationState<Result>(previousState);
  }

  @override
  Future<Result> fn(LockedAsyncState state, Args args) {
    return _fn(args, state);
  }

  @override
  void run(Args args) {
    internalRun(args);
  }
}
