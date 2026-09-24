import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../models/domain_models.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/civic_map.dart';

const _reportCategories = <String>[
  'Road Damage',
  'Street Light',
  'Garbage',
  'Drainage',
  'Dangerous Tree',
  'Public Property Damage',
  'Environmental Issue',
  'Water Issue',
  'Public Health',
  'Noise/Public Nuisance',
  'Other',
];

class ReportWizardScreen extends StatefulWidget {
  const ReportWizardScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ReportWizardScreen> createState() => _ReportWizardScreenState();
}

class _ReportWizardScreenState extends State<ReportWizardScreen> {
  final _detailsKey = GlobalKey<FormState>();
  final _locationKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _locationLabel = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _photos = <XFile>[];
  String _category = 'Road Damage';
  String _urgency = 'Normal';
  GeoPoint? _location;
  int _step = 0;
  bool _submitting = false;
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    final controller = AppScope.of(context);
    _location =
        controller.currentUser?.residentialArea ??
        controller.selectedAuthority?.center ??
        const GeoPoint(7.4864, 80.3642);
    _locationLabel.text =
        '${controller.currentUser?.ward ?? 'Ward 04'} · ${controller.authorityName}';
    _initialised = true;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _locationLabel.dispose();
    super.dispose();
  }

  List<CivicReport> get _similarReports {
    if (_location == null) return const <CivicReport>[];
    return AppScope.of(
      context,
    ).findSimilarReports(category: _category, location: _location!);
  }

  Future<void> _pickPhoto() async {
    final files = await _picker.pickMultiImage(imageQuality: 80);
    if (!mounted || files.isEmpty) return;
    setState(() => _photos.addAll(files));
  }

  Future<void> _continue() async {
    if (_step == 0 && !_detailsKey.currentState!.validate()) return;
    if (_step == 1 &&
        (!_locationKey.currentState!.validate() || _location == null)) {
      return;
    }
    if (_step < 3) {
      setState(() => _step += 1);
      return;
    }
    final controller = AppScope.of(context);
    if (!controller.canParticipate) {
      return showSignInPrompt(
        context,
        message: 'Sign in to submit and track a local issue.',
      );
    }
    setState(() => _submitting = true);
    try {
      final report = await controller.submitReport(
        ReportDraft(
          category: _category,
          title: _title.text.trim(),
          description: _description.text.trim(),
          locationLabel: _locationLabel.text.trim(),
          location: _location!,
          urgency: _urgency,
          attachmentNames: _photos.map((file) => file.name).toList(),
        ),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline,
            color: AppColors.green,
            size: 44,
          ),
          title: const Text('Report submitted'),
          content: Text(
            'Your case number is ${report.caseNumber}. You can track its status and receive updates in Smart Sabha.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              },
              child: const Text('Home'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/reports/${report.id}',
                  (route) => false,
                );
              },
              child: const Text('Track report'),
            ),
          ],
        ),
      );
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _back() {
    if (_step == 0) {
      if (!widget.embedded) Navigator.pop(context);
      return;
    }
    setState(() => _step -= 1);
  }

  @override
  Widget build(BuildContext context) {
    final content = ResponsivePage(
      child: Column(
        children: <Widget>[
          _WizardProgress(
            step: _step,
            labels: const <String>['Details', 'Location', 'Media', 'Review'],
          ),
          const SizedBox(height: 20),
          Expanded(child: _buildStep()),
          const SizedBox(height: 14),
          SafeArea(
            top: false,
            child: Row(
              children: <Widget>[
                if (_step > 0) ...<Widget>[
                  OutlinedButton(
                    onPressed: _submitting ? null : _back,
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _continue,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(_step == 3 ? 'Submit report' : 'Continue'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return widget.embedded
        ? content
        : Scaffold(
            appBar: AppBar(title: const Text('Report a problem')),
            body: content,
          );
  }

  Widget _buildStep() => switch (_step) {
    0 => _detailsStep(),
    1 => _locationStep(),
    2 => _mediaStep(),
    _ => _reviewStep(),
  };

  Widget _detailsStep() {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Form(
          key: _detailsKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const PageHeader(
                icon: Icons.report_problem_outlined,
                title: 'What happened?',
                subtitle:
                    'Describe a local issue clearly so the right department can act.',
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Issue category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _reportCategories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Short title',
                  hintText: 'Example: Drain blocked near market entrance',
                ),
                validator: (value) => value == null || value.trim().length < 6
                    ? 'Write a short, clear title.'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                minLines: 4,
                maxLines: 7,
                maxLength: 900,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText:
                      'What can residents or officers observe? Is there a safety concern?',
                ),
                validator: (value) => value == null || value.trim().length < 15
                    ? 'Add a little more detail.'
                    : null,
              ),
              const SizedBox(height: 14),
              const Text(
                'Urgency',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: <String>['Normal', 'High', 'Urgent']
                    .map(
                      (value) => ChoiceChip(
                        label: Text(value),
                        selected: _urgency == value,
                        selectedColor: value == 'Urgent'
                            ? AppColors.danger.withValues(alpha: 0.18)
                            : null,
                        onSelected: (_) => setState(() => _urgency = value),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              const CivicCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.privacy_tip_outlined,
                      color: AppColors.deepGreen,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your personal contact details stay private. Public issue updates show only the information allowed by your profile settings.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationStep() {
    final controller = AppScope.of(context);
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: Form(
          key: _locationKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const PageHeader(
                icon: Icons.pin_drop_outlined,
                title: 'Where is the issue?',
                subtitle:
                    'Tap the map at the issue location. We use this to route it and check for nearby reports.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationLabel,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Location description',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (value) => value == null || value.trim().length < 4
                    ? 'Enter a useful location description.'
                    : null,
              ),
              const SizedBox(height: 14),
              CivicMap(
                center:
                    _location ??
                    controller.selectedAuthority?.center ??
                    const GeoPoint(7.4864, 80.3642),
                selectedPoint: _location,
                height: 370,
                onTap: (point) => setState(() => _location = point),
              ),
              const SizedBox(height: 10),
              CivicCard(
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.location_searching_outlined,
                      color: AppColors.deepGreen,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _location == null
                            ? 'Tap a point on the map to select an issue location.'
                            : 'Selected issue location: ${_location!.shortLabel}',
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(
                        () => _location = controller.selectedAuthority?.center,
                      ),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaStep() {
    final nearby = _similarReports;
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const PageHeader(
              icon: Icons.add_photo_alternate_outlined,
              title: 'Add evidence',
              subtitle:
                  'Photos help officers understand the issue. You can continue without a photo.',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose photos'),
            ),
            if (_photos.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _photos
                    .asMap()
                    .entries
                    .map(
                      (entry) => InputChip(
                        label: Text(
                          entry.value.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onDeleted: () =>
                            setState(() => _photos.removeAt(entry.key)),
                        avatar: const Icon(Icons.image_outlined, size: 17),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 24),
            if (nearby.isNotEmpty) ...<Widget>[
              const Text(
                'Similar issues were reported nearby',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 6),
              const Text(
                'Following an existing report helps keep updates in one place. You can still submit your own report if this is a different issue.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              ...nearby.map(
                (report) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CivicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                report.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            ReportStatusBadge(status: report.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${report.caseNumber} · ${report.locationLabel}',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final controller = AppScope.of(context);
                            if (!controller.canParticipate) {
                              return showSignInPrompt(context);
                            }
                            controller.toggleReportFollow(report.id);
                            Navigator.pushNamed(
                              context,
                              '/reports/${report.id}',
                            );
                          },
                          icon: const Icon(Icons.notifications_none_outlined),
                          label: const Text('Follow existing report'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else
              CivicCard(
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.check_circle_outline, color: AppColors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No similar issue reports were found close to this selected location.',
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

  Widget _reviewStep() {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const PageHeader(
              icon: Icons.fact_check_outlined,
              title: 'Review your report',
              subtitle:
                  'Please check that the details below accurately describe the issue.',
            ),
            const SizedBox(height: 16),
            CivicCard(
              child: Column(
                children: <Widget>[
                  _ReviewLine(label: 'Category', value: _category),
                  _ReviewLine(label: 'Title', value: _title.text),
                  _ReviewLine(label: 'Urgency', value: _urgency),
                  _ReviewLine(label: 'Location', value: _locationLabel.text),
                  _ReviewLine(
                    label: 'Photos',
                    value: _photos.isEmpty
                        ? 'No photos added'
                        : '${_photos.length} photo(s) attached',
                  ),
                  _ReviewLine(
                    label: 'Responsible department',
                    value: _departmentForCategory(_category),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CivicCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.shield_outlined, color: AppColors.deepGreen),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'When you submit, Smart Sabha securely attaches your account, selected authority, ward and timestamp. It does not publish your exact home coordinates.',
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

  String _departmentForCategory(String category) {
    for (final department in AppScope.of(context).departments) {
      if (department.categories.contains(category)) return department.name;
    }
    return 'Administration';
  }
}

class _WizardProgress extends StatelessWidget {
  const _WizardProgress({required this.step, required this.labels});

  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        LinearProgressIndicator(
          value: (step + 1) / labels.length,
          minHeight: 7,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List<Widget>.generate(
            labels.length,
            (index) => Text(
              labels[index],
              style: TextStyle(
                fontSize: 12,
                color: index <= step ? AppColors.deepGreen : AppColors.muted,
                fontWeight: index == step ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  ReportStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final reports = controller.myReports
        .where((report) => _filter == null || report.status == _filter)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('My reports')),
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PageHeader(
              icon: Icons.assignment_outlined,
              title: controller.isOfficer
                  ? 'Complaint management'
                  : 'Your submitted reports',
              subtitle: controller.isOfficer
                  ? 'View reported issues assigned across the local authority.'
                  : 'Track each case, see updates and confirm whether work is complete.',
              action: controller.canParticipate && !controller.isOfficer
                  ? FilledButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/report'),
                      icon: const Icon(Icons.add),
                      label: const Text('New report'),
                    )
                  : null,
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                  const SizedBox(width: 8),
                  ...ReportStatus.values.map(
                    (status) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(status.label),
                        selected: _filter == status,
                        onSelected: (_) => setState(() => _filter = status),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: reports.isEmpty
                  ? const EmptyState(
                      icon: Icons.assignment_late_outlined,
                      title: 'No reports in this view',
                      message:
                          'Try a different status filter or submit a new issue report.',
                    )
                  : ListView.separated(
                      itemCount: reports.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => ReportCard(
                        report: reports[index],
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/reports/${reports[index].id}',
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final _comment = TextEditingController();
  final List<CivicComment> _comments = <CivicComment>[];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final report = controller.reportById(widget.reportId);
    if (report == null) {
      return const NotFoundScreen(message: 'This report could not be found.');
    }
    final userId = controller.currentUser?.id;
    final following = userId != null && report.followerIds.contains(userId);
    return Scaffold(
      appBar: AppBar(title: Text(report.caseNumber)),
      body: ResponsivePage(
        child: ListView(
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ReportStatusBadge(status: report.status),
                      const SizedBox(height: 10),
                      Text(
                        report.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${report.category} · ${report.locationLabel}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () async {
                    if (!controller.canParticipate) {
                      return showSignInPrompt(context);
                    }
                    controller.toggleReportFollow(report.id);
                  },
                  icon: Icon(
                    following
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_none_outlined,
                  ),
                  tooltip: following ? 'Unfollow report' : 'Follow report',
                ),
              ],
            ),
            const SizedBox(height: 18),
            CivicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Report details',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    report.description,
                    style: const TextStyle(color: AppColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 18,
                    runSpacing: 9,
                    children: <Widget>[
                      _Detail(
                        icon: Icons.category_outlined,
                        label: 'Category',
                        value: report.category,
                      ),
                      _Detail(
                        icon: Icons.business_outlined,
                        label: 'Department',
                        value: report.department,
                      ),
                      _Detail(
                        icon: Icons.priority_high_outlined,
                        label: 'Priority',
                        value: report.priority,
                      ),
                      _Detail(
                        icon: Icons.schedule_outlined,
                        label: 'Submitted',
                        value: formatDate(
                          report.submittedAt,
                          includeYear: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SectionTitle(title: 'Issue location'),
            const SizedBox(height: 10),
            CivicMap(
              center: report.location,
              height: 245,
              zoom: 14,
              markers: <CivicMapMarker>[
                CivicMapMarker(
                  id: report.id,
                  title: report.title,
                  subtitle: report.status.label,
                  point: report.location,
                  type: CivicMapMarkerType.report,
                  color: report.status.color,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const SectionTitle(title: 'Case timeline'),
            const SizedBox(height: 8),
            _ReportTimeline(report: report),
            const SizedBox(height: 20),
            const SectionTitle(title: 'Photos and evidence'),
            const SizedBox(height: 10),
            if (report.attachments.isEmpty)
              const Text(
                'No public photos were attached to this report.',
                style: TextStyle(color: AppColors.muted),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: report.attachments
                    .map((file) => _AttachmentChip(name: file))
                    .toList(),
              ),
            if (report.status == ReportStatus.resolved) ...<Widget>[
              const SizedBox(height: 22),
              _ResolutionConfirmation(reportId: report.id),
            ],
            const SizedBox(height: 22),
            const SectionTitle(title: 'Comments'),
            const SizedBox(height: 10),
            _CommentComposer(
              controller: _comment,
              onSend: () {
                if (!controller.canParticipate) {
                  showSignInPrompt(context);
                  return;
                }
                if (_comment.text.trim().isEmpty) return;
                setState(() {
                  _comments.add(
                    CivicComment(
                      id: 'rc-${DateTime.now().microsecondsSinceEpoch}',
                      author: controller.currentUser!.isVerified
                          ? 'Verified Resident · ${controller.currentUser!.ward}'
                          : 'Resident',
                      message: _comment.text.trim(),
                      createdAt: DateTime.now(),
                      isVerified: controller.currentUser!.isVerified,
                    ),
                  );
                  _comment.clear();
                });
              },
            ),
            if (_comments.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Ask a question or add relevant public information about this issue.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            ..._comments.map(
              (comment) => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _ReportComment(comment: comment),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: AppColors.deepGreen),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ReportTimeline extends StatelessWidget {
  const _ReportTimeline({required this.report});

  final CivicReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: report.updates.map((update) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Column(
              children: <Widget>[
                Icon(
                  update.status == report.status
                      ? Icons.radio_button_checked
                      : Icons.check_circle_outline,
                  color: update.status.color,
                  size: 22,
                ),
                Container(width: 2, height: 53, color: const Color(0xFFDCE6E2)),
              ],
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      update.status.label,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      update.message,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      formatDate(update.date, includeYear: true),
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
        );
      }).toList(),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.mint,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.image_outlined, color: AppColors.deepGreen),
        const SizedBox(width: 7),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _ResolutionConfirmation extends StatelessWidget {
  const _ResolutionConfirmation({required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context) {
    return CivicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Has this issue been resolved?',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 5),
          const Text(
            'Your confirmation helps the authority close the case accurately.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(
                onPressed: () {
                  AppScope.of(
                    context,
                  ).confirmReportResolution(reportId, resolved: true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Thank you. The issue has been confirmed as resolved.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.check),
                label: const Text('Yes, resolved'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  AppScope.of(
                    context,
                  ).confirmReportResolution(reportId, resolved: false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'The report has been reopened for attention.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('No, still a problem'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Row(
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

class _ReportComment extends StatelessWidget {
  const _ReportComment({required this.comment});

  final CivicComment comment;

  @override
  Widget build(BuildContext context) => CivicCard(
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
                color: AppColors.green,
                size: 18,
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(comment.message),
        const SizedBox(height: 5),
        Text(
          relativeTime(comment.createdAt),
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}
