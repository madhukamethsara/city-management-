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
    final panel = _panel();
    final main = Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            const AppLogo(compact: true),
            const SizedBox(width: 10),
            Text('Officer · ${_section.label}'),
          ],
        ),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/citizen',
              (route) => false,
            ),
            icon: const Icon(Icons.public_outlined),
            label: const Text('Citizen app'),
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
          : _AdminDrawer(selected: _section, onSelected: _select),
      body: panel,
    );
    if (!desktop) return main;
    return Scaffold(
      body: Row(
        children: <Widget>[
          SafeArea(
            child: NavigationRail(
              selectedIndex: AdminSection.values.indexOf(_section),
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
              onDestinationSelected: (index) =>
                  _select(AdminSection.values[index]),
              destinations: AdminSection.values
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
    AdminSection.overview => AdminOverviewPanel(onNavigate: _select),
    AdminSection.reports => const AdminReportsPanel(),
    AdminSection.projects => const AdminProjectsPanel(),
    AdminSection.announcements => const AdminAnnouncementsPanel(),
    AdminSection.departments => const AdminDepartmentsPanel(),
    AdminSection.users => const AdminUsersPanel(),
    AdminSection.analytics => const AdminAnalyticsPanel(),
  };
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({required this.selected, required this.onSelected});

  final AdminSection selected;
  final ValueChanged<AdminSection> onSelected;

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
            ...AdminSection.values.map(
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
            height: 160,
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
              (_department == null || report.department == _department),
        )
        .toList();
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
                        child: Text(department.name),
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
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
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
                            IconButton(
                              onPressed: () => _openEditor(report),
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Open case',
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
    if (mounted && image != null) setState(() => _completionPhoto = image);
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
              value: _department,
              decoration: const InputDecoration(labelText: 'Department'),
              items: controller.departments
                  .map(
                    (department) => DropdownMenuItem(
                      value: department.name,
                      child: Text(department.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _department = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
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
              value: _officer,
              decoration: const InputDecoration(labelText: 'Assigned officer'),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem(value: null, child: Text('Unassigned')),
                ...officers.map(
                  (officer) => DropdownMenuItem(
                    value: officer.fullName,
                    child: Text(officer.fullName),
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
                        await controller.updateReportStatus(
                          reportId: widget.report.id,
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
                              : <String>[_completionPhoto!.name],
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not save the case update. Please try again.',
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
  final _budget = TextEditingController();
  final _contractor = TextEditingController();
  final _update = TextEditingController();
  final _milestone = TextEditingController();
  final _document = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _images = <XFile>[];
  late ProjectStatus _status;
  late String _department;
  late int _progress;
  late bool _budgetPublic;

  @override
  void initState() {
    super.initState();
    final project = widget.project;
    _title.text = project?.title ?? '';
    _description.text = project?.description ?? '';
    _category.text = project?.category ?? 'Public infrastructure';
    _location.text = project?.locationLabel ?? '';
    _budget.text = '${project?.budget ?? 0}';
    _contractor.text = project?.contractor ?? '';
    _status = project?.status ?? ProjectStatus.proposed;
    _department = project?.department ?? 'Engineering';
    _progress = project?.progress ?? 0;
    _budgetPublic = project?.isBudgetPublic ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _category.dispose();
    _location.dispose();
    _budget.dispose();
    _contractor.dispose();
    _update.dispose();
    _milestone.dispose();
    _document.dispose();
    super.dispose();
  }

  Future<void> _addImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 80);
    if (mounted && images.isNotEmpty) setState(() => _images.addAll(images));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = AppScope.of(context);
    final now = DateTime.now();
    final budget = int.tryParse(_budget.text.replaceAll(',', '')) ?? 0;
    final document = _document.text.trim().isEmpty
        ? const <PublicDocument>[]
        : <PublicDocument>[
            PublicDocument(
              name: _document.text.trim(),
              kind: 'PDF',
              sizeLabel: 'Awaiting upload',
            ),
          ];
    final milestone = _milestone.text.trim().isEmpty
        ? const <ProjectMilestone>[]
        : <ProjectMilestone>[
            ProjectMilestone(
              title: _milestone.text.trim(),
              description: 'Milestone added by the authority.',
              percentage: _progress,
              expectedDate: now.add(const Duration(days: 30)),
              completedDate: null,
              isComplete: false,
            ),
          ];
    final update = _update.text.trim().isEmpty
        ? const <ProjectUpdate>[]
        : <ProjectUpdate>[
            ProjectUpdate(
              title: 'Project update',
              message: _update.text.trim(),
              date: now,
              isPublic: true,
            ),
          ];
    if (widget.project == null) {
      final created = controller.buildProject(
        ProjectDraft(
          title: _title.text.trim(),
          description: _description.text.trim(),
          category: _category.text.trim(),
          locationLabel: _location.text.trim(),
          status: _status,
          progress: _progress,
          budget: budget,
          department: _department,
        ),
      );
      if (!await saveCivicAction(
        context,
        () => controller.saveProject(
          created.copyWith(
            contractor: _contractor.text.trim(),
            isBudgetPublic: _budgetPublic,
            documents: document,
            milestones: milestone,
            updates: <ProjectUpdate>[...created.updates, ...update],
            imageLabels: _images.map((image) => image.name).toList(),
          ),
        ),
      )) {
        return;
      }
      if (!mounted) return;
    } else {
      final project = widget.project!;
      if (!await saveCivicAction(
        context,
        () => controller.saveProject(
          project.copyWith(
            title: _title.text.trim(),
            description: _description.text.trim(),
            category: _category.text.trim(),
            locationLabel: _location.text.trim(),
            status: _status,
            progress: _progress,
            department: _department,
            budget: budget,
            isBudgetPublic: _budgetPublic,
            contractor: _contractor.text.trim(),
            documents: <PublicDocument>[...project.documents, ...document],
            milestones: <ProjectMilestone>[...project.milestones, ...milestone],
            updates: <ProjectUpdate>[...project.updates, ...update],
            imageLabels: <String>[
              ...project.imageLabels,
              ..._images.map((image) => image.name),
            ],
          ),
        ),
      )) {
        return;
      }
      if (!mounted) return;
    }
    Navigator.pop(context);
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
                validator: (value) => value == null || value.trim().length < 8
                    ? 'Enter a project title.'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _description,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Public description',
                ),
                validator: (value) => value == null || value.trim().length < 20
                    ? 'Add a public description.'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _category,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Location label'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Add a project location.'
                    : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<ProjectStatus>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Project status'),
                items: ProjectStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _status = value ?? _status),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _department,
                decoration: const InputDecoration(
                  labelText: 'Responsible department',
                ),
                items: controller.departments
                    .map(
                      (department) => DropdownMenuItem(
                        value: department.name,
                        child: Text(department.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _department = value ?? _department),
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
                divisions: 20,
                label: '$_progress%',
                onChanged: (value) => setState(() => _progress = value.round()),
              ),
              TextFormField(
                controller: _budget,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Allocated budget (LKR)',
                ),
                validator: (value) =>
                    int.tryParse((value ?? '').replaceAll(',', '')) == null
                    ? 'Enter an amount in LKR.'
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Display budget publicly'),
                value: _budgetPublic,
                onChanged: (value) => setState(() => _budgetPublic = value),
              ),
              TextField(
                controller: _contractor,
                decoration: const InputDecoration(
                  labelText: 'Contractor (optional)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _update,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Public progress update (optional)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _milestone,
                decoration: const InputDecoration(
                  labelText: 'Add milestone (optional)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _document,
                decoration: const InputDecoration(
                  labelText: 'Public document name (optional)',
                ),
              ),
              const SizedBox(height: 10),
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
                onPressed: _save,
                child: Text(
                  widget.project == null
                      ? 'Create project'
                      : 'Save project changes',
                ),
              ),
            ],
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
                'Draft, schedule, publish and archive authority notices with geographic targeting.',
            action: FilledButton.icon(
              onPressed: () => _openComposer(context),
              icon: const Icon(Icons.add),
              label: const Text('New announcement'),
            ),
          ),
          const SizedBox(height: 18),
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
                                : 'Draft / scheduled',
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
                            child: Text('Archive'),
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
    _type = announcement?.type ?? AnnouncementType.normal;
    _department = announcement?.department ?? 'Administration';
    _publishNow = announcement?.isPublished ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = AppScope.of(context);
    if (widget.existing == null) {
      if (!await saveCivicAction(
        context,
        () => controller.createAnnouncement(
          AnnouncementDraft(
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
                minLines: 4,
                maxLines: 7,
                decoration: const InputDecoration(labelText: 'Public message'),
                validator: (value) => value == null || value.trim().length < 20
                    ? 'Add a public message.'
                    : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<AnnouncementType>(
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
                  _publishNow
                      ? 'Publish immediately'
                      : 'Keep as draft / schedule later',
                ),
              ),
              FilledButton(
                onPressed: _save,
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
          const SizedBox(height: 16),
          ...departments.map(
            (department) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CivicCard(
                onTap: () => _editDepartment(context, department),
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
                    const Icon(Icons.edit_outlined, color: AppColors.deepGreen),
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
    Department department,
  ) async {
    final head = TextEditingController(text: department.headName);
    final officers = TextEditingController(text: '${department.officerCount}');
    final categories = TextEditingController(
      text: department.categories.join(', '),
    );
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
            Text(
              'Manage ${department.name}',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
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
                if (!await saveCivicAction(
                  context,
                  () => AppScope.of(context).updateDepartment(
                    department.copyWith(
                      headName: head.text.trim(),
                      officerCount:
                          int.tryParse(officers.text) ??
                          department.officerCount,
                      categories: categories.text
                          .split(',')
                          .map((value) => value.trim())
                          .where((value) => value.isNotEmpty)
                          .toList(),
                    ),
                  ),
                )) {
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
    );
    head.dispose();
    officers.dispose();
    categories.dispose();
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
                onTap: () => _editUser(user),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      backgroundColor: user.isActive
                          ? AppColors.mint
                          : const Color(0xFFECECEC),
                      child: Text(
                        user.fullName.substring(0, 1).toUpperCase(),
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
                        .where((item) => item != UserRole.guest)
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
      final ward = report.locationLabel.contains('Ward 02')
          ? 'Ward 02'
          : report.locationLabel.contains('Ward 04')
          ? 'Ward 04'
          : 'Other';
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
              final count = constraints.maxWidth >= 800 ? 4 : 2;
              return GridView.count(
                crossAxisCount: count,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: count == 4 ? 1.4 : 1.15,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
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
                ],
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
