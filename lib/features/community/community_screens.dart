import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../models/domain_models.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_widgets.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  AnnouncementType? _filter;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final announcements = controller.announcements
        .where((item) => _filter == null || item.type == _filter)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const PageHeader(
              icon: Icons.campaign_outlined,
              title: 'Local announcements',
              subtitle:
                  'Official notices and service information for your selected area.',
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
                  ...AnnouncementType.values.map(
                    (type) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(type.label),
                        selected: _filter == type,
                        onSelected: (_) => setState(() => _filter = type),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: announcements.isEmpty
                  ? const EmptyState(
                      icon: Icons.campaign_outlined,
                      title: 'No announcements in this category',
                      message: 'Choose another category to see local notices.',
                    )
                  : ListView.separated(
                      itemCount: announcements.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => AnnouncementCard(
                        announcement: announcements[index],
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/announcements/${announcements[index].id}',
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

class AnnouncementDetailScreen extends StatelessWidget {
  const AnnouncementDetailScreen({super.key, required this.announcementId});

  final String announcementId;

  @override
  Widget build(BuildContext context) {
    final announcement = AppScope.of(context).announcementById(announcementId);
    if (announcement == null || !announcement.isPublished) {
      return const NotFoundScreen(
        message: 'This announcement is no longer available.',
      );
    }
    final color = announcement.type == AnnouncementType.emergency
        ? AppColors.danger
        : AppColors.green;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement'),
        actions: <Widget>[
          IconButton(
            onPressed: () => _share(context, announcement),
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: 'Share announcement',
          ),
        ],
      ),
      body: ResponsivePage(
        child: ListView(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(announcement.type.icon, color: color, size: 36),
                  const SizedBox(height: 18),
                  Text(
                    announcement.type.label.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    announcement.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              announcement.body,
              style: const TextStyle(
                fontSize: 16,
                height: 1.65,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 26),
            CivicCard(
              child: Wrap(
                spacing: 22,
                runSpacing: 12,
                children: <Widget>[
                  _AnnouncementFact(
                    icon: Icons.business_outlined,
                    label: 'Published by',
                    value: announcement.department,
                  ),
                  _AnnouncementFact(
                    icon: Icons.location_on_outlined,
                    label: 'Audience',
                    value: announcement.targetLabel,
                  ),
                  _AnnouncementFact(
                    icon: Icons.schedule_outlined,
                    label: 'Published',
                    value: formatDate(
                      announcement.publishedAt,
                      includeYear: true,
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

  Future<void> _share(BuildContext context, Announcement announcement) async {
    await Clipboard.setData(
      ClipboardData(text: 'Smart Sabha announcement: ${announcement.title}'),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement link copied to clipboard.')),
      );
    }
  }
}

class _AnnouncementFact extends StatelessWidget {
  const _AnnouncementFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 19, color: AppColors.deepGreen),
        const SizedBox(width: 8),
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

class ProposalsScreen extends StatefulWidget {
  const ProposalsScreen({super.key});

  @override
  State<ProposalsScreen> createState() => _ProposalsScreenState();
}

class _ProposalsScreenState extends State<ProposalsScreen> {
  ProposalStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final proposals = controller.proposals
        .where((item) => _filter == null || item.status == _filter)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Community proposals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (!controller.canParticipate) {
            return showSignInPrompt(
              context,
              message: 'Sign in to submit a community proposal.',
            );
          }
          Navigator.pushNamed(context, '/proposals/new');
        },
        icon: const Icon(Icons.add),
        label: const Text('New proposal'),
      ),
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const PageHeader(
              icon: Icons.lightbulb_outline,
              title: 'Community proposals',
              subtitle:
                  'Share practical local-development ideas and follow their review progress.',
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
                  ...ProposalStatus.values
                      .take(6)
                      .map(
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
              child: proposals.isEmpty
                  ? const EmptyState(
                      icon: Icons.lightbulb_outline,
                      title: 'No proposals found',
                      message:
                          'Try another review status or create a new local-development idea.',
                    )
                  : ListView.separated(
                      itemCount: proposals.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _ProposalCard(proposal: proposals[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({required this.proposal});

  final Proposal proposal;

  @override
  Widget build(BuildContext context) {
    return CivicCard(
      onTap: () => Navigator.pushNamed(context, '/proposals/${proposal.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  proposal.category,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              _ProposalStatusBadge(status: proposal.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            proposal.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            proposal.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 14,
            runSpacing: 7,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.muted,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    proposal.locationLabel,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.volunteer_activism_outlined,
                    color: AppColors.muted,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${proposal.supporterIds.length} supporters',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.muted,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${proposal.comments.length} comments',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProposalStatusBadge extends StatelessWidget {
  const _ProposalStatusBadge({required this.status});

  final ProposalStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ProposalStatus.approved ||
      ProposalStatus.convertedToProject => AppColors.green,
      ProposalStatus.rejected => AppColors.danger,
      ProposalStatus.communityReview ||
      ProposalStatus.technicalReview => const Color(0xFF2C6EAA),
      _ => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class NewProposalScreen extends StatefulWidget {
  const NewProposalScreen({super.key});

  @override
  State<NewProposalScreen> createState() => _NewProposalScreenState();
}

class _NewProposalScreenState extends State<NewProposalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _benefit = TextEditingController();
  final _picker = ImagePicker();
  final _attachments = <XFile>[];
  String _category = 'Public spaces';
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _benefit.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 80);
    if (!mounted || files.isEmpty) return;
    setState(() => _attachments.addAll(files));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = AppScope.of(context);
    setState(() => _submitting = true);
    final proposal = await controller.submitProposal(
      ProposalDraft(
        title: _title.text.trim(),
        description: _description.text.trim(),
        category: _category,
        locationLabel: _location.text.trim(),
        expectedBenefit: _benefit.text.trim(),
        attachmentNames: _attachments.map((file) => file.name).toList(),
      ),
    );
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/proposals/${proposal.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New community proposal')),
      body: ResponsivePage(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const PageHeader(
                      icon: Icons.lightbulb_outline,
                      title: 'Share a local-development idea',
                      subtitle:
                          'Explain a practical community benefit. This is a proposal, not a political vote.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Proposal title',
                      ),
                      validator: (value) =>
                          value == null || value.trim().length < 8
                          ? 'Add a clear title.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(
                          value: 'Public spaces',
                          child: Text('Public spaces'),
                        ),
                        DropdownMenuItem(
                          value: 'Transport & Access',
                          child: Text('Transport & access'),
                        ),
                        DropdownMenuItem(
                          value: 'Environment',
                          child: Text('Environment'),
                        ),
                        DropdownMenuItem(
                          value: 'Water & Sanitation',
                          child: Text('Water & sanitation'),
                        ),
                        DropdownMenuItem(
                          value: 'Community services',
                          child: Text('Community services'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _category = value ?? _category),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      minLines: 4,
                      maxLines: 7,
                      maxLength: 1200,
                      decoration: const InputDecoration(
                        labelText: 'Describe the idea',
                      ),
                      validator: (value) =>
                          value == null || value.trim().length < 30
                          ? 'Describe the idea in a little more detail.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _location,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Proposed location',
                      ),
                      validator: (value) =>
                          value == null || value.trim().length < 4
                          ? 'Add a proposed location.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _benefit,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 700,
                      decoration: const InputDecoration(
                        labelText: 'Expected community benefit',
                      ),
                      validator: (value) =>
                          value == null || value.trim().length < 20
                          ? 'Explain the expected benefit.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Add optional images'),
                    ),
                    if (_attachments.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _attachments
                            .asMap()
                            .entries
                            .map(
                              (entry) => InputChip(
                                label: Text(entry.value.name),
                                onDeleted: () => setState(
                                  () => _attachments.removeAt(entry.key),
                                ),
                                avatar: const Icon(
                                  Icons.image_outlined,
                                  size: 17,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Submit proposal'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProposalDetailScreen extends StatefulWidget {
  const ProposalDetailScreen({super.key, required this.proposalId});

  final String proposalId;

  @override
  State<ProposalDetailScreen> createState() => _ProposalDetailScreenState();
}

class _ProposalDetailScreenState extends State<ProposalDetailScreen> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final proposal = controller.proposalById(widget.proposalId);
    if (proposal == null) {
      return const NotFoundScreen(
        message: 'This community proposal could not be found.',
      );
    }
    final userId = controller.currentUser?.id;
    final supported = userId != null && proposal.supporterIds.contains(userId);
    final following = userId != null && proposal.followerIds.contains(userId);
    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          IconButton(
            onPressed: () => _share(context, proposal),
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: 'Share proposal',
          ),
        ],
      ),
      body: ResponsivePage(
        child: ListView(
          children: <Widget>[
            _ProposalStatusBadge(status: proposal.status),
            const SizedBox(height: 12),
            Text(
              proposal.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '${proposal.category} · ${proposal.locationLabel}',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            Text(
              proposal.description,
              style: const TextStyle(color: AppColors.ink, height: 1.6),
            ),
            const SizedBox(height: 18),
            CivicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Expected community benefit',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    proposal.expectedBenefit,
                    style: const TextStyle(color: AppColors.muted, height: 1.5),
                  ),
                ],
              ),
            ),
            if (proposal.attachments.isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              const SectionTitle(title: 'Attached images'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: proposal.attachments
                    .map(
                      (file) => Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.image_outlined,
                              color: AppColors.deepGreen,
                            ),
                            const SizedBox(width: 6),
                            Text(file),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () async {
                    if (!controller.canParticipate) {
                      return showSignInPrompt(context);
                    }
                    controller.toggleProposalSupport(proposal.id);
                  },
                  icon: Icon(
                    supported
                        ? Icons.volunteer_activism
                        : Icons.volunteer_activism_outlined,
                  ),
                  label: Text(supported ? 'Supported' : 'Support this idea'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    if (!controller.canParticipate) {
                      return showSignInPrompt(context);
                    }
                    controller.toggleProposalFollow(proposal.id);
                  },
                  icon: Icon(
                    following
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_none_outlined,
                  ),
                  label: Text(following ? 'Following' : 'Follow updates'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${proposal.supporterIds.length} residents support this proposal · ${proposal.author}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Comments'),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _comment,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Add a respectful, practical comment',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () async {
                    if (!controller.canParticipate) {
                      return showSignInPrompt(context);
                    }
                    if (_comment.text.trim().isEmpty) return;
                    controller.addProposalComment(proposal.id, _comment.text);
                    _comment.clear();
                  },
                  icon: const Icon(Icons.send_outlined),
                  tooltip: 'Post comment',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (proposal.comments.isEmpty)
              const Text(
                'No comments yet. Help refine this idea with constructive feedback.',
                style: TextStyle(color: AppColors.muted),
              ),
            ...proposal.comments.map(
              (comment) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _ProposalComment(comment: comment),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, Proposal proposal) async {
    await Clipboard.setData(
      ClipboardData(text: 'Smart Sabha proposal: ${proposal.title}'),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proposal link copied to clipboard.')),
      );
    }
  }
}

class _ProposalComment extends StatelessWidget {
  const _ProposalComment({required this.comment});

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
        const SizedBox(height: 6),
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

class ConsultationsScreen extends StatelessWidget {
  const ConsultationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Public consultations')),
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const PageHeader(
              icon: Icons.forum_outlined,
              title: 'Public consultations',
              subtitle:
                  'Share your experience and local knowledge before the closing date.',
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: controller.consultations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _ConsultationCard(
                  consultation: controller.consultations[index],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  const _ConsultationCard({required this.consultation});

  final Consultation consultation;

  @override
  Widget build(BuildContext context) {
    final userId = AppScope.of(context).currentUser?.id;
    final responded =
        userId != null && consultation.respondedUserIds.contains(userId);
    return CivicCard(
      onTap: () =>
          Navigator.pushNamed(context, '/consultations/${consultation.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.forum_outlined,
                  color: AppColors.deepGreen,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      consultation.department,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      consultation.isOpen
                          ? 'Open until ${formatDate(consultation.closingDate, includeYear: true)}'
                          : 'Closed',
                      style: TextStyle(
                        color: consultation.isOpen
                            ? AppColors.green
                            : AppColors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (responded)
                const Icon(Icons.check_circle, color: AppColors.green),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            consultation.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            consultation.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class ConsultationDetailScreen extends StatefulWidget {
  const ConsultationDetailScreen({super.key, required this.consultationId});

  final String consultationId;

  @override
  State<ConsultationDetailScreen> createState() =>
      _ConsultationDetailScreenState();
}

class _ConsultationDetailScreenState extends State<ConsultationDetailScreen> {
  final Map<String, String> _answers = <String, String>{};
  final Map<String, TextEditingController> _textControllers =
      <String, TextEditingController>{};

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final consultation = controller.consultationById(widget.consultationId);
    if (consultation == null) {
      return const NotFoundScreen(
        message: 'This consultation could not be found.',
      );
    }
    final responded =
        controller.currentUser != null &&
        consultation.respondedUserIds.contains(controller.currentUser!.id);
    return Scaffold(
      appBar: AppBar(title: const Text('Consultation')),
      body: ResponsivePage(
        child: ListView(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    consultation.isOpen
                        ? 'OPEN CONSULTATION'
                        : 'CLOSED CONSULTATION',
                    style: TextStyle(
                      color: consultation.isOpen
                          ? AppColors.deepGreen
                          : AppColors.muted,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    consultation.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Closes ${formatDate(consultation.closingDate, includeYear: true)} · ${consultation.department}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              consultation.description,
              style: const TextStyle(color: AppColors.ink, height: 1.6),
            ),
            const SizedBox(height: 22),
            if (responded)
              const CivicCard(
                child: Row(
                  children: <Widget>[
                    Icon(Icons.check_circle_outline, color: AppColors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your response has been recorded. Thank you for contributing to this local decision process.',
                      ),
                    ),
                  ],
                ),
              )
            else if (!consultation.isOpen)
              const CivicCard(
                child: Row(
                  children: <Widget>[
                    Icon(Icons.lock_clock_outlined, color: AppColors.muted),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This consultation is closed and no longer accepts responses.',
                      ),
                    ),
                  ],
                ),
              )
            else ...<Widget>[
              ...consultation.questions.map(_questionCard),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => _submit(consultation),
                child: const Text('Submit response'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _questionCard(ConsultationQuestion question) {
    final controller = _textControllers.putIfAbsent(
      question.id,
      TextEditingController.new,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CivicCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              question.question,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (question.allowsLongText)
              TextField(
                controller: controller,
                minLines: 3,
                maxLines: 6,
                onChanged: (value) => _answers[question.id] = value,
                decoration: const InputDecoration(
                  hintText: 'Write your response',
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: question.options
                    .map(
                      (option) => ChoiceChip(
                        label: Text(option),
                        selected: _answers[question.id] == option,
                        onSelected: (_) =>
                            setState(() => _answers[question.id] = option),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  void _submit(Consultation consultation) {
    final missing = consultation.questions
        .where((question) => (_answers[question.id] ?? '').trim().isEmpty)
        .toList();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please answer every consultation question before submitting.',
          ),
        ),
      );
      return;
    }
    final controller = AppScope.of(context);
    if (!controller.canParticipate) {
      showSignInPrompt(
        context,
        message: 'Sign in to submit a consultation response.',
      );
      return;
    }
    controller.submitConsultationResponse(consultation.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your response was submitted. Thank you.')),
    );
  }
}
