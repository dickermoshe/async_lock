import 'package:equatable/equatable.dart';
import 'package:qm/src/base.dart';

sealed class MutationState<T> implements BaseStateInterface<T> {
  MutationState<T>? _previousState;
  MutationState<T>? get previousState => _previousState;
  MutationState(this._previousState);

  bool get isIdle => (this is IdleMutationState);
  bool get isLoading => (this is RunningMutationState);
  bool get hasValue => (this is CompletedMutationState);
  bool get hasFailed => (this is FailedMutationState);

  T? get value => (this is CompletedMutationState)
      ? (this as CompletedMutationState<T>).value
      : null;

  Object? get error {
    if (this is FailedMutationState) {
      return (this as FailedMutationState<T>).error;
    }
    return null;
  }

  StackTrace? get stackTrace {
    if (this is FailedMutationState) {
      return (this as FailedMutationState<T>).stackTrace;
    }
    return null;
  }

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

// The props which are mutable are not included in equals and hashCode, so
// it is safe to ignore the warning
// ignore: must_be_immutable
class IdleMutationState<T> extends MutationState<T> with EquatableMixin {
  IdleMutationState([super._previousState]);

  @override
  List<Object?> get props => [];
}

// The props which are mutable are not included in equals and hashCode, so
// it is safe to ignore the warning
// ignore: must_be_immutable
class RunningMutationState<T> extends MutationState<T> with EquatableMixin {
  RunningMutationState([super._previousState]);

  @override
  List<Object?> get props => [];
}

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
