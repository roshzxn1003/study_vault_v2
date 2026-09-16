import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/achievement.dart';

class GamificationState {
  final int currentStreak;
  final int longestStreak;
  final List<Achievement> achievements;

  GamificationState({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.achievements = const [],
  });

  GamificationState copyWith({
    int? currentStreak,
    int? longestStreak,
    List<Achievement>? achievements,
  }) {
    return GamificationState(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      achievements: achievements ?? this.achievements,
    );
  }
}

class GamificationNotifier extends StateNotifier<GamificationState> {
  GamificationNotifier() : super(GamificationState(
    achievements: [
      Achievement(id: 'first_note', title: 'First Note', description: 'Created your first note', icon: Icons.edit_note),
      Achievement(id: 'first_upload', title: 'Vault Starter', description: 'Uploaded your first file', icon: Icons.upload_file),
      Achievement(id: 'ai_explorer', title: 'AI Explorer', description: 'Asked your first AI question', icon: Icons.auto_awesome),
      Achievement(id: 'streak_7', title: 'Dedicated', description: '7 day study streak', icon: Icons.fireplace),
    ],
  ));

  void incrementStreak() {
    state = state.copyWith(currentStreak: state.currentStreak + 1);
    if (state.currentStreak > state.longestStreak) {
      state = state.copyWith(longestStreak: state.currentStreak);
    }
  }

  void unlockAchievement(String id) {
    final updated = state.achievements.map((a) {
      if (a.id == id) return Achievement(id: a.id, title: a.title, description: a.description, icon: a.icon, isUnlocked: true, unlockedAt: DateTime.now());
      return a;
    }).toList();
    state = state.copyWith(achievements: updated);
  }
}

final gamificationProvider = StateNotifierProvider<GamificationNotifier, GamificationState>((ref) {
  return GamificationNotifier();
});
