import 'package:flutter/foundation.dart';
import 'package:locked_async/locked_async.dart';
import 'package:qm/src/base.dart';
import 'package:qm/src/query_state.dart';

abstract class Query<Result> implements ValueNotifier<QueryState<Result>> {
  factory Query(Future<Result> Function(LockedAsyncState state) fn) {
    return QueryImpl<Result>(fn);
  }
  void run();
  void restart() => run();
}

@internal
class QueryImpl<Result> extends Base<Result, void, QueryState<Result>>
    implements Query<Result> {
  final Future<Result> Function(LockedAsyncState state) _fn;
  QueryImpl(this._fn) : super(LoadingQueryState<Result>()) {
    run();
  }

  @override
  Future<Result> fn(LockedAsyncState state, void args) {
    return _fn(state);
  }

  @override
  buildCompleted(previousState, value) {
    return CompletedQueryState<Result>(value, previousState);
  }

  @override
  buildFailed(previousState, Object error, StackTrace stackTrace) {
    return FailedQueryState<Result>(error, stackTrace, previousState);
  }

  @override
  buildLoading(previousState) {
    return LoadingQueryState<Result>(previousState);
  }

  @override
  void run() {
    internalRun(null);
  }

  @override
  void restart() {
    internalRun(null);
  }
}
