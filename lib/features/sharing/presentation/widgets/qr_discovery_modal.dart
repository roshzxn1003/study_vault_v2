import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/widgets.dart';
import '../providers/sharing_providers.dart';
import '../../domain/models/models.dart';
import 'student_profile_preview_modal.dart';

/// Clean academic modal providing QR Code discovery for student identities.
class QrDiscoveryModal extends ConsumerStatefulWidget {
  const QrDiscoveryModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QrDiscoveryModal(),
    );
  }

  @override
  ConsumerState<QrDiscoveryModal> createState() => _QrDiscoveryModalState();
}

class _QrDiscoveryModalState extends ConsumerState<QrDiscoveryModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _lookupController = TextEditingController();
  bool _isSearching = false;
  String? _lookupError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _lookupController.dispose();
    super.dispose();
  }

  Future<void> _handleLookup() async {
    final query = _lookupController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _lookupError = null;
    });

    try {
      final repo = ref.read(sharingRepositoryProvider);
      StudentProfile? profile;

      // Check if it's a safe QR payload
      final parsed = StudentProfile.parseQrPayload(query);
      if (parsed != null && parsed['username'] != null) {
        profile = await repo.getStudentByUsername(parsed['username']!);
      } else {
        profile = await repo.getStudentByUsername(query);
      }

      if (profile == null) {
        setState(() => _lookupError = 'Student not found. Please check the @username.');
      } else if (mounted) {
        Navigator.pop(context);
        StudentProfilePreviewModal.show(context: context, profile: profile);
      }
    } catch (e) {
      setState(() => _lookupError = 'Error looking up student: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentStudentProfileProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SafeArea(
        top: false,
        child: Column(
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
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primaryLight,
              labelColor: AppColors.primaryLight,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: AppTypography.subtitle.copyWith(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'My Study Vault QR'),
                Tab(text: 'Lookup Student'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: My QR
                  profileAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryLight)),
                    error: (e, _) => Center(child: Text('Error loading profile: $e')),
                    data: (profile) {
                      if (profile == null) {
                        return const Center(child: Text('Student profile not available'));
                      }

                      final qrPayload = profile.toQrPayload();

                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: AppSpacing.md),
                            // QR Card Container
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: AppRadius.card,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: QrImageView(
                                data: qrPayload,
                                version: QrVersions.auto,
                                size: 200,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Colors.black,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              profile.fullName,
                              style: AppTypography.title.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              profile.displayUsername,
                              style: AppTypography.body.copyWith(
                                color: AppColors.primaryLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            // Safe notice
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSecondary,
                                borderRadius: AppRadius.chip,
                                border: AppBorders.allStandard,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.security_rounded, size: 14, color: AppColors.textMuted),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Public identifier only • Zero credential exposure',
                                    style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: AppBorders.standard,
                                shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                              ),
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text('Copy My @username'),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: profile.displayUsername));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Copied ${profile.displayUsername} to clipboard!')),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Tab 2: Lookup
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Enter a student\'s @username or scan their QR payload to preview their public profile.',
                            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField(
                            controller: _lookupController,
                            label: 'Student Username',
                            hint: '@arunroshan',
                            prefixIcon: const Icon(Icons.alternate_email_rounded),
                          ),
                          if (_lookupError != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _lookupError!,
                              style: AppTypography.caption.copyWith(color: AppColors.error),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            text: _isSearching ? 'Looking up...' : 'Lookup Student',
                            icon: const Icon(Icons.search_rounded),
                            isLoading: _isSearching,
                            onPressed: _isSearching ? null : _handleLookup,
                          ),
                        ],
                      ),
                    ),
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
