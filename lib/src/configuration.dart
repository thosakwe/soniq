import 'package:args/args.dart';
import 'package:merge_map/merge_map.dart';

class Configuration {
  String url, command, format;
  int threads, connections;
  Duration duration;
  final Map<String, dynamic> headers = {};

  Configuration(
      {this.url,
      this.command,
      this.format,
      this.threads,
      this.connections,
      this.duration,
      Map<String, dynamic> headers: const {}}) {
    this.headers.addAll(headers ?? {});
  }

  static final Configuration DEFAULT = new Configuration(
      format: ConfigurationFormat.STDOUT,
      threads: 5,
      connections: 5,
      duration: new Duration(seconds: 30));

  factory Configuration.fromArgs(ArgResults result) {
    return new Configuration(
        url: result.rest.isNotEmpty ? result.rest.first : null,
        command: result['command'],
        format: result['format'],
        threads:
            result['threads'] != null ? int.parse(result['threads']) : null,
        connections: result['connections'] != null
            ? int.parse(result['connections'])
            : null,
        duration: result['duration'] != null
            ? new Duration(milliseconds: int.parse(result['duration']))
            : null);
  }

  factory Configuration.fromMap(Map map) {
    return new Configuration(
        url: map['url'],
        command: map['command'],
        format: map['format'],
        threads: map['threads'],
        connections: map['connections'],
        duration: map['duration'] is int
            ? new Duration(milliseconds: map['duration'])
            : null,
        headers: map['headers']);
  }

  factory Configuration.copy(Configuration configuration) => new Configuration(
      url: configuration.url,
      command: configuration.command,
      format: configuration.format,
      threads: configuration.threads,
      connections: configuration.connections,
      duration: configuration.duration,
      headers: configuration.headers);

  factory Configuration.merge(Configuration a, Configuration b) {
    var config = new Configuration(
        url: b?.url ?? a?.url,
        command: b?.command ?? a?.command,
        format: b?.format ?? a?.format,
        threads: b?.threads ?? a?.threads,
        connections: b?.connections ?? a?.connections,
        duration: b?.duration ?? a?.duration,
        headers: mergeMap([a?.headers, b?.headers]));

    return config;
  }

  factory Configuration.mergeAll(Iterable<Configuration> configurations) {
    if (configurations.isEmpty) return new Configuration.copy(DEFAULT);
    return configurations.reduce((a, b) => new Configuration.merge(a, b));
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'format': format,
      'threads': threads,
      'connections': connections,
      'duration': duration.inMilliseconds,
      'headers': headers
    };
  }

  void verify() {
    if (url?.isNotEmpty != true)
      throw new StateError('Invalid or no URL provided in configuration.');

    if (threads == null || threads < 0)
      throw new StateError(
          'Invalid or no thread count provided in configuration.');

    if (connections == null)
      throw new StateError(
          'Invalid or no connection count provided in configuration.');

    if (connections < threads)
      throw new StateError(
          'Cannot maintain less connections ($connections) than there are threads ($threads).');

    if (duration == null || duration.inSeconds <= 0)
      throw new StateError(
          'Invalid or no duration provided in configuration. Tests must run for at least one second.');

    if (format != null && !ConfigurationFormat.ALLOWED.contains(format))
      throw new UnsupportedError(
          'Cannot format results as "$format". Allowed formats: ${ConfigurationFormat.ALLOWED}');
  }
}

abstract class ConfigurationFormat {
  static const String JSON = 'json';
  static const String STDOUT = 'stdout';
  static const List<String> ALLOWED = const [JSON, STDOUT];
}
