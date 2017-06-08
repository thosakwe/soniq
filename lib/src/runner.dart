import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:cli_util/cli_logging.dart';
import 'package:kilobyte/kilobyte.dart';
import 'configuration.dart';

double average(Iterable<num> tallies) {
  if (tallies.isEmpty) return -1.0;
  var sum = tallies.reduce((a, b) => a + b);
  return sum / tallies.length;
}

class Runner {
  final Configuration configuration;

  Runner(this.configuration);

  Future<RunnerResult> run() {
    Process p;

    if (configuration.command?.isNotEmpty == true) {
      print('Pre-test command: "${configuration.command}"\n');
      var split = configuration.command.split(' ');
      Process.start(split.first, split.skip(1).toList()).then((process) {
        p = process;
        //process.stdout.listen(stdout.add);
        //process.stderr.listen(stderr.add);
      });
    }

    var c = new Completer<RunnerResult>();
    var errorPort = new ReceivePort();
    var startupPort = new ReceivePort();
    var resultPort = new ReceivePort();
    var logger = new Logger.standard();
    Progress progress;
    int results = 0;
    List<Isolate> isolates = new List<Isolate>(configuration.threads);
    Map<int, SendPort> ports = {};
    int socketErrors = 0, transfer = 0, totalRequests = 0;
    List<int> latencies = [];

    // Listen for errors...
    errorPort.listen((e) {
      print('Error: $e');
    });

    // On startup, receive send port and assign accordingly...
    startupPort.listen((List packet) {
      int id = packet[0];
      SendPort sp = packet[1];
      ports[id] = sp;

      if (ports.length == configuration.threads) {
        // Start running!!!
        int connectionsPerThread =
            (configuration.connections / configuration.threads).round();
        int total = connectionsPerThread * configuration.threads;

        print('Now testing: ${configuration.url}');
        print('*  ${configuration.duration.inMilliseconds}ms');
        print('*  ${configuration.threads} threads');
        print('*  $total total connections');

        // Send info about testing...
        var mission = new Mission(
                url: configuration.url,
                connections: connectionsPerThread,
                duration: configuration.duration.inMilliseconds)
            .toJson();

        for (int j = 0; j < configuration.threads; j++) ports[j].send(mission);
        progress = logger.progress('Stress testing');
      }
    });

    // Listen for results...
    resultPort.listen((Map map) {
      var r = new Result.fromMap(map);
      latencies.addAll(r.latencies);
      socketErrors += r.socketErrors;
      transfer += r.transfer;
      totalRequests += r.totalRequests;

      if (++results == configuration.threads) {
        progress.finish(message: 'All threads completed.', showTiming: true);
        var result = new RunnerResult(
            averageLatency: average(latencies),
            socketErrors: socketErrors,
            totalRequests: totalRequests,
            transfer: new Size(bytes: transfer));
        c.complete(result);
        isolates.forEach((i) => i.kill());
        errorPort.close();
        resultPort.close();
        startupPort.close();
        p?.kill();
      }
    });

    // Spawn the threads!
    for (int i = 0; i < configuration.threads; i++) {
      Isolate
          .spawn(
              isolateMain,
              [
                i,
                startupPort.sendPort,
                resultPort.sendPort,
                configuration.headers
              ],
              onError: errorPort.sendPort)
          .then((isolate) {
        isolates[i] = isolate;
      });
    }

    return c.future;
  }
}

bool done = false;

void isolateMain(List args) {
  int id = args[0];
  SendPort startupPort = args[1], resultPort = args[2];
  Map<String, String> headers = args[3];
  var missionPort = new ReceivePort();

  // Listen for incoming missions!!!
  missionPort.listen((Map data) async {
    var mission = new Mission.fromMap(data);
    var url = Uri.parse(mission.url);

    // Create a number of connections!!!
    List<HttpClient> clients = [];
    var result = new Result(threadId: id);

    new Timer(new Duration(milliseconds: mission.duration), () {
      // Send result...
      done = true;
      clients.forEach((c) => c.close(force: true));
      resultPort.send(result.toJson());
    });

    // Start clients
    for (int i = 0; i < mission.connections; i++) {
      var client = new HttpClient();
      clients.add(client);
      startClient(client, url, headers, result);
    }
  });

  // Send startup notification
  startupPort.send([id, missionPort.sendPort]);
}

void startClient(
    HttpClient client, Uri url, Map<String, dynamic> headers, Result result) {
  client.getUrl(url).then((rq) async {
    headers.forEach((k, v) => rq.headers.add(k, v.toString()));
    var sw = new Stopwatch()..start();
    var rs = await rq.close();
    sw.stop();
    result.totalRequests++;
    result.latencies.add(sw.elapsedMicroseconds);
    result.transfer += await rs.length;
    if (!done) startClient(client, url, headers, result);
  }).catchError((e, st) {
    if (e is SocketException) result.socketErrors++;
  });
}

class Mission {
  String url;
  int connections, duration;

  Mission({this.url, this.connections, this.duration}) {}

  factory Mission.fromMap(Map map) => new Mission(
      url: map['url'],
      connections: map['connections'],
      duration: map['duration']);

  Map<String, dynamic> toJson() {
    return {'url': url, 'connections': connections, 'duration': duration};
  }
}

class Result {
  int threadId, transfer, socketErrors, totalRequests;
  final List<int> latencies = [];

  Result(
      {this.threadId,
      this.transfer: 0,
      this.socketErrors: 0,
      this.totalRequests: 0,
      Iterable<int> latencies: const []}) {
    this.latencies.addAll(latencies ?? []);
  }

  factory Result.fromMap(Map map) => new Result(
      threadId: map['thread_id'],
      transfer: map['transfer'],
      socketErrors: map['socket_errors'],
      totalRequests: map['total_requests'],
      latencies: map['latencies']);

  Map<String, dynamic> toJson() {
    return {
      'thread_id': threadId,
      'transfer': transfer,
      'socket_errors': socketErrors,
      'total_requests': totalRequests,
      'latencies': latencies
    };
  }
}

class RunnerResult {
  final double averageLatency;
  final int socketErrors, totalRequests;
  final Size transfer;

  RunnerResult(
      {this.averageLatency,
      this.socketErrors,
      this.totalRequests,
      this.transfer});

  Map<String, dynamic> toJson() {
    return {
      'average_latency': averageLatency,
      'socket_errors': socketErrors,
      'total_requests': totalRequests,
      'transfer': transfer.inBytes
    };
  }
}
