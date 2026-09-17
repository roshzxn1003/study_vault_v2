import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/design/design_system.dart';
import 'package:study_vault/core/design/preview/design_system_preview_screen.dart';

Widget _wrapWithTheme(Widget child, {Size? surfaceSize}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: surfaceSize?.width ?? 600,
          height: surfaceSize?.height ?? 800,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('Design Tokens Unit & Value Tests', () {
    test('Obsidian & Zinc color palette conforms to dark aesthetic', () {
      expect(AppColors.background, const Color(0xFF09090B));
      expect(AppColors.surface, const Color(0xFF18181B));
      expect(AppColors.surfaceElevated, const Color(0xFF27272A));
      expect(AppColors.border, const Color(0xFF27272A));
      expect(AppColors.textPrimary, const Color(0xFFFAFAFA));
      expect(AppColors.textSecondary, const Color(0xFFA1A1AA));
      expect(AppColors.primary, const Color(0xFF6366F1));
    });

    test('Typography tokens define consistent hierarchy', () {
      expect(AppTypography.display.fontSize, 32);
      expect(AppTypography.headline.fontSize, 24);
      expect(AppTypography.title.fontSize, 18);
      expect(AppTypography.body.fontSize, 14);
      expect(AppTypography.caption.fontSize, 12);
    });

    test('Spacing tokens adhere to strict geometric scale', () {
      expect(AppSpacing.xxs, 4);
      expect(AppSpacing.xs, 8);
      expect(AppSpacing.sm, 12);
      expect(AppSpacing.md, 16);
      expect(AppSpacing.lg, 20);
      expect(AppSpacing.xl, 24);
      expect(AppSpacing.xxl, 32);
    });

    test('Radius tokens provide restrained curvature', () {
      expect(AppRadius.xs, 4);
      expect(AppRadius.sm, 8);
      expect(AppRadius.md, 12);
      expect(AppRadius.lg, 16);
      expect(AppRadius.xl, 20);
      expect(AppRadius.button, AppRadius.brMd);
      expect(AppRadius.card, AppRadius.brLg);
    });

    test('Breakpoints correctly categorize screen widths', () {
      expect(AppBreakpoints.isMobileWidth(400), isTrue);
      expect(AppBreakpoints.isMobileWidth(700), isFalse);
      expect(AppBreakpoints.isTabletWidth(768), isTrue);
      expect(AppBreakpoints.isDesktopWidth(1200), isTrue);
    });
  });

  group('Interactive Buttons & Inputs Widget Tests', () {
    testWidgets('AppButton triggers onPressed and shows text', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          AppButton(
            text: 'Save Changes',
            onPressed: () => pressed = true,
          ),
        ),
      );

      expect(find.text('Save Changes'), findsOneWidget);
      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      expect(pressed, isTrue);
    });

    testWidgets('AppButton displays loading spinner when isLoading is true', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          AppButton(
            text: 'Processing',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Processing'), findsNothing);
    });

    testWidgets('AppSecondaryButton renders with outlined style and responds', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          AppSecondaryButton(
            text: 'Cancel',
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('AppIconButton enforces minimum 44px touch target', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          AppIconButton(
            icon: AppIcons.search,
            tooltip: 'Search',
            onPressed: () => tapped = true,
          ),
        ),
      );

      final renderBox = tester.renderObject<RenderBox>(find.byType(AppIconButton));
      expect(renderBox.size.width, greaterThanOrEqualTo(AppDimensions.minTouchTarget));
      expect(renderBox.size.height, greaterThanOrEqualTo(AppDimensions.minTouchTarget));

      await tester.tap(find.byType(AppIconButton));
      expect(tapped, isTrue);
    });

    testWidgets('AppTextField displays label, hint, and accepts text', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrapWithTheme(
          AppTextField(
            label: 'Subject Name',
            hint: 'e.g. Linear Algebra',
            controller: controller,
          ),
        ),
      );

      expect(find.text('Subject Name'), findsOneWidget);
      expect(find.text('e.g. Linear Algebra'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Data Structures');
      expect(controller.text, 'Data Structures');
    });

    testWidgets('AppPasswordField toggles obscureText via eye button', (tester) async {
      final controller = TextEditingController(text: 'secret_vault_key');
      await tester.pumpWidget(
        _wrapWithTheme(
          AppPasswordField(
            label: 'Vault Password',
            controller: controller,
          ),
        ),
      );

      final textFieldFinder = find.byType(TextField);
      var textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.obscureText, isTrue);

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.obscureText, isFalse);
    });

    testWidgets('AppSearchField clears query on suffix tap', (tester) async {
      final controller = TextEditingController(text: 'Calculus');
      await tester.pumpWidget(
        _wrapWithTheme(
          AppSearchField(
            controller: controller,
          ),
        ),
      );

      expect(controller.text, 'Calculus');
      expect(find.byIcon(AppIcons.close), findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.close));
      await tester.pump();

      expect(controller.text, isEmpty);
    });
  });

  group('Cards, Chips & Feedback States Widget Tests', () {
    testWidgets('AppCard renders child and fires onTap when interactive', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          AppCard(
            variant: AppCardVariant.interactive,
            onTap: () => tapped = true,
            child: const Text('Interactive Card Content'),
          ),
        ),
      );

      expect(find.text('Interactive Card Content'), findsOneWidget);
      await tester.tap(find.text('Interactive Card Content'));
      expect(tapped, isTrue);
    });

    testWidgets('AppChip toggles selection and renders label', (tester) async {
      bool selected = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _wrapWithTheme(
              AppChip(
                label: 'Recent Notes',
                isSelected: selected,
                onTap: () => setState(() => selected = !selected),
              ),
            );
          },
        ),
      );

      expect(find.text('Recent Notes'), findsOneWidget);
      await tester.tap(find.text('Recent Notes'));
      await tester.pump();
      expect(selected, isTrue);
    });

    testWidgets('AppLabelChip renders badge text', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const AppLabelChip(
            label: 'Active Semester',
            color: AppColors.success,
          ),
        ),
      );

      expect(find.text('Active Semester'), findsOneWidget);
    });

    testWidgets('AppAvatar computes initials accurately', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const AppAvatar(
            name: 'Alexander Hamilton',
          ),
        ),
      );

      expect(find.text('AH'), findsOneWidget);
    });

    testWidgets('AppEmptyState displays title, message, and action CTA', (tester) async {
      bool ctaTriggered = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          AppEmptyState(
            icon: AppIcons.vault,
            title: 'No Documents Yet',
            description: 'Your personal knowledge vault is empty.',
            actionText: 'Upload File',
            onAction: () => ctaTriggered = true,
          ),
        ),
      );

      expect(find.text('No Documents Yet'), findsOneWidget);
      expect(find.text('Your personal knowledge vault is empty.'), findsOneWidget);
      expect(find.text('Upload File'), findsOneWidget);

      await tester.tap(find.text('Upload File'));
      expect(ctaTriggered, isTrue);
    });

    testWidgets('AppErrorState displays error message and retry button', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        _wrapWithTheme(
          AppErrorState(
            message: 'Could not load course materials.',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.text('Could not load course materials.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);
    });

    testWidgets('AppLoadingState renders loading skeleton and indicator', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const AppLoadingState(
            message: 'Indexing documents...',
          ),
        ),
      );

      expect(find.text('Indexing documents...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AppFileTypeIcon recognizes extensions accurately', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          Row(
            children: [
              AppFileTypeIcon.fromExtension('pdf'),
              AppFileTypeIcon.fromExtension('md'),
              AppFileTypeIcon.fromExtension('docx'),
            ],
          ),
        ),
      );

      expect(find.byIcon(AppIcons.pdf), findsOneWidget);
      expect(find.byIcon(AppIcons.note), findsOneWidget);
      expect(find.byIcon(AppIcons.document), findsOneWidget);
    });
  });

  group('Structural Navigation & Scaffold Layout Tests', () {
    testWidgets('AppTopBar renders title and trailing actions', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const AppTopBar(
            title: 'Computer Architecture',
            actions: [
              Icon(Icons.more_vert_rounded),
            ],
          ),
        ),
      );

      expect(find.text('Computer Architecture'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    });

    testWidgets('AppBottomNavigation displays destinations and triggers navigation', (tester) async {
      int activeIndex = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _wrapWithTheme(
              AppBottomNavigation(
                currentIndex: activeIndex,
                onTap: (index) => setState(() => activeIndex = index),
              ),
            );
          },
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Subjects'), findsOneWidget);
      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('Vault'), findsOneWidget);

      await tester.tap(find.text('Subjects'));
      await tester.pump();
      expect(activeIndex, 1);
    });

    testWidgets('AppScaffold renders mobile layout on narrow viewports', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: AppScaffold(
            navigationIndex: 0,
            onNavigationChanged: (_) {},
            body: const Text('Mobile Main View'),
          ),
        ),
      );

      expect(find.text('Mobile Main View'), findsOneWidget);
      expect(find.byType(AppBottomNavigation), findsOneWidget);
    });

    testWidgets('DesignSystemPreviewScreen mounts all tabs without error', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const DesignSystemPreviewScreen(),
        ),
      );

      expect(find.text('Design System Preview'), findsOneWidget);
      expect(find.text('Colors'), findsOneWidget);
      expect(find.text('Buttons'), findsOneWidget);
      expect(find.text('Cards'), findsOneWidget);

      // Switch to Buttons tab
      await tester.tap(find.text('Buttons'));
      await tester.pumpAndSettle();
      expect(find.text('Primary Button'), findsOneWidget);

      // Switch to Cards tab
      await tester.tap(find.text('Cards'));
      await tester.pumpAndSettle();
      expect(find.text('Standard Card'), findsOneWidget);
    });
  });
}
