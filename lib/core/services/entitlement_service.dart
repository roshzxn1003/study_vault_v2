import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UserPlan { free, premium }

class EntitlementService {
  // All features are 100% free and permanently unlocked for all students.
  UserPlan get currentPlan => UserPlan.free;

  bool canUseFeature(String featureId) {
    return true;
  }
}

final entitlementServiceProvider = Provider((ref) => EntitlementService());
