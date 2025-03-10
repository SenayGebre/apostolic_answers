// lib/core/logging/models/log_level.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';

enum LogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
  critical,
}

// Extension for converting between LogLevel enum and logging package's Level
extension LogLevelExtension on LogLevel {
  Level toLoggingLevel() {
    switch (this) {
      case LogLevel.verbose:
        return Level.FINEST;
      case LogLevel.debug:
        return Level.FINE;
      case LogLevel.info:
        return Level.INFO;
      case LogLevel.warning:
        return Level.WARNING;
      case LogLevel.error:
        return Level.SEVERE;
      case LogLevel.critical:
        return Level.SHOUT;
    }
  }

  String get name {
    switch (this) {
      case LogLevel.verbose:
        return 'VERBOSE';
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARNING';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.critical:
        return 'CRITICAL';
    }
  }
}

// Extension for converting from logging package's Level to LogLevel
extension LoggingLevelExtension on Level {
  LogLevel toAppLogLevel() {
    if (this == Level.FINEST || this == Level.FINER) return LogLevel.verbose;
    if (this == Level.FINE || this == Level.CONFIG) return LogLevel.debug;
    if (this == Level.INFO) return LogLevel.info;
    if (this == Level.WARNING) return LogLevel.warning;
    if (this == Level.SEVERE) return LogLevel.error;
    if (this == Level.SHOUT) return LogLevel.critical;
    return LogLevel.info; // Default
  }
}
