import 'package:flutter/foundation.dart';
import 'package:locked_async/locked_async.dart'
    as locked_async
    show LockedAsyncState;
import 'package:qm/src/base.dart';
import 'package:qm/src/mutation_state.dart';

/// A [ValueNotifier] that executes an async function with arguments and
/// manages its idle, running, success, and error states.
///
/// Unlike [Query], a [Mutation] starts in an idle state and only runs when
/// [run] is called with arguments. This makes it ideal for actions like
/// submitting forms, updating data, or performing user-triggered operations.
///
/// Example:
/// ```dart
/// final updateUser = Mutation<User, String>((name, state) async {
///   final response = await http.post('/api/user', body: {'name': name});
///   return User.fromJson(response.body);
/// });
///
/// // In your widget:
/// ValueListenableBuilder(
///   valueListenable: updateUser,
///   builder: (context, state, child) {
///     return Column(
///       children: [
///         ElevatedButton(
///           onPressed: () => updateUser.run('John'),
///           child: state.isLoading
///             ? CircularProgressIndicator()
///             : Text('Update Name'),
///         ),
///         state.map(
///           idle: () => SizedBox(),
///           running: () => Text('Updating...'),
///           data: (user) => Text('Updated: ${user.name}'),
///           failed: (error, _) => Column(
///             children: [
///               Text('Error: $error'),
///               TextButton(
///                 onPressed: updateUser.retry,
///                 child: Text('Retry'),
///               ),
///             ],
///           ),
///         ),
///       ],
///     );
///   },
/// )
/// ```
abstract class Mutation<Result, Args>
    implements ValueNotifier<MutationState<Result>> {
  /// Creates a mutation that executes the given async function when [run] is called.
  ///
  /// The function receives the arguments passed to [run] and a [locked_async.LockedAsyncState]
  /// that can be used to check if the operation was cancelled.
  factory Mutation(
    Future<Result> Function(Args args, locked_async.LockedAsyncState state) fn,
  ) {
    return MutationImpl<Result, Args>(fn);
  }

  /// Executes the mutation function with the given arguments.
  ///
  /// Transitions the state to running, then to either completed or failed
  /// based on the result.
  void run(Args args);

  /// Reruns the mutation with the last arguments passed to [run].
  ///
  /// Does nothing if [run] has never been called. Useful for retry buttons
  /// after a failure.
  void retry();

  /// Executes the mutation function with the given arguments and waits for it to complete.
  ///
  /// Returns the result of the mutation.
  ///
  /// Throws a [DisposedException] if the mutation is disposed.
  ///
  /// Throws a [QueryMutationCancelledException] if the mutation is cancelled.
  Future<Result> runAndAwait(Args args);

  /// Reruns the mutation with the last arguments passed to [run] and waits for it to complete.
  ///
  /// Returns the result of the mutation.
  ///
  /// Throws a [DisposedException] if the mutation is disposed.
  ///
  /// Throws a [QueryMutationCancelledException] if the mutation is cancelled.
  Future<Result> retryAndAwait();
}

@internal
class MutationImpl<Result, Args>
    extends Base<Result, Args, MutationState<Result>>
    implements Mutation<Result, Args> {
  Args? _lastArgs;
  final Future<Result> Function(Args args, locked_async.LockedAsyncState state)
  _fn;
  MutationImpl(this._fn) : super(IdleMutationState<Result>());

  @override
  MutationState<Result> buildCompleted({
    required MutationState<Result> previousState,
    required Result value,
  }) {
    return CompletedMutationState<Result>(value, previousState);
  }

  @override
  MutationState<Result> buildFailed({
    required MutationState<Result> previousState,
    required Object error,
    required StackTrace stackTrace,
  }) {
    return FailedMutationState<Result>(error, stackTrace, previousState);
  }

  @override
  MutationState<Result> buildLoading({
    required MutationState<Result> previousState,
  }) {
    return RunningMutationState<Result>(previousState);
  }

  @override
  Future<Result> fn(locked_async.LockedAsyncState state, Args args) {
    return _fn(args, state);
  }

  @override
  void run(Args args) {
    _lastArgs = args;
    internalRun(args).ignore();
  }

  @override
  void retry() {
    if (_lastArgs == null) {
      return;
    }
    internalRun(_lastArgs as Args).ignore();
  }

  @override
  Future<Result> runAndAwait(Args args) {
    _lastArgs = args;
    return internalRun(args);
  }

  @override
  Future<Result> retryAndAwait() {
    if (_lastArgs == null) {
      return Future.error(
        InvalidRetryException(
          'Unable to retry a mutation that has not been run yet.',
        ),
      );
    }
    return internalRun(_lastArgs as Args);
  }
}

class InvalidRetryException implements Exception {
  final String message;
  const InvalidRetryException(this.message);

  @override
  String toString() => 'InvalidRetryException($message)';
}
