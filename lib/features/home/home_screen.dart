import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/theme/app_colors.dart';
import 'package:study_vault/features/home/presentation/widgets/dashboard_header.dart';
import 'package:study_vault/features/home/presentation/widgets/quick_actions_grid.dart';
import 'package:study_vault/features/home/presentation/widgets/ai_topic_launcher_sheet.dart';
import 'package:study_vault/features/home/presentation/widgets/quick_scratchpad_sheet.dart';
import 'package:study_vault/features/home/presentation/widgets/exam_goal_dialog.dart';
import 'package:study_vault/features/folders/presentation/providers/folders_provider.dart';
import 'package:study_vault/features/notes/presentation/providers/notes_provider.dart';
import 'package:study_vault/core/services/document_import_service.dart';
import 'package:study_vault/features/home/presentation/providers/home_provider.dart';
import 'package:study_vault/core/providers/database_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedVaultTab = 0; // 0: All, 1: Documents/PDFs, 2: Notes, 3: Folders
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateFolderDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Create Subject Folder', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g., Data Structures, Physics',
            labelText: 'Folder Name',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                await ref.read(folderRepositoryProvider).createFolder(name: name);
                ref.invalidate(foldersProvider);
                ref.invalidate(vaultStatsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _importDocument() async {
    try {
      final importService = ref.read(documentImportServiceProvider);
      final fileData = await importService.pickAndImportDocument(context: context);
      if (fileData != null && mounted) {
        ref.invalidate(allFilesProvider);
        ref.invalidate(vaultStatsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported "${fileData['name']}" into Study Vault!'),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View PDF',
              textColor: Colors.white,
              onPressed: () => context.push('/files/${fileData['id']}'),
            ),
          ),
        );
        context.push('/files/${fileData['id']}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(foldersProvider);
    final notesAsync = ref.watch(allNotesProvider);
    final filesAsync = ref.watch(allFilesProvider);
    final statsAsync = ref.watch(vaultStatsProvider);
    final examGoalsAsync = ref.watch(examGoalsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(foldersProvider);
            ref.invalidate(allNotesProvider);
            ref.invalidate(allFilesProvider);
            ref.invalidate(homeDataProvider);
            ref.invalidate(vaultStatsProvider);
            ref.invalidate(examGoalsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Greeting & Streak Counter
                const DashboardHeader(),
                const SizedBox(height: 18),

                // Search & Quick AI Hub Trigger Bar
                _buildSearchAndAiBar(),
                const SizedBox(height: 20),

                // Vault Metrics & Daily Target Progress
                _buildVaultMetricsBanner(statsAsync),
                const SizedBox(height: 22),

                // Active Exam Target or Goal Setup Card
                _buildExamTargetWidget(examGoalsAsync),
                const SizedBox(height: 24),

                // Quick Action Buttons Grid
                const SectionTitle(title: 'Quick Tools & Actions'),
                const SizedBox(height: 12),
                const QuickActionsGrid(),
                const SizedBox(height: 26),

                // AI Study Assistant Carousel
                _buildAiStudyToolsCarousel(),
                const SizedBox(height: 26),

                // Interactive Vault Explorer (Tabs & Items)
                _buildVaultExplorerSection(filesAsync, notesAsync, foldersAsync),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSearchAndAiBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
              onTap: () => context.push('/search'),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Search vault notes, PDFs, topics...',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => AiTopicLauncherSheet.show(context),
              icon: const Icon(Icons.auto_awesome, size: 15),
              label: const Text('AI Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVaultMetricsBanner(AsyncValue<Map<String, dynamic>> statsAsync) {
    return statsAsync.when(
      data: (stats) {
        final folderCount = stats['folderCount'] ?? 0;
        final noteCount = stats['noteCount'] ?? 0;
        final fileCount = stats['fileCount'] ?? 0;
        final streak = stats['streak'] ?? 1;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF3730A3).withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricPill(
                    icon: Icons.folder_rounded,
                    label: 'Subjects',
                    value: '$folderCount',
                    color: AppColors.primaryLight,
                    onTap: () => context.push('/folders'),
                  ),
                  _buildMetricDivider(),
                  _buildMetricPill(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'PDF Docs',
                    value: '$fileCount',
                    color: AppColors.cyan,
                    onTap: () => setState(() => _selectedVaultTab = 1),
                  ),
                  _buildMetricDivider(),
                  _buildMetricPill(
                    icon: Icons.notes_rounded,
                    label: 'Notes',
                    value: '$noteCount',
                    color: AppColors.emerald,
                    onTap: () => setState(() => _selectedVaultTab = 2),
                  ),
                  _buildMetricDivider(),
                  _buildMetricPill(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Streak',
                    value: '$streak d',
                    color: AppColors.amber,
                    onTap: () => context.push('/gamification'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 70),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _buildMetricDivider() {
    return Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.15));
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 15),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamTargetWidget(AsyncValue<List<Map<String, dynamic>>> examGoalsAsync) {
    return examGoalsAsync.when(
      data: (goals) {
        if (goals.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.flag_circle_rounded, color: AppColors.primaryLight, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set Next Exam Target',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'AI calculates daily milestones and active recall',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => ExamGoalDialog.show(context),
                  child: const Text('+ Target', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          );
        }

        final primaryGoal = goals.first;
        final targetDateStr = primaryGoal['target_date'] as String? ?? '';
        final targetDate = DateTime.tryParse(targetDateStr) ?? DateTime.now().add(const Duration(days: 7));
        final daysLeft = (targetDate.difference(DateTime.now()).inDays + 1).clamp(0, 365);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4338CA), Color(0xFF6D28D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                blurRadius: 14,
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
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '$daysLeft Days Left',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 20),
                    tooltip: 'Add Exam',
                    onPressed: () => ExamGoalDialog.show(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                primaryGoal['title'] ?? 'Upcoming Exam',
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                'Subject: ${primaryGoal['subject'] ?? 'Course Study'}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => AiTopicLauncherSheet.show(context, initialTopic: primaryGoal['subject']),
                    icon: const Icon(Icons.school_outlined, size: 14),
                    label: const Text('AI Lesson', style: TextStyle(fontSize: 11)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4338CA),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => context.push('/exam/plan'),
                    child: const Text('Open AI Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 70),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _buildAiStudyToolsCarousel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionTitle(title: 'Interactive AI Study Arena'),
            TextButton(
              onPressed: () => AiTopicLauncherSheet.show(context),
              child: const Text('Open Hub'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 115,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildStudyFeatureCard(
                icon: Icons.school_rounded,
                title: 'Socratic Tutor',
                subtitle: 'Step-by-step master lessons',
                color: AppColors.primary,
                onTap: () => AiTopicLauncherSheet.show(context),
              ),
              const SizedBox(width: 12),
              _buildStudyFeatureCard(
                icon: Icons.quiz_rounded,
                title: 'Quiz Arena',
                subtitle: 'Instant MCQ test & grading',
                color: AppColors.emerald,
                onTap: () => context.push('/study/quiz/general'),
              ),
              const SizedBox(width: 12),
              _buildStudyFeatureCard(
                icon: Icons.style_rounded,
                title: 'Flashcards',
                subtitle: 'Spaced active recall cards',
                color: AppColors.amber,
                onTap: () => context.push('/study/flashcards/general'),
              ),
              const SizedBox(width: 12),
              _buildStudyFeatureCard(
                icon: Icons.sticky_note_2_rounded,
                title: 'Scratchpad',
                subtitle: 'Formula & equation board',
                color: AppColors.cyan,
                onTap: () => QuickScratchpadSheet.show(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudyFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 175,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color, size: 18),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textSecondary),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVaultExplorerSection(
    AsyncValue<List<Map<String, dynamic>>> filesAsync,
    AsyncValue<List<Map<String, dynamic>>> notesAsync,
    AsyncValue<List<Map<String, dynamic>>> foldersAsync,
  ) {
    final files = filesAsync.value ?? [];
    final notes = notesAsync.value ?? [];
    final folders = foldersAsync.value ?? [];

    final isVaultEmpty = files.isEmpty && notes.isEmpty && folders.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionTitle(title: 'Your Study Vault'),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.upload_file_rounded, size: 20),
                  tooltip: 'Import PDF',
                  onPressed: _importDocument,
                ),
                IconButton(
                  icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                  tooltip: 'New Subject Folder',
                  onPressed: _showCreateFolderDialog,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Filter Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTabPill('All Vault (${files.length + notes.length + folders.length})', 0),
              const SizedBox(width: 8),
              _buildTabPill('PDFs & Documents (${files.length})', 1),
              const SizedBox(width: 8),
              _buildTabPill('Notes (${notes.length})', 2),
              const SizedBox(width: 8),
              _buildTabPill('Subjects (${folders.length})', 3),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (isVaultEmpty)
          _buildEmptyVaultOnboarding()
        else
          _buildVaultTabContent(files, notes, folders),
      ],
    );
  }

  Widget _buildTabPill(String label, int index) {
    final isSelected = _selectedVaultTab == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedVaultTab = index),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceElevated,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.cardBorder),
    );
  }

  Widget _buildVaultTabContent(
    List<Map<String, dynamic>> files,
    List<Map<String, dynamic>> notes,
    List<Map<String, dynamic>> folders,
  ) {
    switch (_selectedVaultTab) {
      case 1: // Documents
        if (files.isEmpty) return _buildNoItemsCard('No PDF documents imported yet.', 'Import a PDF from device', _importDocument);
        return _buildFilesGrid(files);

      case 2: // Notes
        if (notes.isEmpty) return _buildNoItemsCard('No notes written yet.', 'Create your first note', () => context.push('/notes/create'));
        return _buildNotesList(notes);

      case 3: // Folders
        if (folders.isEmpty) return _buildNoItemsCard('No subject folders created.', 'Create Subject Folder', _showCreateFolderDialog);
        return _buildFoldersGrid(folders);

      case 0: // All
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (files.isNotEmpty) ...[
              const Text('Recent Documents & PDFs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              _buildFilesGrid(files.take(4).toList()),
              const SizedBox(height: 18),
            ],
            if (notes.isNotEmpty) ...[
              const Text('Recent Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              _buildNotesList(notes.take(3).toList()),
              const SizedBox(height: 18),
            ],
            if (folders.isNotEmpty) ...[
              const Text('Subject Folders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              _buildFoldersGrid(folders.take(4).toList()),
            ],
          ],
        );
    }
  }

  Widget _buildFilesGrid(List<Map<String, dynamic>> files) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: files.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final f = files[i];
        final name = f['name'] ?? 'Document.pdf';
        final type = f['file_type'] ?? 'PDF';
        final sizeKb = ((f['file_size'] ?? 1500000) / 1024).toStringAsFixed(0);

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/files/${f['id']}'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.cyan.withValues(alpha: 0.15),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.cyan, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$type • $sizeKb KB • Indexed for AI',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'View PDF',
                    style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotesList(List<Map<String, dynamic>> notes) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: notes.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final n = notes[i];
        final title = n['title'] ?? 'Untitled Note';
        final snippet = (n['content'] ?? '').replaceAll('#', '').replaceAll('*', '').trim();

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/notes/${n['id']}'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.emerald.withValues(alpha: 0.15),
                  child: const Icon(Icons.edit_note_rounded, color: AppColors.emerald, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        snippet.isEmpty ? 'No additional text' : snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFoldersGrid(List<Map<String, dynamic>> folders) {
    final colors = [AppColors.primary, AppColors.emerald, AppColors.cyan, AppColors.amber];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        final color = colors[index % colors.length];

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/folder/${folder['id']}'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(Icons.folder_rounded, color: color, size: 20),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder['name'] ?? 'Subject Folder',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    const Text('Tap to view notes & docs', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyVaultOnboarding() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.library_books_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 14),
          const Text(
            'Your Study Vault is Ready',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Import your lecture PDFs, textbooks, or write quick notes. The AI study tutor will index everything for instant Socratic reasoning.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _showCreateFolderDialog,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                  label: const Text('New Folder', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _importDocument,
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: const Text('Import PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoItemsCard(String message, String buttonText, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 32, color: AppColors.textSecondary),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: onTap,
            child: Text(buttonText, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
    );
  }
}
