import 'package:build_runner/build_runner.dart';
import 'package:check_for_update/builder.dart';

final PhaseGroup PHASES = new PhaseGroup()
  ..newPhase().addAction(new CheckForUpdateBuilder(subDirectory: 'lib/src'),
      new InputSet('soniq', ['pubspec.yaml']));
