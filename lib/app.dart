import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/admin/admin_screens.dart';
import 'features/auth/auth_screens.dart';
import 'features/citizen/citizen_screens.dart';
import 'features/community/community_screens.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/projects/project_screens.dart';
import 'features/reports/report_screens.dart';
import 'state/app_controller.dart';
import 'state/app_scope.dart';
import 'widgets/app_widgets.dart';
import 'widgets/civic_shell.dart';

class SmartSabhaApp extends StatelessWidget {
  const SmartSabhaApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => MaterialApp(
          title: 'Smart Sabha',
          theme: AppTheme.light(),
          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          onGenerateRoute: (settings) => _routeFor(settings, controller),
        ),
      ),
    );
  }
}

Route<dynamic> _routeFor(RouteSettings settings, AppController controller) {
  final route = settings.name ?? '/';
  if (controller.isLoading) return _page(settings, const LoadingView());

  if (route == '/login') return _page(settings, const LoginScreen());
  if (route == '/register') return _page(settings, const RegisterScreen());
  if (route == '/forgot-password') {
    return _page(settings, const ForgotPasswordScreen());
  }
  if (route == '/reset-password') {
    return _page(settings, const ResetPasswordScreen());
  }

  if (!controller.hasSession) return _page(settings, const WelcomeScreen());
  final user = controller.currentUser!;
  if (!user.isGuest && !user.onboardingComplete && route != '/onboarding') {
    return _page(settings, const OnboardingScreen());
  }
  if (route == '/onboarding') return _page(settings, const OnboardingScreen());

  if (route.startsWith('/admin')) {
    if (!controller.isOfficer) {
      return _page(settings, const AccessDeniedScreen());
    }
    final section = switch (route) {
      '/admin/reports' => AdminSection.reports,
      '/admin/projects' || '/admin/projects/new' => AdminSection.projects,
      '/admin/announcements' => AdminSection.announcements,
      '/admin/departments' => AdminSection.departments,
      '/admin/users' => AdminSection.users,
      '/admin/analytics' => AdminSection.analytics,
      _ => AdminSection.overview,
    };
    return _page(settings, AdminShell(initialSection: section));
  }

  if (route == '/') {
    return _page(
      settings,
      controller.isOfficer ? const AdminShell() : const CitizenShell(),
    );
  }
  if (route == '/citizen') return _page(settings, const CitizenShell());
  if (route == '/feed') {
    return _page(settings, const CitizenShell(initialIndex: 1));
  }
  if (route == '/report') return _page(settings, const ReportWizardScreen());
  if (route == '/projects') {
    return _page(settings, const ProjectExplorerScreen());
  }
  if (route == '/map') return _page(settings, const PublicMapScreen());
  if (route == '/notifications') {
    return _page(settings, const CitizenShell(initialIndex: 4));
  }
  if (route == '/profile') {
    return _page(settings, const CitizenShell(initialIndex: 5));
  }
  if (route == '/my-reports') return _page(settings, const MyReportsScreen());
  if (route == '/announcements') {
    return _page(settings, const AnnouncementsScreen());
  }
  if (route == '/proposals') return _page(settings, const ProposalsScreen());
  if (route == '/proposals/new') {
    return _page(settings, const NewProposalScreen());
  }
  if (route == '/consultations') {
    return _page(settings, const ConsultationsScreen());
  }
  if (route == '/search') return _page(settings, const GlobalSearchScreen());

  if (route.startsWith('/projects/')) {
    return _page(
      settings,
      ProjectDetailScreen(projectId: route.split('/').last),
    );
  }
  if (route.startsWith('/reports/')) {
    return _page(settings, ReportDetailScreen(reportId: route.split('/').last));
  }
  if (route.startsWith('/announcements/')) {
    return _page(
      settings,
      AnnouncementDetailScreen(announcementId: route.split('/').last),
    );
  }
  if (route.startsWith('/proposals/')) {
    return _page(
      settings,
      ProposalDetailScreen(proposalId: route.split('/').last),
    );
  }
  if (route.startsWith('/consultations/')) {
    return _page(
      settings,
      ConsultationDetailScreen(consultationId: route.split('/').last),
    );
  }
  return _page(settings, const NotFoundScreen());
}

MaterialPageRoute<dynamic> _page(RouteSettings settings, Widget child) {
  return MaterialPageRoute<dynamic>(settings: settings, builder: (_) => child);
}
