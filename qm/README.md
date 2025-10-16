# QM - Query & Mutation State Management

A lightweight Flutter package for managing async operations with **Queries** and **Mutations**. Built on top of `ValueNotifier` and `locked_async`, QM provides a simple, type-safe way to handle loading states, errors, and data in your Flutter applications.

## Why QM?

QM uses `locked_async` under the hood to ensure only one operation runs at a time. When a new operation starts, the previous one is automatically cancelled. No more race conditions, no manual state management.

Checkout the [locked_async](https://pub.dev/packages/locked_async) package for more details why we need this.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  qm: ^0.1.0
```

## Usage

### Query - Automatic Data Fetching

A `Query` runs automatically when created and manages loading, success, and error states.

```dart
import 'package:qm/qm.dart';

// Create a query
final userQuery = Query<User>((state) async {
  final response = await http.get('/api/user');
  return User.fromJson(response.body);
});

// Use in a widget
class UserProfile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: userQuery,
      builder: (context, state, child) {
        return state.when(
          loading: () => CircularProgressIndicator(),
          data: (user) => Text('Hello, ${user.name}!'),
          failed: (error, _) => Column(
            children: [
              Text('Error: $error'),
              ElevatedButton(
                onPressed: userQuery.restart,
                child: Text('Retry'),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

### Mutation - User-Triggered Actions

A `Mutation` starts idle and only runs when explicitly called with arguments.

```dart
import 'package:qm/qm.dart';

// Create a mutation
final updateUser = Mutation<User, String>((name, state) async {
  final response = await http.post('/api/user', body: {'name': name});
  return User.fromJson(response.body);
});

// Use in a widget
class UpdateNameForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: updateUser,
      builder: (context, state, child) {
        return Column(
          children: [
            ElevatedButton(
              onPressed: () => updateUser.run('John'),
              child: state.isLoading
                ? CircularProgressIndicator()
                : Text('Update Name'),
            ),
            state.map(
              idle: () => SizedBox(),
              running: () => Text('Updating...'),
              data: (user) => Text('Updated: ${user.name}'),
              failed: (error, _) => Column(
                children: [
                  Text('Error: $error'),
                  TextButton(
                    onPressed: updateUser.retry,
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
```

#### Multiple Arguments in Mutations

Use classes or records for complex arguments:

```dart
final updateProfile = Mutation<User, ({String name, int age})>(
  (args, state) async {
    final response = await http.post('/api/user', body: {
      'name': args.name,
      'age': args.age,
    });
    return User.fromJson(response.body);
  },
);

// Call it
updateProfile.run((name: 'John', age: 30));
```
