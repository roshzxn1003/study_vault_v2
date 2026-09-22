import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/widgets.dart';
import 'package:study_vault/features/sharing/domain/models/models.dart';
import 'package:study_vault/features/sharing/presentation/providers/sharing_providers.dart';
import 'package:study_vault/features/sharing/presentation/widgets/student_search_sheet.dart';
import 'package:study_vault/features/sharing/presentation/widgets/qr_discovery_modal.dart';
import 'package:study_vault/features/sharing/presentation/widgets/save_to_vault_dialog.dart';
import 'package:study_vault/features/sharing/presentation/widgets/create_group_dialog.dart';
import 'package:study_vault/features/sharing/presentation/screens/group_detail_screen.dart';
import 'package:study_vault/features/sharing/presentation/screens/create_study_pack_screen.dart';
import 'package:study_vault/features/sharing/presentation/screens/study_pack_detail_screen.dart';
import 'package:study_vault/features/sharing/presentation/screens/privacy_sharing_settings_screen.dart';

/// Custom FAB location ensuring buttons in sub-tabs float comfortably above the bottom navigation bar.
class FloatingAboveNavLocation extends FloatingActionButtonLocation {
  final double bottomClearance;
  const FloatingAboveNavLocation({this.bottomClearance = 100.0});

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX = scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.floatingActionButtonSize.width -
        20.0;
    final double fabY = scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.floatingActionButtonSize.height -
        bottomClearance;
    return Offset(fabX, fabY);
  }
}

/// Phase 9: Student Sharing, Study Groups, Study Packs, and Collaboration Suite.
class SharedScreen extends ConsumerStatefulWidget {
  const SharedScreen({super.key});

  @override
  ConsumerState<SharedScreen> createState() => _SharedScreenState();
}

class _SharedScreenState extends ConsumerState<SharedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _groupsSubTab = 0; // 0: Study Groups, 1: Study Packs

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleRevokeAccess(ShareItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: const Text('Stop Sharing?'),
        content: Text(
          'Stop sharing "${item.resourceTitle}" with @${item.recipientUsername ?? "student"}? '
          'They will lose access to this shared resource. Note: Any independent copy they already saved into their personal Vault will remain in their Vault.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Stop Sharing', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(sharedByMeProvider.notifier).revokeShare(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access revoked successfully.'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => _buildNotificationsSheetContent(scrollCtrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadNotifs = ref.watch(shareNotificationsProvider).unreadCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          'Shared & Collaboration',
          style: AppTypography.subtitle.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search_rounded, color: AppColors.textPrimary),
            tooltip: 'Search Students',
            onPressed: () => StudentSearchSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_rounded, color: AppColors.textPrimary),
            tooltip: 'My Study Vault QR',
            onPressed: () => QrDiscoveryModal.show(context),
          ),
          // Notification Bell
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                tooltip: 'Sharing Notifications',
                onPressed: () => _showNotificationsSheet(context),
              ),
              if (unreadNotifs > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      unreadNotifs > 9 ? '9+' : '$unreadNotifs',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: AppColors.textPrimary),
            tooltip: 'Privacy & Sharing Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacySharingSettingsScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryLight,
          labelColor: AppColors.primaryLight,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: AppTypography.subtitle.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Shared With Me'),
            Tab(text: 'Shared By Me'),
            Tab(text: 'Groups'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildSharedWithMeTab(),
            _buildSharedByMeTab(),
            _buildUnifiedGroupsTab(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: SHARED WITH ME
  // ===========================================================================
  Widget _buildSharedWithMeTab() {
    final state = ref.watch(sharedWithMeProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryLight));
    }

    if (state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppEmptyState(
            icon: Icons.inbox_rounded,
            title: 'Nothing has been shared with you yet.',
            description: 'Connect with classmates or scan student QR codes to exchange notes.',
            actionText: 'Search Students',
            onAction: () => StudentSearchSheet.show(context),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(sharedWithMeProvider.notifier).loadItems(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
        itemCount: state.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (ctx, index) {
          final item = state.items[index];
          final isExpired = item.isExpired;

          return Card(
            color: AppColors.surface,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isExpired ? AppColors.textMuted.withValues(alpha: 0.15) : AppColors.primaryLight.withValues(alpha: 0.15),
                        child: Icon(
                          Icons.description_outlined,
                          size: 18,
                          color: isExpired ? AppColors.textMuted : AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.resourceTitle,
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.bold,
                                decoration: isExpired ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            Text(
                              'Shared by @${item.ownerUsername?.replaceAll('@', '') ?? "scholar"} • ${item.relativeCreatedTime}',
                              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.status.color.withValues(alpha: 0.12),
                          borderRadius: AppRadius.chip,
                        ),
                        child: Text(
                          item.displayStatusText,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: item.status.color),
                        ),
                      ),
                    ],
                  ),
                  if (item.message?.isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: AppRadius.chip,
                      ),
                      child: Text(
                        '"${item.message!}"',
                        style: AppTypography.caption.copyWith(fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isExpired)
                        TextButton.icon(
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text('Open'),
                          onPressed: () {
                            context.push('/material/${item.resourceId}');
                          },
                        ),
                      if (!isExpired && item.canSaveCopy) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryLight,
                            foregroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          icon: const Icon(Icons.save_alt_rounded, size: 16),
                          label: const Text('Save to Library'),
                          onPressed: () => SaveToVaultDialog.show(context, share: item),
                        ),
                      ],
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                        tooltip: 'Remove from Shared',
                        onPressed: () => ref.read(sharedWithMeProvider.notifier).removeItem(item.id),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // TAB 2: SHARED BY ME
  // ===========================================================================
  Widget _buildSharedByMeTab() {
    final state = ref.watch(sharedByMeProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryLight));
    }

    if (state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppEmptyState(
            icon: Icons.send_outlined,
            title: 'Shared by me',
            description: 'You haven\'t shared any materials yet. Open any material in your Vault to share with classmates.',
            actionText: 'Go to Vault',
            onAction: () => context.go('/vault'),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(sharedByMeProvider.notifier).loadItems(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
        itemCount: state.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (ctx, index) {
          final item = state.items[index];

          return Card(
            color: AppColors.surface,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0x1A10B981),
                        child: Icon(Icons.arrow_outward_rounded, size: 18, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.resourceTitle, style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
                            Text(
                              'Shared with @${item.recipientUsername?.replaceAll('@', '') ?? "student"} • ${item.expiryDescription}',
                              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.status.color.withValues(alpha: 0.12),
                          borderRadius: AppRadius.chip,
                        ),
                        child: Text(
                          item.displayStatusText,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: item.status.color),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Permissions: ${item.permissions.map((p) => p.label).join(', ')}',
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      if (item.isActive)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          onPressed: () => _handleRevokeAccess(item),
                          child: const Text('Revoke Access', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // TAB 3: UNIFIED GROUPS & PACKS
  // ===========================================================================
  Widget _buildUnifiedGroupsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _groupsSubTab = 0),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _groupsSubTab == 0 ? AppColors.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _groupsSubTab == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.groups_rounded,
                            size: 16,
                            color: _groupsSubTab == 0 ? AppColors.primaryLight : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Study Groups',
                            style: AppTypography.caption.copyWith(
                              fontWeight: _groupsSubTab == 0 ? FontWeight.bold : FontWeight.normal,
                              color: _groupsSubTab == 0 ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _groupsSubTab = 1),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _groupsSubTab == 1 ? AppColors.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _groupsSubTab == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_zip_outlined,
                            size: 16,
                            color: _groupsSubTab == 1 ? AppColors.primaryLight : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Study Packs',
                            style: AppTypography.caption.copyWith(
                              fontWeight: _groupsSubTab == 1 ? FontWeight.bold : FontWeight.normal,
                              color: _groupsSubTab == 1 ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _groupsSubTab == 0 ? _buildGroupsTab() : _buildStudyPacksTab(),
        ),
      ],
    );
  }

  // ===========================================================================
  // SUB-VIEW: STUDY GROUPS
  // ===========================================================================
  Widget _buildGroupsTab() {
    final groupsState = ref.watch(studyGroupsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: const FloatingAboveNavLocation(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Create Group'),
        onPressed: () => CreateGroupDialog.show(context),
      ),
      body: groupsState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
          : groupsState.groups.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: AppEmptyState(
                      icon: Icons.groups_outlined,
                      title: 'Study Groups',
                      description: 'You\'re not in any study groups yet. Create a group for your semester or batch to exchange materials and questions.',
                      actionText: 'Create Study Group',
                      onAction: () => CreateGroupDialog.show(context),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(studyGroupsProvider.notifier).loadGroups(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
                    itemCount: groupsState.groups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (ctx, index) {
                      final group = groupsState.groups[index];
                      return Card(
                        color: AppColors.surface,
                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
                        child: InkWell(
                          borderRadius: AppRadius.card,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                                  child: const Icon(Icons.groups_rounded, color: AppColors.primaryLight),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(group.name, style: AppTypography.body.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
                                      if (group.description?.isNotEmpty == true) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          group.description!,
                                          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        'Owner: ${group.displayOwner} • ${group.memberCount} members',
                                        style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  // ===========================================================================
  // TAB 4: STUDY PACKS
  // ===========================================================================
  Widget _buildStudyPacksTab() {
    final packsState = ref.watch(studyPacksProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButtonLocation: const FloatingAboveNavLocation(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.folder_zip_outlined),
        label: const Text('Create Pack'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateStudyPackScreen()),
          );
        },
      ),
      body: packsState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
          : packsState.packs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: AppEmptyState(
                      icon: Icons.folder_zip_outlined,
                      title: 'Study Packs',
                      description: 'No Study Packs yet. Create curated collections of notes, diagrams, and question banks for focused exam revision.',
                      actionText: 'Create Study Pack',
                      onAction: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CreateStudyPackScreen()),
                        );
                      },
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(studyPacksProvider.notifier).loadPacks(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
                    itemCount: packsState.packs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (ctx, index) {
                      final pack = packsState.packs[index];
                      return Card(
                        color: AppColors.surface,
                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
                        child: InkWell(
                          borderRadius: AppRadius.card,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => StudyPackDetailScreen(pack: pack)),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                  child: const Icon(Icons.folder_zip_outlined, color: Color(0xFF8B5CF6)),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(pack.name, style: AppTypography.body.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
                                      if (pack.description?.isNotEmpty == true) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          pack.description!,
                                          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        'Created by ${pack.displayOwner} • ${pack.itemCount} materials',
                                        style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationsSheetContent(ScrollController scrollCtrl) {
    final notifsState = ref.watch(shareNotificationsProvider);
    final notifsNotifier = ref.read(shareNotificationsProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sharing Notifications',
                style: AppTypography.subtitle.copyWith(fontWeight: FontWeight.bold),
              ),
              if (notifsState.notifications.isNotEmpty)
                TextButton(
                  onPressed: () => notifsNotifier.markAllAsRead(),
                  child: const Text('Mark all as read', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
        const AppDivider(),
        Expanded(
          child: notifsState.notifications.isEmpty
              ? Center(
                  child: AppEmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'No notifications',
                    description: 'You have no pending sharing notifications.',
                  ),
                )
              : ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: notifsState.notifications.length,
                  separatorBuilder: (_, _) => const AppDivider(),
                  itemBuilder: (ctx, index) {
                    final notif = notifsState.notifications[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: notif.type.color.withValues(alpha: 0.15),
                        child: Icon(notif.type.icon, color: notif.type.color, size: 20),
                      ),
                      title: Text(
                        notif.title,
                        style: AppTypography.body.copyWith(
                          fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notif.message, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(notif.relativeTime, style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                      onTap: () {
                        notifsNotifier.markAsRead(notif.id);
                        Navigator.pop(ctx);
                        if (notif.type == ShareNotificationType.materialShared) {
                          _tabController.animateTo(0);
                        } else {
                          _tabController.animateTo(2);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
