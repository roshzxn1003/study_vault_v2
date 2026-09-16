import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UserPlan { free, premium }

class EntitlementService {
  // This should be backed by the 'subscriptions' table in Supabase
  UserPlan get currentPlan => UserPlan.free;

  bool canUseFeature(String featureId) {
    if (currentPlan == UserPlan.premium) return true;
    
    final freeFeatures = {
      'basic_ai',
      'basic_ocr',
      'basic_notes',
    };
    
    return freeFeatures.contains(featureId);
  }
}

final entitlementServiceProvider = Provider((ref) => EntitlementService());
