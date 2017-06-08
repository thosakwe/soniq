import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:soniq/soniq.dart';
import 'package:yaml/yaml.dart' as yaml;

main(List<String> args) async {
  try {
    var result = SONIQ_ARGS.parse(args);

    if (result['help']) {
      printHelp(stdout);
      return;
    }

    Configuration configFromFile;
    var configFile = new File('soniq.yaml');

    if (await configFile.exists()) {
      var contents = await configFile.readAsString();
      var doc = yaml
          .loadYamlDocument(contents, sourceUrl: configFile.uri)
          .contents
          .value;
      configFromFile = chooseConfiguration(doc, result['profile']);
    }

    var config = new Configuration.mergeAll([
      Configuration.DEFAULT,
      configFromFile,
      new Configuration.fromArgs(result)
    ]);
    config.verify();

    var runner = new Runner(config);
    var report = await runner.run();
    var sink =
        result.wasParsed('out') ? new File(result['out']).openWrite() : stdout;

    if (result['format'] == ConfigurationFormat.JSON) {
      sink.write(JSON.encode(report.toJson()));
    } else {
      var requestsPerSecond = report.totalRequests / config.duration.inSeconds;

      sink.writeln('Total requests: ${report.totalRequests}');
      sink.writeln(
          'Requests per second: ' + requestsPerSecond.toStringAsFixed(2));

      if (report.averageLatency >= 1000)
        sink.writeln(
            'Average latency: ${(report.averageLatency / 1000).toStringAsFixed(2)}ms');
      else
        sink.writeln(
            'Average latency: ${report.averageLatency.toStringAsFixed(2)}us');
      sink.writeln('Total bytes read: ${report.transfer}');

      if (report.socketErrors > 0)
        sink.writeln('Socket errors: ${report.socketErrors}');
    }

    await sink.close();
  } on ArgParserException catch (e) {
    stderr.writeln('fatal error: ${e.message}');
    printHelp(stderr);
    exitCode = 1;
  } catch (e, st) {
    stderr.writeln('fatal error: $e');
    stderr.writeln(st);
    exitCode = 1;
  }
}

Configuration chooseConfiguration(
    Map<String, dynamic> doc, String profileName) {
  List<Configuration> configs = [];
  Configuration defaultConfig;

  doc.forEach((k, v) {
    if (v is Map) {
      if (k == 'default')
        defaultConfig = new Configuration.fromMap(v);
      else if (k == profileName) configs.add(new Configuration.fromMap(v));
    }
  });

  if (profileName != null && profileName != 'default' && configs.isEmpty)
    throw new UnsupportedError(
        'Could not find a configuration named "$profileName" in "soniq.yaml".');

  if (defaultConfig != null) configs.insert(0, defaultConfig);
  return configs.isNotEmpty ? new Configuration.mergeAll(configs) : null;
}

void printHelp(IOSink sink) {
  sink
    ..writeln('usage: soniq [options...] <url>')
    ..writeln()
    ..writeln('Options:')
    ..writeln(SONIQ_ARGS.usage);
}
