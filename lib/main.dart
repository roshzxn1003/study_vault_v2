import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/config/supabase_config.dart';
import 'core/services/monitoring_service.dart';
import 'features/import/presentation/providers/import_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  CrashMonitoringService.instance.init();

  final supabaseUrl = SupabaseConfig.isConfigured
      ? SupabaseConfig.url
      : 'https://placeholder.supabase.co';
  final supabaseAnonKey = SupabaseConfig.isConfigured
      ? SupabaseConfig.anonKey
      : 'placeholder-anon-key';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey, // ignore: deprecated_member_use
  );

  runApp(
    const ProviderScope(
      child: StudyVaultApp(),
    ),
  );
}

class StudyVaultApp extends ConsumerStatefulWidget {
  const StudyVaultApp({super.key});

  @override
  ConsumerState<StudyVaultApp> createState() => _StudyVaultAppState();
}

class _StudyVaultAppState extends ConsumerState<StudyVaultApp> {
  StreamSubscription? _shareSubscription;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logEvent(AnalyticsService.appLaunch);
    _initShareReceiver();
  }

  void _initShareReceiver() {
    final shareService = ref.read(incomingShareServiceProvider);

    // 1. Listen for incoming runtime shares (when app is already running or backgrounded)
    _shareSubscription = shareService.incomingShareStream.listen((items) {
      if (items.isNotEmpty && mounted) {
        ref.read(importProvider.notifier).stageItems(items);
        final router = ref.read(appRouterProvider);
        router.push('/import');
      }
    });

    // 2. Check for cold-start share (when app was launched from Android Share Target)
    Future.microtask(() async {
      final initialItems = await shareService.getInitialSharedItems();
      if (initialItems != null && initialItems.isNotEmpty && mounted) {
        await ref.read(importProvider.notifier).stageItems(initialItems);
        if (mounted) {
          final router = ref.read(appRouterProvider);
          router.push('/import');
        }
      }
    });
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Study Vault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
