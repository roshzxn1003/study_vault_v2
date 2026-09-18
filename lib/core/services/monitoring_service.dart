import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Privacy-preserving crash and error monitoring service.
/// Collects operational error telemetry and breadcrumbs while strictly scrubbing
/// sensitive user data, API keys, credentials, and prompt text.
class CrashMonitoringService {
  static final CrashMonitoringService _instance = CrashMonitoringService._internal();
  static CrashMonitoringService get instance => _instance;

  CrashMonitoringService._internal();

  final List<Map<String, dynamic>> _breadcrumbs = [];
  final List<Map<String, dynamic>> _recordedErrors = [];
  static const int maxBreadcrumbs = 50;
  static const int maxRecordedErrors = 20;

  bool _initialized = false;

  /// Initializes global error hooks for Flutter and PlatformDispatcher.
  void init() {
    if (_initialized) return;
    _initialized = true;

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      recordError(
        details.exception,
        details.stack,
        reason: details.context?.toDescription(),
        fatal: false,
      );
      if (originalOnError != null) {
        originalOnError(details);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// Adds an in-memory breadcrumb tracking recent user-flow milestones.
  void addBreadcrumb(String message, {String category = 'navigation', Map<String, dynamic>? data}) {
    final sanitizedData = data != null ? _sanitizeMap(data) : null;
    final crumb = {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'category': category,
      'message': _sanitizeString(message),
      'data': ?sanitizedData,
    };

    _breadcrumbs.add(crumb);
    if (_breadcrumbs.length > maxBreadcrumbs) {
      _breadcrumbs.removeAt(0);
    }
  }

  /// Records an uncaught or caught exception with sanitized stack trace and context.
  void recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    Map<String, dynamic>? metadata,
  }) {
    final errorRecord = {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'exception': _sanitizeString(exception.toString()),
      'reason': reason != null ? _sanitizeString(reason) : null,
      'fatal': fatal,
      'stack': stack?.toString(),
      'metadata': metadata != null ? _sanitizeMap(metadata) : null,
    };

    _recordedErrors.add(errorRecord);
    if (_recordedErrors.length > maxRecordedErrors) {
      _recordedErrors.removeAt(0);
    }

    if (kDebugMode) {
      debugPrint('🔴 [CrashMonitoring] ${fatal ? "FATAL " : ""}$exception ${reason != null ? "($reason)" : ""}');
    }
  }

  List<Map<String, dynamic>> get recentBreadcrumbs => List.unmodifiable(_breadcrumbs);
  List<Map<String, dynamic>> get recordedErrors => List.unmodifiable(_recordedErrors);

  @visibleForTesting
  void clearForTesting() {
    _breadcrumbs.clear;
    _recordedErrors.clear();
  }

  /// Scrub passwords, tokens, API keys, and sensitive fields.
  static String _sanitizeString(String input) {
    // Mask potential API keys (e.g. AIzaSy..., Bearer tokens)
    return input
        .replaceAll(RegExp(r'AIza[0-9A-Za-z-_]{16,}'), '[MASKED_KEY]')
        .replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9-_.]+'), 'Bearer [MASKED_TOKEN]')
        .replaceAll(RegExp(r'[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+'), '[MASKED_EMAIL]');
  }

  static Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
    const sensitiveKeys = {
      'password',
      'token',
      'secret',
      'key',
      'api_key',
      'apiKey',
      'prompt',
      'content',
      'notes',
      'email',
      'auth',
      'credential',
    };

    final sanitized = <String, dynamic>{};
    for (final entry in map.entries) {
      if (sensitiveKeys.any((k) => entry.key.toLowerCase().contains(k))) {
        sanitized[entry.key] = '[REDACTED]';
      } else if (entry.value is Map<String, dynamic>) {
        sanitized[entry.key] = _sanitizeMap(entry.value as Map<String, dynamic>);
      } else if (entry.value is String) {
        sanitized[entry.key] = _sanitizeString(entry.value as String);
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }
}

/// Privacy-conscious application telemetry and product analytics service.
/// Records operational milestones without collecting student academic notes,
/// search queries, or AI prompts.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get instance => _instance;

  AnalyticsService._internal();

  final List<Map<String, dynamic>> _loggedEvents = [];
  static const int maxLoggedEvents = 100;

  // Standard release event names
  static const String appLaunch = 'app_launch';
  static const String screenView = 'screen_view';
  static const String authLogin = 'auth_login';
  static const String authLogout = 'auth_logout';
  static const String accountDeleted = 'account_deleted';
  static const String dataExported = 'data_exported';
  static const String materialImported = 'material_imported';
  static const String ragQueryExecuted = 'rag_query_executed';
  static const String quizGenerated = 'quiz_generated';
  static const String flashcardReviewed = 'flashcard_reviewed';
  static const String syncCompleted = 'sync_completed';

  void logEvent(String name, {Map<String, dynamic>? parameters}) {
    final sanitizedParams = parameters != null ? CrashMonitoringService._sanitizeMap(parameters) : null;
    final event = {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'name': name,
      'parameters': ?sanitizedParams,
    };

    _loggedEvents.add(event);
    if (_loggedEvents.length > maxLoggedEvents) {
      _loggedEvents.removeAt(0);
    }

    if (kDebugMode) {
      debugPrint('📊 [Analytics] $name ${sanitizedParams ?? ""}');
    }
  }

  List<Map<String, dynamic>> get loggedEvents => List.unmodifiable(_loggedEvents);

  @visibleForTesting
  void clearForTesting() {
    _loggedEvents.clear();
  }
}

final crashMonitoringServiceProvider = Provider<CrashMonitoringService>((ref) => CrashMonitoringService.instance);
final analyticsServiceProvider = Provider<AnalyticsService>((ref) => AnalyticsService.instance);
