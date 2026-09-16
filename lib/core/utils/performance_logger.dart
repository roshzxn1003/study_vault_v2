import 'dart:developer';

class PerformanceLogger {
  static void logEvent(String event, {Duration? duration}) {
    final timestamp = DateTime.now().toIso8601String();
    final durationText = duration != null ? ' Duration: ${duration.inMilliseconds}ms' : '';
    log('[PERF] $timestamp - $event$durationText');
  }
}
