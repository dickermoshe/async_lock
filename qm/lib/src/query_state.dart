import 'package:equatable/equatable.dart';
import 'package:qm/src/base.dart';

sealed class QueryState<T> implements BaseStateInterface<T> {
  QueryState<T>? _previousState;
  QueryState<T>? get previousState => _previousState;
  QueryState(this._previousState);

  bool get isLoading => (this is LoadingQueryState);
  bool get hasValue => (this is CompletedQueryState);
  bool get hasFailed => (this is FailedQueryState);

  T? get value => (this is CompletedQueryState)
      ? (this as CompletedQueryState<T>).value
      : null;
  Object? get error {
    if (this is FailedQueryState) {
      return (this as FailedQueryState<T>).error;
    }
    return null;
  }

  StackTrace? get stackTrace {
    if (this is FailedQueryState) {
      return (this as FailedQueryState<T>).stackTrace;
    }
    return null;
  }

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

  NewT when<NewT>({
    bool skipLoadingOnRestartAfterSuccess = false,
    bool skipLoadingOnRestartAfterFailure = true,
    required NewT Function(T data) data,
    required NewT Function(Object error, StackTrace stackTrace) failed,
    required NewT Function() loading,
  }) {
    QueryState<T> that = this;

    if (that is LoadingQueryState) {
      final previousState = that._previousState;
      if (previousState is FailedQueryState &&
          skipLoadingOnRestartAfterFailure) {
        that = previousState!;
      } else if (previousState is CompletedQueryState &&
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

// The props which are mutable are not included in equals and hashCode, so
// it is safe to ignore the warning
// ignore: must_be_immutable
class LoadingQueryState<T> extends QueryState<T> with EquatableMixin {
  LoadingQueryState([super._previousState]);

  @override
  List<Object?> get props => [];
}

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
