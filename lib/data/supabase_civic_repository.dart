import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/domain_models.dart';
import 'civic_failure.dart';
import 'civic_repository.dart';
import 'report_codec.dart';
import 'project_codec.dart';
import 'announcement_codec.dart';

/// Connected release: profiles, reports, projects, evidence, and notifications.
/// Unsupported civic modules never fall back to in-memory writes.
class SupabaseCivicRepository extends CivicRepository {
  SupabaseCivicRepository({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;
  SupabaseClient get client => _client ?? Supabase.instance.client;
  @override
  bool get isPersistent => true;

  @override
  Future<AppUser> manageUser(AppUser user, AppUser expected) =>
      _perform(() async {
        final saved = await client.rpc(
          'civic_manage_user',
          params: {
            'payload': userToJson(user),
            'expected_role': expected.role.name,
            'expected_active': expected.isActive,
          },
        );
        return userFromJson(Json.from(saved as Map));
      });

  Future<T> _perform<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on CivicFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw CivicFailure(switch (error.code) {
        '40001' =>
          'This record changed. Refresh the page, review the latest update, and try again.',
        '42501' =>
          'You do not have permission for this action. Check your account and local authority.',
        '23505' =>
          'This request was already saved. Refresh to see the latest version.',
        '23503' =>
          'This department still owns reports, projects or announcements. Reassign those records before removal.',
        '22023' => 'Check the required fields and try again.',
        _ => 'Could not save or load civic data. Please try again.',
      });
    } catch (_) {
      throw const CivicFailure(
        'Unable to connect. Your changes have not been confirmed. Please try again.',
      );
    }
  }

  Map<String, dynamic> _departmentPayload(Department d) => {
    'id': d.id,
    'name': d.name,
    'headName': d.headName,
    'officerCount': d.officerCount,
    'categories': d.categories,
  };

  @override
  Future<Department> createDepartment(Department department) =>
      _perform(() async {
        final saved = Json.from(
          await client.rpc(
                'civic_create_department',
                params: {'payload': _departmentPayload(department)},
              )
              as Map,
        );
        return Department(
          id: saved['id'] as String,
          name: saved['name'] as String,
          headName: saved['headName'] as String,
          officerCount: saved['officerCount'] as int,
          categories: strings(saved['categories']),
        );
      });

  @override
  Future<void> removeDepartment(Department department) => _perform(() async {
    await client.rpc(
      'civic_remove_department',
      params: {'payload': _departmentPayload(department)},
    );
  });

  @override
  Future<InitialCivicData> loadInitialData() => _perform(() async {
    final data = Json.from(await client.rpc('civic_bootstrap') as Map);
    final projectPage = await listProjects();
    final announcementPage = await listAnnouncements();
    return InitialCivicData(
      authorities: objects(data['authorities'])
          .map(
            (a) => LocalAuthority(
              id: a['id'] as String,
              name: a['name'] as String,
              type: a['type'] as String,
              district: a['district'] as String,
              province: a['province'] as String,
              center: pointFromJson(Json.from(a['center'] as Map)),
            ),
          )
          .toList(),
      departments: objects(data['departments'])
          .map(
            (d) => Department(
              id: d['id'] as String,
              name: d['name'] as String,
              headName: d['headName'] as String? ?? '',
              categories: strings(d['categories']),
              officerCount: d['officerCount'] as int? ?? 0,
            ),
          )
          .toList(),
      users: objects(data['users']).map(userFromJson).toList(),
      reports: objects(data['reports']).map(reportFromJson).toList(),
      notifications: objects(
        data['notifications'],
      ).map(notificationFromJson).toList(),
      projects: projectPage.projects,
      announcements: announcementPage.announcements,
      feedItems: announcementPage.feedItems,
      announcementTotal: announcementPage.total,
      proposals: const [],
      consultations: const [],
    );
  });

  @override
  Future<CivicChanges> saveChanges(CivicChanges changes) => _perform(() async {
    if (changes.departments.isNotEmpty) {
      if (changes.departments.length != 1 ||
          changes.users.isNotEmpty ||
          changes.projects.isNotEmpty ||
          changes.announcements.isNotEmpty ||
          changes.notifications.isNotEmpty ||
          changes.feedItems.isNotEmpty ||
          changes.proposals.isNotEmpty ||
          changes.consultations.isNotEmpty) {
        throw const CivicFailure('Save one department at a time.');
      }
      final d = changes.departments.single;
      final saved = Json.from(
        await client.rpc(
              'civic_save_department',
              params: {
                'payload': {
                  'id': d.id,
                  'name': d.name,
                  'headName': d.headName,
                  'officerCount': d.officerCount,
                  'categories': d.categories,
                },
              },
            )
            as Map,
      );
      return CivicChanges(
        departments: [
          Department(
            id: saved['id'] as String,
            name: saved['name'] as String,
            headName: saved['headName'] as String,
            officerCount: saved['officerCount'] as int,
            categories: strings(saved['categories']),
          ),
        ],
      );
    }
    if (changes.feedItems.isNotEmpty ||
        changes.proposals.isNotEmpty ||
        changes.consultations.isNotEmpty) {
      throw const CivicFailure(
        'This service is not available in the connected release yet.',
      );
    }
    if (changes.announcements.isNotEmpty) {
      if (changes.announcements.length != 1 ||
          changes.users.isNotEmpty ||
          changes.projects.isNotEmpty ||
          changes.notifications.isNotEmpty) {
        throw const CivicFailure('Save one announcement at a time.');
      }
      final saved = Json.from(
        await client.rpc(
              'civic_save_announcement',
              params: {
                'payload': announcementToJson(changes.announcements.single),
              },
            )
            as Map,
      );
      return CivicChanges(
        announcements: [announcementFromJson(saved)],
        feedItems: saved['isPublished'] == true ? [feedFromJson(saved)] : [],
      );
    }
    if (changes.projects.isNotEmpty) {
      if (changes.projects.length != 1 ||
          changes.users.isNotEmpty ||
          changes.notifications.isNotEmpty) {
        throw const CivicFailure('Save one project at a time.');
      }
      final saved = await client.rpc(
        'civic_save_project',
        params: {'payload': projectToJson(changes.projects.single)},
      );
      return CivicChanges(projects: [projectFromJson(Json.from(saved as Map))]);
    }
    final data = Json.from(
      await client.rpc(
            'civic_save_profile_notifications',
            params: {
              'profiles': changes.users.map(userToJson).toList(),
              'read_notifications': changes.notifications
                  .map((n) => {'id': n.id, 'isRead': n.isRead})
                  .toList(),
            },
          )
          as Map,
    );
    return CivicChanges(
      users: objects(data['users']).map(userFromJson).toList(),
      notifications: objects(
        data['notifications'],
      ).map(notificationFromJson).toList(),
    );
  });

  @override
  Future<AnnouncementPage> listAnnouncements({int offset = 0}) =>
      _perform(() async {
        final data = Json.from(
          await client.rpc(
                'civic_list_announcements',
                params: {'page_offset': offset, 'page_size': 25},
              )
              as Map,
        );
        final records = objects(data['announcements']);
        return AnnouncementPage(
          announcements: records.map(announcementFromJson).toList(),
          feedItems: records
              .where((a) => a['isPublished'] == true)
              .map(feedFromJson)
              .toList(),
          total: data['total'] as int,
        );
      });

  @override
  Future<Announcement?> getAnnouncement(String id) => _perform(
    () async => announcementFromJson(
      Json.from(
        await client.rpc(
              'civic_get_announcement',
              params: {'announcement_id': id},
            )
            as Map,
      ),
    ),
  );

  @override
  Future<FeedItem> updateFeedPreference(
    FeedItem item,
    String userId, {
    bool? reacted,
    bool? saved,
  }) => _perform(
    () async => feedFromJson(
      Json.from(
        await client.rpc(
              'civic_set_feed_preference',
              params: {
                'announcement_id': item.id,
                'reacted': reacted,
                'saved': saved,
              },
            )
            as Map,
      ),
    ),
  );

  @override
  Future<FeedItem> addFeedComment(FeedItem item, CivicComment comment) =>
      _perform(
        () async => feedFromJson(
          Json.from(
            await client.rpc(
                  'civic_add_feed_comment',
                  params: {
                    'announcement_id': item.id,
                    'comment_id': comment.id,
                    'message': comment.message,
                  },
                )
                as Map,
          ),
        ),
      );

  @override
  Future<ProjectPage> listProjects({
    String search = '',
    ProjectStatus? status,
    String sort = 'Latest',
    int offset = 0,
    int limit = 25,
  }) => _perform(() async {
    final result = Json.from(
      await client.rpc(
            'civic_list_projects',
            params: {
              'search_text': search.trim(),
              'status_filter': status?.name,
              'sort_order': sort,
              'page_offset': offset,
              'page_size': limit,
            },
          )
          as Map,
    );
    return ProjectPage(
      projects: objects(result['projects']).map(projectFromJson).toList(),
      total: result['total'] as int,
    );
  });

  @override
  Future<Project?> getProject(String id) => _perform(
    () async => projectFromJson(
      Json.from(
        await client.rpc('civic_get_project', params: {'project_id': id})
            as Map,
      ),
    ),
  );

  @override
  Future<Project> followProject(
    Project project,
    String userId,
    bool following,
  ) => _perform(
    () async => projectFromJson(
      Json.from(
        await client.rpc(
              'civic_follow_project',
              params: {'project_id': project.id, 'following': following},
            )
            as Map,
      ),
    ),
  );

  @override
  Future<CivicReport> createReport(
    CivicReport report, {
    List<AppNotification> notifications = const [],
  }) => _saveReport(report, true);
  @override
  Future<CivicReport> updateReport(
    CivicReport report, {
    List<AppNotification> notifications = const [],
  }) => _saveReport(report, false);

  Future<CivicReport> _saveReport(CivicReport report, bool create) => _perform(
    () async => reportFromJson(
      Json.from(
        await client.rpc(
              'civic_save_report',
              params: {'payload': reportToJson(report), 'is_new': create},
            )
            as Map,
      ),
    ),
  );

  @override
  Future<String> uploadReportPhoto(String name, Uint8List bytes) => _perform(
    () async {
      final user = client.auth.currentUser;
      if (user == null) throw const CivicFailure('Sign in to upload evidence.');
      final extension = name.split('.').last.toLowerCase();
      final contentType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => null,
      };
      if (contentType == null ||
          bytes.isEmpty ||
          bytes.length > 5 * 1024 * 1024) {
        throw const CivicFailure(
          'Choose a JPG, PNG, or WebP photo smaller than 5 MB.',
        );
      }
      final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path =
          '${user.id}/${DateTime.now().microsecondsSinceEpoch}-$safeName';
      await client.storage
          .from('report-evidence')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );
      return path;
    },
  );

  @override
  Future<String?> reportPhotoUrl(String path) => _perform(
    () => client.storage.from('report-evidence').createSignedUrl(path, 60),
  );
}
