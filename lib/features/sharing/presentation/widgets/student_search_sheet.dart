import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/widgets.dart';
import '../providers/sharing_providers.dart';
import '../../domain/models/models.dart';
import 'student_profile_preview_modal.dart';

/// Bottom sheet allowing users to search students by username or name.
class StudentSearchSheet extends ConsumerStatefulWidget {
  final ValueChanged<StudentProfile>? onSelectStudent;
  final String title;

  const StudentSearchSheet({
    super.key,
    this.onSelectStudent,
    this.title = 'Search Student',
  });

  static Future<StudentProfile?> show(
    BuildContext context, {
    String title = 'Search Student',
  }) {
    return showModalBottomSheet<StudentProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StudentSearchSheet(
        title: title,
        onSelectStudent: (student) => Navigator.pop(ctx, student),
      ),
    );
  }

  @override
  ConsumerState<StudentSearchSheet> createState() => _StudentSearchSheetState();
}

class _StudentSearchSheetState extends ConsumerState<StudentSearchSheet> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(studentSearchResultsProvider);
    final query = ref.watch(studentSearchQueryProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.md,
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(widget.title, style: AppTypography.subtitle.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Connect with other students via their unique @username.',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),

          // Search input
          AppSearchField(
            controller: _searchController,
            hint: 'Search @username or name...',
            onChanged: (val) {
              ref.read(studentSearchQueryProvider.notifier).state = val;
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Results
          Expanded(
            child: query.trim().isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search_rounded, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Enter a student\'s username to search',
                            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  )
                : searchAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryLight)),
                    error: (e, _) => Center(
                      child: Text('Error searching students: $e', style: const TextStyle(color: AppColors.error)),
                    ),
                    data: (results) {
                      if (results.isEmpty) {
                        return Center(
                          child: Text(
                            'No student found for "$query"',
                            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const AppDivider(),
                        itemBuilder: (ctx, index) {
                          final student = results[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                              child: Text(
                                student.initial,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                              ),
                            ),
                            title: Text(student.fullName, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${student.displayUsername}${student.publicAcademicSummary.isNotEmpty ? ' • ${student.publicAcademicSummary}' : ''}',
                              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                            ),
                            trailing: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryLight,
                                side: const BorderSide(color: AppColors.primaryLight),
                                shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              onPressed: () {
                                if (widget.onSelectStudent != null) {
                                  widget.onSelectStudent!(student);
                                } else {
                                  StudentProfilePreviewModal.show(context: ctx, profile: student);
                                }
                              },
                              child: const Text('Select', style: TextStyle(fontSize: 12)),
                            ),
                            onTap: () {
                              if (widget.onSelectStudent != null) {
                                widget.onSelectStudent!(student);
                              } else {
                                StudentProfilePreviewModal.show(context: ctx, profile: student);
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
