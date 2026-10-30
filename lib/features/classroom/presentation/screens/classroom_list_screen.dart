import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/tokens/app_colors.dart';
import '../../../../core/design/tokens/app_typography.dart';
import '../providers/classroom_providers.dart';
import '../../domain/models/models.dart';

class ClassroomListScreen extends ConsumerStatefulWidget {
  const ClassroomListScreen({super.key});

  @override
  ConsumerState<ClassroomListScreen> createState() => _ClassroomListScreenState();
}

class _ClassroomListScreenState extends ConsumerState<ClassroomListScreen> {
  @override
  Widget build(BuildContext context) {
    final classroomsAsync = ref.watch(classroomListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          'Classrooms',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Join with Code',
            icon: const Icon(Icons.add_link, color: AppColors.primary),
            onPressed: () => _showJoinClassDialog(context),
          ),
          IconButton(
            tooltip: 'Create Class',
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            onPressed: () => _showCreateClassDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: classroomsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                'Failed to load classrooms',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(classroomListProvider.notifier).loadClassrooms(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (classrooms) {
          if (classrooms.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () => ref.read(classroomListProvider.notifier).loadClassrooms(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: classrooms.length,
              itemBuilder: (context, index) {
                final c = classrooms[index];
                return _buildClassroomCard(context, c);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardOutline),
              ),
              child: const Icon(Icons.school_outlined, size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'No Classrooms Yet',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a course as an instructor or enter a 6-character class code from your teacher to enroll.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.group_add),
                  label: const Text('Join Class'),
                  onPressed: () => _showJoinClassDialog(context),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Class'),
                  onPressed: () => _showCreateClassDialog(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassroomCard(BuildContext context, Classroom c) {
    Color headerBg = const Color(0xFF312E81); // Deep indigo default
    if (c.bannerTheme == 'emerald') headerBg = const Color(0xFF064E3B);
    if (c.bannerTheme == 'amber') headerBg = const Color(0xFF78350F);
    if (c.bannerTheme == 'rose') headerBg = const Color(0xFF881337);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardOutline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/classroom/${c.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Banner
            Container(
              padding: const EdgeInsets.all(16),
              color: headerBg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: AppTypography.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (c.section != null && c.section!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                c.section!,
                                style: AppTypography.bodySmall.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          c.code,
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(
                        c.creatorName,
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Bottom Info Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        '${c.studentCount} Students',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Enter Classroom',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinClassDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardOutline),
        ),
        title: Text(
          'Join Classroom',
          style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ask your teacher for the 6-character class code, then enter it below:',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. SV-DIST',
                hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final code = codeCtrl.text.trim();
              if (code.isEmpty) return;

              final messenger = ScaffoldMessenger.of(context);
              final router = GoRouter.of(context);
              Navigator.pop(dialogCtx);
              final joined = await ref.read(classroomListProvider.notifier).joinClassroomWithCode(
                    code: code,
                    studentId: 'user-current',
                    studentName: 'Student User',
                  );

              if (!mounted) return;

              if (joined != null) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Successfully enrolled in "${joined.name}"!'),
                    backgroundColor: Colors.green,
                  ),
                );
                router.push('/classroom/${joined.id}');
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Class code not found. Please verify with instructor.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Join', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCreateClassDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final sectionCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final roomCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardOutline),
        ),
        title: Text(
          'Create Classroom',
          style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Class Name (required)',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: sectionCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Section (e.g. Fall 2026)',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: subjectCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: roomCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Room',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final messenger = ScaffoldMessenger.of(context);
              final router = GoRouter.of(context);
              Navigator.pop(dialogCtx);
              final created = await ref.read(classroomListProvider.notifier).createClassroom(
                    name: name,
                    section: sectionCtrl.text.trim().isEmpty ? null : sectionCtrl.text.trim(),
                    subject: subjectCtrl.text.trim().isEmpty ? null : subjectCtrl.text.trim(),
                    room: roomCtrl.text.trim().isEmpty ? null : roomCtrl.text.trim(),
                    creatorId: 'user-current',
                    creatorName: 'Instructor (You)',
                  );

              if (!mounted) return;

              if (created != null) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Created class "${created.name}" (Code: ${created.code})'),
                    backgroundColor: Colors.green,
                  ),
                );
                router.push('/classroom/${created.id}');
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
