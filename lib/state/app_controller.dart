import 'dart:async';

import 'dart:math';

import '../data/auth/auth_repository.dart';

import 'package:flutter/foundation.dart';

import '../data/civic_repository.dart';
import '../data/civic_failure.dart';
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
    this.requestId,
  });

  final String? requestId;
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
    this.requestId,
    this.targetWard = '',
    this.targetDivision = '',
  });

  final String title;
  final String body;
  final AnnouncementType type;
  final String department;
  final String targetLabel;
  final String? requestId;
  final String targetWard;
  final String targetDivision;
}

class AppController extends ChangeNotifier {
  AppController(this._repository, {AuthRepository? auth}) : _auth = auth {
    _auth?.addListener(_authChanged);
  }

  final AuthRepository? _auth;
  final Map<String, String> _demoPasswords = {};
  bool get isDemoAuth => _auth == null;
  bool get needsPasswordRecovery => _auth?.needsPasswordRecovery ?? false;
  String get sessionKey =>
      '${_currentUser?.id ?? "signed-out"}:${_currentUser?.role.name}:${_currentUser?.onboardingComplete}:$needsPasswordRecovery';

  bool get usesPersistentData => _repository.isPersistent;
  int _sessionGeneration = 0;
  int _refreshSequence = 0;
  int _projectReadSequence = 0;
  int _announcementReadSequence = 0;
  int _announcementOffset = 0;
  int _announcementTotal = 0;
  bool get hasMoreAnnouncements => _announcementOffset < _announcementTotal;
  int _dataRevision = 0;
  int get dataRevision => _dataRevision;
  Future<void>? _sessionLoad;
  bool _disposed = false;

  void _authChanged() {
    final incoming = _auth!.currentUser;
    final changed = incoming?.id != _currentUser?.id;
    if (incoming != null && !changed) {
      _currentUser = _currentUser!.copyWith(
        email: incoming.email,
        role: usesPersistentData ? _currentUser!.role : incoming.role,
        isActive: incoming.isActive,
      );
    } else {
      _currentUser = incoming;
    }
    if (changed && usesPersistentData) {
      _sessionGeneration++;
      _clearSessionData();
      if (!_bootstrapInProgress) {
        _sessionLoad = _loadSession();
      }
    }
    notifyListeners();
  }

  void _clearSessionData() {
    _users = [];
    _departments = [];
    _reports = [];
    _notifications = [];
    _projects = [];
    ++_announcementReadSequence;
    _announcementOffset = 0;
    _announcementTotal = 0;
    _announcements = [];
    _feedItems = [];
    _proposals = [];
    _consultations = [];
  }

  Future<void> _loadSession() async {
    final generation = _sessionGeneration;
    isLoading = true;
    startupError = null;
    try {
      await refreshData();
    } catch (_) {
      if (generation == _sessionGeneration && !_disposed) {
        startupError = 'We could not load your account. Please try again.';
      }
    } finally {
      if (generation == _sessionGeneration && !_disposed) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  void _applyData(InitialCivicData data) {
    ++_dataRevision;
    ++_projectReadSequence;
    _authorities = data.authorities;
    _departments = data.departments;
    _users = data.users;
    _projects = data.projects;
    _reports = data.reports;
    ++_announcementReadSequence;
    _announcementOffset = data.announcements.length;
    _announcementTotal = data.announcementTotal;
    _announcements = data.announcements;
    _feedItems = data.feedItems;
    _proposals = data.proposals;
    _consultations = data.consultations;
    _notifications = data.notifications;
    if (usesPersistentData && _currentUser != null && !isGuest) {
      final profile = _firstOrNull(_users, (u) => u.id == _currentUser!.id);
      if (profile == null || !profile.isActive) {
        _clearSessionData();
        throw const CivicFailure('Your account is unavailable.');
      }
      _currentUser = profile;
    }
  }

  Future<void> refreshData() async {
    final sequence = ++_refreshSequence;
    final generation = _sessionGeneration;
    final data = await _repository.loadInitialData();
    if (_disposed ||
        generation != _sessionGeneration ||
        sequence != _refreshSequence) {
      return;
    }
    _applyData(data);
    notifyListeners();
  }

  Future<String> uploadReportPhoto(String name, Uint8List bytes) =>
      _repository.uploadReportPhoto(name, bytes);
  Future<String?> reportPhotoUrl(String path) =>
      _repository.reportPhotoUrl(path);

  @override
  void dispose() {
    _disposed = true;
    _sessionGeneration++;
    _auth?.removeListener(_authChanged);
    _auth?.dispose();
    super.dispose();
  }

  final CivicRepository _repository;
  final Random _random = Random();

  bool isLoading = true;
  String? startupError;
  bool _bootstrapInProgress = false;
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
    if (_bootstrapInProgress) return;
    _bootstrapInProgress = true;
    isLoading = true;
    startupError = null;
    notifyListeners();
    try {
      await _auth?.initialize();
      await refreshData();
    } on AuthenticationFailure catch (error) {
      startupError = error.message;
    } catch (_) {
      startupError = 'We could not load Smart Sabha. Please try again.';
    } finally {
      _bootstrapInProgress = false;
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    if (_auth != null) {
      await _auth.signIn(email: email, password: password);
      _authChanged();
      await _sessionLoad;
      return;
    }
    final normalizedEmail = email.trim().toLowerCase();
    final match = _firstOrNull(
      _users,
      (user) => user.email.toLowerCase() == normalizedEmail,
    );
    if (match == null ||
        !match.isActive ||
        password != (_demoPasswords[match.id] ?? 'demo12345')) {
      throw const AuthenticationFailure('Email or password is incorrect.');
    }
    _currentUser = match;
    notifyListeners();
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (password.length < 8) {
      throw const AuthenticationFailure('Use at least 8 characters.');
    }
    if (_auth != null) {
      final confirmationRequired = await _auth.register(
        fullName: fullName,
        email: email,
        password: password,
      );
      _authChanged();
      await _sessionLoad;
      return confirmationRequired;
    }
    if (_users.any(
      (user) => user.email.toLowerCase() == email.trim().toLowerCase(),
    )) {
      throw const AuthenticationFailure(
        'An account with this email already exists.',
      );
    }
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
    await _commit(CivicChanges(users: [user]));
    _demoPasswords[user.id] = password;
    _currentUser = _users.firstWhere((item) => item.id == user.id);
    notifyListeners();
    return false;
  }

  void continueAsGuest() {
    if (usesPersistentData) {
      if (_auth?.currentUser != null) return;
      _sessionGeneration++;
      _clearSessionData();
    }
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

  Future<void> signOut() async {
    if (_auth != null && !isGuest) await _auth.signOut();
    _currentUser = null;
    await _sessionLoad;
    notifyListeners();
  }

  Future<void> sendPasswordReset(String email) async {
    if (_auth == null) {
      throw const AuthenticationFailure(
        'Password-reset emails are unavailable in demo mode.',
      );
    }
    await _auth.sendPasswordReset(email);
  }

  Future<void> updatePassword(String password) async {
    if (_auth == null || !needsPasswordRecovery) {
      throw const AuthenticationFailure(
        'Open a valid password-reset link from your email first.',
      );
    }
    if (password.length < 8) {
      throw const AuthenticationFailure('Use at least 8 characters.');
    }
    await _auth.updatePassword(password);
  }

  Future<void> completeOnboarding(OnboardingDraft draft) async {
    final user = _currentUser;
    if (user == null) return;
    final updated = user.copyWith(
      fullName: draft.fullName,
      preferredLanguage: draft.language,
      phone: draft.phone,
      localAuthorityId: draft.localAuthorityId,
      ward: draft.ward,
      gnDivision: draft.gnDivision,
      residentialArea: draft.residentialArea,
      onboardingComplete: true,
    );
    await _commit(CivicChanges(users: [updated]));
    if (usesPersistentData) await refreshData();
    notifyListeners();
  }

  Future<void> updateProfile({
    required String fullName,
    required String phone,
    required String preferredLanguage,
  }) async {
    final user = _currentUser;
    if (user == null || user.isGuest) return;
    final updated = user.copyWith(
      fullName: fullName,
      phone: phone,
      preferredLanguage: preferredLanguage,
    );
    await _commit(CivicChanges(users: [updated]));
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

  Future<void> toggleProjectFollow(String projectId) async {
    final user = _currentUser;
    if (user == null || user.isGuest) return;
    final project = projectById(projectId);
    if (project == null) return;
    if (!user.isActive) {
      throw const CivicFailure('Your account is unavailable.');
    }
    final generation = _sessionGeneration;
    ++_projectReadSequence;
    final saved = await _repository.followProject(
      project,
      user.id,
      !project.followerIds.contains(user.id),
    );
    _checkSession(generation);
    ++_projectReadSequence;
    _projects = _mergeRecords(_projects, [saved], (p) => p.id);
    notifyListeners();
  }

  Future<void> toggleReportFollow(String reportId) async {
    final user = _currentUser;
    final report = reportById(reportId);
    if (user == null || user.isGuest || report == null) return;
    final followers = Set<String>.from(report.followerIds);
    followers.contains(user.id)
        ? followers.remove(user.id)
        : followers.add(user.id);
    final generation = _sessionGeneration;
    final saved = await _repository.updateReport(
      report.copyWith(followerIds: followers),
    );
    _checkSession(generation);
    _replaceReport(saved);
    notifyListeners();
  }

  Future<void> loadMoreAnnouncements() async {
    final generation = _sessionGeneration;
    final sequence = ++_announcementReadSequence;
    final page = await _repository.listAnnouncements(
      offset: _announcementOffset,
    );
    _checkSession(generation, isMutation: false);
    if (sequence != _announcementReadSequence) return;
    _announcementOffset += page.announcements.length;
    _announcementTotal = page.total;
    _announcements = {
      for (final a in _announcements) a.id: a,
      for (final a in page.announcements) a.id: a,
    }.values.toList();
    _feedItems = {
      for (final f in _feedItems) f.id: f,
      for (final f in page.feedItems) f.id: f,
    }.values.toList();
    notifyListeners();
  }

  Future<Announcement?> fetchAnnouncement(String id) async {
    final generation = _sessionGeneration;
    final result = await _repository.getAnnouncement(id);
    _checkSession(generation, isMutation: false);
    return result;
  }

  Future<void> _updateFeed(
    String id,
    Future<FeedItem> Function(FeedItem, AppUser) action,
  ) async {
    final user = _currentUser;
    final item = _firstOrNull(_feedItems, (entry) => entry.id == id);
    if (user == null || user.isGuest || item == null) return;
    if (!user.isActive) {
      throw const CivicFailure('Your account is unavailable.');
    }
    final generation = _sessionGeneration;
    ++_announcementReadSequence;
    final saved = await action(item, user);
    _checkSession(generation);
    ++_announcementReadSequence;
    _feedItems = _mergeRecords(_feedItems, [saved], (f) => f.id);
    notifyListeners();
  }

  Future<void> toggleFeedReaction(String feedId) => _updateFeed(
    feedId,
    (item, user) => _repository.updateFeedPreference(
      item,
      user.id,
      reacted: !item.reactedUserIds.contains(user.id),
    ),
  );

  Future<void> toggleFeedSave(String feedId) => _updateFeed(
    feedId,
    (item, user) => _repository.updateFeedPreference(
      item,
      user.id,
      saved: !item.savedUserIds.contains(user.id),
    ),
  );

  Future<void> addFeedComment(
    String feedId,
    String message, {
    String? requestId,
  }) async {
    final text = message.trim();
    if (text.isEmpty || text.length > 2000) {
      throw const CivicFailure(
        'Write a comment between 1 and 2000 characters.',
      );
    }
    await _updateFeed(
      feedId,
      (item, user) => _repository.addFeedComment(
        item,
        CivicComment(
          id: requestId ?? 'c-${DateTime.now().microsecondsSinceEpoch}',
          author: user.fullName,
          message: text,
          createdAt: DateTime.now(),
          isVerified: user.isVerified,
        ),
      ),
    );
  }

  Future<CivicReport> submitReport(ReportDraft draft) async {
    final user = _currentUser;
    if (user == null || user.isGuest) {
      throw StateError('Sign in before submitting a report.');
    }
    final today = DateTime.now();
    final caseNumber = 'SS-${today.year}-${(1000 + _random.nextInt(8999))}';
    final report = CivicReport(
      id: draft.requestId ?? 'r-${today.microsecondsSinceEpoch}',
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
    final notifications = <AppNotification>[
      AppNotification(
        id: 'n-${today.microsecondsSinceEpoch}',
        title: 'Your report was submitted',
        message: '${report.caseNumber} was sent to ${report.department}.',
        category: 'Report update',
        createdAt: today,
        isRead: false,
        route: '/reports/${report.id}',
      ),
    ];
    final generation = _sessionGeneration;
    final savedReport = await _repository.createReport(
      report,
      notifications: notifications,
    );
    _checkSession(generation);
    _reports = <CivicReport>[
      savedReport,
      ..._reports.where((r) => r.id != savedReport.id),
    ];
    if (!usesPersistentData) {
      _notifications = [...notifications, ..._notifications];
    }
    notifyListeners();
    return savedReport;
  }

  Future<void> updateReportStatus({
    required String reportId,
    required ReportStatus status,
    required String department,
    required String priority,
    String? assignedOfficer,
    required String publicUpdate,
    List<String>? attachmentNames,
    String? internalNote,
    int? expectedRevision,
  }) async {
    final report = reportById(reportId);
    if (report == null) return;
    if (expectedRevision != null && expectedRevision != report.revision) {
      throw const CivicFailure(
        'This case changed. Close this editor, refresh, and review the latest update.',
      );
    }
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
    var notifications = <AppNotification>[];
    if (report.ownerUserId == _currentUser?.id ||
        report.ownerUserId == 'u-citizen') {
      notifications = <AppNotification>[
        AppNotification(
          id: 'n-admin-${now.microsecondsSinceEpoch}',
          title: 'Your report has an update',
          message: '${report.caseNumber}: $publicUpdate',
          category: 'Report update',
          createdAt: now,
          isRead: false,
          route: '/reports/$reportId',
        ),
      ];
    }
    final generation = _sessionGeneration;
    final savedReport = await _repository.updateReport(
      report.copyWith(
        status: status,
        department: department,
        priority: priority,
        assignedOfficer: assignedOfficer,
        clearAssignedOfficer: assignedOfficer == null,
        lastUpdated: now,
        attachments: attachmentNames == null
            ? report.attachments
            : <String>[...report.attachments, ...attachmentNames],
        internalNotes: internalNote == null || internalNote.trim().isEmpty
            ? report.internalNotes
            : <String>[...report.internalNotes, internalNote.trim()],
        updates: updates,
      ),
      notifications: notifications,
    );
    _checkSession(generation);
    _replaceReport(savedReport);
    if (!usesPersistentData) {
      _notifications = [...notifications, ..._notifications];
    }
    notifyListeners();
  }

  Future<void> confirmReportResolution(
    String reportId, {
    required bool resolved,
  }) async {
    final report = reportById(reportId);
    if (report == null) return;
    final now = DateTime.now();
    final message = resolved
        ? 'The resident confirmed that this issue is resolved.'
        : 'The resident reported that the issue still needs attention.';
    final generation = _sessionGeneration;
    final savedReport = await _repository.updateReport(
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
    _checkSession(generation);
    _replaceReport(savedReport);
    notifyListeners();
  }

  Future<void> addReportComment(String reportId, String message) async {
    final report = reportById(reportId);
    final user = currentUser;
    if (report == null || user == null || user.isGuest) {
      throw const CivicFailure('Sign in to comment.');
    }
    if (message.trim().isEmpty || message.trim().length > 2000) {
      throw const CivicFailure('Write a comment of up to 2,000 characters.');
    }
    final generation = _sessionGeneration;
    final saved = await _repository.updateReport(
      report.copyWith(
        comments: [
          ...report.comments,
          CivicComment(
            id: 'rc-${DateTime.now().microsecondsSinceEpoch}',
            author: user.isOfficer ? 'Authority officer' : 'Resident',
            message: message.trim(),
            createdAt: DateTime.now(),
            isVerified: user.isVerified,
          ),
        ],
      ),
    );
    _checkSession(generation);
    _replaceReport(saved);
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
    await _commit(CivicChanges(proposals: [proposal]));
    notifyListeners();
    return proposalById(proposal.id)!;
  }

  Future<void> toggleProposalSupport(String proposalId) async {
    final user = _currentUser;
    final proposal = proposalById(proposalId);
    if (user == null || user.isGuest || proposal == null) return;
    final supporters = Set<String>.from(proposal.supporterIds);
    supporters.contains(user.id)
        ? supporters.remove(user.id)
        : supporters.add(user.id);
    await _commit(
      CivicChanges(proposals: [proposal.copyWith(supporterIds: supporters)]),
    );
    notifyListeners();
  }

  Future<void> toggleProposalFollow(String proposalId) async {
    final user = _currentUser;
    final proposal = proposalById(proposalId);
    if (user == null || user.isGuest || proposal == null) return;
    final followers = Set<String>.from(proposal.followerIds);
    followers.contains(user.id)
        ? followers.remove(user.id)
        : followers.add(user.id);
    await _commit(
      CivicChanges(proposals: [proposal.copyWith(followerIds: followers)]),
    );
    notifyListeners();
  }

  Future<void> addProposalComment(String proposalId, String message) async {
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
    await _commit(
      CivicChanges(
        proposals: [
          proposal.copyWith(
            comments: <CivicComment>[...proposal.comments, comment],
          ),
        ],
      ),
    );
    notifyListeners();
  }

  Future<void> submitConsultationResponse(String consultationId) async {
    final user = _currentUser;
    final consultation = consultationById(consultationId);
    if (user == null || user.isGuest || consultation == null) return;
    final responses = Set<String>.from(consultation.respondedUserIds)
      ..add(user.id);
    final updated = consultation.copyWith(respondedUserIds: responses);
    final notifications = <AppNotification>[
      AppNotification(
        id: 'n-consult-${DateTime.now().microsecondsSinceEpoch}',
        title: 'Thank you for your response',
        message: 'Your response to ${consultation.title} was recorded.',
        category: 'Consultation',
        createdAt: DateTime.now(),
        isRead: false,
      ),
    ];
    await _commit(
      CivicChanges(consultations: [updated], notifications: notifications),
    );
    notifyListeners();
  }

  Future<void> markNotificationRead(String id) async {
    final notification = _firstOrNull(_notifications, (item) => item.id == id);
    if (notification == null || notification.isRead) return;
    await _commit(
      CivicChanges(notifications: [notification.copyWith(isRead: true)]),
    );
    notifyListeners();
  }

  Future<void> markAllNotificationsRead() async {
    final updated = _notifications
        .map((item) => item.copyWith(isRead: true))
        .toList();
    await _commit(CivicChanges(notifications: updated));
    notifyListeners();
  }

  Future<ProjectPage> searchProjects({
    String search = '',
    ProjectStatus? status,
    String sort = 'Latest',
    int offset = 0,
  }) async {
    final generation = _sessionGeneration;
    final sequence = ++_projectReadSequence;
    final page = await _repository.listProjects(
      search: search,
      status: status,
      sort: sort,
      offset: offset,
    );
    _checkSession(generation, isMutation: false);
    if (sequence == _projectReadSequence) {
      _projects = _mergeRecords(_projects, page.projects, (p) => p.id);
    }
    notifyListeners();
    return page;
  }

  Future<void> loadProject(String id) async {
    final generation = _sessionGeneration;
    final sequence = ++_projectReadSequence;
    final project = await _repository.getProject(id);
    _checkSession(generation, isMutation: false);
    if (project != null && sequence == _projectReadSequence) {
      _projects = _mergeRecords(_projects, [project], (p) => p.id);
    }
    notifyListeners();
  }

  Future<void> saveProject(Project project) async {
    if (!isOfficer || _currentUser?.isActive != true) {
      throw const CivicFailure('An active officer account is required.');
    }
    ++_projectReadSequence;
    await _commit(CivicChanges(projects: [project]));
    ++_projectReadSequence;
    notifyListeners();
  }

  Future<Project> createProject(ProjectDraft draft) async {
    final project = buildProject(draft);
    await saveProject(project);
    return projectById(project.id)!;
  }

  Project buildProject(ProjectDraft draft) {
    final now = DateTime.now();
    final project = Project(
      id: 'p-${now.microsecondsSinceEpoch}',
      authorityId: _currentUser?.localAuthorityId ?? '',
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
    return project;
  }

  Future<Announcement> createAnnouncement(
    AnnouncementDraft draft, {
    bool publishNow = false,
  }) async {
    final announcement = Announcement(
      id: draft.requestId ?? 'a-${DateTime.now().microsecondsSinceEpoch}',
      authorityId: _currentUser?.localAuthorityId ?? '',
      targetWard: draft.targetWard,
      targetDivision: draft.targetDivision,
      title: draft.title,
      body: draft.body,
      type: draft.type,
      department: draft.department,
      publishedAt: DateTime.now(),
      targetLabel: draft.targetLabel,
      isPinned: false,
      isPublished: publishNow,
    );
    var notifications = <AppNotification>[];
    if (publishNow && !usesPersistentData) {
      notifications = <AppNotification>[
        AppNotification(
          id: 'n-announcement-${DateTime.now().microsecondsSinceEpoch}',
          title: 'New local announcement',
          message: announcement.title,
          category: 'Announcement',
          createdAt: DateTime.now(),
          isRead: false,
          route: '/announcements/${announcement.id}',
        ),
      ];
    }
    await _commit(
      CivicChanges(announcements: [announcement], notifications: notifications),
    );
    notifyListeners();
    return announcementById(announcement.id)!;
  }

  Future<void> publishAnnouncement(String announcementId) async {
    final announcement = announcementById(announcementId);
    if (announcement == null) return;
    final published = announcement.copyWith(isPublished: true);
    await _commit(CivicChanges(announcements: [published]));
    notifyListeners();
  }

  Future<void> saveAnnouncement(Announcement announcement) async {
    await _commit(CivicChanges(announcements: [announcement]));
    notifyListeners();
  }

  Future<void> toggleUserActive(String userId) async {
    final user = _firstOrNull(_users, (item) => item.id == userId);
    if (user == null) return;
    await _commit(
      CivicChanges(users: [user.copyWith(isActive: !user.isActive)]),
    );
    notifyListeners();
  }

  Future<void> changeUserRole(String userId, UserRole role) async {
    final user = _firstOrNull(_users, (item) => item.id == userId);
    if (user == null) return;
    await _commit(CivicChanges(users: [user.copyWith(role: role)]));
    notifyListeners();
  }

  Future<void> updateDepartment(Department department) async {
    await _commit(CivicChanges(departments: [department]));
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

  void _checkSession(int generation, {bool isMutation = true}) {
    if (_disposed || generation != _sessionGeneration) {
      throw const CivicFailure(
        'Your session changed. Sign in again to check the saved result.',
      );
    }
    if (isMutation) _refreshSequence++;
  }

  void _replaceReport(CivicReport updated) {
    _reports = _reports
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
  }

  Future<void> _commit(CivicChanges changes) async {
    final generation = _sessionGeneration;
    if (changes.announcements.isNotEmpty) ++_announcementReadSequence;
    final saved = await _repository.saveChanges(changes);
    _checkSession(generation);
    if (saved.announcements.isNotEmpty) {
      ++_announcementReadSequence;
      final newCount = saved.announcements
          .where((a) => announcementById(a.id) == null)
          .length;
      _announcementOffset += newCount;
      _announcementTotal += newCount;
      final unpublished = saved.announcements
          .where((a) => !a.isPublished)
          .map((a) => a.id)
          .toSet();
      _feedItems = _feedItems
          .where((f) => !unpublished.contains(f.id))
          .toList();
    }
    _announcements = _mergeRecords(
      _announcements,
      saved.announcements,
      (item) => item.id,
    );
    _users = _mergeRecords(_users, saved.users, (item) => item.id);
    _departments = _mergeRecords(
      _departments,
      saved.departments,
      (item) => item.id,
    );
    _projects = _mergeRecords(_projects, saved.projects, (item) => item.id);
    _feedItems = _mergeRecords(_feedItems, saved.feedItems, (item) => item.id);
    _proposals = _mergeRecords(_proposals, saved.proposals, (item) => item.id);
    _consultations = _mergeRecords(
      _consultations,
      saved.consultations,
      (item) => item.id,
    );
    _notifications = _mergeRecords(
      _notifications,
      saved.notifications,
      (item) => item.id,
    );
    final current = _currentUser;
    if (current != null) {
      _currentUser =
          _firstOrNull(saved.users, (user) => user.id == current.id) ?? current;
    }
  }

  List<T> _mergeRecords<T>(
    List<T> current,
    List<T> changed,
    String Function(T) id,
  ) {
    final byId = {for (final item in changed) id(item): item};
    final existingIds = current.map(id).toSet();
    return [
      ...changed.where((item) => !existingIds.contains(id(item))),
      ...current.map((item) => byId[id(item)] ?? item),
    ];
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
