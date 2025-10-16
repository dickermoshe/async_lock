import 'package:equatable/equatable.dart';
import 'package:qm/qm.dart';
import 'package:qm/src/base.dart';

/// Represents the state of a [Query].
///
/// A sealed class with three possible states:
/// - [LoadingQueryState]: Query is currently executing
/// - [CompletedQueryState]: Query completed successfully with data
/// - [FailedQueryState]: Query failed with an error
sealed class QueryState<T> implements BaseStateInterface<T> {
  QueryState<T>? _previousState;

  /// The previous state before this one, if available.
  QueryState<T>? get previousState => _previousState;
  QueryState(this._previousState);

  /// True if the query is currently loading.
  bool get isLoading => (this is LoadingQueryState);

  /// True if the query completed successfully.
  bool get hasValue => (this is CompletedQueryState);

  /// True if the query failed.
  bool get hasFailed => (this is FailedQueryState);

  /// The result value if the query completed successfully, null otherwise.
  T? get value => (this is CompletedQueryState)
      ? (this as CompletedQueryState<T>).value
      : null;

  /// The error if the query failed, null otherwise.
  Object? get error {
    if (this is FailedQueryState) {
      return (this as FailedQueryState<T>).error;
    }
    return null;
  }

  /// The stack trace if the query failed, null otherwise.
  StackTrace? get stackTrace {
    if (this is FailedQueryState) {
      return (this as FailedQueryState<T>).stackTrace;
    }
    return null;
  }

  /// Maps the state to a value based on which state it is.
  ///
  /// Requires handlers for all three possible states.
  NewT map<NewT>({
    required NewT Function() loading,
    required NewT Function(T) data,
    required NewT Function(Object error, StackTrace stackTrace) failed,
  }) {
    return switch (this) {
      LoadingQueryState<T> _ => loading(),
      CompletedQueryState<T> d => data(d.value),
      FailedQueryState<T> f => failed(f.error, f.stackTrace),
    };
  }

  /// Maps the state to a value, with options to skip loading states.
  ///
  /// Unlike [map], this method can skip showing loading states on retries
  /// by using the previous state instead.
  ///
  /// - [skipLoadingOnRestartAfterSuccess]: If a query is restarted after a successful state, show the stale state instead of loading.
  ///   This is useful for showing stale data while fetching the latest data.
  NewT when<NewT>({
    bool skipLoadingOnRestartAfterSuccess = false,
    required NewT Function(T data) data,
    required NewT Function(Object error, StackTrace stackTrace) failed,
    required NewT Function() loading,
  }) {
    QueryState<T> that = this;
    if (that is LoadingQueryState) {
      final previousState = that._previousState;
      if (previousState is CompletedQueryState &&
          skipLoadingOnRestartAfterSuccess) {
        that = previousState!;
      }
    }
    return that.map(
      loading: () => loading(),
      data: (d) => data(d),
      failed: (error, stackTrace) => failed(error, stackTrace),
    );
  }

  @override
  void clearPreviousState() {
    _previousState = null;
  }
}

/// The loading state of a query, indicating it is currently executing.
// The props which are mutable are not included in equals and hashCode, so
// it is safe to ignore the warning
// ignore: must_be_immutable
class LoadingQueryState<T> extends QueryState<T> with EquatableMixin {
  LoadingQueryState([super._previousState]);

  @override
  List<Object?> get props => [];
}

/// The failed state of a query, containing error information.
// The props which are mutable are not included in equals and hashCode, so
// it is safe to ignore the warning
// ignore: must_be_immutable
class FailedQueryState<T> extends QueryState<T> with EquatableMixin {
  @override
  final Object error;
  @override
  final StackTrace stackTrace;
  FailedQueryState(this.error, this.stackTrace, [super._previousState]);

  @override
  List<Object?> get props => [error, stackTrace];
}

/// The completed state of a query, containing the result value.
// The props which are mutable are not included in equals and hashCode, so
// it is safe to ignore the warning
// ignore: must_be_immutable
class CompletedQueryState<T> extends QueryState<T> with EquatableMixin {
  @override
  final T value;
  CompletedQueryState(this.value, [super._previousState]);
  @override
  List<Object?> get props => [value];
}
