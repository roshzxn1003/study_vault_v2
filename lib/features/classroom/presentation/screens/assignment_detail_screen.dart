import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/tokens/app_colors.dart';
import '../../../../core/design/tokens/app_typography.dart';
import '../providers/classroom_providers.dart';
import '../../data/services/classroom_ai_service.dart';
import '../../domain/models/models.dart';

class AssignmentDetailScreen extends ConsumerStatefulWidget {
  final String classroomId;
  final String itemId;

  const AssignmentDetailScreen({
    super.key,
    required this.classroomId,
    required this.itemId,
  });

  @override
  ConsumerState<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends ConsumerState<AssignmentDetailScreen> {
  final TextEditingController _submissionCtrl = TextEditingController();
  final TextEditingController _socraticQuestionCtrl = TextEditingController();

  String? _socraticHint;
  bool _isLoadingHint = false;

  String? _preSubmissionReview;
  bool _isLoadingReview = false;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _submissionCtrl.dispose();
    _socraticQuestionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(classroomDetailProvider(widget.classroomId));

    return detailAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/classroom/${widget.classroomId}');
              }
            },
          ),
          title: const Text('Assignment', style: TextStyle(color: AppColors.textPrimary)),
        ),
        body: const Center(
          child: Text('Assignment could not be loaded', style: TextStyle(color: AppColors.textSecondary)),
        ),
      ),
      data: (state) {
        final item = state.items.firstWhere(
          (i) => i.id == widget.itemId,
          orElse: () => ClassroomItem(
            id: widget.itemId,
            classroomId: widget.classroomId,
            type: ClassroomItemType.assignment,
            title: 'Assignment',
            description: '',
            creatorId: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final mySubmission = state.submissions.cast<ClassroomSubmission?>().firstWhere(
              (s) => s?.itemId == widget.itemId && s?.studentId == 'user-current',
              orElse: () => null,
            );

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
                  context.go('/classroom/${widget.classroomId}');
                }
              },
            ),
            title: Text(
              item.isAssignment ? 'Assignment Details' : 'Classwork',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardOutline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.assignment, color: AppColors.primary, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: AppTypography.titleMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (item.dueDate != null) ...[
                                    const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Due ${item.dueDate!.day}/${item.dueDate!.month}/${item.dueDate!.year}',
                                      style: AppTypography.labelSmall.copyWith(color: AppColors.textMuted),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Text(
                                    '${item.maxPoints} points',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.border, height: 24),
                    Text(
                      'Instructions',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Rubric Section
              if (item.rubric.isNotEmpty) ...[
                Text(
                  'Grading Rubric',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...item.rubric.map(
                  (r) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.cardOutline),
                          ),
                          child: Text(
                            '${r.maxPoints} pts',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.title,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                r.description,
                                style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ==========================================
              // AI SOCRATIC ASSIGNMENT TUTOR
              // ==========================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'AI Socratic Tutor',
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Stuck on this assignment? Ask for conceptual hints without spoiling the full solution.',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _socraticQuestionCtrl,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. How does leader election resolve split votes?',
                        hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6), fontSize: 13),
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        icon: _isLoadingHint
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.lightbulb_outline, size: 16),
                        label: Text(_isLoadingHint ? 'Thinking...' : 'Get Socratic Hint'),
                        onPressed: _isLoadingHint
                            ? null
                            : () async {
                                final q = _socraticQuestionCtrl.text.trim();
                                if (q.isEmpty) return;

                                setState(() => _isLoadingHint = true);
                                final hint = await ClassroomAiService.instance.getSocraticHint(
                                  assignmentTitle: item.title,
                                  assignmentDescription: item.description,
                                  studentQuestion: q,
                                );
                                setState(() {
                                  _socraticHint = hint;
                                  _isLoadingHint = false;
                                });
                              },
                      ),
                    ),
                    if (_socraticHint != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          _socraticHint!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // STUDENT SUBMISSION PANEL
              // ==========================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardOutline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your Submission',
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: mySubmission != null ? Colors.green.withValues(alpha: 0.2) : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            mySubmission != null
                                ? (mySubmission.isGraded ? 'Graded (${mySubmission.grade?.toInt()} pts)' : 'Turned In')
                                : 'Assigned',
                            style: AppTypography.labelSmall.copyWith(
                              color: mySubmission != null ? Colors.greenAccent : Colors.orangeAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _submissionCtrl,
                      maxLines: 5,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Enter your response, code outline, or summary of your solution...',
                        hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6)),
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Actions Row: Check My Work & Turn In
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: _isLoadingReview
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                  )
                                : const Icon(Icons.rule_folder_outlined, size: 18),
                            label: Text(_isLoadingReview ? 'Checking...' : 'Check My Work'),
                            onPressed: _isLoadingReview
                                ? null
                                : () async {
                                    final content = _submissionCtrl.text.trim();
                                    if (content.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please write your draft before checking!')),
                                      );
                                      return;
                                    }

                                    setState(() => _isLoadingReview = true);
                                    final review = await ClassroomAiService.instance.checkDraftAgainstRubric(
                                      assignmentTitle: item.title,
                                      assignmentDescription: item.description,
                                      rubric: item.rubric,
                                      draftContent: content,
                                    );
                                    setState(() {
                                      _preSubmissionReview = review;
                                      _isLoadingReview = false;
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check_circle_outline, size: 18),
                            label: Text(_isSubmitting ? 'Submitting...' : 'Turn In'),
                            onPressed: _isSubmitting
                                ? null
                                : () async {
                                    final content = _submissionCtrl.text.trim();
                                    if (content.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Submission cannot be empty.')),
                                      );
                                      return;
                                    }

                                    setState(() => _isSubmitting = true);
                                    final messenger = ScaffoldMessenger.of(context);
                                    final success = await ref
                                        .read(classroomDetailProvider(widget.classroomId).notifier)
                                        .submitAssignment(
                                          itemId: item.id,
                                          studentId: 'user-current',
                                          studentName: 'Student User',
                                          content: content,
                                        );
                                    if (mounted) {
                                      setState(() => _isSubmitting = false);
                                      if (success) {
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('Assignment turned in successfully!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),

                    if (_preSubmissionReview != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          _preSubmissionReview!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}
