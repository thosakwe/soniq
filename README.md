# soniq
Multithreaded, futuristic HTTP benchmarking tool.

Use `soniq` to estimate your server's response latency under different levels of load.

`soniq` can be used from the command-line, but you can also embed its API into your own
applications.

# Installation
Install it to your PATH:
```bash
pub global activate soniq
```

Or add the API as a dependency in your `pubspec.yaml`:
```yaml
dependencies:
  soniq: ^0.0.0
```

# Command-line
`soniq` is available an executable with the following usage:

```
usage: soniq [options...] <url>

Options:
-h, --[no-]help      Print this help information.
-f, --format         The format to print results in. Allowed: ["json", "stdout"]..
-j, --threads        The number of isolates (threads) to run tests in.
-c, --connections    The number of concurrent connections to maintain.
-x, --command        An optional shell command to run prior to testing.
-d, --duration       The length, in milliseconds, of the stress test.
-o, --out            A file path to write results to.
-p, --profile        The name of the profile to run, if any.
```

Instead of manually specifying options on each run, you can create a `soniq.yaml` file with
multiple *profiles*.

A single profile takes this shape:
```yaml
  format: stdout # Can also be "json"
  threads: 5 # Number of threads to spawn
  connections: 5 # Total number of HTTP connections to maintain. Each thread maintains (connections / threads).
  command: # Runs *asynchronously* before testing. Use this to start a server or other process whenever you test.
  duration: 30000 # In milliseconds. Converted to a Dart `Duration`.
```

Your `soniq.yaml` should look like this:

If you provide a `default` profile, then if you specify a different profile, its settings will be merged.
This allows you to provide common characteristics among profile, like quasi-inheritance:

```yaml
default:
  connections: 10
  threads: 10
  url: http://localhost:3000
json:
  url: http://localhost:3000/api/json
```

In the above case, running `soniq -p json` would be the same as running
`soniq -c 10 -t 10 http://localhost:3000/api/json`.

Command-line options will override options from a `soniq.yaml`, you can still run something like
`soniq -p json -c 20`.

# API
To make integration easier on yourself, just use the `Runner` class, and pass it a
`Configuration` object. The return value will be a `RunnerResult` report with statistics
and tallied data attached.

Example:
```dart
import 'package:soniq/soniq.dart';

main() async {
  var config = new Configuration(
    url: 'http://localhost:3000',
    threads: 15,
    connections: 60,
    duration: new Duration(minutes: 3)
  );
  var runner = new Runner(config);
  var report = await runner.run();
  
  print('Average latency (microseconds): ' + report.averageLatency.toStringAsFixed(2));
}
```

The `Configuration` class directly corresponds to the YAML configuration specified earlier
in this document. There are several factory constructors available to build configurations
at your convenience.

```dart
main() {
  var userConfig = new Configuration(...);
  
  // Merge with defaults
  var mergedConfig = new Configuration.merge(Configuration.DEFAULT, userConfig);
  
  // Merge multiple
  var multiMerged = new Configuration.mergeAll([...]);
  
  // Copy existing config
  var copy = new Configuration.copy(multiMerged);
}
```

# Planned Features
* WebSocket benchmarking
* Running tests across multiple CPU's/computers