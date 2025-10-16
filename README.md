## Getting Started

Install the package with:

```bash
dart pub add locked_async
```

Import and create a lock:

```dart
import 'package:locked_async/locked_async.dart';

final lock = LockedAsync();

await lock.run((state) async {
  final data = await fetchData();
  state.guard();
  processData(data);  // Won't run if another task started
});
```

That's it. The lock ensures only one task runs at a time, automatically canceling old ones when new ones start.

## Why Do We Need This?

Let's say you've got a search input where every keystroke triggers an API call. Simple, right?

```dart
final results = ValueNotifier<List<String>>([]);

// The naive approach
Future<void> getSearchResults(String query) async {
  final response = await http.get(Uri.parse('https://api.example.com/search?q=$query'));
  results.value = jsonDecode(response.body);  // But for *which* query?
}

// User types: h-e-l-l-o
getSearchResults('he');    // Request #1, 500ms response time
getSearchResults('hel');   // Request #2, 200ms response time (fast server response)
```

Here's the problem: Request #2 finishes first! Your UI shows "hel" results, then immediately flips back to "he" results when the slower request completes. Users see wrong results flickering. It's wasteful and confusing.

## The LockedAsync Solution

`LockedAsync` ensures only one task runs at a time. When a new `lock.run()` starts, it cancels the previous one. Inside your callback, you get a `state` object to cooperate with cancellation:

```dart
import 'package:locked_async/locked_async.dart';
import 'package:http/http.dart' as http;

final lock = LockedAsync();
final results = ValueNotifier<List<String>>([]);

Future<void> getSearchResults(String query) async {
  await lock.run((state) async {
    // Wrap async operations with state.wait() to check for cancellation
    final response = await state.wait(() => 
      http.get(Uri.parse('https://api.example.com/search?q=$query'))
    );
    
    state.guard();  // Final check before updating
    results.value = jsonDecode(response.body);
  });
}
```

Now when users type fast:
- `'he'` starts
- `'hel'` cancels it and starts fresh
- Only the latest query's results make it to your UI

## The Cancellation Catch

Dart futures don't cancel themselves—you need to *cooperate* with cancellation. This means checking the cancellation state regularly:

```dart
await lock.run((state) async {
  await someSetup();
  state.guard();  // Check if cancelled
  
  await heavyAsyncOperation();
  state.guard();  // Check again - crucial!
  
  // If you forget this, cancelled tasks could still run expensive operations
  processResults();
});
```

To make this easier, use `state.wait()` as a wrapper:

```dart
await lock.run((state) async {
  await state.wait(() => someSetup());           // Auto-checks cancellation
  await state.wait(() => heavyAsyncOperation()); // Auto-checks again
  processResults();  // Safe outside async ops
});
```

## The Real Problem: HTTP Doesn't Stop

Even with the lock, if you're using `http`, cancelled requests still complete—they just don't update your UI. The network call wastes time and bandwidth. For search-as-you-type, this means waiting seconds longer than necessary.

### Solution A: Use Dio with CancelTokens

Dio actually supports true request cancellation:

```dart
import 'package:dio/dio.dart';

final dio = Dio();
final lock = LockedAsync();

Future<void> getSearchResults(String query) async {
  await lock.run((state) async {
    final cancelToken = CancelToken();
    
    // When this task gets cancelled, kill the HTTP request too
    state.onCancel(() => cancelToken.cancel());
    
    final response = await state.wait(() => 
      dio.get('https://api.example.com/search?q=$query', 
              cancelToken: cancelToken)
    );
    
    results.value = jsonDecode(response.data);
  });
}
```

Now when users type "hel", the "he" request gets aborted immediately. No waiting for slow servers!

### Solution B: Add Debouncing

Even with cancellation, rapid typing can spam your API. Debouncing waits for users to pause typing:

```dart
import 'dart:async';

Timer? _debounceTimer;

Future<void> onSearchChanged(String query) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 300), () {
    getSearchResults(query);  // Only fires after user pauses
  });
}
```

Combine with the lock and you get instant response when users pause, without the race condition mess.

### The Ultimate: Both Together

```dart
Timer? _debounceTimer;
final dio = Dio();
final lock = LockedAsync();

Future<void> onSearchChanged(String query) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
    await lock.run((state) async {
      final cancelToken = CancelToken();
      state.onCancel(() => cancelToken.cancel());
      
      final response = await state.wait(() => 
        dio.get('https://api.example.com/search?q=$query', 
                cancelToken: cancelToken)
      );
      
      results.value = jsonDecode(response.data);
    });
  });
}
```

Wait 300ms for the user to stop typing, then make a single cancellable request. Perfect balance of responsiveness and efficiency.

## Real Talk

I used to think async in Dart was straightforward. Then I built search features that made users rage-quit. This pattern (inspired by Riverpod's `ref.onDispose()`) solved it for me.