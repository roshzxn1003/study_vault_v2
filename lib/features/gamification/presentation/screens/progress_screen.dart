import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/theme/app_colors.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text("Study Analytics & Progress")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Level & XP Hero Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF9333EA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('LEVEL 4 SCHOLAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 20),
                          SizedBox(width: 4),
                          Text('3 Day Streak', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('620 / 800 XP', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('180 XP until Level 5 • Master Scholar badge unlocked soon', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: 620 / 800,
                      minHeight: 8,
                      backgroundColor: Colors.black26,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Weekly Study Hours Chart
            const Text("Weekly Activity (Hours)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Total this week: 5.8 hrs", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('+24% vs last week', style: TextStyle(color: AppColors.emerald, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildDayBar("Mon", 0.6, "1.2h"),
                      _buildDayBar("Tue", 0.4, "0.8h"),
                      _buildDayBar("Wed", 0.85, "1.7h"),
                      _buildDayBar("Thu", 0.3, "0.6h"),
                      _buildDayBar("Fri", 0.75, "1.5h", isToday: true),
                      _buildDayBar("Sat", 0.0, "0h"),
                      _buildDayBar("Sun", 0.0, "0h"),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Subject Mastery List
            const Text("Subject Mastery", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            _buildMasteryTile(context, "Database Management Systems", 0.82, AppColors.primary),
            _buildMasteryTile(context, "Operating Systems", 0.65, AppColors.emerald),
            _buildMasteryTile(context, "Computer Networks", 0.50, AppColors.cyan),
            _buildMasteryTile(context, "Data Structures & Algorithms", 0.38, AppColors.amber),
            const SizedBox(height: 24),

            // Badges & Achievements
            const Text("Badges & Achievements", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _buildBadgeCard("Vault Pioneer", "Uploaded 5+ study materials", Icons.workspace_premium, AppColors.amber, true),
                _buildBadgeCard("Streak Master", "3 consecutive study days", Icons.local_fire_department, Colors.orangeAccent, true),
                _buildBadgeCard("ACID Wizard", "100% on Transactions Quiz", Icons.psychology, AppColors.primary, true),
                _buildBadgeCard("Night Owl", "Studied after 10 PM", Icons.nightlight_round, AppColors.cyan, false),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDayBar(String day, double heightFactor, String label, {bool isToday = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        const SizedBox(height: 6),
        Container(
          width: 18,
          height: 80,
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Container(
            width: 18,
            height: (80 * heightFactor).clamp(4.0, 80.0),
            decoration: BoxDecoration(
              color: isToday ? AppColors.primary : AppColors.primary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            color: isToday ? AppColors.primaryLight : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMasteryTile(BuildContext context, String title, double score, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
              ),
              Text('${(score * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score,
              minHeight: 6,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(String name, String desc, IconData icon, Color color, bool isUnlocked) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnlocked ? AppColors.surfaceElevated : AppColors.surfaceElevated.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isUnlocked ? color.withValues(alpha: 0.4) : AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: color.withValues(alpha: isUnlocked ? 0.2 : 0.05),
                child: Icon(icon, size: 16, color: isUnlocked ? color : AppColors.textMuted),
              ),
              const Spacer(),
              if (isUnlocked)
                const Icon(Icons.check_circle, size: 14, color: AppColors.emerald),
            ],
          ),
          const SizedBox(height: 8),
          Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isUnlocked ? AppColors.textPrimary : AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
