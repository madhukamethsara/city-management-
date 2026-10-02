import '../models/domain_models.dart';
import 'report_codec.dart';

Json announcementToJson(Announcement a) => {
  'id': a.id,
  'authorityId': a.authorityId,
  'revision': a.revision,
  'title': a.title,
  'body': a.body,
  'type': a.type.name,
  'department': a.department,
  'targetLabel': a.targetLabel,
  'targetWard': a.targetWard,
  'targetDivision': a.targetDivision,
  'isPinned': a.isPinned,
  'isPublished': a.isPublished,
};

Announcement announcementFromJson(Json a) => Announcement(
  id: a['id'] as String,
  authorityId: a['authorityId'] as String,
  revision: a['revision'] as int,
  title: a['title'] as String,
  body: a['body'] as String,
  type: AnnouncementType.values.byName(a['type'] as String),
  department: a['department'] as String,
  publishedAt: DateTime.parse(a['publishedAt'] as String),
  targetLabel: a['targetLabel'] as String,
  targetWard: a['targetWard'] as String? ?? '',
  targetDivision: a['targetDivision'] as String? ?? '',
  isPinned: a['isPinned'] == true,
  isPublished: a['isPublished'] == true,
);

FeedItem feedFromJson(Json f) => FeedItem(
  id: f['id'] as String,
  title: f['title'] as String,
  body: f['body'] as String,
  kind: 'Announcement',
  department: f['department'] as String,
  locationLabel: f['targetLabel'] as String,
  date: DateTime.parse(f['publishedAt'] as String),
  reactionCount: f['reactionCount'] as int,
  commentCount: f['commentCount'] as int,
  reactedUserIds: strings(f['reactedUserIds']).toSet(),
  savedUserIds: strings(f['savedUserIds']).toSet(),
  comments: objects(f['comments'])
      .map(
        (c) => CivicComment(
          id: c['id'] as String,
          author: c['author'] as String,
          message: c['message'] as String,
          createdAt: DateTime.parse(c['createdAt'] as String),
          isVerified: c['isVerified'] == true,
        ),
      )
      .toList(),
);
