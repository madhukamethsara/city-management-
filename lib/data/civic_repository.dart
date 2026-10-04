import 'dart:typed_data';

import '../models/domain_models.dart';

/// Data boundary for loading and saving civic records.
/// Production adapters must enforce authentication and authority-scoped access.
abstract class CivicRepository {
  bool get isPersistent => false;

  Future<AppUser> manageUser(AppUser user, AppUser expected) async =>
      (await saveChanges(CivicChanges(users: [user]))).users.single;

  Future<AnnouncementPage> listAnnouncements({int offset = 0}) async {
    final data = await loadInitialData();
    return AnnouncementPage(
      announcements: data.announcements.skip(offset).take(25).toList(),
      feedItems: data.feedItems,
      total: data.announcements.length,
    );
  }

  Future<Announcement?> getAnnouncement(String id) async {
    final data = await loadInitialData();
    for (final a in data.announcements) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<FeedItem> updateFeedPreference(
    FeedItem item,
    String userId, {
    bool? reacted,
    bool? saved,
  }) async {
    final reactions = Set<String>.from(item.reactedUserIds);
    final saves = Set<String>.from(item.savedUserIds);
    if (reacted != null) {
      reacted ? reactions.add(userId) : reactions.remove(userId);
    }
    if (saved != null) {
      saved ? saves.add(userId) : saves.remove(userId);
    }
    return (await saveChanges(
      CivicChanges(
        feedItems: [
          item.copyWith(
            reactionCount:
                item.reactionCount +
                reactions.length -
                item.reactedUserIds.length,
            reactedUserIds: reactions,
            savedUserIds: saves,
          ),
        ],
      ),
    )).feedItems.single;
  }

  Future<FeedItem> addFeedComment(FeedItem item, CivicComment comment) async {
    if (item.comments.any((c) => c.id == comment.id)) return item;
    return (await saveChanges(
      CivicChanges(
        feedItems: [
          item.copyWith(
            commentCount: item.commentCount + 1,
            comments: [...item.comments, comment],
          ),
        ],
      ),
    )).feedItems.single;
  }

  Future<ProjectPage> listProjects({
    String search = '',
    ProjectStatus? status,
    String sort = 'Latest',
    int offset = 0,
    int limit = 25,
  }) async {
    final data = await loadInitialData();
    final query = search.trim().toLowerCase();
    final items = data.projects
        .where(
          (p) =>
              (status == null || p.status == status) &&
              [
                p.title,
                p.description,
                p.category,
                p.locationLabel,
              ].join(' ').toLowerCase().contains(query),
        )
        .toList();
    items.sort((a, b) {
      final order = switch (sort) {
        'A-Z' => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        'Most progress' => b.progress.compareTo(a.progress),
        'Completion date' => a.expectedCompletion.compareTo(
          b.expectedCompletion,
        ),
        _ => b.startDate.compareTo(a.startDate),
      };
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
    return ProjectPage(
      projects: items.skip(offset).take(limit).toList(),
      total: items.length,
    );
  }

  Future<Project?> getProject(String id) async {
    final data = await loadInitialData();
    for (final project in data.projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  Future<Project> followProject(
    Project project,
    String userId,
    bool following,
  ) async {
    final ids = Set<String>.from(project.followerIds);
    following ? ids.add(userId) : ids.remove(userId);
    final saved = await saveChanges(
      CivicChanges(projects: [project.copyWith(followerIds: ids)]),
    );
    return saved.projects.single;
  }

  Future<String> uploadReportPhoto(String name, Uint8List bytes) async => name;
  Future<String?> reportPhotoUrl(String path) async => null;

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

class ProjectPage {
  const ProjectPage({required this.projects, required this.total});
  final List<Project> projects;
  final int total;
}

class AnnouncementPage {
  const AnnouncementPage({
    required this.announcements,
    required this.feedItems,
    required this.total,
  });
  final List<Announcement> announcements;
  final List<FeedItem> feedItems;
  final int total;
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
    this.announcementTotal = 0,
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
  final int announcementTotal;
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
