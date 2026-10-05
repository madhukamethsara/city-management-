import '../../data/civic_failure.dart';
import '../projects/connected_project_list.dart';
import '../community/announcement_controls.dart';
import '../../widgets/save_civic_action.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../models/domain_models.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_widgets.dart';

enum AdminSection {
  overview,
  reports,
  projects,
  announcements,
  departments,
  users,
  analytics,
}

extension AdminSectionInfo on AdminSection {
  String get label => switch (this) {
    AdminSection.overview => 'Overview',
    AdminSection.reports => 'Complaints',
    AdminSection.projects => 'Projects',
    AdminSection.announcements => 'Announcements',
    AdminSection.departments => 'Departments',
    AdminSection.users => 'Users',
    AdminSection.analytics => 'Analytics',
  };

  IconData get icon => switch (this) {
    AdminSection.overview => Icons.dashboard_outlined,
    AdminSection.reports => Icons.assignment_outlined,
    AdminSection.projects => Icons.account_tree_outlined,
    AdminSection.announcements => Icons.campaign_outlined,
    AdminSection.departments => Icons.apartment_outlined,
    AdminSection.users => Icons.group_outlined,
    AdminSection.analytics => Icons.insights_outlined,
  };
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, this.initialSection = AdminSection.overview});

  final AdminSection initialSection;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late AdminSection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1000;
    final controller = AppScope.of(context);
    final sections = [
      AdminSection.overview,
      AdminSection.reports,
      AdminSection.projects,
      AdminSection.announcements,
      if (controller.canManageDepartments) AdminSection.departments,
      if (controller.canManageUsers) AdminSection.users,
      AdminSection.analytics,
    ];
    if (!sections.contains(_section)) _section = AdminSection.overview;
    if (controller.usesPersistentData) {
      return Scaffold(
        drawer: desktop
            ? null
            : Drawer(
                child: SafeArea(
                  child: ListView(
                    children: [
                      for (final section in sections)
                        ListTile(
                          leading: Icon(section.icon),
                          title: Text(section.label),
                          selected: section == _section,
                          onTap: () {
                            Navigator.pop(context);
                            setState(() => _section = section);
                          },
                        ),
                    ],
                  ),
                ),
              ),
        appBar: AppBar(
          title: Text(switch (_section) {
            AdminSection.projects => 'Officer projects',
            AdminSection.announcements => 'Officer announcements',
            AdminSection.overview => 'Officer dashboard',
            AdminSection.departments => 'Officer departments',
            AdminSection.users => 'Officer users',
            AdminSection.analytics => 'Officer analytics',
            _ => 'Officer cases',
          }),
          actions: [
            IconButton(
              tooltip: 'Refresh data',
              icon: const Icon(Icons.refresh),
              onPressed: () => saveCivicAction(context, controller.refreshData),
            ),
            IconButton(
              tooltip: 'Citizen app',
              icon: const Icon(Icons.public_outlined),
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/citizen',
                (route) => false,
              ),
            ),
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                if (!await saveCivicAction(context, controller.signOut)) return;
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/',
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
        body: Row(
          children: [
            if (desktop)
              NavigationRail(
                selectedIndex: sections.indexOf(_section),
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: (index) =>
                    setState(() => _section = sections[index]),
                destinations: [
                  for (final section in sections)
                    NavigationRailDestination(
                      icon: Icon(section.icon),
                      label: Text(section.label),
                    ),
                ],
              ),
            Expanded(
              child: switch (_section) {
                AdminSection.overview => OfficerOverviewPanel(
                  onNavigate: (section) => setState(() => _section = section),
                ),
                AdminSection.projects => const AdminProjectsPanel(),
                AdminSection.announcements => const AdminAnnouncementsPanel(),
                AdminSection.departments =>
                  controller.canManageDepartments
                      ? const AdminDepartmentsPanel()
                      : const AdminReportsPanel(),
                AdminSection.users =>
                  controller.canManageUsers
                      ? const AdminUsersPanel()
                      : const AdminReportsPanel(),
                AdminSection.analytics => const AdminAnalyticsPanel(),
                _ => const AdminReportsPanel(),
              },
            ),
          ],
        ),
        bottomNavigationBar:
            desktop ||
                [
                  AdminSection.departments,
                  AdminSection.users,
                  AdminSection.analytics,
                ].contains(_section)
            ? null
            : NavigationBar(
                selectedIndex: switch (_section) {
                  AdminSection.overview => 0,
                  AdminSection.projects => 2,
                  AdminSection.announcements => 3,
                  _ => 1,
                },
                onDestinationSelected: (index) => setState(
                  () => _section = [
                    AdminSection.overview,
                    AdminSection.reports,
                    AdminSection.projects,
                    AdminSection.announcements,
                  ][index],
                ),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    label: 'Overview',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.assignment_outlined),
                    label: 'Complaints',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.account_tree_outlined),
                    label: 'Projects',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.campaign_outlined),
                    label: 'Notices',
                  ),
                ],
              ),
      );
    }
    final panel = _panel();
    final main = Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            const AppLogo(compact: true),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_section.label, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh cases',
            icon: const Icon(Icons.refresh),
            onPressed: () => saveCivicAction(context, controller.refreshData),
          ),
          IconButton(
            tooltip: 'Citizen app',
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/citizen',
              (route) => false,
            ),
            icon: const Icon(Icons.public_outlined),
          ),
          IconButton(
            onPressed: () async {
              if (!await saveCivicAction(context, controller.signOut)) return;
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      drawer: desktop
          ? null
          : _AdminDrawer(
              selected: _section,
              onSelected: _select,
              sections: sections,
            ),
      body: panel,
    );
    if (!desktop) return main;
    return Scaffold(
      body: Row(
        children: <Widget>[
          SafeArea(
            child: NavigationRail(
              selectedIndex: sections.indexOf(_section),
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.fromLTRB(0, 12, 0, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AppLogo(compact: true),
                    SizedBox(height: 8),
                    Text(
                      'Officer console',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              onDestinationSelected: (index) => _select(sections[index]),
              destinations: sections
                  .map(
                    (section) => NavigationRailDestination(
                      icon: Icon(section.icon),
                      selectedIcon: Icon(
                        section.icon,
                        color: AppColors.deepGreen,
                      ),
                      label: Text(section.label),
                    ),
                  )
                  .toList(),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: main),
        ],
      ),
    );
  }

  void _select(AdminSection section) {
    setState(() => _section = section);
    Navigator.maybePop(context);
  }

  Widget _panel() => switch (_section) {
    AdminSection.overview => OfficerOverviewPanel(onNavigate: _select),
    AdminSection.reports => const AdminReportsPanel(),
    AdminSection.projects => const AdminProjectsPanel(),
    AdminSection.announcements => const AdminAnnouncementsPanel(),
    AdminSection.departments => const AdminDepartmentsPanel(),
    AdminSection.users => const AdminUsersPanel(),
    AdminSection.analytics => const AdminAnalyticsPanel(),
  };
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({
    required this.selected,
    required this.onSelected,
    required this.sections,
  });

  final AdminSection selected;
  final ValueChanged<AdminSection> onSelected;
  final List<AdminSection> sections;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: <Widget>[
                  AppLogo(),
                  SizedBox(width: 8),
                  Text(
                    'Officer console',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const Divider(),
            ...sections.map(
              (section) => ListTile(
                leading: Icon(section.icon),
                title: Text(section.label),
                selected: selected == section,
                onTap: () => onSelected(section),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OfficerOverviewPanel extends StatelessWidget {
  const OfficerOverviewPanel({super.key, required this.onNavigate});

  final ValueChanged<AdminSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final open = controller.reports
        .where(
          (report) =>
              report.status != ReportStatus.resolved &&
              report.status != ReportStatus.rejected,
        )
        .toList();
    final mine = open
        .where(
          (report) =>
              report.assignedOfficer == controller.currentUser?.fullName,
        )
        .length;
    final unassigned = open
        .where(
          (report) =>
              report.assignedOfficer == null ||
              report.assignedOfficer!.trim().isEmpty,
        )
        .length;
    final urgent = open.where((report) => report.priority == 'Urgent').length;
    final recent = [...controller.reports]
      ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    return ResponsivePage(
      child: ListView(
        children: [
          PageHeader(
            icon: Icons.dashboard_outlined,
            title: 'Officer workspace',
            subtitle:
                '${controller.authorityName} • Welcome, ${controller.currentUser?.fullName ?? 'officer'}',
          ),
          const SizedBox(height: 16),
          Text(
            'Current case workload',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final entry in [
                ('Open cases', open.length, Icons.assignment_outlined),
                ('Assigned to me', mine, Icons.person_outline),
                ('Unassigned', unassigned, Icons.person_add_alt),
                ('Urgent open cases', urgent, Icons.priority_high),
              ])
                SizedBox(
                  width: 240,
                  child: MetricTile(
                    label: entry.$1,
                    value: '${entry.$2}',
                    icon: entry.$3,
                    color: AppColors.deepGreen,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => onNavigate(AdminSection.reports),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Manage complaints'),
              ),
              OutlinedButton.icon(
                onPressed: () => onNavigate(AdminSection.projects),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('Manage projects'),
              ),
              OutlinedButton.icon(
                onPressed: () => onNavigate(AdminSection.announcements),
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Manage notices'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Recently updated cases'),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            const EmptyState(
              icon: Icons.assignment_turned_in_outlined,
              title: 'No cases yet',
              message:
                  'Resident reports will appear here. Use refresh to fetch new cases.',
            ),
          for (final report in recent.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CivicCard(
                onTap: () =>
                    Navigator.pushNamed(context, '/reports/${report.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.caseNumber,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        ReportStatusBadge(status: report.status),
                        Text(report.department),
                        Text(relativeTime(report.lastUpdated)),
                      ],
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

class AdminOverviewPanel extends StatelessWidget {
  const AdminOverviewPanel({super.key, required this.onNavigate});

  final ValueChanged<AdminSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final metrics = controller.dashboardMetrics;
    return ResponsivePage(
      child: ListView(
        children: <Widget>[
          PageHeader(
            icon: Icons.dashboard_outlined,
            title: 'Authority overview',
            subtitle: 'An operational view of ${controller.authorityName}.',
            action: FilledButton.icon(
              onPressed: () => onNavigate(AdminSection.reports),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Manage complaints'),
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth >= 1020
                  ? 4
                  : constraints.maxWidth >= 580
                  ? 2
                  : 1;
              final tiles = <MetricTile>[
                MetricTile(
                  label: 'New complaints',
                  value: '${metrics.newComplaints}',
                  icon: Icons.fiber_new_outlined,
                  color: AppColors.danger,
                ),
                MetricTile(
                  label: 'Assigned complaints',
                  value: '${metrics.assignedComplaints}',
                  icon: Icons.assignment_ind_outlined,
                  color: const Color(0xFF2C6EAA),
                ),
                MetricTile(
                  label: 'Active projects',
                  value: '${metrics.activeProjects}',
                  icon: Icons.construction_outlined,
                  color: AppColors.green,
                ),
                MetricTile(
                  label: 'Average resolution',
                  value: '${metrics.averageResolutionDays} days',
                  icon: Icons.timer_outlined,
                  color: AppColors.warning,
                ),
                MetricTile(
                  label: 'Delayed projects',
                  value: '${metrics.delayedProjects}',
                  icon: Icons.schedule_outlined,
                  color: AppColors.warning,
                ),
                MetricTile(
                  label: 'Open consultations',
                  value: '${metrics.openConsultations}',
                  icon: Icons.forum_outlined,
                  color: const Color(0xFF805AD5),
                ),
                MetricTile(
                  label: 'Citizen proposals',
                  value: '${metrics.citizenProposals}',
                  icon: Icons.lightbulb_outline,
                  color: AppColors.deepGreen,
                ),
                MetricTile(
                  label: 'Overdue complaints',
                  value: '${metrics.overdueComplaints}',
                  icon: Icons.warning_amber_outlined,
                  color: AppColors.danger,
                ),
              ];
              return GridView.count(
                crossAxisCount: count,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: count == 1 ? 3.4 : 1.45,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: tiles,
              );
            },
          ),
          const SizedBox(height: 26),
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth >= 840
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: _ComplaintsChart(reports: controller.reports),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ProjectsChart(projects: controller.projects),
                      ),
                    ],
                  )
                : Column(
                    children: <Widget>[
                      _ComplaintsChart(reports: controller.reports),
                      const SizedBox(height: 16),
                      _ProjectsChart(projects: controller.projects),
                    ],
                  ),
          ),
          const SizedBox(height: 26),
          const SectionTitle(title: 'Recent complaints'),
          const SizedBox(height: 10),
          ...controller.reports
              .take(3)
              .map(
                (report) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CivicCard(
                    onTap: () => onNavigate(AdminSection.reports),
                    child: Row(
                      children: <Widget>[
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
                              const SizedBox(height: 3),
                              Text(
                                report.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${report.department} · ${relativeTime(report.lastUpdated)}',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ReportStatusBadge(status: report.status),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, color: AppColors.muted),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _ComplaintsChart extends StatelessWidget {
  const _ComplaintsChart({required this.reports});

  final List<CivicReport> reports;

  @override
  Widget build(BuildContext context) {
    final values = <String, int>{
      'Submitted': reports
          .where((report) => report.status == ReportStatus.submitted)
          .length,
      'Assigned': reports
          .where((report) => report.status == ReportStatus.assigned)
          .length,
      'In progress': reports
          .where((report) => report.status == ReportStatus.inProgress)
          .length,
      'Resolved': reports
          .where((report) => report.status == ReportStatus.resolved)
          .length,
    };
    return _BarChartCard(
      title: 'Complaints by status',
      values: values,
      color: AppColors.green,
    );
  }
}

class _ProjectsChart extends StatelessWidget {
  const _ProjectsChart({required this.projects});

  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final values = <String, int>{
      'Proposed': projects
          .where(
            (project) =>
                project.status == ProjectStatus.proposed ||
                project.status == ProjectStatus.planned,
          )
          .length,
      'Active': projects
          .where((project) => project.status == ProjectStatus.inProgress)
          .length,
      'Delayed': projects
          .where((project) => project.status == ProjectStatus.delayed)
          .length,
      'Completed': projects
          .where((project) => project.status == ProjectStatus.completed)
          .length,
    };
    return _BarChartCard(
      title: 'Projects by status',
      values: values,
      color: const Color(0xFF2C6EAA),
    );
  }
}

class _BarChartCard extends StatelessWidget {
  const _BarChartCard({
    required this.title,
    required this.values,
    required this.color,
  });

  final String title;
  final Map<String, int> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maximum = values.values.fold(
      1,
      (highest, value) => value > highest ? value : highest,
    );
    return CivicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          SizedBox(
            height: 120 + MediaQuery.textScalerOf(context).scale(64),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: values.entries
                  .map(
                    (entry) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              '${entry.value}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 108 * (entry.value / maximum),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.82),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(7),
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              entry.key,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminReportsPanel extends StatefulWidget {
  const AdminReportsPanel({super.key});

  @override
  State<AdminReportsPanel> createState() => _AdminReportsPanelState();
}

class _AdminReportsPanelState extends State<AdminReportsPanel> {
  final _search = TextEditingController();
  ReportStatus? _status;
  String? _department;
  String _assignment = 'All assignments';
  bool _urgentOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final query = _search.text.trim().toLowerCase();
    final reports = controller.reports
        .where(
          (report) =>
              (query.isEmpty ||
                  '${report.caseNumber} ${report.title} ${report.category} ${report.locationLabel}'
                      .toLowerCase()
                      .contains(query)) &&
              (_status == null || report.status == _status) &&
              (_department == null || report.department == _department) &&
              (!_urgentOnly || report.priority == 'Urgent') &&
              (_assignment == 'All assignments' ||
                  (_assignment == 'Assigned to me' &&
                      report.assignedOfficer ==
                          controller.currentUser?.fullName) ||
                  (_assignment == 'Unassigned' &&
                      (report.assignedOfficer == null ||
                          report.assignedOfficer!.trim().isEmpty))),
        )
        .toList();
    reports.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    return ResponsivePage(
      child: ListView(
        children: <Widget>[
          const PageHeader(
            icon: Icons.assignment_outlined,
            title: 'Complaint management',
            subtitle:
                'Assign, prioritise and publish updates while preserving a clear case history.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in [
                'All assignments',
                'Assigned to me',
                'Unassigned',
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _assignment == label,
                  onSelected: (_) => setState(() => _assignment = label),
                ),
              FilterChip(
                label: const Text('Urgent only'),
                selected: _urgentOnly,
                onSelected: (value) => setState(() => _urgentOnly = value),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _search.clear();
                  _status = null;
                  _department = null;
                  _assignment = 'All assignments';
                  _urgentOnly = false;
                }),
                child: const Text('Clear filters'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search case number, title, category or location',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: <Widget>[
              DropdownButtonHideUnderline(
                child: DropdownButton<ReportStatus?>(
                  value: _status,
                  hint: const Text('All statuses'),
                  items: <DropdownMenuItem<ReportStatus?>>[
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All statuses'),
                    ),
                    ...ReportStatus.values.map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _status = value),
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: _department,
                  hint: const Text('All departments'),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All departments'),
                    ),
                    ...controller.departments.map(
                      (department) => DropdownMenuItem(
                        value: department.name,
                        child: Text(
                          department.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _department = value),
                ),
              ),
              Text(
                '${reports.length} cases',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 50),
              child: EmptyState(
                icon: Icons.filter_alt_off_outlined,
                title: 'No matching complaints',
                message: 'Adjust the search or filters to see cases.',
              ),
            )
          else if (MediaQuery.sizeOf(context).width < 760 ||
              MediaQuery.textScalerOf(context).scale(16) > 24)
            ...reports.map(
              (report) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CivicCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.caseNumber,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        report.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          ReportStatusBadge(status: report.status),
                          Text(report.priority),
                          Text(report.department),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/reports/${report.id}',
                            ),
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('View case'),
                          ),
                          FilledButton.icon(
                            onPressed: () => _openEditor(report),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Update case'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                dataRowMinHeight: 64,
                dataRowMaxHeight:
                    64 + MediaQuery.textScalerOf(context).scale(20),
                columns: const <DataColumn>[
                  DataColumn(label: Text('Case')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Department')),
                  DataColumn(label: Text('Priority')),
                  DataColumn(label: Text('Updated')),
                  DataColumn(label: Text('Action')),
                ],
                rows: reports
                    .map(
                      (report) => DataRow(
                        cells: <DataCell>[
                          DataCell(
                            SizedBox(
                              width: 230,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    report.caseNumber,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    report.title,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(ReportStatusBadge(status: report.status)),
                          DataCell(Text(report.department)),
                          DataCell(Text(report.priority)),
                          DataCell(Text(relativeTime(report.lastUpdated))),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'View case',
                                  icon: const Icon(Icons.visibility_outlined),
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    '/reports/${report.id}',
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _openEditor(report),
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Update case',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openEditor(CivicReport report) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReportEditor(report: report),
    );
  }
}

class _ReportEditor extends StatefulWidget {
  const _ReportEditor({required this.report});

  final CivicReport report;

  @override
  State<_ReportEditor> createState() => _ReportEditorState();
}

class _ReportEditorState extends State<_ReportEditor> {
  final _publicUpdate = TextEditingController();
  final _internalNote = TextEditingController();
  final _picker = ImagePicker();
  ReportStatus? _status;
  String? _department;
  String? _priority;
  String? _officer;
  XFile? _completionPhoto;
  String? _uploadedEvidence;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.report.status;
    _department = widget.report.department;
    _priority = widget.report.priority;
    _officer = widget.report.assignedOfficer;
  }

  @override
  void dispose() {
    _publicUpdate.dispose();
    _internalNote.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (mounted && image != null) {
      setState(() {
        _completionPhoto = image;
        _uploadedEvidence = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final officers = controller.users
        .where((user) => user.isOfficer && user.isActive)
        .toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        22,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${widget.report.caseNumber} · Update complaint',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              widget.report.title,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<ReportStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Case status'),
              items: ReportStatus.values
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(status.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _status = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _department,
              decoration: const InputDecoration(labelText: 'Department'),
              items:
                  {
                        ...controller.departments.map((d) => d.name),
                        if (_department != null) _department!,
                      }
                      .map(
                        (department) => DropdownMenuItem(
                          value: department,
                          child: Text(
                            department,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _department = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                DropdownMenuItem(value: 'High', child: Text('High')),
                DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
              ],
              onChanged: (value) => setState(() => _priority = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              value: _officer,
              decoration: const InputDecoration(labelText: 'Assigned officer'),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem(value: null, child: Text('Unassigned')),
                ...{
                  ...officers.map((o) => o.fullName),
                  if (_officer != null) _officer!,
                }.map(
                  (officer) => DropdownMenuItem(
                    value: officer,
                    child: Text(officer, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _officer = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _publicUpdate,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Public update',
                hintText: 'Visible to the resident and report followers',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _internalNote,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Internal note',
                hintText: 'Visible only to authorised officers',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickEvidence,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(
                _completionPhoto == null
                    ? 'Upload completion evidence'
                    : _completionPhoto!.name,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      try {
                        if (_completionPhoto != null) {
                          _uploadedEvidence ??= await controller
                              .uploadReportPhoto(
                                _completionPhoto!.name,
                                await _completionPhoto!.readAsBytes(),
                              );
                        }
                        await controller.updateReportStatus(
                          reportId: widget.report.id,
                          expectedRevision: widget.report.revision,
                          status: _status!,
                          department: _department!,
                          priority: _priority!,
                          assignedOfficer: _officer,
                          publicUpdate: _publicUpdate.text.trim().isEmpty
                              ? 'Case details updated by the local authority.'
                              : _publicUpdate.text.trim(),
                          internalNote: _internalNote.text,
                          attachmentNames: _completionPhoto == null
                              ? null
                              : <String>[_uploadedEvidence!],
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error is CivicFailure
                                  ? error.message
                                  : 'Could not save the case update. Please try again.',
                            ),
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              child: const Text('Save case update'),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminProjectsPanel extends StatelessWidget {
  const AdminProjectsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.usesPersistentData) {
      return ConnectedProjectList(
        title: 'Project administration',
        onCreate: () => _openEditor(context),
        onOpen: (project) => _openEditor(context, project: project),
      );
    }
    return ResponsivePage(
      child: ListView(
        children: <Widget>[
          PageHeader(
            icon: Icons.account_tree_outlined,
            title: 'Project administration',
            subtitle:
                'Create, publish and maintain transparent public project information.',
            action: FilledButton.icon(
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('New project'),
            ),
          ),
          const SizedBox(height: 18),
          ...controller.projects.map(
            (project) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CivicCard(
                onTap: () => _openEditor(context, project: project),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: project.status.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.account_tree_outlined,
                        color: project.status.color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            project.title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${project.department} · ${project.progress}% · ${project.locationLabel}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ProjectStatusBadge(status: project.status),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _openEditor(
    BuildContext context, {
    Project? project,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ProjectEditor(project: project),
    );
  }
}

class _ProjectEditor extends StatefulWidget {
  const _ProjectEditor({this.project});

  final Project? project;

  @override
  State<_ProjectEditor> createState() => _ProjectEditorState();
}

class _ProjectEditorState extends State<_ProjectEditor> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController();
  final _location = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _budget = TextEditingController();
  final _spent = TextEditingController();
  final _contractor = TextEditingController();
  final _update = TextEditingController();
  final _milestone = TextEditingController();
  final _document = TextEditingController();
  final _documentUrl = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  final _eventTime = DateTime.now();
  final List<ProjectMilestone> _milestones = [];
  final List<PublicDocument> _documents = [];
  Project? _base;
  ProjectStatus _status = ProjectStatus.proposed;
  String? _department;
  int _progress = 0;
  bool _budgetPublic = true;
  bool _updatePublic = true;
  bool _saving = false;
  late DateTime _startDate;
  late DateTime _completionDate;
  late DateTime _milestoneDate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_base != null) return;
    final controller = AppScope.of(context);
    _base =
        widget.project ??
        controller.buildProject(
          ProjectDraft(
            title: '',
            description: '',
            category: 'Public infrastructure',
            locationLabel: '',
            status: ProjectStatus.proposed,
            progress: 0,
            budget: 0,
            department: controller.departments.isEmpty
                ? ''
                : controller.departments.first.name,
          ),
        );
    final p = _base!;
    _title.text = p.title;
    _description.text = p.description;
    _category.text = p.category;
    _location.text = p.locationLabel;
    _latitude.text = p.location.latitude.toString();
    _longitude.text = p.location.longitude.toString();
    _budget.text = '${p.budget}';
    _spent.text = '${p.spent}';
    _contractor.text = p.contractor ?? '';
    _status = p.status;
    _department = controller.departments.any((d) => d.name == p.department)
        ? p.department
        : null;
    _progress = p.progress;
    _budgetPublic = p.isBudgetPublic;
    _startDate = p.startDate;
    _completionDate = p.expectedCompletion;
    _milestoneDate = p.expectedCompletion;
    _milestones.addAll(p.milestones);
    _documents.addAll(p.documents);
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _category,
      _location,
      _latitude,
      _longitude,
      _budget,
      _spent,
      _contractor,
      _update,
      _milestone,
      _document,
      _documentUrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 80);
    if (mounted && images.isNotEmpty) setState(() => _images.addAll(images));
  }

  Future<void> _pickDate(
    DateTime current,
    ValueChanged<DateTime> update,
  ) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (mounted && selected != null) setState(() => update(selected));
  }

  String? _amount(String? value) {
    final amount = int.tryParse((value ?? '').replaceAll(',', ''));
    return amount == null || amount < 0 || amount > 999999999999999
        ? 'Enter a non-negative amount in LKR.'
        : null;
  }

  String? _coordinate(String? value, double max) {
    final n = double.tryParse(value ?? '');
    return n == null || !n.isFinite || n.abs() > max
        ? 'Enter a coordinate between -$max and $max.'
        : null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_completionDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completion must be on or after the start date.'),
        ),
      );
      return;
    }
    final controller = AppScope.of(context);
    final documents = [..._documents];
    if (_document.text.trim().isNotEmpty) {
      documents.add(
        PublicDocument(
          name: _document.text.trim(),
          kind: 'Link',
          sizeLabel: 'Public document',
          url: _documentUrl.text.trim().isEmpty
              ? null
              : _documentUrl.text.trim(),
        ),
      );
    }
    final milestones = [..._milestones];
    if (_milestone.text.trim().isNotEmpty) {
      milestones.add(
        ProjectMilestone(
          title: _milestone.text.trim(),
          description: 'Milestone added by the authority.',
          percentage: _progress,
          expectedDate: _milestoneDate,
          completedDate: null,
          isComplete: false,
        ),
      );
    }
    final project = _base!.copyWith(
      title: _title.text.trim(),
      description: _description.text.trim(),
      category: _category.text.trim(),
      locationLabel: _location.text.trim(),
      location: GeoPoint(
        double.parse(_latitude.text),
        double.parse(_longitude.text),
      ),
      status: _status,
      progress: _progress,
      department: _department!,
      startDate: _startDate,
      expectedCompletion: _completionDate,
      budget: int.parse(_budget.text.replaceAll(',', '')),
      spent: int.parse(_spent.text.replaceAll(',', '')),
      isBudgetPublic: _budgetPublic,
      contractor: _contractor.text.trim(),
      documents: documents,
      milestones: milestones,
      updates: [
        ..._base!.updates,
        if (_update.text.trim().isNotEmpty)
          ProjectUpdate(
            title: 'Project update',
            message: _update.text.trim(),
            date: _eventTime,
            isPublic: _updatePublic,
          ),
      ],
      imageLabels: [
        ..._base!.imageLabels,
        ..._images.map((image) => image.name),
      ],
    );
    setState(() => _saving = true);
    final saved = await saveCivicAction(
      context,
      () => controller.saveProject(project),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        22,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: AbsorbPointer(
            absorbing: _saving,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.project == null ? 'Create project' : 'Manage project',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _title,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Project title'),
                  validator: (v) => (v ?? '').trim().length < 8
                      ? 'Enter a project title.'
                      : null,
                ),
                TextFormField(
                  controller: _description,
                  maxLength: 10000,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Public description',
                  ),
                  validator: (v) => (v ?? '').trim().length < 20
                      ? 'Add a public description.'
                      : null,
                ),
                TextFormField(
                  controller: _category,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Category'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Enter a category.' : null,
                ),
                TextFormField(
                  controller: _location,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Location label',
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Add a project location.'
                      : null,
                ),
                TextFormField(
                  controller: _latitude,
                  decoration: const InputDecoration(
                    labelText: 'Project latitude',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: (v) => _coordinate(v, 90),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _longitude,
                  decoration: const InputDecoration(
                    labelText: 'Project longitude',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: (v) => _coordinate(v, 180),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<ProjectStatus>(
                  value: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Project status',
                  ),
                  items: ProjectStatus.values
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                      )
                      .toList(),
                  onChanged: (s) => setState(() => _status = s ?? _status),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _department,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Responsible department',
                  ),
                  items: controller.departments
                      .map(
                        (d) => DropdownMenuItem(
                          value: d.name,
                          child: Text(d.name),
                        ),
                      )
                      .toList(),
                  validator: (v) => v == null ? 'Choose a department.' : null,
                  onChanged: (v) => setState(() => _department = v),
                ),
                const SizedBox(height: 10),
                Text(
                  'Progress: $_progress%',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Slider(
                  value: _progress.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: '$_progress%',
                  onChanged: (v) => setState(() => _progress = v.round()),
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: () =>
                          _pickDate(_startDate, (d) => _startDate = d),
                      child: Text(
                        'Start: ${formatDate(_startDate, includeYear: true)}',
                      ),
                    ),
                    TextButton(
                      onPressed: () => _pickDate(
                        _completionDate,
                        (d) => _completionDate = d,
                      ),
                      child: Text(
                        'Completion: ${formatDate(_completionDate, includeYear: true)}',
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _budget,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Allocated budget (LKR)',
                  ),
                  validator: _amount,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _spent,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount spent (LKR)',
                  ),
                  validator: _amount,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Display budget publicly'),
                  value: _budgetPublic,
                  onChanged: (v) => setState(() => _budgetPublic = v),
                ),
                TextFormField(
                  controller: _contractor,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Contractor (optional)',
                  ),
                ),
                TextFormField(
                  controller: _update,
                  maxLength: 4000,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Progress update (optional)',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Publish this update'),
                  subtitle: const Text(
                    'Private updates are visible to authority officers.',
                  ),
                  value: _updatePublic,
                  onChanged: (v) => setState(() => _updatePublic = v),
                ),
                if (_base!.updates.any((u) => !u.isPublic)) ...[
                  const Text(
                    'Internal updates',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  ..._base!.updates
                      .where((u) => !u.isPublic)
                      .map(
                        (u) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(u.title),
                          subtitle: Text(u.message),
                        ),
                      ),
                ],
                ..._milestones.asMap().entries.map((entry) {
                  final m = entry.value;
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(m.title),
                    value: m.isComplete,
                    onChanged: (complete) => setState(
                      () => _milestones[entry.key] = ProjectMilestone(
                        title: m.title,
                        description: m.description,
                        percentage: m.percentage,
                        expectedDate: m.expectedDate,
                        completedDate: complete == true ? _eventTime : null,
                        isComplete: complete == true,
                      ),
                    ),
                  );
                }),
                TextFormField(
                  controller: _milestone,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Add milestone (optional)',
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      _pickDate(_milestoneDate, (d) => _milestoneDate = d),
                  child: Text(
                    'Milestone due: ${formatDate(_milestoneDate, includeYear: true)}',
                  ),
                ),
                ..._documents.asMap().entries.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value.name),
                    subtitle: Text(entry.value.url ?? 'Demo document'),
                    trailing: IconButton(
                      tooltip: 'Remove document',
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          setState(() => _documents.removeAt(entry.key)),
                    ),
                  ),
                ),
                TextFormField(
                  controller: _document,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Public document name (optional)',
                  ),
                  validator: (v) =>
                      _documentUrl.text.trim().isNotEmpty &&
                          (v ?? '').trim().isEmpty
                      ? 'Name the document.'
                      : null,
                ),
                TextFormField(
                  controller: _documentUrl,
                  maxLength: 2048,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Public document HTTPS link',
                    helperText: 'Use a publicly accessible document link.',
                  ),
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty &&
                        (!controller.usesPersistentData ||
                            _document.text.trim().isEmpty)) {
                      return null;
                    }
                    final uri = Uri.tryParse((v ?? '').trim());
                    return uri == null ||
                            uri.scheme != 'https' ||
                            uri.host.isEmpty ||
                            uri.userInfo.isNotEmpty ||
                            RegExp(r'\s').hasMatch(v ?? '')
                        ? 'Enter a public HTTPS document link.'
                        : null;
                  },
                ),
                if (!controller.usesPersistentData)
                  OutlinedButton.icon(
                    onPressed: _addImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      _images.isEmpty
                          ? 'Add project images'
                          : '${_images.length} image(s) selected',
                    ),
                  ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving
                        ? 'Saving...'
                        : widget.project == null
                        ? 'Create project'
                        : 'Save project changes',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminAnnouncementsPanel extends StatelessWidget {
  const AdminAnnouncementsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return ResponsivePage(
      child: ListView(
        children: <Widget>[
          PageHeader(
            icon: Icons.campaign_outlined,
            title: 'Announcement administration',
            subtitle:
                'Draft, publish and unpublish authority notices for selected wards and GN divisions.',
            action: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => _openComposer(context),
              icon: const Icon(Icons.add),
              label: const Text('New announcement'),
            ),
          ),
          const SizedBox(height: 18),
          const AnnouncementControls(),
          ...controller.managedAnnouncements.map(
            (announcement) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CivicCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            (announcement.isPublished
                                    ? AppColors.green
                                    : AppColors.warning)
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        announcement.type.icon,
                        color: announcement.isPublished
                            ? AppColors.green
                            : AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            announcement.title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${announcement.department} · ${announcement.targetLabel}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            announcement.isPublished
                                ? 'Published'
                                : 'Unpublished',
                            style: TextStyle(
                              color: announcement.isPublished
                                  ? AppColors.green
                                  : AppColors.warning,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          _openComposer(context, existing: announcement);
                        } else if (value == 'publish') {
                          if (!await saveCivicAction(
                            context,
                            () =>
                                controller.publishAnnouncement(announcement.id),
                          )) {
                            return;
                          }
                          if (!context.mounted) return;
                        } else {
                          if (!await saveCivicAction(
                            context,
                            () => controller.saveAnnouncement(
                              announcement.copyWith(isPublished: false),
                            ),
                          )) {
                            return;
                          }
                          if (!context.mounted) return;
                        }
                      },
                      itemBuilder: (context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        if (!announcement.isPublished)
                          const PopupMenuItem(
                            value: 'publish',
                            child: Text('Publish now'),
                          ),
                        if (announcement.isPublished)
                          const PopupMenuItem(
                            value: 'archive',
                            child: Text('Unpublish'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _openComposer(
    BuildContext context, {
    Announcement? existing,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AnnouncementComposer(existing: existing),
    );
  }
}

class _AnnouncementComposer extends StatefulWidget {
  const _AnnouncementComposer({this.existing});

  final Announcement? existing;

  @override
  State<_AnnouncementComposer> createState() => _AnnouncementComposerState();
}

class _AnnouncementComposerState extends State<_AnnouncementComposer> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _target = TextEditingController();
  final _ward = TextEditingController();
  final _division = TextEditingController();
  final _requestId = 'a-${DateTime.now().microsecondsSinceEpoch}';
  bool _saving = false;
  late AnnouncementType _type;
  late String _department;
  bool _publishNow = false;

  @override
  void initState() {
    super.initState();
    final announcement = widget.existing;
    _title.text = announcement?.title ?? '';
    _body.text = announcement?.body ?? '';
    _target.text = announcement?.targetLabel ?? 'All wards';
    _ward.text = announcement?.targetWard ?? '';
    _division.text = announcement?.targetDivision ?? '';
    _type = announcement?.type ?? AnnouncementType.normal;
    _department = announcement?.department ?? 'Administration';
    _publishNow = announcement?.isPublished ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _target.dispose();
    _ward.dispose();
    _division.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;
    setState(() => _saving = true);
    final controller = AppScope.of(context);
    try {
      if (widget.existing == null) {
        if (!await saveCivicAction(
          context,
          () => controller.createAnnouncement(
            AnnouncementDraft(
              requestId: _requestId,
              targetWard: _ward.text.trim(),
              targetDivision: _division.text.trim(),
              title: _title.text.trim(),
              body: _body.text.trim(),
              type: _type,
              department: _department,
              targetLabel: _target.text.trim(),
            ),
            publishNow: _publishNow,
          ),
        )) {
          return;
        }
        if (!mounted) return;
      } else {
        if (!await saveCivicAction(
          context,
          () => controller.saveAnnouncement(
            widget.existing!.copyWith(
              targetWard: _ward.text.trim(),
              targetDivision: _division.text.trim(),
              title: _title.text.trim(),
              body: _body.text.trim(),
              type: _type,
              department: _department,
              targetLabel: _target.text.trim(),
              isPublished: _publishNow,
            ),
          ),
        )) {
          return;
        }
        if (!mounted) return;
      }
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        22,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.existing == null
                    ? 'Create announcement'
                    : 'Edit announcement',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _title,
                maxLength: 130,
                decoration: const InputDecoration(
                  labelText: 'Announcement title',
                ),
                validator: (value) => value == null || value.trim().length < 8
                    ? 'Add a useful title.'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _body,
                maxLength: 10000,
                minLines: 4,
                maxLines: 7,
                decoration: const InputDecoration(labelText: 'Public message'),
                validator: (value) => value == null || value.trim().length < 20
                    ? 'Add a public message.'
                    : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<AnnouncementType>(
                isExpanded: true,
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Announcement type',
                ),
                items: AnnouncementType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _department,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Department'),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem(
                    value: 'Administration',
                    child: Text('Administration'),
                  ),
                  ...controller.departments.map(
                    (department) => DropdownMenuItem(
                      value: department.name,
                      child: Text(department.name),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _department = value ?? _department),
              ),
              const SizedBox(height: 10),
              if (controller.usesPersistentData) ...[
                TextFormField(
                  controller: _ward,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Target ward (optional)',
                    helperText:
                        'Use the exact ward name. Blank includes all wards.',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _division,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Target GN division (optional)',
                    helperText:
                        'Use the exact division name. Both filled targets must match.',
                  ),
                ),
              ] else
                TextFormField(
                  controller: _target,
                  decoration: const InputDecoration(
                    labelText: 'Geographic target',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Specify who should see this.'
                      : null,
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _publishNow,
                onChanged: (value) => setState(() => _publishNow = value),
                title: Text(
                  _publishNow ? 'Publish immediately' : 'Keep unpublished',
                ),
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  widget.existing == null
                      ? (_publishNow ? 'Publish announcement' : 'Save draft')
                      : 'Save announcement',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminDepartmentsPanel extends StatelessWidget {
  const AdminDepartmentsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final departments = AppScope.of(context).departments;
    return ResponsivePage(
      child: ListView(
        children: <Widget>[
          const PageHeader(
            icon: Icons.apartment_outlined,
            title: 'Department management',
            subtitle:
                'Maintain service ownership, heads, officers and complaint categories.',
          ),
          if (AppScope.of(context).canManageUsers)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _editDepartment(context, null),
                icon: const Icon(Icons.add),
                label: const Text('Create department'),
              ),
            ),
          const SizedBox(height: 16),
          ...departments.map(
            (department) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CivicCard(
                onTap: AppScope.of(context).canManageDepartments
                    ? () => _editDepartment(context, department)
                    : null,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.mint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.apartment_outlined,
                        color: AppColors.deepGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            department.name,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Head: ${department.headName} · ${department.officerCount} officers',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: department.categories
                                .map(
                                  (category) => Chip(
                                    label: Text(
                                      category,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        const Icon(
                          Icons.edit_outlined,
                          color: AppColors.deepGreen,
                        ),
                        if (AppScope.of(context).canManageUsers)
                          IconButton(
                            tooltip: 'Remove ${department.name}',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                _removeDepartment(context, department),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editDepartment(
    BuildContext context,
    Department? department,
  ) async {
    final requestId = 'd-${DateTime.now().microsecondsSinceEpoch}';
    final name = TextEditingController(text: department?.name ?? '');
    final head = TextEditingController(text: department?.headName ?? '');
    final officers = TextEditingController(
      text: '${department?.officerCount ?? 0}',
    );
    final categories = TextEditingController(
      text: department?.categories.join(', ') ?? '',
    );
    final route = ModalBottomSheetRoute<void>(
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: Navigator.of(context).context,
      ),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          22,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                department == null
                    ? 'Create department'
                    : 'Manage ${department.name}',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              if (department == null) ...[
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Department name',
                  ),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: head,
                decoration: const InputDecoration(labelText: 'Department head'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: officers,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Officer count'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: categories,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Categories handled (comma separated)',
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () async {
                  if (int.tryParse(officers.text.trim()) == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Enter a non-negative whole number of officers.',
                        ),
                      ),
                    );
                    return;
                  }
                  if (!await saveCivicAction(context, () {
                    final edited = Department(
                      id: department?.id ?? requestId,
                      name: department?.name ?? name.text.trim(),
                      headName: head.text.trim(),
                      officerCount: int.parse(officers.text.trim()),
                      categories: categories.text
                          .split(',')
                          .map((value) => value.trim())
                          .where((value) => value.isNotEmpty)
                          .toList(),
                    );
                    return department == null
                        ? AppScope.of(context).createDepartment(edited)
                        : AppScope.of(context).updateDepartment(edited);
                  })) {
                    return;
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                child: const Text('Save department'),
              ),
            ],
          ),
        ),
      ),
    );
    await Navigator.of(context).push(route);
    // The pop future resolves before the sheet's closing animation unmounts fields.
    await route.completed;
    name.dispose();
    head.dispose();
    officers.dispose();
    categories.dispose();
  }

  Future<void> _removeDepartment(
    BuildContext context,
    Department department,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${department.name}?'),
        content: const Text(
          'Only unused departments can be removed. Reports, projects and announcements must be reassigned first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (await saveCivicAction(
                    context,
                    () => AppScope.of(context).removeDepartment(department),
                  ) &&
                  context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Remove department'),
          ),
        ],
      ),
    );
  }
}

class AdminUsersPanel extends StatefulWidget {
  const AdminUsersPanel({super.key});

  @override
  State<AdminUsersPanel> createState() => _AdminUsersPanelState();
}

class _AdminUsersPanelState extends State<AdminUsersPanel> {
  final _search = TextEditingController();
  UserRole? _role;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final needle = _search.text.trim().toLowerCase();
    final users = controller.users
        .where(
          (user) =>
              (needle.isEmpty ||
                  '${user.fullName} ${user.email}'.toLowerCase().contains(
                    needle,
                  )) &&
              (_role == null || user.role == _role),
        )
        .toList();
    return ResponsivePage(
      child: ListView(
        children: <Widget>[
          const PageHeader(
            icon: Icons.group_outlined,
            title: 'User management',
            subtitle:
                'Review citizen and officer accounts. Passwords are never exposed in this console.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search name or email',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonHideUnderline(
            child: DropdownButton<UserRole?>(
              value: _role,
              hint: const Text('All roles'),
              items: <DropdownMenuItem<UserRole?>>[
                const DropdownMenuItem(value: null, child: Text('All roles')),
                ...UserRole.values
                    .where((role) => role != UserRole.guest)
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(role.label),
                      ),
                    ),
              ],
              onChanged: (value) => setState(() => _role = value),
            ),
          ),
          const SizedBox(height: 16),
          ...users.map(
            (user) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CivicCard(
                onTap:
                    controller.canManageUsers &&
                        user.id != controller.currentUser?.id &&
                        (controller.currentUser?.role ==
                                UserRole.platformAdmin ||
                            user.role != UserRole.platformAdmin)
                    ? () => _editUser(user)
                    : null,
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      backgroundColor: user.isActive
                          ? AppColors.mint
                          : const Color(0xFFECECEC),
                      child: Text(
                        user.fullName.isEmpty
                            ? '?'
                            : user.fullName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: user.isActive
                              ? AppColors.deepGreen
                              : AppColors.muted,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            user.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            user.email,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${user.role.label} · ${user.isActive ? 'Active' : 'Inactive'}',
                            style: TextStyle(
                              color: user.isActive
                                  ? AppColors.green
                                  : AppColors.danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editUser(AppUser user) async {
    var role = user.role;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              user.fullName,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(user.email, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setModalState) =>
                  DropdownButtonFormField<UserRole>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: UserRole.values
                        .where(
                          (item) =>
                              item != UserRole.guest &&
                              (item != UserRole.platformAdmin ||
                                  AppScope.of(context).currentUser?.role ==
                                      UserRole.platformAdmin),
                        )
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setModalState(() => role = value ?? role),
                  ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () async {
                if (!await saveCivicAction(
                  context,
                  () => AppScope.of(context).changeUserRole(user.id, role),
                )) {
                  return;
                }
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Update role'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                if (!await saveCivicAction(
                  context,
                  () => AppScope.of(context).toggleUserActive(user.id),
                )) {
                  return;
                }
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              icon: Icon(
                user.isActive
                    ? Icons.block_outlined
                    : Icons.check_circle_outline,
              ),
              label: Text(
                user.isActive ? 'Deactivate account' : 'Activate account',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminAnalyticsPanel extends StatelessWidget {
  const AdminAnalyticsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final reports = controller.reports;
    final resolved = reports
        .where((report) => report.status == ReportStatus.resolved)
        .length;
    final rate = reports.isEmpty
        ? 0
        : ((resolved / reports.length) * 100).round();
    final byCategory = <String, int>{};
    final byWard = <String, int>{};
    for (final report in reports) {
      byCategory[report.category] = (byCategory[report.category] ?? 0) + 1;
      final ward =
          RegExp(
            r'Ward\s+\d+',
            caseSensitive: false,
          ).firstMatch(report.locationLabel)?.group(0) ??
          'Other';
      byWard[ward] = (byWard[ward] ?? 0) + 1;
    }
    return ResponsivePage(
      child: ListView(
        children: <Widget>[
          const PageHeader(
            icon: Icons.insights_outlined,
            title: 'Authority analytics',
            subtitle:
                'Use transparent service metrics to identify local priorities and improve delivery.',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth >= 1000
                  ? 4
                  : constraints.maxWidth >= 580
                  ? 2
                  : 1;
              final width = (constraints.maxWidth - 12 * (count - 1)) / count;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  MetricTile(
                    label: 'Received',
                    value: '${reports.length}',
                    icon: Icons.inbox_outlined,
                    color: const Color(0xFF2C6EAA),
                  ),
                  MetricTile(
                    label: 'Resolved',
                    value: '$resolved',
                    icon: Icons.check_circle_outline,
                    color: AppColors.green,
                  ),
                  MetricTile(
                    label: 'Resolution rate',
                    value: '$rate%',
                    icon: Icons.trending_up_outlined,
                    color: AppColors.deepGreen,
                  ),
                  MetricTile(
                    label: 'Average resolution',
                    value:
                        '${controller.dashboardMetrics.averageResolutionDays} days',
                    icon: Icons.timer_outlined,
                    color: AppColors.warning,
                  ),
                ].map((tile) => SizedBox(width: width, child: tile)).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth >= 840
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: _BarChartCard(
                          title: 'Reports by category',
                          values: byCategory,
                          color: AppColors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _BarChartCard(
                          title: 'Reports by ward',
                          values: byWard,
                          color: const Color(0xFF805AD5),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: <Widget>[
                      _BarChartCard(
                        title: 'Reports by category',
                        values: byCategory,
                        color: AppColors.green,
                      ),
                      const SizedBox(height: 16),
                      _BarChartCard(
                        title: 'Reports by ward',
                        values: byWard,
                        color: const Color(0xFF805AD5),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          _BarChartCard(
            title: 'Project progress (%)',
            values: <String, int>{
              for (final project in controller.projects)
                project.title.length > 14
                        ? '${project.title.substring(0, 14)}…'
                        : project.title:
                    project.progress,
            },
            color: AppColors.warning,
          ),
          const SizedBox(height: 18),
          CivicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Public transparency note',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Budget totals are displayed only for projects marked public. Analytics should be shared at an aggregate level and must not expose private resident information.',
                  style: TextStyle(color: AppColors.muted, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
