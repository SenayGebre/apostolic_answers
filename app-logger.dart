import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import 'models/log_entry.dart';
import 'models/log_level.dart';

class AppLogger {
  factory AppLogger() => _instance;

  AppLogger._internal();

  static final AppLogger _instance = AppLogger._internal();
  static const String _loggerName = 'BankAppLogger';
  static const int _maxRecentLogs = 1000;

  final Logger _rootLogger = Logger.root;
  final Map<String, Logger> _loggers = {};
  final List<LogEntry> _recentLogs = [];

  bool _initialized = false;
  bool _isDebugMode = false;

  List<LogEntry> get recentLogs => List.unmodifiable(_recentLogs);

  Future<void> init({
    required bool isDebugMode,
    LogLevel minLogLevel = LogLevel.info,
  }) async {
    if (_initialized) return;

    _isDebugMode = isDebugMode;

    Logger.root.level = minLogLevel.toLoggingLevel();
    Logger.root.clearListeners();
    Logger.root.onRecord.listen(_handleLogRecord);

    _initialized = true;

    final environment = isDebugMode ? 'DEBUG' : 'PRODUCTION';
    info(
      'Logging initialized',
      context: 'AppLogger',
      data: {
        'environment': environment,
        'min_log_level': minLogLevel.name,
      },
    );
  }

  Logger getLogger(String name) {
    return _loggers.putIfAbsent(name, () => Logger('$_loggerName.$name'));
  }

  void _handleLogRecord(LogRecord record) {
    final logEntry = LogEntry(
      timestamp: record.time,
      level: record.level.toAppLogLevel().name,
      message: record.message,
      context: record.loggerName.replaceFirst('$_loggerName.', ''),
      error: record.error?.toString(),
      stackTrace: record.stackTrace?.toString(),
      data: record.object is Map<String, dynamic> ? record.object! as Map<String, dynamic> : null,
    );

    _addLogEntry(logEntry);
    _logToConsole(record, logEntry);
    _logToFile(logEntry);
  }

  void _addLogEntry(LogEntry entry) {
    _recentLogs.add(entry);
    if (_recentLogs.length > _maxRecentLogs) {
      _recentLogs.removeAt(0);
    }
  }

  void _logToConsole(LogRecord record, LogEntry logEntry) {
    if (!_isDebugMode) return;
    final logString = logEntry.toLogString();
    final colorCode = _getColorCode(record.level);
    debugPrint('${colorCode ?? ''}$logString${colorCode != null ? '\x1B[0m' : ''}');
  }

  String? _getColorCode(Level level) {
    switch (level.value) {
      case Level.WARNING:
        return '\x1B[33m';
      case Level.SEVERE:
      case Level.SHOUT:
        return '\x1B[31m';
      default:
        return null;
    }
  }

  void _logToFile(LogEntry logEntry) async {
    if (!_isDebugMode || kIsWeb) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final file = File('${directory.path}/logs_$date.jsonl');
      await file.writeAsString('${jsonEncode(logEntry.toJson())}\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('Error writing to log file: $e');
    }
  }

  Future<File?> exportLogs() async {
    if (kIsWeb || _recentLogs.isEmpty) return null;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory.path}/export_logs_$timestamp.json');
      final exportData = {
        'timestamp': DateTime.now().toIso8601String(),
        'environment': _isDebugMode ? 'development' : 'production',
        'logs': _recentLogs.map((log) => log.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(exportData));
      return file;
    } catch (e) {
      debugPrint('Error exporting logs: $e');
      return null;
    }
  }

  void clearRecentLogs() {
    _recentLogs.clear();
  }

  void verbose(String message, {String? context, dynamic error, StackTrace? stackTrace, Map<String, dynamic>? data}) =>
      _log(Level.FINEST, message, context: context, error: error, stackTrace: stackTrace, data: data);

  void debug(String message, {String? context, dynamic error, StackTrace? stackTrace, Map<String, dynamic>? data}) =>
      _log(Level.FINE, message, context: context, error: error, stackTrace: stackTrace, data: data);

  void info(String message, {String? context, dynamic error, StackTrace? stackTrace, Map<String, dynamic>? data}) =>
      _log(Level.INFO, message, context: context, error: error, stackTrace: stackTrace, data: data);

  void warning(String message, {String? context, dynamic error, StackTrace? stackTrace, Map<String, dynamic>? data}) =>
      _log(Level.WARNING, message, context: context, error: error, stackTrace: stackTrace, data: data);

  void error(String message, {String? context, dynamic error, StackTrace? stackTrace, Map<String, dynamic>? data}) =>
      _log(Level.SEVERE, message, context: context, error: error, stackTrace: stackTrace, data: data);

  void critical(String message, {String? context, dynamic error, StackTrace? stackTrace, Map<String, dynamic>? data}) =>
      _log(Level.SHOUT, message, context: context, error: error, stackTrace: stackTrace, data: data);

  void _log(Level level, String message, {String? context, dynamic error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    final logger = context != null ? getLogger(context) : _rootLogger;
    logger.log(level, message, error, stackTrace, data);
  }

  void logPerformance(String operation, Duration duration, {String? context, Map<String, dynamic>? data}) {
    info(
      'Performance: $operation took ${duration.inMilliseconds}ms',
      context: context ?? 'Performance',
      data: {'operation': operation, 'duration_ms': duration.inMilliseconds, ...?data},
    );
  }

  Future<T> measurePerformance<T>(String operation, Future<T> Function() function, {String? context, Map<String, dynamic>? data}) async {
    final stopwatch = Stopwatch().start();
    try {
      return await function();
    } finally {
      stopwatch.stop();
      logPerformance(operation, stopwatch.elapsed, context: context, data: data);
    }
  }

  T measurePerformanceSync<T>(String operation, T Function() function, {String? context, Map<String, dynamic>? data}) {
    final stopwatch = Stopwatch().start();
    try {
      return function();
    } finally {
      stopwatch.stop();
      logPerformance(operation, stopwatch.elapsed, context: context, data: data);
    }
  }
}
