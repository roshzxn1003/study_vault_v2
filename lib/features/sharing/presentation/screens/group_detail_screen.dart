import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/widgets.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import '../providers/sharing_providers.dart';
import '../../domain/models/models.dart';
import '../widgets/invite_group_member_dialog.dart';
import '../widgets/share_to_group_dialog.dart';
import '../widgets/save_to_vault_dialog.dart';

/// Screen presenting a Study Group's collaborative materials feed, member list, and settings.
class GroupDetailScreen extends ConsumerStatefulWidget {
  final StudyGroup group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentUserId => ref.read(authRepositoryProvider).getCurrentUser()?.id ?? 'guest';
  bool get _isOwner => widget.group.isOwner(_currentUserId);

  Future<void> _handleLeaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: const Text('Leave Study Group?'),
        content: const Text(
          'You will no longer receive updates or materials from this group. Previously saved copies in your personal Vault will remain intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave Group', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(studyGroupsProvider.notifier).leaveGroup(widget.group.id);
      if (mounted) context.pop();
    }
  }

  Future<void> _handleDeleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: const Text('Delete Study Group?'),
        content: const Text(
          'This will permanently delete this group for all members. Materials saved into members\' personal vaults will remain safe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Group', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(studyGroupsProvider.notifier).deleteGroup(widget.group.id);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersProvider(widget.group.id));
    final resourcesAsync = ref.watch(groupResourcesProvider(widget.group.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.group.name,
          style: AppTypography.subtitle.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_outlined),
              tooltip: 'Invite Student',
              onPressed: () => InviteGroupMemberDialog.show(context, group: widget.group),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'leave') _handleLeaveGroup();
              if (val == 'delete') _handleDeleteGroup();
            },
            itemBuilder: (ctx) => [
              if (!_isOwner)
                const PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app_rounded, color: AppColors.error, size: 18),
                      SizedBox(width: 8),
                      Text('Leave Group', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              if (_isOwner)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                      SizedBox(width: 8),
                      Text('Delete Group', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryLight,
          labelColor: AppColors.primaryLight,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: AppTypography.subtitle.copyWith(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Materials Feed'),
            Tab(text: 'Members'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Group Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: const BoxDecoration(
                color: AppColors.surfaceSecondary,
                border: Border(bottom: AppBorders.subtle),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.group.description?.isNotEmpty == true)
                          Text(
                            widget.group.description!,
                            style: AppTypography.body.copyWith(fontSize: 13, color: AppColors.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 2),
                        Text(
                          'Created by ${widget.group.displayOwner} • ${widget.group.memberCount} members',
                          style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share Material', style: TextStyle(fontSize: 12)),
                    onPressed: () => ShareToGroupDialog.show(context, preselectedGroupId: widget.group.id),
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Materials Feed
                  resourcesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryLight)),
                    error: (e, _) => Center(child: Text('Error loading feed: $e')),
                    data: (resources) {
                      if (resources.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: AppEmptyState(
                              icon: Icons.menu_book_rounded,
                              title: 'No materials shared yet',
                              description: 'Share notes, diagrams, and revision questions with members in this group.',
                              actionText: 'Share Material to Group',
                              onAction: () => ShareToGroupDialog.show(context, preselectedGroupId: widget.group.id),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: resources.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (ctx, index) {
                          final res = resources[index];
                          return Card(
                            color: AppColors.surface,
                            shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0x1A3B82F6),
                                child: Icon(Icons.description_outlined, color: AppColors.primaryLight),
                              ),
                              title: Text(res.resourceTitle, style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                'Shared by ${res.displaySharer} • ${res.relativeCreatedTime}',
                                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                              ),
                              trailing: res.canSaveCopy
                                  ? IconButton(
                                      icon: const Icon(Icons.save_alt_rounded, color: AppColors.primaryLight),
                                      tooltip: 'Save Copy to My Vault',
                                      onPressed: () {
                                        final shareItem = ShareItem(
                                          id: res.id,
                                          ownerId: res.sharedBy,
                                          ownerUsername: res.sharedByUsername,
                                          resourceId: res.resourceId,
                                          resourceTitle: res.resourceTitle,
                                          permissions: res.permissions,
                                          createdAt: res.createdAt,
                                        );
                                        SaveToVaultDialog.show(context, share: shareItem);
                                      },
                                    )
                                  : null,
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // Tab 2: Members List
                  membersAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryLight)),
                    error: (e, _) => Center(child: Text('Error loading members: $e')),
                    data: (members) {
                      return ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: members.length,
                        separatorBuilder: (_, _) => const AppDivider(),
                        itemBuilder: (ctx, index) {
                          final m = members[index];
                          final isMe = m.userId == _currentUserId;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                              child: Text(
                                m.displayName.isNotEmpty ? m.displayName[0].toUpperCase() : 'S',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(m.displayName, style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
                                if (isMe) ...[
                                  const SizedBox(width: 6),
                                  const Text('(You)', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                ],
                              ],
                            ),
                            subtitle: Text(m.displayUsername, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: m.role == GroupRole.owner
                                    ? AppColors.primaryLight.withValues(alpha: 0.15)
                                    : AppColors.surfaceSecondary,
                                borderRadius: AppRadius.chip,
                              ),
                              child: Text(
                                m.role.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: m.role == GroupRole.owner ? AppColors.primaryLight : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
