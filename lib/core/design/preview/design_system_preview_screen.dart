import 'package:flutter/material.dart';
import '../design_system.dart';

/// Development-only preview screen showcasing the complete Study Vault Design System.
/// Demonstrates tokens, typography, buttons, inputs, cards, chips, icons, states, and modals.
class DesignSystemPreviewScreen extends StatefulWidget {
  const DesignSystemPreviewScreen({super.key});

  @override
  State<DesignSystemPreviewScreen> createState() => _DesignSystemPreviewScreenState();
}

class _DesignSystemPreviewScreenState extends State<DesignSystemPreviewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  int _selectedChipIndex = 0;
  bool _isLoadingButton = false;

  final List<String> _tabs = [
    'Colors',
    'Typography',
    'Buttons',
    'Fields',
    'Cards',
    'Chips',
    'States',
    'Overlays',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        title: 'Design System Preview',
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primaryLight,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildColorsTab(),
          _buildTypographyTab(),
          _buildButtonsTab(),
          _buildFieldsTab(),
          _buildCardsTab(),
          _buildChipsTab(),
          _buildStatesTab(),
          _buildOverlaysTab(),
        ],
      ),
    );
  }

  // 1. Colors Tab
  Widget _buildColorsTab() {
    return ListView(
      padding: AppSpacing.p24,
      children: [
        const AppSectionHeader(
          title: 'Base Surfaces (Obsidian / Zinc)',
          subtitle: 'Clean background and elevated surfaces without neon glow',
        ),
        _buildColorSwatch('Background', AppColors.background, '#09090B'),
        _buildColorSwatch('Surface Primary', AppColors.surface, '#18181B'),
        _buildColorSwatch('Surface Secondary', AppColors.surfaceSecondary, '#202023'),
        _buildColorSwatch('Surface Elevated', AppColors.surfaceElevated, '#27272A'),
        _buildColorSwatch('Border', AppColors.border, '#27272A'),
        AppSpacing.v24,

        const AppSectionHeader(
          title: 'Restrained Accent & Semantics',
          subtitle: 'Single primary accent with semantic statuses',
        ),
        _buildColorSwatch('Primary Accent', AppColors.primary, '#6366F1'),
        _buildColorSwatch('Primary Light', AppColors.primaryLight, '#818CF8'),
        _buildColorSwatch('Destructive', AppColors.destructive, '#EF4444'),
        _buildColorSwatch('Success', AppColors.success, '#10B981'),
        _buildColorSwatch('Warning', AppColors.warning, '#F59E0B'),
        _buildColorSwatch('Info', AppColors.info, '#3B82F6'),
        AppSpacing.v24,

        const AppSectionHeader(
          title: 'File Type Indicators',
          subtitle: 'Restrained academic document badges',
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildFileIconShowcase('PDF', AppFileType.pdf),
            _buildFileIconShowcase('Notes', AppFileType.note),
            _buildFileIconShowcase('Word', AppFileType.document),
            _buildFileIconShowcase('Image', AppFileType.image),
            _buildFileIconShowcase('Audio', AppFileType.audio),
            _buildFileIconShowcase('Folder', AppFileType.folder),
          ],
        ),
      ],
    );
  }

  Widget _buildColorSwatch(String label, Color color, String hex) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brMd,
        border: AppBorders.allStandard,
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppRadius.brSm,
              border: AppBorders.allStandard,
            ),
          ),
          AppSpacing.h16,
          Text(label, style: AppTypography.body),
          const Spacer(),
          Text(hex, style: AppTypography.caption),
        ],
      ),
    );
  }

  Widget _buildFileIconShowcase(String label, AppFileType type) {
    return Column(
      children: [
        AppFileTypeIcon(type: type, size: 42),
        AppSpacing.v8,
        Text(label, style: AppTypography.caption),
      ],
    );
  }

  // 2. Typography Tab
  Widget _buildTypographyTab() {
    return ListView(
      padding: AppSpacing.p24,
      children: [
        const AppSectionHeader(
          title: 'Inter Typography Hierarchy',
          subtitle: 'Centralized typography tokens',
        ),
        _buildTypeRow('Display (32px Bold)', AppTypography.display),
        _buildTypeRow('Headline (24px SemiBold)', AppTypography.headline),
        _buildTypeRow('Title (18px SemiBold)', AppTypography.title),
        _buildTypeRow('Subtitle (15px Medium)', AppTypography.subtitle),
        _buildTypeRow('Body (14px Regular)', AppTypography.body),
        _buildTypeRow('Body Small (13px Regular)', AppTypography.bodySmall),
        _buildTypeRow('Caption (12px Muted)', AppTypography.caption),
        _buildTypeRow('Label (13px Medium)', AppTypography.label),
        _buildTypeRow('Button (14px SemiBold)', AppTypography.button.copyWith(color: AppColors.primaryLight)),
        _buildTypeRow('Error (12px Destructive)', AppTypography.error),
      ],
    );
  }

  Widget _buildTypeRow(String tokenName, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tokenName, style: AppTypography.caption),
          AppSpacing.v4,
          Text('The quick brown fox jumps over the lazy dog', style: style),
          const Divider(color: AppColors.border, height: 16),
        ],
      ),
    );
  }

  // 3. Buttons Tab
  Widget _buildButtonsTab() {
    return ListView(
      padding: AppSpacing.p24,
      children: [
        const AppSectionHeader(
          title: 'Button Variants',
          subtitle: 'Primary, Secondary, Tertiary, and Destructive',
        ),
        AppButton.primary(
          text: 'Primary Button',
          onPressed: () {},
        ),
        AppSpacing.v12,
        AppButton.secondary(
          text: 'Secondary Button',
          onPressed: () {},
        ),
        AppSpacing.v12,
        AppButton.tertiary(
          text: 'Tertiary Action Button',
          onPressed: () {},
        ),
        AppSpacing.v12,
        AppButton.destructive(
          text: 'Destructive Button',
          onPressed: () {},
        ),
        AppSpacing.v24,

        const AppSectionHeader(
          title: 'Button States & Sizes',
          subtitle: 'Loading, disabled, and sized controls',
        ),
        AppButton.primary(
          text: 'Toggle Loading State',
          isLoading: _isLoadingButton,
          onPressed: () {
            setState(() => _isLoadingButton = !_isLoadingButton);
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() => _isLoadingButton = false);
            });
          },
        ),
        AppSpacing.v12,
        const AppButton.primary(
          text: 'Disabled Button',
          onPressed: null,
        ),
        AppSpacing.v16,
        Row(
          children: [
            Expanded(
              child: AppButton.primary(
                text: 'Small (36px)',
                size: AppButtonSize.sm,
                onPressed: () {},
              ),
            ),
            AppSpacing.h12,
            Expanded(
              child: AppButton.secondary(
                text: 'Medium (44px)',
                size: AppButtonSize.md,
                onPressed: () {},
              ),
            ),
          ],
        ),
        AppSpacing.v24,

        const AppSectionHeader(
          title: 'Icon Buttons',
          subtitle: 'Guaranteed 44x44 minimum touch target',
        ),
        Row(
          children: [
            AppIconButton(
              icon: AppIcons.search,
              tooltip: 'Search',
              onPressed: () {},
            ),
            AppSpacing.h12,
            AppIconButton(
              icon: AppIcons.filter,
              tooltip: 'Filter',
              backgroundColor: AppColors.surface,
              border: AppBorders.standard,
              onPressed: () {},
            ),
            AppSpacing.h12,
            AppIconButton(
              icon: AppIcons.delete,
              color: AppColors.destructive,
              tooltip: 'Delete',
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }

  // 4. Fields Tab
  Widget _buildFieldsTab() {
    return ListView(
      padding: AppSpacing.p24,
      children: [
        const AppSectionHeader(
          title: 'Text Inputs',
          subtitle: 'Unified academic form fields with states',
        ),
        AppTextField(
          label: 'Standard Input',
          hint: 'Enter your username or ID',
          controller: _textController,
        ),
        AppSpacing.v16,
        AppPasswordField(
          controller: _passwordController,
        ),
        AppSpacing.v16,
        const AppTextField(
          label: 'Error State Input',
          hint: 'Enter your university email',
          errorText: 'Please enter a valid academic email address.',
        ),
        AppSpacing.v16,
        const AppTextField(
          label: 'Disabled Input',
          hint: 'Read only value',
          enabled: false,
        ),
        AppSpacing.v24,

        const AppSectionHeader(
          title: 'Search Field',
          subtitle: 'Search input with clear button and shortcut support',
        ),
        AppSearchField(
          controller: _searchController,
        ),
      ],
    );
  }

  // 5. Cards Tab
  Widget _buildCardsTab() {
    return ListView(
      padding: AppSpacing.p24,
      children: [
        const AppSectionHeader(
          title: 'Card Variants',
          subtitle: 'Standard, Interactive, Selected, and Subtle',
        ),
        AppCard.standard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Standard Card', style: AppTypography.title),
              AppSpacing.v4,
              Text('Clean surface with subtle border, 0 elevation.', style: AppTypography.bodySmall),
            ],
          ),
        ),
        AppSpacing.v16,
        AppCard.interactive(
          onTap: () {},
          child: Row(
            children: [
              const AppFileTypeIcon(type: AppFileType.pdf),
              AppSpacing.h16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Interactive Card (Tap Me)', style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                    Text('Hover/pressed ink feedback with subtle shadow.', style: AppTypography.caption),
                  ],
                ),
              ),
              const Icon(AppIcons.chevronRight, color: AppColors.textMuted),
            ],
          ),
        ),
        AppSpacing.v16,
        AppCard.selected(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Selected Card', style: AppTypography.title),
                  const Spacer(),
                  const Icon(AppIcons.check, size: AppIcons.sm, color: AppColors.primaryLight),
                ],
              ),
              AppSpacing.v4,
              Text('Secondary surface with active primary border.', style: AppTypography.bodySmall),
            ],
          ),
        ),
        AppSpacing.v16,
        AppCard.subtle(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subtle Card', style: AppTypography.title),
              AppSpacing.v4,
              Text('Muted container for secondary metadata.', style: AppTypography.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  // 6. Chips Tab
  Widget _buildChipsTab() {
    final chipOptions = ['All Materials', 'Lectures', 'Assignments', 'Exams', 'Flashcards'];

    return ListView(
      padding: AppSpacing.p24,
      children: [
        const AppSectionHeader(
          title: 'Interactive Filter Chips',
          subtitle: 'Category and multi-filter tags',
        ),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: List.generate(chipOptions.length, (index) {
            return AppChip(
              label: chipOptions[index],
              isSelected: _selectedChipIndex == index,
              onTap: () => setState(() => _selectedChipIndex = index),
            );
          }),
        ),
        AppSpacing.v24,

        const AppSectionHeader(
          title: 'Metadata Label Chips',
          subtitle: 'Status and semantic category badges',
        ),
        const Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            AppLabelChip(label: 'Active', color: AppColors.success),
            AppLabelChip(label: 'Review Needed', color: AppColors.warning),
            AppLabelChip(label: 'Failed', color: AppColors.destructive),
            AppLabelChip(label: 'Synced', color: AppColors.info),
            AppLabelChip(label: 'Semester 1', color: AppColors.primaryLight),
          ],
        ),
        AppSpacing.v24,

        const AppSectionHeader(
          title: 'Avatars',
          subtitle: 'User initials or profile images with fallback',
        ),
        const Row(
          children: [
            AppAvatar(name: 'Arun Roshan', size: 40),
            AppSpacing.h12,
            AppAvatar(name: 'Data Structures', size: 40, isCircular: false),
            AppSpacing.h12,
            AppAvatar(name: 'Computer Networks', size: 32),
            AppSpacing.h12,
            AppAvatar(size: 28),
          ],
        ),
      ],
    );
  }

  // 7. States Tab
  Widget _buildStatesTab() {
    return ListView(
      padding: AppSpacing.p24,
      children: [
        const AppSectionHeader(
          title: 'Empty State',
          subtitle: 'Calm academic placeholder with call to action',
        ),
        AppCard.standard(
          padding: EdgeInsets.zero,
          child: AppEmptyState(
            icon: AppIcons.subjects,
            title: 'No subjects yet',
            description: 'Add your first academic subject to start organizing your study vault.',
            actionText: 'Add Subject',
            onAction: () {},
          ),
        ),
        AppSpacing.v24,

        const AppSectionHeader(
          title: 'Error State',
          subtitle: 'Human-readable error with retry action',
        ),
        AppCard.standard(
          padding: EdgeInsets.zero,
          child: AppErrorState(
            message: 'Unable to connect to your offline database. Please check permissions.',
            onRetry: () {},
          ),
        ),
        AppSpacing.v24,

        const AppSectionHeader(
          title: 'Loading Skeleton',
          subtitle: 'Pulse animation for content placeholders',
        ),
        const AppListSkeleton(count: 2),
      ],
    );
  }

  // 8. Overlays Tab
  Widget _buildOverlaysTab() {
    return ListView(
      padding: AppSpacing.p24,
      children: [
        const AppSectionHeader(
          title: 'Modal Dialogs',
          subtitle: 'Confirmation and contextual dialogs',
        ),
        AppButton.secondary(
          text: 'Show Standard Confirmation Modal',
          onPressed: () {
            AppModal.show(
              context: context,
              title: 'Archive Subject?',
              message: 'This will move the subject into your vault archive. You can restore it anytime.',
              confirmText: 'Archive',
              onConfirm: () => Navigator.of(context).pop(),
              icon: AppIcons.vault,
            );
          },
        ),
        AppSpacing.v12,
        AppButton.destructive(
          text: 'Show Destructive Modal',
          onPressed: () {
            AppModal.show(
              context: context,
              title: 'Delete Document?',
              message: 'This permanently removes the PDF document and all associated flashcards.',
              confirmText: 'Delete Permanently',
              isDestructive: true,
              onConfirm: () => Navigator.of(context).pop(),
              icon: AppIcons.delete,
            );
          },
        ),
        AppSpacing.v24,

        const AppSectionHeader(
          title: 'Bottom Sheets',
          subtitle: 'Draggable sheets with grab handles',
        ),
        AppButton.primary(
          text: 'Open Sample Bottom Sheet',
          onPressed: () {
            AppBottomSheet.show(
              context: context,
              title: 'Document Options',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    leading: const Icon(AppIcons.edit, size: AppIcons.md),
                    title: const Text('Rename document'),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  ListTile(
                    leading: const Icon(AppIcons.share, size: AppIcons.md),
                    title: const Text('Share with classmates'),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  ListTile(
                    leading: const Icon(AppIcons.download, size: AppIcons.md),
                    title: const Text('Export as Markdown'),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
