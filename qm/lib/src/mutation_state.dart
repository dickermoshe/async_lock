import 'package:equatable/equatable.dart';
import 'package:qm/src/base.dart';

/// Represents the state of a [Mutation].
///
/// A sealed class with four possible states:
/// - [IdleMutationState]: Mutation has not been run yet
/// - [RunningMutationState]: Mutation is currently executing
/// - [CompletedMutationState]: Mutation completed successfully with data
/// - [FailedMutationState]: Mutation failed with an error
sealed class MutationState<T> implements BaseStateInterface<T> {
  MutationState<T>? _previousState;

  /// The previous state before this one, if available.
  MutationState<T>? get previousState => _previousState;
  MutationState(this._previousState);

  /// True if the mutation is idle (not yet run).
  bool get isIdle => (this is IdleMutationState);

  /// True if the mutation is currently running.
  bool get isLoading => (this is RunningMutationState);

  /// True if the mutation completed successfully.
  bool get hasValue => (this is CompletedMutationState);

  /// True if the mutation failed.
  bool get hasFailed => (this is FailedMutationState);

  /// The result value if the mutation completed successfully, null otherwise.
  T? get value => (this is CompletedMutationState)
      ? (this as CompletedMutationState<T>).value
      : null;

  /// The error if the mutation failed, null otherwise.
  Object? get error {
    if (this is FailedMutationState) {
      return (this as FailedMutationState<T>).error;
    }
    return null;
  }

  /// The stack trace if the mutation failed, null otherwise.
  StackTrace? get stackTrace {
    if (this is FailedMutationState) {
      return (this as FailedMutationState<T>).stackTrace;
    }
    return null;
  }

  /// Maps the state to a value based on which state it is.
  ///
  /// Requires handlers for all four possible states.
  NewT map<NewT>({
    required NewT Function() idle,
    required NewT Function() running,
    required NewT Function(T data) data,
    required NewT Function(Object error, StackTrace stackTrace) failed,
  }) {
    return switch (this) {
      IdleMutationState<T> _ => idle(),
      RunningMutationState<T> _ => running(),
      CompletedMutationState<T> d => data(d.value),
      FailedMutationState<T> f => failed(f.error, f.stackTrace),
    };
  }

  @override
  void clearPreviousState() {
    _previousState = null;
  }
}

/// The idle state of a mutation, indicating it has not been run yet.
// The props which are mutable are not included in equals and hashCode, so
// it is safe to ignore the warning
// ignore: must_be_immutable
class IdleMutationState<T> extends MutationState<T> with EquatableMixin {
  IdleMutationState([super._previousState]);

  @override
  List<Object?> get props => [];
}

/// The running state of a mutation, indicating it is currently executing.
// The props which are mutable are not included in equals and hashCode, so
// it is safe to ignore the warning
// ignore: must_be_immutable
class RunningMutationState<T> extends MutationState<T> with EquatableMixin {
  RunningMutationState([super._previousState]);

  @override
  List<Object?> get props => [];
}

/// The failed state of a mutation, containing error information.
// The props which are mutable are not included in equals and hashCode, so
// it is safe to ignore the warning
// ignore: must_be_immutable
class FailedMutationState<T> extends MutationState<T> with EquatableMixin {
  @override
  final Object error;
  @override
  final StackTrace stackTrace;
  FailedMutationState(this.error, this.stackTrace, [super._previousState]);

  @override
  List<Object?> get props => [error, stackTrace];
}

/// The completed state of a mutation, containing the result value.
// The props which are mutable are not included in equals and hashCode, so
// it is safe to ignore the warning
// ignore: must_be_immutable
class CompletedMutationState<T> extends MutationState<T> with EquatableMixin {
  @override
  final T value;
  CompletedMutationState(this.value, [super._previousState]);

  @override
  List<Object?> get props => [value];
}
