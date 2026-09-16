import 'package:flutter_riverpod/flutter_riverpod.dart';

class UsageLimit {
  final bool allowed;
  final int remaining;
  final DateTime resetAt;

  UsageLimit({required this.allowed, required this.remaining, required this.resetAt});
}

class AiUsageService {
  // In a real app, this would call the 'ai_usage' table in Supabase
  
  Future<UsageLimit> checkLimit(String feature) async {
    // Mocking a free tier limit
    return UsageLimit(
      allowed: true,
      remaining: 26,
      resetAt: DateTime.now().add(const Duration(days: 12)),
    );
  }

  Future<void> recordUsage(String feature) async {
    // Update record in Supabase 'ai_usage' table
  }
}

final aiUsageServiceProvider = Provider((ref) => AiUsageService());
