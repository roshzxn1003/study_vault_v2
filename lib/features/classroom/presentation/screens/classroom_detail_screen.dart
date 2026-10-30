import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/tokens/app_colors.dart';
import '../../../../core/design/tokens/app_typography.dart';
import '../providers/classroom_providers.dart';
import '../../domain/models/models.dart';

class ClassroomDetailScreen extends ConsumerStatefulWidget {
  final String classroomId;

  const ClassroomDetailScreen({
    super.key,
    required this.classroomId,
  });

  @override
  ConsumerState<ClassroomDetailScreen> createState() => _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState extends ConsumerState<ClassroomDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
                context.go('/classrooms');
              }
            },
          ),
          title: const Text('Error', style: TextStyle(color: AppColors.textPrimary)),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                'Classroom not found',
                style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go('/classrooms'),
                child: const Text('Back to Classrooms'),
              ),
            ],
          ),
        ),
      ),
      data: (state) {
        final c = state.classroom;
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
                  context.go('/classrooms');
                }
              },
            ),
            title: Text(
              c.name,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                tooltip: 'Copy Class Code',
                icon: const Icon(Icons.copy, color: AppColors.textSecondary, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: c.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Class code ${c.code} copied to clipboard!'),
                      backgroundColor: AppColors.primary,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Stream'),
                Tab(text: 'Classwork'),
                Tab(text: 'People'),
                Tab(text: 'Grades'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildStreamTab(context, state),
              _buildClassworkTab(context, state),
              _buildPeopleTab(context, state),
              _buildGradesTab(context, state),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 1: STREAM
  // ==========================================

  Widget _buildStreamTab(BuildContext context, ClassroomDetailState state) {
    final c = state.classroom;
    Color headerBg = const Color(0xFF312E81);
    if (c.bannerTheme == 'emerald') headerBg = const Color(0xFF064E3B);
    if (c.bannerTheme == 'amber') headerBg = const Color(0xFF78350F);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Class Banner Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: headerBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardOutline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      c.name,
                      style: AppTypography.titleLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.key, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          c.code,
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (c.section != null) ...[
                const SizedBox(height: 6),
                Text(
                  c.section!,
                  style: AppTypography.bodySmall.copyWith(color: Colors.white70),
                ),
              ],
              if (c.description != null && c.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  c.description!,
                  style: AppTypography.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Announcement Composer Card
        _buildAnnouncementComposer(context),
        const SizedBox(height: 16),

        // Stream Announcements List
        if (state.announcements.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 40, color: AppColors.textMuted),
                  const SizedBox(height: 8),
                  Text(
                    'No stream announcements yet',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          )
        else
          ...state.announcements.map((ann) => _buildAnnouncementCard(context, ann)),
      ],
    );
  }

  Widget _buildAnnouncementComposer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardOutline),
      ),
      child: InkWell(
        onTap: () => _showPostAnnouncementDialog(context),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.edit, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Announce something to your class...',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
              ),
            ),
            const Icon(Icons.send_outlined, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(BuildContext context, ClassroomAnnouncement ann) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: ann.authorRole == 'teacher'
                    ? AppColors.primary
                    : AppColors.surfaceElevated,
                child: Text(
                  ann.authorName.isNotEmpty ? ann.authorName[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          ann.authorName,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (ann.authorRole == 'teacher') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Teacher',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _formatDate(ann.createdAt),
                      style: AppTypography.labelSmall.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (ann.isPinned)
                const Icon(Icons.push_pin, size: 16, color: Colors.amberAccent),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ann.content,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: CLASSWORK
  // ==========================================

  Widget _buildClassworkTab(BuildContext context, ClassroomDetailState state) {
    return Column(
      children: [
        // Topic Filter Chips
        if (state.topics.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All Topics'),
                    selected: state.selectedTopicId == null,
                    onSelected: (_) => ref
                        .read(classroomDetailProvider(widget.classroomId).notifier)
                        .filterByTopic(null),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: state.selectedTopicId == null ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...state.topics.map(
                    (topic) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(topic.title),
                        selected: state.selectedTopicId == topic.id,
                        onSelected: (_) => ref
                            .read(classroomDetailProvider(widget.classroomId).notifier)
                            .filterByTopic(topic.id),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: state.selectedTopicId == topic.id
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Items List
        Expanded(
          child: state.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.assignment_outlined, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        'No classwork posted yet',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    return _buildClassworkItemCard(context, item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildClassworkItemCard(BuildContext context, ClassroomItem item) {
    IconData iconData = Icons.assignment;
    Color iconColor = AppColors.primary;
    if (item.isMaterial) {
      iconData = Icons.menu_book;
      iconColor = Colors.tealAccent;
    } else if (item.isQuiz) {
      iconData = Icons.quiz;
      iconColor = Colors.orangeAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardOutline),
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(iconData, color: iconColor, size: 24),
        ),
        title: Text(
          item.title,
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            if (item.dueDate != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Due ${_formatDate(item.dueDate!)}',
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${item.maxPoints} pts',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: () {
          context.push('/classroom/${widget.classroomId}/assignment/${item.id}');
        },
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: PEOPLE
  // ==========================================

  Widget _buildPeopleTab(BuildContext context, ClassroomDetailState state) {
    final teachers = state.members.where((m) => m.isTeacher).toList();
    final students = state.members.where((m) => !m.isTeacher).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Teachers Section
        Text(
          'Teachers',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Divider(color: AppColors.border, height: 16),
        ...teachers.map((t) => _buildPersonTile(t.name, t.email, isTeacher: true)),
        const SizedBox(height: 24),

        // Students Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Classmates',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${students.length} students',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        const Divider(color: AppColors.border, height: 16),
        if (students.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No students enrolled yet. Share the class code "${state.classroom.code}" to invite them.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          )
        else
          ...students.map((s) => _buildPersonTile(s.name, s.email, isTeacher: false)),
      ],
    );
  }

  Widget _buildPersonTile(String name, String? email, {required bool isTeacher}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isTeacher ? AppColors.primary : AppColors.surfaceElevated,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (email != null && email.isNotEmpty)
                  Text(
                    email,
                    style: AppTypography.labelSmall.copyWith(color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: GRADES
  // ==========================================

  Widget _buildGradesTab(BuildContext context, ClassroomDetailState state) {
    if (state.items.isEmpty) {
      return Center(
        child: Text(
          'No assignments created to grade yet.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Class Gradebook',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Overview of student submissions and scores.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        ...state.items.where((i) => i.isAssignment).map((item) {
          final itemSubs = state.submissions.where((s) => s.itemId == item.id).toList();
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardOutline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'Max: ${item.maxPoints} pts',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${itemSubs.length} Submissions recorded',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
                if (itemSubs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...itemSubs.map((sub) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              sub.studentName,
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                            ),
                            Text(
                              sub.grade != null ? '${sub.grade!.toInt()} pts' : 'Pending Review',
                              style: AppTypography.bodySmall.copyWith(
                                color: sub.grade != null ? Colors.greenAccent : Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _showPostAnnouncementDialog(BuildContext context) {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardOutline),
        ),
        title: Text(
          'Post Announcement',
          style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Share an update, notes, or discussion with your class...',
            hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6)),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
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
              final text = textCtrl.text.trim();
              if (text.isEmpty) return;

              Navigator.pop(dialogCtx);
              await ref.read(classroomDetailProvider(widget.classroomId).notifier).postAnnouncement(
                    authorId: 'user-current',
                    authorName: 'You (Instructor)',
                    content: text,
                  );
            },
            child: const Text('Post', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
