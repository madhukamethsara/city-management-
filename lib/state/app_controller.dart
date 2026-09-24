import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/demo_civic_repository.dart';
import '../models/domain_models.dart';

class OnboardingDraft {
  const OnboardingDraft({
    required this.fullName,
    required this.language,
    required this.phone,
    required this.localAuthorityId,
    required this.ward,
    required this.gnDivision,
    required this.residentialArea,
  });

  final String fullName;
  final String language;
  final String phone;
  final String localAuthorityId;
  final String ward;
  final String gnDivision;
  final GeoPoint? residentialArea;
}

class ReportDraft {
  const ReportDraft({
    required this.category,
    required this.title,
    required this.description,
    required this.locationLabel,
    required this.location,
    required this.urgency,
    required this.attachmentNames,
  });

  final String category;
  final String title;
  final String description;
  final String locationLabel;
  final GeoPoint location;
  final String urgency;
  final List<String> attachmentNames;
}

class ProposalDraft {
  const ProposalDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.locationLabel,
    required this.expectedBenefit,
    required this.attachmentNames,
  });

  final String title;
  final String description;
  final String category;
  final String locationLabel;
  final String expectedBenefit;
  final List<String> attachmentNames;
}

class ProjectDraft {
  const ProjectDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.locationLabel,
    required this.status,
    required this.progress,
    required this.budget,
    required this.department,
  });

  final String title;
  final String description;
  final String category;
  final String locationLabel;
  final ProjectStatus status;
  final int progress;
  final int budget;
  final String department;
}

class AnnouncementDraft {
  const AnnouncementDraft({
    required this.title,
    required this.body,
    required this.type,
    required this.department,
    required this.targetLabel,
  });

  final String title;
  final String body;
  final AnnouncementType type;
  final String department;
  final String targetLabel;
}

class AppController extends ChangeNotifier {
  AppController(this._repository);

  final CivicRepository _repository;
  final Random _random = Random();

  bool isLoading = true;
  AppUser? _currentUser;
  List<LocalAuthority> _authorities = <LocalAuthority>[];
  List<Department> _departments = <Department>[];
  List<AppUser> _users = <AppUser>[];
  List<Project> _projects = <Project>[];
  List<CivicReport> _reports = <CivicReport>[];
  List<Announcement> _announcements = <Announcement>[];
  List<FeedItem> _feedItems = <FeedItem>[];
  List<Proposal> _proposals = <Proposal>[];
  List<Consultation> _consultations = <Consultation>[];
  List<AppNotification> _notifications = <AppNotification>[];

  AppUser? get currentUser => _currentUser;
  bool get hasSession => _currentUser != null;
  bool get isOfficer => _currentUser?.isOfficer ?? false;
  bool get isGuest => _currentUser?.isGuest ?? false;
  bool get canParticipate => hasSession && !isGuest;
  List<LocalAuthority> get authorities => List.unmodifiable(_authorities);
  List<Department> get departments => List.unmodifiable(_departments);
  List<Project> get projects => List.unmodifiable(_projects);
  List<CivicReport> get reports => List.unmodifiable(_reports);
  List<Announcement> get announcements =>
      List.unmodifiable(_announcements.where((item) => item.isPublished));
  List<Announcement> get managedAnnouncements =>
      List.unmodifiable(_announcements);
  List<FeedItem> get feedItems => List.unmodifiable(_feedItems);
  List<Proposal> get proposals => List.unmodifiable(_proposals);
  List<Consultation> get consultations => List.unmodifiable(_consultations);
  List<AppUser> get users => List.unmodifiable(_users);
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadNotificationCount =>
      _notifications.where((item) => !item.isRead).length;

  LocalAuthority? get selectedAuthority {
    final id = _currentUser?.localAuthorityId;
    if (id == null || id.isEmpty) return null;
    return _firstOrNull(_authorities, (authority) => authority.id == id);
  }

  String get authorityName => selectedAuthority?.name ?? 'your local authority';
  String get locale => _currentUser?.preferredLanguage ?? 'en';

  List<CivicReport> get myReports {
    final user = _currentUser;
    if (user == null) return const <CivicReport>[];
    if (user.isOfficer) return reports;
    if (user.isGuest) return const <CivicReport>[];
    return _reports.where((report) => report.ownerUserId == user.id).toList();
  }

  DashboardMetrics get dashboardMetrics => DashboardMetrics(
    newComplaints: _reports
        .where((report) => report.status == ReportStatus.submitted)
        .length,
    assignedComplaints: _reports
        .where((report) => report.status == ReportStatus.assigned)
        .length,
    overdueComplaints: _reports
        .where(
          (report) =>
              report.priority == 'Urgent' &&
              report.status != ReportStatus.resolved,
        )
        .length,
    activeProjects: _projects
        .where((project) => project.status == ProjectStatus.inProgress)
        .length,
    delayedProjects: _projects
        .where((project) => project.status == ProjectStatus.delayed)
        .length,
    openConsultations: _consultations
        .where((consultation) => consultation.isOpen)
        .length,
    citizenProposals: _proposals.length,
    averageResolutionDays: 4.8,
  );

  Future<void> bootstrap() async {
    final data = await _repository.loadInitialData();
    _authorities = data.authorities;
    _departments = data.departments;
    _users = data.users;
    _projects = data.projects;
    _reports = data.reports;
    _announcements = data.announcements;
    _feedItems = data.feedItems;
    _proposals = data.proposals;
    _consultations = data.consultations;
    _notifications = data.notifications;
    isLoading = false;
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final normalizedEmail = email.trim().toLowerCase();
    AppUser? match;
    for (final user in _users) {
      if (user.email.toLowerCase() == normalizedEmail) {
        match = user;
        break;
      }
    }
    match ??= normalizedEmail.contains('officer')
        ? _users.firstWhere((user) => user.isOfficer)
        : _users.firstWhere((user) => user.id == 'u-citizen');
    _currentUser = match;
    notifyListeners();
  }

  Future<void> register({
    required String fullName,
    required String email,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final user = AppUser(
      id: 'u-${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName.trim(),
      email: email.trim(),
      role: UserRole.citizen,
      localAuthorityId: '',
      ward: '',
      gnDivision: '',
      phone: '',
      preferredLanguage: 'en',
      onboardingComplete: false,
      isActive: true,
    );
    _users = <AppUser>[..._users, user];
    _currentUser = user;
    notifyListeners();
  }

  void continueAsGuest() {
    _currentUser = const AppUser(
      id: 'guest',
      fullName: 'Guest',
      email: '',
      role: UserRole.guest,
      localAuthorityId: 'la-kumbukgate',
      ward: 'Ward 04',
      gnDivision: '',
      phone: '',
      preferredLanguage: 'en',
      onboardingComplete: true,
      isActive: true,
    );
    notifyListeners();
  }

  void signOut() {
    _currentUser = null;
    notifyListeners();
  }

  void completeOnboarding(OnboardingDraft draft) {
    final user = _currentUser;
    if (user == null) return;
    _currentUser = user.copyWith(
      fullName: draft.fullName,
      preferredLanguage: draft.language,
      phone: draft.phone,
      localAuthorityId: draft.localAuthorityId,
      ward: draft.ward,
      gnDivision: draft.gnDivision,
      residentialArea: draft.residentialArea,
      onboardingComplete: true,
    );
    _replaceUser(_currentUser!);
    notifyListeners();
  }

  void updateProfile({
    required String fullName,
    required String phone,
    required String preferredLanguage,
  }) {
    final user = _currentUser;
    if (user == null || user.isGuest) return;
    _currentUser = user.copyWith(
      fullName: fullName,
      phone: phone,
      preferredLanguage: preferredLanguage,
    );
    _replaceUser(_currentUser!);
    notifyListeners();
  }

  Project? projectById(String id) =>
      _firstOrNull(_projects, (project) => project.id == id);
  CivicReport? reportById(String id) =>
      _firstOrNull(_reports, (report) => report.id == id);
  Announcement? announcementById(String id) =>
      _firstOrNull(_announcements, (item) => item.id == id);
  Proposal? proposalById(String id) =>
      _firstOrNull(_proposals, (item) => item.id == id);
  Consultation? consultationById(String id) =>
      _firstOrNull(_consultations, (item) => item.id == id);

  List<CivicReport> findSimilarReports({
    required String category,
    required GeoPoint location,
  }) {
    return _reports.where((report) {
      return report.category == category &&
          _distanceInKm(report.location, location) < 0.8;
    }).toList();
  }

  void toggleProjectFollow(String projectId) {
    final user = _currentUser;
    if (user == null || user.isGuest) return;
    final project = projectById(projectId);
    if (project == null) return;
    final followers = Set<String>.from(project.followerIds);
    followers.contains(user.id)
        ? followers.remove(user.id)
        : followers.add(user.id);
    _replaceProject(project.copyWith(followerIds: followers));
    notifyListeners();
  }

  void toggleReportFollow(String reportId) {
    final user = _currentUser;
    final report = reportById(reportId);
    if (user == null || user.isGuest || report == null) return;
    final followers = Set<String>.from(report.followerIds);
    followers.contains(user.id)
        ? followers.remove(user.id)
        : followers.add(user.id);
    _replaceReport(report.copyWith(followerIds: followers));
    notifyListeners();
  }

  void toggleFeedReaction(String feedId) {
    final user = _currentUser;
    if (user == null || user.isGuest) return;
    final item = _firstOrNull(_feedItems, (entry) => entry.id == feedId);
    if (item == null) return;
    final reacted = Set<String>.from(item.reactedUserIds);
    final isRemoving = reacted.contains(user.id);
    isRemoving ? reacted.remove(user.id) : reacted.add(user.id);
    _replaceFeedItem(
      item.copyWith(
        reactionCount: item.reactionCount + (isRemoving ? -1 : 1),
        reactedUserIds: reacted,
      ),
    );
    notifyListeners();
  }

  void toggleFeedSave(String feedId) {
    final user = _currentUser;
    if (user == null || user.isGuest) return;
    final item = _firstOrNull(_feedItems, (entry) => entry.id == feedId);
    if (item == null) return;
    final saved = Set<String>.from(item.savedUserIds);
    saved.contains(user.id) ? saved.remove(user.id) : saved.add(user.id);
    _replaceFeedItem(item.copyWith(savedUserIds: saved));
    notifyListeners();
  }

  void addFeedComment(String feedId) {
    final user = _currentUser;
    if (user == null || user.isGuest) return;
    final item = _firstOrNull(_feedItems, (entry) => entry.id == feedId);
    if (item == null) return;
    _replaceFeedItem(item.copyWith(commentCount: item.commentCount + 1));
    notifyListeners();
  }

  Future<CivicReport> submitReport(ReportDraft draft) async {
    final user = _currentUser;
    if (user == null || user.isGuest) {
      throw StateError('Sign in before submitting a report.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final today = DateTime.now();
    final caseNumber = 'SS-${today.year}-${(1000 + _random.nextInt(8999))}';
    final report = CivicReport(
      id: 'r-${today.microsecondsSinceEpoch}',
      caseNumber: caseNumber,
      title: draft.title,
      description: draft.description,
      category: draft.category,
      locationLabel: draft.locationLabel,
      location: draft.location,
      status: ReportStatus.submitted,
      priority: draft.urgency,
      submittedAt: today,
      lastUpdated: today,
      department: _departmentForCategory(draft.category),
      ownerUserId: user.id,
      assignedOfficer: null,
      attachments: draft.attachmentNames,
      updates: <ReportUpdate>[
        ReportUpdate(
          status: ReportStatus.submitted,
          message: 'Your report was received and given a case number.',
          date: today,
          isPublic: true,
        ),
      ],
      followerIds: <String>{user.id},
    );
    _reports = <CivicReport>[report, ..._reports];
    _notifications = <AppNotification>[
      AppNotification(
        id: 'n-${today.microsecondsSinceEpoch}',
        title: 'Your report was submitted',
        message: '$caseNumber was sent to ${report.department}.',
        category: 'Report update',
        createdAt: today,
        isRead: false,
        route: '/reports/${report.id}',
      ),
      ..._notifications,
    ];
    notifyListeners();
    return report;
  }

  void updateReportStatus({
    required String reportId,
    required ReportStatus status,
    required String department,
    required String priority,
    String? assignedOfficer,
    required String publicUpdate,
    List<String>? attachmentNames,
    String? internalNote,
  }) {
    final report = reportById(reportId);
    if (report == null) return;
    final now = DateTime.now();
    final updates = <ReportUpdate>[
      ...report.updates,
      ReportUpdate(
        status: status,
        message: publicUpdate,
        date: now,
        isPublic: true,
      ),
    ];
    _replaceReport(
      report.copyWith(
        status: status,
        department: department,
        priority: priority,
        assignedOfficer: assignedOfficer,
        lastUpdated: now,
        attachments: attachmentNames == null
            ? report.attachments
            : <String>[...report.attachments, ...attachmentNames],
        internalNotes: internalNote == null || internalNote.trim().isEmpty
            ? report.internalNotes
            : <String>[...report.internalNotes, internalNote.trim()],
        updates: updates,
      ),
    );
    if (report.ownerUserId == _currentUser?.id ||
        report.ownerUserId == 'u-citizen') {
      _notifications = <AppNotification>[
        AppNotification(
          id: 'n-admin-${now.microsecondsSinceEpoch}',
          title: 'Your report has an update',
          message: '${report.caseNumber}: $publicUpdate',
          category: 'Report update',
          createdAt: now,
          isRead: false,
          route: '/reports/$reportId',
        ),
        ..._notifications,
      ];
    }
    notifyListeners();
  }

  void confirmReportResolution(String reportId, {required bool resolved}) {
    final report = reportById(reportId);
    if (report == null) return;
    final now = DateTime.now();
    final message = resolved
        ? 'The resident confirmed that this issue is resolved.'
        : 'The resident reported that the issue still needs attention.';
    _replaceReport(
      report.copyWith(
        status: resolved ? ReportStatus.resolved : ReportStatus.inProgress,
        lastUpdated: now,
        updates: <ReportUpdate>[
          ...report.updates,
          ReportUpdate(
            status: resolved ? ReportStatus.resolved : ReportStatus.inProgress,
            message: message,
            date: now,
            isPublic: true,
          ),
        ],
      ),
    );
    notifyListeners();
  }

  Future<Proposal> submitProposal(ProposalDraft draft) async {
    final user = _currentUser;
    if (user == null || user.isGuest) {
      throw StateError('Sign in before submitting a proposal.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final proposal = Proposal(
      id: 'pr-${DateTime.now().microsecondsSinceEpoch}',
      title: draft.title,
      description: draft.description,
      category: draft.category,
      locationLabel: draft.locationLabel,
      expectedBenefit: draft.expectedBenefit,
      status: ProposalStatus.submitted,
      author: user.isVerified ? 'Verified Resident · ${user.ward}' : 'Resident',
      createdAt: DateTime.now(),
      attachments: draft.attachmentNames,
      supporterIds: <String>{user.id},
      comments: const <CivicComment>[],
      followerIds: <String>{user.id},
    );
    _proposals = <Proposal>[proposal, ..._proposals];
    notifyListeners();
    return proposal;
  }

  void toggleProposalSupport(String proposalId) {
    final user = _currentUser;
    final proposal = proposalById(proposalId);
    if (user == null || user.isGuest || proposal == null) return;
    final supporters = Set<String>.from(proposal.supporterIds);
    supporters.contains(user.id)
        ? supporters.remove(user.id)
        : supporters.add(user.id);
    _replaceProposal(proposal.copyWith(supporterIds: supporters));
    notifyListeners();
  }

  void toggleProposalFollow(String proposalId) {
    final user = _currentUser;
    final proposal = proposalById(proposalId);
    if (user == null || user.isGuest || proposal == null) return;
    final followers = Set<String>.from(proposal.followerIds);
    followers.contains(user.id)
        ? followers.remove(user.id)
        : followers.add(user.id);
    _replaceProposal(proposal.copyWith(followerIds: followers));
    notifyListeners();
  }

  void addProposalComment(String proposalId, String message) {
    final user = _currentUser;
    final proposal = proposalById(proposalId);
    if (user == null ||
        user.isGuest ||
        proposal == null ||
        message.trim().isEmpty) {
      return;
    }
    final comment = CivicComment(
      id: 'pc-${DateTime.now().microsecondsSinceEpoch}',
      author: user.isVerified ? 'Verified Resident · ${user.ward}' : 'Resident',
      message: message.trim(),
      createdAt: DateTime.now(),
      isVerified: user.isVerified,
    );
    _replaceProposal(
      proposal.copyWith(
        comments: <CivicComment>[...proposal.comments, comment],
      ),
    );
    notifyListeners();
  }

  void submitConsultationResponse(String consultationId) {
    final user = _currentUser;
    final consultation = consultationById(consultationId);
    if (user == null || user.isGuest || consultation == null) return;
    final responses = Set<String>.from(consultation.respondedUserIds)
      ..add(user.id);
    _replaceConsultation(consultation.copyWith(respondedUserIds: responses));
    _notifications = <AppNotification>[
      AppNotification(
        id: 'n-consult-${DateTime.now().microsecondsSinceEpoch}',
        title: 'Thank you for your response',
        message: 'Your response to ${consultation.title} was recorded.',
        category: 'Consultation',
        createdAt: DateTime.now(),
        isRead: false,
      ),
      ..._notifications,
    ];
    notifyListeners();
  }

  void markNotificationRead(String id) {
    final notification = _firstOrNull(_notifications, (item) => item.id == id);
    if (notification == null || notification.isRead) return;
    _replaceNotification(notification.copyWith(isRead: true));
    notifyListeners();
  }

  void markAllNotificationsRead() {
    _notifications = _notifications
        .map((item) => item.copyWith(isRead: true))
        .toList();
    notifyListeners();
  }

  void saveProject(Project project) {
    final existing = projectById(project.id);
    if (existing == null) {
      _projects = <Project>[project, ..._projects];
    } else {
      _replaceProject(project);
    }
    notifyListeners();
  }

  Project createProject(ProjectDraft draft) {
    final now = DateTime.now();
    final project = Project(
      id: 'p-${now.microsecondsSinceEpoch}',
      title: draft.title,
      description: draft.description,
      category: draft.category,
      locationLabel: draft.locationLabel,
      location: selectedAuthority?.center ?? const GeoPoint(7.4864, 80.3642),
      status: draft.status,
      progress: draft.progress,
      startDate: now,
      expectedCompletion: now.add(const Duration(days: 180)),
      department: draft.department,
      budget: draft.budget,
      spent: 0,
      isBudgetPublic: true,
      milestones: const <ProjectMilestone>[],
      updates: <ProjectUpdate>[
        ProjectUpdate(
          title: 'Project created',
          message: 'This project was created by an authorised officer.',
          date: now,
          isPublic: false,
        ),
      ],
      documents: const <PublicDocument>[],
      followerIds: <String>{},
      projectManager: _currentUser?.fullName,
    );
    saveProject(project);
    return project;
  }

  Announcement createAnnouncement(
    AnnouncementDraft draft, {
    bool publishNow = false,
  }) {
    final announcement = Announcement(
      id: 'a-${DateTime.now().microsecondsSinceEpoch}',
      title: draft.title,
      body: draft.body,
      type: draft.type,
      department: draft.department,
      publishedAt: DateTime.now(),
      targetLabel: draft.targetLabel,
      isPinned: false,
      isPublished: publishNow,
    );
    _announcements = <Announcement>[announcement, ..._announcements];
    if (publishNow) {
      _notifications = <AppNotification>[
        AppNotification(
          id: 'n-announcement-${DateTime.now().microsecondsSinceEpoch}',
          title: 'New local announcement',
          message: announcement.title,
          category: 'Announcement',
          createdAt: DateTime.now(),
          isRead: false,
          route: '/announcements/${announcement.id}',
        ),
        ..._notifications,
      ];
    }
    notifyListeners();
    return announcement;
  }

  void publishAnnouncement(String announcementId) {
    final announcement = announcementById(announcementId);
    if (announcement == null) return;
    final published = announcement.copyWith(isPublished: true);
    _announcements = _announcements
        .map((item) => item.id == announcementId ? published : item)
        .toList();
    notifyListeners();
  }

  void saveAnnouncement(Announcement announcement) {
    final existing = announcementById(announcement.id);
    _announcements = existing == null
        ? <Announcement>[announcement, ..._announcements]
        : _announcements
              .map((item) => item.id == announcement.id ? announcement : item)
              .toList();
    notifyListeners();
  }

  void toggleUserActive(String userId) {
    final user = _firstOrNull(_users, (item) => item.id == userId);
    if (user == null) return;
    _replaceUser(user.copyWith(isActive: !user.isActive));
    notifyListeners();
  }

  void changeUserRole(String userId, UserRole role) {
    final user = _firstOrNull(_users, (item) => item.id == userId);
    if (user == null) return;
    _replaceUser(user.copyWith(role: role));
    notifyListeners();
  }

  void updateDepartment(Department department) {
    _departments = _departments
        .map((item) => item.id == department.id ? department : item)
        .toList();
    notifyListeners();
  }

  List<Object> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const <Object>[];
    final results = <Object>[];
    results.addAll(
      _projects.where(
        (item) =>
            '${item.title} ${item.description}'.toLowerCase().contains(needle),
      ),
    );
    results.addAll(
      _announcements.where(
        (item) => '${item.title} ${item.body}'.toLowerCase().contains(needle),
      ),
    );
    results.addAll(
      myReports.where(
        (item) =>
            '${item.title} ${item.description}'.toLowerCase().contains(needle),
      ),
    );
    results.addAll(
      _proposals.where(
        (item) =>
            '${item.title} ${item.description}'.toLowerCase().contains(needle),
      ),
    );
    results.addAll(
      _consultations.where(
        (item) =>
            '${item.title} ${item.description}'.toLowerCase().contains(needle),
      ),
    );
    return results;
  }

  void _replaceProject(Project updated) {
    _projects = _projects
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
  }

  void _replaceReport(CivicReport updated) {
    _reports = _reports
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
  }

  void _replaceFeedItem(FeedItem updated) {
    _feedItems = _feedItems
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
  }

  void _replaceProposal(Proposal updated) {
    _proposals = _proposals
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
  }

  void _replaceConsultation(Consultation updated) {
    _consultations = _consultations
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
  }

  void _replaceNotification(AppNotification updated) {
    _notifications = _notifications
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
  }

  void _replaceUser(AppUser updated) {
    _users = _users
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
  }

  String _departmentForCategory(String category) {
    for (final department in _departments) {
      if (department.categories.contains(category)) return department.name;
    }
    return 'Administration';
  }

  T? _firstOrNull<T>(Iterable<T> items, bool Function(T item) predicate) {
    for (final item in items) {
      if (predicate(item)) return item;
    }
    return null;
  }

  double _distanceInKm(GeoPoint first, GeoPoint second) {
    const earthRadius = 6371.0;
    final dLat = _toRadians(second.latitude - first.latitude);
    final dLng = _toRadians(second.longitude - first.longitude);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(first.latitude)) *
            cos(_toRadians(second.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRadians(double degrees) => degrees * pi / 180;
}
