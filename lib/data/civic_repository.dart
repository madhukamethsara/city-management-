import '../models/domain_models.dart';

/// Data boundary for loading and saving civic records.
/// Production adapters must enforce authentication and authority-scoped access.
abstract class CivicRepository {
  /// Atomically upserts these records and returns their saved values, preserving IDs.
  /// Empty collections leave existing records unchanged. A failed operation
  /// must not commit any records. Adapters must enforce permissions server-side.
  Future<CivicChanges> saveChanges(CivicChanges changes);

  Future<InitialCivicData> loadInitialData();

  /// Creates a report and its notifications atomically, returning the saved report.
  /// Must reject an existing ID. Failures must not commit a partial write.
  Future<CivicReport> createReport(
    CivicReport report, {
    List<AppNotification> notifications = const [],
  });

  /// Updates a report and its notifications atomically, returning the saved report.
  /// Must reject an unknown ID. Failures must not commit a partial write.
  Future<CivicReport> updateReport(
    CivicReport report, {
    List<AppNotification> notifications = const [],
  });
}

class InitialCivicData {
  const InitialCivicData({
    required this.authorities,
    required this.departments,
    required this.users,
    required this.projects,
    required this.reports,
    required this.announcements,
    required this.feedItems,
    required this.proposals,
    required this.consultations,
    required this.notifications,
  });

  final List<LocalAuthority> authorities;
  final List<Department> departments;
  final List<AppUser> users;
  final List<Project> projects;
  final List<CivicReport> reports;
  final List<Announcement> announcements;
  final List<FeedItem> feedItems;
  final List<Proposal> proposals;
  final List<Consultation> consultations;
  final List<AppNotification> notifications;
}

/// A batch of related civic records to save together.
class CivicChanges {
  const CivicChanges({
    this.announcements = const [],
    this.users = const [],
    this.departments = const [],
    this.projects = const [],
    this.feedItems = const [],
    this.proposals = const [],
    this.consultations = const [],
    this.notifications = const [],
  });

  final List<Announcement> announcements;
  final List<AppUser> users;
  final List<Department> departments;
  final List<Project> projects;
  final List<FeedItem> feedItems;
  final List<Proposal> proposals;
  final List<Consultation> consultations;
  final List<AppNotification> notifications;
}
