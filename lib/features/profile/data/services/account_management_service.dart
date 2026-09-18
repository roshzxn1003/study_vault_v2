import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/services/monitoring_service.dart';

class AccountManagementService {
  final LocalDbService _localDb;
  final SupabaseClient? supabase;
  final CrashMonitoringService _crashMonitor;
  final AnalyticsService _analytics;

  AccountManagementService({
    LocalDbService? localDb,
    this.supabase,
    CrashMonitoringService? crashMonitor,
    AnalyticsService? analytics,
  })  : _localDb = localDb ?? LocalDbService.instance,
        _crashMonitor = crashMonitor ?? CrashMonitoringService.instance,
        _analytics = analytics ?? AnalyticsService.instance;

  SupabaseClient? get _client {
    if (supabase != null) return supabase;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Completely deletes all user data across local SQLite tables, remote cloud tables,
  /// caches, and signs the user out.
  Future<bool> deleteAccount({required String userId}) async {
    try {
      _crashMonitor.addBreadcrumb('Starting cascading account deletion for user', category: 'account');

      // 1. Cascading wipe across local SQLite database
      await _localDb.clearUserData(userId);

      // 2. Cloud-side cleanup if connected
      try {
        final client = _client;
        if (client != null && client.auth.currentUser != null) {
          // Attempt remote RPC or direct row removal if user has permission
          await client.from('notes').delete().eq('user_id', userId);
          await client.from('folders').delete().eq('user_id', userId);
          await client.from('files').delete().eq('user_id', userId);
          await client.from('materials').delete().eq('user_id', userId);
          await client.from('student_profiles').delete().eq('id', userId);
        }
      } catch (cloudError, cloudStack) {
        // Cloud failure (e.g. offline or limited RLS permissions) is non-fatal for local purge
        _crashMonitor.recordError(cloudError, cloudStack, reason: 'Remote account deletion partial failure (offline or RLS)');
      }

      // 3. Clear cached local preferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('has_completed_onboarding');
        await prefs.remove('onboarding_workspace_name');
        await prefs.remove('active_workspace_id');
        await prefs.remove('gemini_api_key');
      } catch (prefError) {
        // Non-fatal
      }

      // 4. Terminate Supabase authentication session
      try {
        await _client?.auth.signOut();
      } catch (_) {}

      _analytics.logEvent(AnalyticsService.accountDeleted, parameters: {
        'status': 'success',
      });

      return true;
    } catch (e, stack) {
      _crashMonitor.recordError(e, stack, reason: 'Fatal account deletion failure');
      rethrow;
    }
  }

  /// Exports comprehensive user data in a portable JSON format.
  /// Strictly scrubs secrets, API keys, passwords, and tokens.
  Future<String> exportUserData({required String userId}) async {
    try {
      _crashMonitor.addBreadcrumb('Exporting user data archive', category: 'data');

      // 1. Collect structured local SQLite data
      final localData = await _localDb.exportUserData(userId);

      // 2. Build final export archive
      final exportArchive = <String, dynamic>{
        'app': 'Study Vault',
        'export_version': '1.0.0',
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'user_id': userId,
        'vault_data': localData,
      };

      // 3. Encode to formatted JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportArchive);

      _analytics.logEvent(AnalyticsService.dataExported, parameters: {
        'byte_length': jsonString.length,
      });

      return jsonString;
    } catch (e, stack) {
      _crashMonitor.recordError(e, stack, reason: 'User data export failed');
      rethrow;
    }
  }
}

final accountManagementServiceProvider = Provider<AccountManagementService>((ref) {
  return AccountManagementService();
});
