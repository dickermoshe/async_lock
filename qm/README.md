# locked_async_notifier

A Flutter package that combines `ValueNotifier` with `LockedAsync` to provide reactive state management for asynchronous operations with automatic cancellation. Perfect for search-as-you-type, API calls, and any scenario where you need to track the state of async operations in your Flutter UI.

## Features

- 🔄 **Reactive State Management**: Built on `ValueNotifier` for seamless Flutter integration
- 🚫 **Automatic Cancellation**: Automatically cancels previous operations when a new one starts
- 📊 **Type-Safe States**: Sealed class hierarchy for compile-time safe state handling
- 🎯 **Simple API**: Clean, intuitive interface for running async tasks
- 🔒 **Thread-Safe**: Built on proven locking mechanisms
- 🎨 **UI-Friendly**: Designed specifically for Flutter applications

## States

`LockedAsyncNotifier` manages four distinct states:

- **`IdleState<T>`**: Initial state, no operation has been started
- **`RunningState<T>`**: An async operation is currently in progress
- **`CompletedState<T>`**: Operation completed successfully with a result value
- **`FailedState<T>`**: Operation failed with an error and stack trace

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  locked_async_notifier: ^0.1.0
```

Then run:

```bash
flutter pub get
```

## Usage

### Basic Example

```dart
import 'package:flutter/material.dart';
import 'package:locked_async_notifier/locked_async_notifier.dart';

class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late final LockedAsyncNotifier<String, String> _searchNotifier;

  @override
  void initState() {
    super.initState();
    _searchNotifier = LockedAsyncNotifier<String, String>(
      (query, state) async {
        // Simulate API call
        await state.wait(() => Future.delayed(Duration(milliseconds: 500)));
        
        // Check if cancelled
        state.guard();
        
        // Return search results
        return 'Results for: $query';
      },
    );
  }

  @override
  void dispose() {
    _searchNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          onChanged: (value) => _searchNotifier.run(value),
        ),
        ValueListenableBuilder<LockedAsyncNotifierState<String>>(
          valueListenable: _searchNotifier,
          builder: (context, state, child) {
            return switch (state) {
              IdleState() => Text('Enter a search query'),
              RunningState() => CircularProgressIndicator(),
              CompletedState(:final value) => Text(value),
              FailedState(:final error) => Text('Error: $error'),
            };
          },
        ),
      ],
    );
  }
}
```

### Search-as-you-Type Example

```dart
class SearchScreen extends StatefulWidget {
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final LockedAsyncNotifier<List<String>, String> _searchNotifier;

  @override
  void initState() {
    super.initState();
    _searchNotifier = LockedAsyncNotifier<List<String>, String>(
      (query, state) async {
        if (query.isEmpty) return [];
        
        // Wait for API call
        final response = await state.wait(
          () => http.get(Uri.parse('https://api.example.com/search?q=$query')),
        );
        
        // Check if still valid (not cancelled)
        state.guard();
        
        // Parse and return results
        return parseResults(response.body);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(hintText: 'Search...'),
          onChanged: (query) => _searchNotifier.run(query),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: _searchNotifier,
            builder: (context, state, child) {
              return switch (state) {
                IdleState() => Center(child: Text('Start typing to search')),
                RunningState() => Center(child: CircularProgressIndicator()),
                CompletedState(:final value) => ListView.builder(
                    itemCount: value.length,
                    itemBuilder: (context, index) => ListTile(
                      title: Text(value[index]),
                    ),
                  ),
                FailedState(:final error) => Center(
                    child: Text('Error: $error'),
                  ),
              };
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchNotifier.dispose();
    super.dispose();
  }
}
```

### API Call with Error Handling

```dart
class UserProfileWidget extends StatefulWidget {
  final String userId;
  
  const UserProfileWidget({required this.userId});

  @override
  State<UserProfileWidget> createState() => _UserProfileWidgetState();
}

class _UserProfileWidgetState extends State<UserProfileWidget> {
  late final LockedAsyncNotifier<UserProfile, String> _profileNotifier;

  @override
  void initState() {
    super.initState();
    _profileNotifier = LockedAsyncNotifier<UserProfile, String>(
      (userId, state) async {
        // Fetch user profile
        final response = await state.wait(
          () => apiClient.getUserProfile(userId),
        );
        
        state.guard();
        
        if (response.statusCode != 200) {
          throw Exception('Failed to load profile');
        }
        
        return UserProfile.fromJson(response.data);
      },
    );
    
    // Load initial data
    _profileNotifier.run(widget.userId);
  }

  void _refresh() {
    _profileNotifier.run(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _profileNotifier,
      builder: (context, state, child) {
        return switch (state) {
          IdleState() || RunningState() => Center(
              child: CircularProgressIndicator(),
            ),
          CompletedState(:final value) => Column(
              children: [
                Text('Name: ${value.name}'),
                Text('Email: ${value.email}'),
                ElevatedButton(
                  onPressed: _refresh,
                  child: Text('Refresh'),
                ),
              ],
            ),
          FailedState(:final error, :final stackTrace) => Column(
              children: [
                Icon(Icons.error, color: Colors.red),
                Text('Error: $error'),
                ElevatedButton(
                  onPressed: _refresh,
                  child: Text('Retry'),
                ),
              ],
            ),
        };
      },
    );
  }

  @override
  void dispose() {
    _profileNotifier.dispose();
    super.dispose();
  }
}
```

### Form Submission with Loading State

```dart
class SubmitFormButton extends StatefulWidget {
  final Map<String, String> formData;

  const SubmitFormButton({required this.formData});

  @override
  State<SubmitFormButton> createState() => _SubmitFormButtonState();
}

class _SubmitFormButtonState extends State<SubmitFormButton> {
  late final LockedAsyncNotifier<bool, Map<String, String>> _submitNotifier;

  @override
  void initState() {
    super.initState();
    _submitNotifier = LockedAsyncNotifier<bool, Map<String, String>>(
      (formData, state) async {
        // Submit form
        final response = await state.wait(
          () => http.post(
            Uri.parse('https://api.example.com/submit'),
            body: formData,
          ),
        );
        
        state.guard();
        
        return response.statusCode == 200;
      },
    );
  }

  void _submit() {
    _submitNotifier.run(widget.formData);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _submitNotifier,
      builder: (context, state, child) {
        final isLoading = state is RunningState;
        
        return ElevatedButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Submit'),
        );
      },
    );
  }

  @override
  void dispose() {
    _submitNotifier.dispose();
    super.dispose();
  }
}
```

## Type Parameters

`LockedAsyncNotifier<T, Args>` has two type parameters:

- **`T`**: The type of the result value returned by the async operation
- **`Args`**: The type of the argument passed to the `run()` method

Example:
```dart
// Returns String, takes int as argument
LockedAsyncNotifier<String, int>((id, state) async {
  return 'User $id';
});

// Returns List<Product>, takes SearchQuery object as argument
LockedAsyncNotifier<List<Product>, SearchQuery>((query, state) async {
  return await searchProducts(query);
});

// Returns bool, takes no arguments (use void)
LockedAsyncNotifier<bool, void>((_, state) async {
  return await checkStatus();
});
```

## API Reference

### LockedAsyncNotifier

#### Constructor
```dart
LockedAsyncNotifier(Future<T> Function(Args args, LockedAsyncState state) fn)
```

Creates a notifier with the given async function. The function receives:
- `args`: The argument passed to `run()`
- `state`: A `LockedAsyncState` for cancellation checking

#### Methods

**`void run(Args args)`**

Executes the async function with the given arguments. Automatically cancels any previously running operation.

**`void dispose()`**

Disposes the notifier. Always call this in your widget's `dispose()` method.

### LockedAsyncState Methods

Inside your async function, use these `LockedAsyncState` methods:

**`void guard()`**

Throws `CancelledException` if the operation has been cancelled. Use after potentially long operations.

**`Future<R> wait<R>(Future<R> Function() fn)`**

Executes an async function and checks for cancellation before and after. Convenience wrapper around `guard()`.

**`void onCancel(Function callback)`**

Registers a callback to execute when the operation is cancelled. Useful for cleanup.

## Pattern Matching with States

Dart 3's pattern matching makes working with states elegant:

```dart
ValueListenableBuilder(
  valueListenable: notifier,
  builder: (context, state, child) {
    return switch (state) {
      IdleState() => Text('Not started'),
      RunningState() => CircularProgressIndicator(),
      CompletedState(value: var result) => Text('Result: $result'),
      FailedState(error: var err) => Text('Error: $err'),
    };
  },
)
```

## Best Practices

1. **Always dispose**: Call `dispose()` in your widget's dispose method
2. **Use `state.guard()` or `state.wait()`**: Check for cancellation after async operations
3. **Handle all states**: Use pattern matching to handle all possible states
4. **Type safety**: Leverage Dart's type system with proper generic types
5. **Error handling**: Always handle `FailedState` in your UI

## Relationship with `locked_async`

This package is built on top of [`locked_async`](https://pub.dev/packages/locked_async), which provides the core cancellation and locking mechanisms. `locked_async_notifier` adds Flutter-specific state management through `ValueNotifier`.

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
