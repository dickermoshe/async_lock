import 'package:flutter/foundation.dart';
import 'package:locked_async/locked_async.dart';
import 'package:qm/src/base.dart';
import 'package:qm/src/query_state.dart';

/// A [ValueNotifier] that automatically executes an async function and
/// manages its loading, success, and error states.
///
/// A [Query] runs immediately upon creation and notifies listeners when
/// the state changes between loading, completed, or failed states.
///
/// Example:
/// ```dart
/// final userQuery = Query<User>((state) async {
///   final response = await http.get('/api/user');
///   return User.fromJson(response.body);
/// });
///
/// // In your widget:
/// ValueListenableBuilder(
///   valueListenable: userQuery,
///   builder: (context, state, child) {
///     return state.when(
///       loading: () => CircularProgressIndicator(),
///       data: (user) => Text('Hello, ${user.name}!'),
///       failed: (error, _) => Column(
///         children: [
///           Text('Error: $error'),
///           ElevatedButton(
///             onPressed: userQuery.restart,
///             child: Text('Retry'),
///           ),
///         ],
///       ),
///     );
///   },
/// )
/// ```
abstract class Query<Result> implements ValueNotifier<QueryState<Result>> {
  /// Creates a query that executes the given async function.
  ///
  /// The function runs immediately and whenever [restart] is called.
  /// The [LockedAsyncState] parameter can be used to check if the operation
  /// was cancelled.
  factory Query(Future<Result> Function(LockedAsyncState state) fn) {
    return QueryImpl<Result>(fn);
  }

  /// Reruns the query function, transitioning to a loading state.
  void restart();
}

@internal
class QueryImpl<Result> extends Base<Result, void, QueryState<Result>>
    implements Query<Result> {
  final Future<Result> Function(LockedAsyncState state) _fn;
  QueryImpl(this._fn) : super(LoadingQueryState<Result>()) {
    internalRun(null);
  }

  @override
  Future<Result> fn(LockedAsyncState state, void args) {
    return _fn(state);
  }

  @override
  buildCompleted({
    required QueryState<Result> previousState,
    required Result value,
  }) {
    return CompletedQueryState<Result>(value, previousState);
  }

  @override
  buildFailed({
    required QueryState<Result> previousState,
    required Object error,
    required StackTrace stackTrace,
  }) {
    return FailedQueryState<Result>(error, stackTrace, previousState);
  }

  @override
  buildLoading({required QueryState<Result> previousState}) {
    return LoadingQueryState<Result>(previousState);
  }

  @override
  void restart() {
    internalRun(null);
  }
}
