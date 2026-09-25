import '../../widgets/save_civic_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../models/domain_models.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/civic_map.dart';

class ProjectExplorerScreen extends StatefulWidget {
  const ProjectExplorerScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ProjectExplorerScreen> createState() => _ProjectExplorerScreenState();
}

class _ProjectExplorerScreenState extends State<ProjectExplorerScreen> {
  final _searchController = TextEditingController();
  ProjectStatus? _status;
  String _sort = 'Latest';
  bool _grid = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Project> _filteredProjects(List<Project> projects) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = projects.where((project) {
      final matchesQuery =
          query.isEmpty ||
          '${project.title} ${project.description} ${project.category} ${project.locationLabel}'
              .toLowerCase()
              .contains(query);
      return matchesQuery && (_status == null || project.status == _status);
    }).toList();
    switch (_sort) {
      case 'A–Z':
        filtered.sort((a, b) => a.title.compareTo(b.title));
      case 'Most progress':
        filtered.sort((a, b) => b.progress.compareTo(a.progress));
      case 'Completion date':
        filtered.sort(
          (a, b) => a.expectedCompletion.compareTo(b.expectedCompletion),
        );
      default:
        filtered.sort((a, b) => b.startDate.compareTo(a.startDate));
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final projects = _filteredProjects(controller.projects);
    final page = ResponsivePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeader(
            icon: Icons.account_tree_outlined,
            title: 'Public projects',
            subtitle:
                'See what is planned, in progress and completed in ${controller.authorityName}.',
            action: IconButton(
              onPressed: () => Navigator.pushNamed(context, '/map'),
              icon: const Icon(Icons.map_outlined),
              tooltip: 'Open project map',
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search projects by title, category or location',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              DropdownButtonHideUnderline(
                child: DropdownButton<ProjectStatus?>(
                  value: _status,
                  hint: const Text('All statuses'),
                  items: <DropdownMenuItem<ProjectStatus?>>[
                    const DropdownMenuItem<ProjectStatus?>(
                      value: null,
                      child: Text('All statuses'),
                    ),
                    ...ProjectStatus.values.map(
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
                child: DropdownButton<String>(
                  value: _sort,
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'Latest', child: Text('Latest')),
                    DropdownMenuItem(value: 'A–Z', child: Text('A–Z')),
                    DropdownMenuItem(
                      value: 'Most progress',
                      child: Text('Most progress'),
                    ),
                    DropdownMenuItem(
                      value: 'Completion date',
                      child: Text('Completion date'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _sort = value ?? _sort),
                ),
              ),
              Tooltip(
                message: _grid ? 'Switch to list' : 'Switch to grid',
                child: IconButton(
                  onPressed: () => setState(() => _grid = !_grid),
                  icon: Icon(
                    _grid ? Icons.view_list_outlined : Icons.grid_view_outlined,
                  ),
                ),
              ),
              Text(
                '${projects.length} projects',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: projects.isEmpty
                ? const EmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'No matching projects',
                    message:
                        'Adjust your filters or search term to find public projects.',
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (!_grid) {
                        return ListView.separated(
                          itemCount: projects.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => ProjectCard(
                            project: projects[index],
                            compact: true,
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/projects/${projects[index].id}',
                            ),
                          ),
                        );
                      }
                      final count = constraints.maxWidth >= 1000
                          ? 3
                          : constraints.maxWidth >= 600
                          ? 2
                          : 1;
                      return GridView.builder(
                        itemCount: projects.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: count,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: count == 1 ? 1.52 : 0.67,
                        ),
                        itemBuilder: (context, index) => ProjectCard(
                          project: projects[index],
                          compact: false,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/projects/${projects[index].id}',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
    return widget.embedded
        ? page
        : Scaffold(
            appBar: AppBar(title: const Text('Projects')),
            body: page,
          );
  }
}

class PublicMapScreen extends StatefulWidget {
  const PublicMapScreen({super.key});

  @override
  State<PublicMapScreen> createState() => _PublicMapScreenState();
}

class _PublicMapScreenState extends State<PublicMapScreen> {
  bool _projects = true;
  bool _reports = true;
  ProjectStatus? _status;
  late GeoPoint _center;
  bool _centered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_centered) return;
    final controller = AppScope.of(context);
    _center =
        controller.currentUser?.residentialArea ??
        controller.selectedAuthority?.center ??
        const GeoPoint(7.4864, 80.3642);
    _centered = true;
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final markers = <CivicMapMarker>[
      if (_projects)
        ...controller.projects
            .where((project) => _status == null || project.status == _status)
            .map(
              (project) => CivicMapMarker(
                id: project.id,
                title: project.title,
                subtitle: '${project.status.label} · ${project.progress}%',
                point: project.location,
                type: CivicMapMarkerType.project,
                color: project.status.color,
                onTap: () => _showProjectPreview(project),
              ),
            ),
      if (_reports)
        ...controller.reports.map(
          (report) => CivicMapMarker(
            id: report.id,
            title: report.title,
            subtitle: '${report.status.label} · ${report.category}',
            point: report.location,
            type: CivicMapMarkerType.report,
            color: report.status.color,
            onTap: () => _showReportPreview(report),
          ),
        ),
      CivicMapMarker(
        id: 'facility-office',
        title: controller.authorityName,
        subtitle: 'Local authority office',
        point: controller.selectedAuthority?.center ?? _center,
        type: CivicMapMarkerType.facility,
        color: AppColors.deepGreen,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Projects & issues map')),
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const PageHeader(
              icon: Icons.map_outlined,
              title: 'Your local map',
              subtitle:
                  'View public projects, citizen issue updates and authority facilities.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilterChip(
                  label: const Text('Projects'),
                  selected: _projects,
                  onSelected: (selected) =>
                      setState(() => _projects = selected),
                ),
                FilterChip(
                  label: const Text('Issue updates'),
                  selected: _reports,
                  onSelected: (selected) => setState(() => _reports = selected),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<ProjectStatus?>(
                    value: _status,
                    hint: const Text('All project statuses'),
                    items: <DropdownMenuItem<ProjectStatus?>>[
                      const DropdownMenuItem<ProjectStatus?>(
                        value: null,
                        child: Text('All project statuses'),
                      ),
                      ...ProjectStatus.values.map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _status = value),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(
                      () => _center =
                          controller.currentUser?.residentialArea ??
                          controller.selectedAuthority?.center ??
                          _center,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Map centred on your approximate service area.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.my_location_outlined),
                  label: const Text('My area'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: CivicMap(
                key: ValueKey(_center.shortLabel),
                center: _center,
                markers: markers,
                height: 520,
                zoom: 13,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Markers show approximate public project and report locations. Private residential coordinates are never displayed.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showProjectPreview(Project project) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ProjectStatusBadge(status: project.status),
            const SizedBox(height: 10),
            Text(
              project.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              '${project.category} · ${project.locationLabel}',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: project.progress / 100,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 4),
            Text(
              '${project.progress}% complete',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/projects/${project.id}');
              },
              child: const Text('View project details'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportPreview(CivicReport report) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ReportStatusBadge(status: report.status),
            const SizedBox(height: 10),
            Text(
              report.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              '${report.category} · ${report.locationLabel}',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            FilledButton.tonal(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/reports/${report.id}');
              },
              child: const Text('View issue update'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final _commentController = TextEditingController();
  final _comments = <CivicComment>[];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final project = controller.projectById(widget.projectId);
    if (project == null) {
      return const NotFoundScreen(
        message: 'This project may have been removed or is not public.',
      );
    }
    final userId = controller.currentUser?.id;
    final following = userId != null && project.followerIds.contains(userId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project details'),
        actions: <Widget>[
          IconButton(
            onPressed: () => _share(context, project),
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: 'Share project',
          ),
        ],
      ),
      body: ResponsivePage(
        child: ListView(
          children: <Widget>[
            ProjectArtwork(project: project, height: 210),
            if (project.imageLabels.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              SizedBox(
                height: 78,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: project.imageLabels.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => Container(
                    width: 150,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.image_outlined,
                          color: AppColors.deepGreen,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            project.imageLabels[index],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ProjectStatusBadge(status: project.status),
                      const SizedBox(height: 10),
                      Text(
                        project.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${project.category} · ${project.locationLabel}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: () async {
                    if (!controller.canParticipate) {
                      return showSignInPrompt(
                        context,
                        message:
                            'Sign in to follow a project and receive its updates.',
                      );
                    }
                    if (!await saveCivicAction(
                      context,
                      () => controller.toggleProjectFollow(project.id),
                    )) {
                      return;
                    }
                    if (!context.mounted) return;
                  },
                  icon: Icon(
                    following
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_none_outlined,
                  ),
                  tooltip: following ? 'Unfollow project' : 'Follow project',
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              project.description,
              style: const TextStyle(color: AppColors.muted, height: 1.55),
            ),
            const SizedBox(height: 22),
            _ProjectProgress(project: project),
            const SizedBox(height: 22),
            const SectionTitle(title: 'Project location'),
            const SizedBox(height: 10),
            CivicMap(
              center: project.location,
              height: 255,
              zoom: 14,
              markers: <CivicMapMarker>[
                CivicMapMarker(
                  id: project.id,
                  title: project.title,
                  subtitle: project.status.label,
                  point: project.location,
                  type: CivicMapMarkerType.project,
                  color: project.status.color,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              project.locationLabel,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            _ProjectFacts(project: project),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Milestones'),
            const SizedBox(height: 12),
            _MilestoneTimeline(milestones: project.milestones),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Public updates'),
            const SizedBox(height: 12),
            ...project.updates
                .where((update) => update.isPublic)
                .map((update) => _ProjectUpdateCard(update: update)),
            const SizedBox(height: 18),
            const SectionTitle(title: 'Public documents'),
            const SizedBox(height: 10),
            if (project.documents.isEmpty)
              const Text(
                'No public documents have been added yet.',
                style: TextStyle(color: AppColors.muted),
              )
            else
              ...project.documents.map(
                (document) => CivicCard(
                  onTap: () => _copyDocumentName(context, document.name),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.picture_as_pdf_outlined,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              document.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${document.kind} · ${document.sizeLabel}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.download_outlined,
                        color: AppColors.deepGreen,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Citizen feedback'),
            const SizedBox(height: 10),
            _CommentComposer(
              controller: _commentController,
              onSend: () {
                if (!controller.canParticipate) {
                  showSignInPrompt(context);
                  return;
                }
                if (_commentController.text.trim().isEmpty) return;
                setState(() {
                  _comments.add(
                    CivicComment(
                      id: 'comment-${DateTime.now().microsecondsSinceEpoch}',
                      author: controller.currentUser!.isVerified
                          ? 'Verified Resident · ${controller.currentUser!.ward}'
                          : 'Resident',
                      message: _commentController.text.trim(),
                      createdAt: DateTime.now(),
                      isVerified: controller.currentUser!.isVerified,
                    ),
                  );
                  _commentController.clear();
                });
              },
            ),
            const SizedBox(height: 12),
            if (_comments.isEmpty)
              const Text(
                'Be the first to add respectful, project-related feedback.',
                style: TextStyle(color: AppColors.muted),
              )
            else
              ..._comments.map((comment) => _CommentCard(comment: comment)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, Project project) async {
    await Clipboard.setData(
      ClipboardData(text: 'Smart Sabha project: ${project.title}'),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project link copied to clipboard.')),
      );
    }
  }

  Future<void> _copyDocumentName(BuildContext context, String name) async {
    await Clipboard.setData(ClipboardData(text: name));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$name is ready to download when the document service is connected.',
          ),
        ),
      );
    }
  }
}

class _ProjectProgress extends StatelessWidget {
  const _ProjectProgress({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return CivicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Current progress',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${project.progress}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.deepGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: project.progress / 100,
              minHeight: 11,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: <Widget>[
              _Fact(
                icon: Icons.play_circle_outline,
                label: 'Started',
                value: formatDate(project.startDate, includeYear: true),
              ),
              _Fact(
                icon: Icons.event_available_outlined,
                label: 'Expected completion',
                value: formatDate(
                  project.expectedCompletion,
                  includeYear: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectFacts extends StatelessWidget {
  const _ProjectFacts({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final facts = <_Fact>[
      _Fact(
        icon: Icons.business_outlined,
        label: 'Responsible department',
        value: project.department,
      ),
      if (project.projectManager != null)
        _Fact(
          icon: Icons.person_outline,
          label: 'Project manager',
          value: project.projectManager!,
        ),
      if (project.contractor != null)
        _Fact(
          icon: Icons.engineering_outlined,
          label: 'Contractor',
          value: project.contractor!,
        ),
      if (project.isBudgetPublic)
        _Fact(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Allocated budget',
          value: formatLkr(project.budget),
        ),
      if (project.isBudgetPublic)
        _Fact(
          icon: Icons.payments_outlined,
          label: 'Spent',
          value: formatLkr(project.spent),
        ),
      if (project.isBudgetPublic)
        _Fact(
          icon: Icons.savings_outlined,
          label: 'Remaining',
          value: formatLkr(project.remaining),
        ),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: facts
          .map((fact) => SizedBox(width: 250, child: CivicCard(child: fact)))
          .toList(),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: AppColors.deepGreen, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MilestoneTimeline extends StatelessWidget {
  const _MilestoneTimeline({required this.milestones});

  final List<ProjectMilestone> milestones;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: milestones
          .map(
            (milestone) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    Icon(
                      milestone.isComplete
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: milestone.isComplete
                          ? AppColors.green
                          : AppColors.muted,
                    ),
                    Container(
                      width: 2,
                      height: 58,
                      color: const Color(0xFFDCE6E2),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                milestone.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              '${milestone.percentage}%',
                              style: const TextStyle(
                                color: AppColors.deepGreen,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          milestone.description,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          milestone.isComplete &&
                                  milestone.completedDate != null
                              ? 'Completed ${formatDate(milestone.completedDate!)}'
                              : 'Expected ${formatDate(milestone.expectedDate)}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _ProjectUpdateCard extends StatelessWidget {
  const _ProjectUpdateCard({required this.update});

  final ProjectUpdate update;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CivicCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              update.title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              update.message,
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              formatDate(update.date, includeYear: true),
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: 'Add a respectful public comment',
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: onSend,
          icon: const Icon(Icons.send_outlined),
          tooltip: 'Post comment',
        ),
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment});

  final CivicComment comment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CivicCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    comment.author,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (comment.isVerified)
                  const Icon(
                    Icons.verified_outlined,
                    size: 17,
                    color: AppColors.green,
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(comment.message),
            const SizedBox(height: 6),
            Text(
              relativeTime(comment.createdAt),
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
