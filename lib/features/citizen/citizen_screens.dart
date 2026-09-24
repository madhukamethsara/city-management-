import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../models/domain_models.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_widgets.dart';

class CitizenHomeScreen extends StatelessWidget {
  const CitizenHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final user = controller.currentUser!;
    final pinned = controller.announcements
        .where((item) => item.isPinned)
        .toList();
    final nearbyReports = controller.reports.take(2).toList();
    return ResponsivePage(
      child: ListView(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _greeting(),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${user.isGuest ? 'Welcome' : user.firstName}!',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: const BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wb_sunny_outlined,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          CivicCard(
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.deepGreen,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Your service area',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${user.ward} · ${controller.authorityName}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const Text(
                  '28°C',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          if (pinned.isNotEmpty) ...<Widget>[
            const SizedBox(height: 22),
            _AlertBanner(announcement: pinned.first),
          ],
          const SizedBox(height: 26),
          const SectionTitle(title: 'Quick actions'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth >= 880
                  ? 4
                  : constraints.maxWidth >= 540
                  ? 2
                  : 2;
              return GridView(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: count,
                  mainAxisExtent: 150,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  _QuickAction(
                    icon: Icons.add_location_alt_outlined,
                    label: 'Report a problem',
                    color: AppColors.danger,
                    onTap: () => Navigator.pushNamed(context, '/report'),
                  ),
                  _QuickAction(
                    icon: Icons.account_tree_outlined,
                    label: 'View projects',
                    color: AppColors.green,
                    onTap: () => Navigator.pushNamed(context, '/projects'),
                  ),
                  _QuickAction(
                    icon: Icons.assignment_outlined,
                    label: 'My reports',
                    color: const Color(0xFF2C6EAA),
                    onTap: () => Navigator.pushNamed(context, '/my-reports'),
                  ),
                  _QuickAction(
                    icon: Icons.lightbulb_outline,
                    label: 'Community proposals',
                    color: const Color(0xFF805AD5),
                    onTap: () => Navigator.pushNamed(context, '/proposals'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          SectionTitle(
            title: 'Latest projects',
            actionLabel: 'View all',
            onAction: () => Navigator.pushNamed(context, '/projects'),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 980
                  ? 3
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: controller.projects.take(3).length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: crossAxisCount == 1 ? 1.65 : 0.72,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                ),
                itemBuilder: (context, index) {
                  final project = controller.projects[index];
                  return ProjectCard(
                    project: project,
                    compact: crossAxisCount == 1,
                    onTap: () =>
                        Navigator.pushNamed(context, '/projects/${project.id}'),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 28),
          SectionTitle(
            title: 'Local announcements',
            actionLabel: 'View all',
            onAction: () => Navigator.pushNamed(context, '/announcements'),
          ),
          const SizedBox(height: 12),
          ...controller.announcements
              .take(2)
              .map(
                (announcement) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AnnouncementCard(
                    announcement: announcement,
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/announcements/${announcement.id}',
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 18),
          SectionTitle(
            title: 'Nearby issue updates',
            actionLabel: 'Map',
            onAction: () => Navigator.pushNamed(context, '/map'),
          ),
          const SizedBox(height: 12),
          ...nearbyReports.map(
            (report) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ReportCard(
                report: report,
                onTap: () =>
                    Navigator.pushNamed(context, '/reports/${report.id}'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          CivicCard(
            onTap: () => Navigator.pushNamed(context, '/feed'),
            child: const Row(
              children: <Widget>[
                Icon(Icons.forum_outlined, color: AppColors.deepGreen),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Community updates',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Read public project news, consultations and local events.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () =>
          Navigator.pushNamed(context, '/announcements/${announcement.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.campaign_outlined, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Current alert',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    announcement.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.warning),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class CivicFeedScreen extends StatefulWidget {
  const CivicFeedScreen({super.key});

  @override
  State<CivicFeedScreen> createState() => _CivicFeedScreenState();
}

class _CivicFeedScreenState extends State<CivicFeedScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final categories = <String>[
      'All',
      ...controller.feedItems.map((item) => item.kind).toSet(),
    ];
    final items = _filter == 'All'
        ? controller.feedItems
        : controller.feedItems.where((item) => item.kind == _filter).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Community updates')),
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const PageHeader(
              icon: Icons.forum_outlined,
              title: 'Local civic feed',
              subtitle:
                  'Official notices, project updates and community opportunities.',
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories
                    .map(
                      (category) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: _filter == category,
                          onSelected: (_) => setState(() => _filter = category),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _FeedCard(item: items[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final userId = controller.currentUser?.id;
    final reacted = userId != null && item.reactedUserIds.contains(userId);
    final saved = userId != null && item.savedUserIds.contains(userId);
    return CivicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_outlined,
                  color: AppColors.deepGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.department,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${item.kind} · ${relativeTime(item.date)}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _share(context),
                icon: const Icon(Icons.ios_share_outlined),
                tooltip: 'Share update',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            item.body,
            style: const TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.muted,
              ),
              const SizedBox(width: 4),
              Text(
                item.locationLabel,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
          const Divider(height: 28),
          Row(
            children: <Widget>[
              _FeedAction(
                icon: reacted ? Icons.favorite : Icons.favorite_border,
                label: '${item.reactionCount}',
                active: reacted,
                onTap: () async {
                  if (!controller.canParticipate) {
                    return showSignInPrompt(context);
                  }
                  controller.toggleFeedReaction(item.id);
                },
              ),
              const SizedBox(width: 14),
              _FeedAction(
                icon: Icons.chat_bubble_outline,
                label: '${item.commentCount}',
                onTap: () => _showCommentDialog(context, item),
              ),
              const Spacer(),
              IconButton(
                onPressed: () async {
                  if (!controller.canParticipate) {
                    return showSignInPrompt(context);
                  }
                  controller.toggleFeedSave(item.id);
                },
                icon: Icon(
                  saved ? Icons.bookmark : Icons.bookmark_outline,
                  color: saved ? AppColors.deepGreen : null,
                ),
                tooltip: saved ? 'Remove saved update' : 'Save update',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: 'Smart Sabha update: ${item.title}'),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update link copied to clipboard.')),
      );
    }
  }

  Future<void> _showCommentDialog(BuildContext context, FeedItem item) async {
    final textController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a civic comment'),
        content: TextField(
          controller: textController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Keep your comment respectful and relevant.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final controller = AppScope.of(context);
              if (!controller.canParticipate) {
                Navigator.pop(context);
                showSignInPrompt(context);
                return;
              }
              if (textController.text.trim().isNotEmpty) {
                controller.addFeedComment(item.id);
              }
              Navigator.pop(context);
            },
            child: const Text('Post comment'),
          ),
        ],
      ),
    );
    textController.dispose();
  }
}

class _FeedAction extends StatelessWidget {
  const _FeedAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              color: active ? AppColors.danger : AppColors.muted,
              size: 20,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.danger : AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return ResponsivePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            icon: Icons.notifications_none_outlined,
            title: 'Notifications',
            subtitle:
                'Updates about your reports, followed projects and local announcements.',
            action: controller.unreadNotificationCount > 0
                ? TextButton(
                    onPressed: controller.markAllNotificationsRead,
                    child: const Text('Mark all read'),
                  )
                : null,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: controller.notifications.isEmpty
                ? const EmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'You are all caught up',
                    message: 'New local updates will appear here.',
                  )
                : ListView.separated(
                    itemCount: controller.notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notification = controller.notifications[index];
                      return CivicCard(
                        onTap: () {
                          controller.markNotificationRead(notification.id);
                          if (notification.route != null) {
                            Navigator.pushNamed(context, notification.route!);
                          }
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 11,
                              height: 11,
                              margin: const EdgeInsets.only(top: 5),
                              decoration: BoxDecoration(
                                color: notification.isRead
                                    ? Colors.transparent
                                    : AppColors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    notification.title,
                                    style: TextStyle(
                                      fontWeight: notification.isRead
                                          ? FontWeight.w700
                                          : FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    notification.message,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${notification.category} · ${relativeTime(notification.createdAt)}',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.muted,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final user = controller.currentUser!;
    final followedProjects = controller.projects
        .where((project) => project.followerIds.contains(user.id))
        .length;
    final followedReports = controller.reports
        .where((report) => report.followerIds.contains(user.id))
        .length;
    return ResponsivePage(
      child: ListView(
        children: <Widget>[
          PageHeader(
            icon: Icons.account_circle_outlined,
            title: user.isGuest ? 'Guest profile' : 'Your profile',
            subtitle: user.isGuest
                ? 'Sign in to personalise your local services.'
                : 'Manage your local service area and privacy preferences.',
            action: user.isGuest
                ? null
                : IconButton(
                    onPressed: () => _editProfile(context),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit profile',
                  ),
          ),
          const SizedBox(height: 22),
          CivicCard(
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 31,
                  backgroundColor: AppColors.mint,
                  child: Text(
                    user.fullName.isNotEmpty
                        ? user.fullName.substring(0, 1).toUpperCase()
                        : 'G',
                    style: const TextStyle(
                      color: AppColors.deepGreen,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        user.fullName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.isGuest
                            ? 'Browsing public information'
                            : user.role.label,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user.isVerified
                              ? 'Verified resident · ${user.ward}'
                              : user.role.label,
                          style: const TextStyle(
                            color: AppColors.deepGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (!user.isGuest) ...<Widget>[
            _ProfileSection(
              title: 'Local profile',
              rows: <_ProfileRowData>[
                _ProfileRowData(Icons.mail_outline, 'Email', user.email),
                _ProfileRowData(Icons.phone_outlined, 'Phone', user.phone),
                _ProfileRowData(
                  Icons.language_outlined,
                  'Language',
                  user.preferredLanguage == 'si'
                      ? 'සිංහල'
                      : user.preferredLanguage == 'ta'
                      ? 'தமிழ்'
                      : 'English',
                ),
                _ProfileRowData(
                  Icons.account_balance_outlined,
                  'Local authority',
                  controller.authorityName,
                ),
                _ProfileRowData(
                  Icons.map_outlined,
                  'Ward & GN division',
                  '${user.ward} · ${user.gnDivision}',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _ProfileSection(
              title: 'Your participation',
              rows: <_ProfileRowData>[
                _ProfileRowData(
                  Icons.account_tree_outlined,
                  'Followed projects',
                  '$followedProjects projects',
                  onTap: () => Navigator.pushNamed(context, '/projects'),
                ),
                _ProfileRowData(
                  Icons.report_problem_outlined,
                  'Followed issues',
                  '$followedReports reports',
                  onTap: () => Navigator.pushNamed(context, '/my-reports'),
                ),
                _ProfileRowData(
                  Icons.lightbulb_outline,
                  'Community proposals',
                  '${controller.proposals.where((proposal) => proposal.author.contains(user.ward)).length} local ideas',
                  onTap: () => Navigator.pushNamed(context, '/proposals'),
                ),
                _ProfileRowData(
                  Icons.forum_outlined,
                  'Consultation history',
                  '${controller.consultations.where((consultation) => consultation.respondedUserIds.contains(user.id)).length} responses',
                  onTap: () => Navigator.pushNamed(context, '/consultations'),
                ),
              ],
            ),
          ] else
            FilledButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/register',
                (route) => false,
              ),
              child: const Text('Create a citizen account'),
            ),
          const SizedBox(height: 18),
          _ProfileSection(
            title: 'Account',
            rows: <_ProfileRowData>[
              if (user.isOfficer)
                _ProfileRowData(
                  Icons.admin_panel_settings_outlined,
                  'Officer dashboard',
                  'Manage your authority',
                  onTap: () => Navigator.pushNamed(context, '/admin'),
                ),
              _ProfileRowData(
                Icons.privacy_tip_outlined,
                'Privacy and location',
                'Your exact home location is never public.',
              ),
              _ProfileRowData(
                Icons.logout,
                user.isGuest ? 'Leave guest mode' : 'Sign out',
                'Return to the sign-in screen',
                danger: true,
                onTap: () {
                  controller.signOut();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/',
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final controller = AppScope.of(context);
    final user = controller.currentUser!;
    final name = TextEditingController(text: user.fullName);
    final phone = TextEditingController(text: user.phone);
    var language = user.preferredLanguage;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          22,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Edit profile',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
            ),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (context, setModalState) =>
                  DropdownButtonFormField<String>(
                    value: language,
                    decoration: const InputDecoration(
                      labelText: 'Preferred language',
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'si', child: Text('සිංහල')),
                      DropdownMenuItem(value: 'ta', child: Text('தமிழ்')),
                    ],
                    onChanged: (value) =>
                        setModalState(() => language = value ?? 'en'),
                  ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                controller.updateProfile(
                  fullName: name.text.trim(),
                  phone: phone.text.trim(),
                  preferredLanguage: language,
                );
                Navigator.pop(context);
              },
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    phone.dispose();
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.rows});

  final String title;
  final List<_ProfileRowData> rows;

  @override
  Widget build(BuildContext context) {
    return CivicCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          ...rows.map(
            (row) => ListTile(
              leading: Icon(
                row.icon,
                color: row.danger ? AppColors.danger : AppColors.deepGreen,
              ),
              title: Text(
                row.title,
                style: TextStyle(
                  color: row.danger ? AppColors.danger : null,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(row.subtitle),
              trailing: row.onTap == null
                  ? null
                  : const Icon(Icons.chevron_right),
              onTap: row.onTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRowData {
  const _ProfileRowData(
    this.icon,
    this.title,
    this.subtitle, {
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;
}

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final results = controller.search(_query.text);
    return Scaffold(
      appBar: AppBar(title: const Text('Search Smart Sabha')),
      body: ResponsivePage(
        child: Column(
          children: <Widget>[
            TextField(
              controller: _query,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search projects, notices, reports and consultations',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _query.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _query.text.trim().isEmpty
                  ? const EmptyState(
                      icon: Icons.travel_explore_outlined,
                      title: 'Search local information',
                      message:
                          'Try a project name, issue category, service notice or consultation topic.',
                    )
                  : results.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_outlined,
                      title: 'No results found',
                      message: 'Try a broader or different search term.',
                    )
                  : ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _SearchResult(item: results[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResult extends StatelessWidget {
  const _SearchResult({required this.item});

  final Object item;

  @override
  Widget build(BuildContext context) {
    final data = switch (item) {
      Project project => (
        title: project.title,
        subtitle: '${project.category} · ${project.locationLabel}',
        icon: Icons.account_tree_outlined,
        route: '/projects/${project.id}',
      ),
      CivicReport report => (
        title: report.title,
        subtitle: '${report.caseNumber} · ${report.status.label}',
        icon: Icons.report_problem_outlined,
        route: '/reports/${report.id}',
      ),
      Announcement announcement => (
        title: announcement.title,
        subtitle: announcement.type.label,
        icon: announcement.type.icon,
        route: '/announcements/${announcement.id}',
      ),
      Proposal proposal => (
        title: proposal.title,
        subtitle: proposal.status.label,
        icon: Icons.lightbulb_outline,
        route: '/proposals/${proposal.id}',
      ),
      Consultation consultation => (
        title: consultation.title,
        subtitle: consultation.isOpen
            ? 'Open consultation'
            : 'Closed consultation',
        icon: Icons.forum_outlined,
        route: '/consultations/${consultation.id}',
      ),
      _ => (title: 'Result', subtitle: '', icon: Icons.search, route: '/'),
    };
    return CivicCard(
      onTap: () => Navigator.pushNamed(context, data.route),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, color: AppColors.deepGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  data.subtitle,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}
