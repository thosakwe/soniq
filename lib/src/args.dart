import 'package:args/args.dart';

final ArgParser SONIQ_ARGS = new ArgParser(allowTrailingOptions: true)
  ..addFlag('help', abbr: 'h', help: 'Print this help information.')
  ..addOption('format',
      abbr: 'f',
      help: 'The format to print results in. Allowed: ["json", "stdout"]..')
  ..addOption('threads',
      abbr: 'j', help: 'The number of isolates (threads) to run tests in.')
  ..addOption('connections',
      abbr: 'c', help: 'The number of concurrent connections to maintain.')
  ..addOption('command',
      abbr: 'x', help: 'An optional shell command to run prior to testing.')
  ..addOption('duration',
      abbr: 'd', help: 'The length, in milliseconds, of the stress test.')
  ..addOption('out', abbr: 'o', help: 'A file path to write results to.')
  ..addOption('profile',
      abbr: 'p', help: 'The name of the profile to run, if any.');
