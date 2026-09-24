import 'package:flutter/material.dart';

import '../core/constants/app_copy.dart';
import '../core/theme/app_theme.dart';
import '../models/domain_models.dart';

String formatDate(DateTime value, {bool includeYear = false}) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final suffix = includeYear ? ' ${value.year}' : '';
  return '${months[value.month - 1]} ${value.day}$suffix';
}

String relativeTime(DateTime value) {
  final difference = DateTime.now().difference(value);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return formatDate(value, includeYear: true);
}

String formatLkr(int value) {
  final digits = value.toString();
  final result = StringBuffer();
  for (var index = 0; index < digits.length; index += 1) {
    final remaining = digits.length - index;
    result.write(digits[index]);
    if (remaining > 1 && remaining % 3 == 1) result.write(',');
  }
  return 'Rs. $result';
}

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.compact = false, this.inverse = false});

  final bool compact;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final foreground = inverse ? Colors.white : AppColors.ink;
    return Semantics(
      label: AppCopy.text('appName'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: inverse
                  ? Colors.white.withValues(alpha: 0.16)
                  : AppColors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.account_balance_outlined,
              color: inverse ? Colors.white : Colors.white,
            ),
          ),
          if (!compact) ...<Widget>[
            const SizedBox(width: 10),
            Text(
              AppCopy.text('appName'),
              style: TextStyle(
                color: foreground,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ResponsivePage extends StatelessWidget {
  const ResponsivePage({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 760 ? 28.0 : 16.0;
        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 1240,
                maxHeight: constraints.maxHeight,
              ),
              child: Padding(
                padding:
                    padding ??
                    EdgeInsets.fromLTRB(horizontal, 22, horizontal, 32),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.deepGreen),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...<Widget>[const SizedBox(width: 12), action!],
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class CivicCard extends StatelessWidget {
  const CivicCard({super.key, required this.child, this.padding, this.onTap});

  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class ProjectStatusBadge extends StatelessWidget {
  const ProjectStatusBadge({super.key, required this.status});

  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    return _StatusPill(label: status.label, color: status.color);
  }
}

class ReportStatusBadge extends StatelessWidget {
  const ReportStatusBadge({super.key, required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    return _StatusPill(label: status.label, color: status.color);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class ProjectArtwork extends StatelessWidget {
  const ProjectArtwork({super.key, required this.project, this.height = 150});

  final Project project;
  final double height;

  IconData get _icon => switch (project.category) {
    'Roads & Transport' => Icons.add_road_outlined,
    'Water & Sanitation' => Icons.water_drop_outlined,
    'Public Spaces' => Icons.park_outlined,
    'Drainage' => Icons.water_outlined,
    _ => Icons.account_balance_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final color = project.status.color;
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[color.withValues(alpha: 0.92), AppColors.deepGreen],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -12,
            bottom: -22,
            child: Icon(
              _icon,
              size: height * 0.9,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.location_on_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      project.locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.onTap,
    this.compact = false,
  });

  final Project project;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ProjectArtwork(project: project, height: compact ? 108 : 148),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          project.category,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      ProjectStatusBadge(status: project.status),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    project.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (!compact) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      project.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                  const SizedBox(height: 13),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LinearProgressIndicator(
                            value: project.progress / 100,
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${project.progress}%',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.event_outlined,
                        size: 16,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Expected ${formatDate(project.expectedCompletion)}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (project.isBudgetPublic)
                        Text(
                          formatLkr(project.budget),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                    ],
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

class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report, required this.onTap});

  final CivicReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CivicCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.report_problem_outlined,
                  color: AppColors.deepGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      report.caseNumber,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              ReportStatusBadge(status: report.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: <Widget>[
              _SmallDetail(
                icon: Icons.category_outlined,
                label: report.category,
              ),
              _SmallDetail(
                icon: Icons.location_on_outlined,
                label: report.locationLabel,
              ),
              _SmallDetail(
                icon: Icons.business_outlined,
                label: report.department,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallDetail extends StatelessWidget {
  const _SmallDetail({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({
    super.key,
    required this.announcement,
    required this.onTap,
  });

  final Announcement announcement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = announcement.type == AnnouncementType.emergency
        ? AppColors.danger
        : AppColors.green;
    return CivicCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(announcement.type.icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        announcement.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (announcement.isPinned)
                      const Icon(
                        Icons.push_pin_outlined,
                        size: 18,
                        color: AppColors.warning,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  announcement.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                Text(
                  '${announcement.type.label} · ${announcement.targetLabel} · ${relativeTime(announcement.publishedAt)}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return CivicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (caption != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              caption!,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.mint,
              ),
              child: Icon(icon, size: 38, color: AppColors.deepGreen),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Loading your local services…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            Text(message, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

Future<void> showSignInPrompt(
  BuildContext context, {
  String message = 'Please sign in to use this community feature.',
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.lock_outline, color: AppColors.deepGreen),
      title: const Text('Sign in required'),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (route) => false,
            );
          },
          child: const Text('Sign in'),
        ),
      ],
    ),
  );
}

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppLogo()),
      body: EmptyState(
        icon: Icons.admin_panel_settings_outlined,
        title: 'Officer access required',
        message:
            'This area is available only to authorised local authority staff.',
        action: FilledButton.tonal(
          onPressed: () =>
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
          child: const Text('Return to Smart Sabha'),
        ),
      ),
    );
  }
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({
    super.key,
    this.message = 'The page or public record you requested is unavailable.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppLogo()),
      body: EmptyState(
        icon: Icons.search_off_outlined,
        title: 'Nothing to show here',
        message: message,
        action: FilledButton.tonal(
          onPressed: () =>
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
          child: const Text('Go home'),
        ),
      ),
    );
  }
}
