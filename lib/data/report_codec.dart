import '../models/domain_models.dart';

typedef Json = Map<String, dynamic>;
List<String> strings(dynamic value) => (value as List? ?? []).cast<String>();
List<Json> objects(dynamic value) =>
    (value as List? ?? []).map((e) => Json.from(e as Map)).toList();

Json userToJson(AppUser user) => {
  'id': user.id,
  'fullName': user.fullName,
  'email': user.email,
  'role': user.role.name,
  'localAuthorityId': user.localAuthorityId,
  'ward': user.ward,
  'gnDivision': user.gnDivision,
  'phone': user.phone,
  'preferredLanguage': user.preferredLanguage,
  'onboardingComplete': user.onboardingComplete,
  'isActive': user.isActive,
  'residentialArea': user.residentialArea == null
      ? null
      : {
          'latitude': user.residentialArea!.latitude,
          'longitude': user.residentialArea!.longitude,
        },
};

AppUser userFromJson(Json data) => AppUser(
  id: data['id'] as String,
  fullName: data['fullName'] as String,
  email: data['email'] as String? ?? '',
  role: UserRole.values.byName(data['role'] as String),
  localAuthorityId: data['localAuthorityId'] as String? ?? '',
  ward: data['ward'] as String? ?? '',
  gnDivision: data['gnDivision'] as String? ?? '',
  phone: data['phone'] as String? ?? '',
  preferredLanguage: data['preferredLanguage'] as String? ?? 'en',
  onboardingComplete: data['onboardingComplete'] == true,
  isActive: data['isActive'] == true,
  residentialArea: data['residentialArea'] == null
      ? null
      : pointFromJson(Json.from(data['residentialArea'] as Map)),
);

GeoPoint pointFromJson(Json data) => GeoPoint(
  (data['latitude'] as num).toDouble(),
  (data['longitude'] as num).toDouble(),
);

Json reportToJson(CivicReport report) => {
  'id': report.id,
  'caseNumber': report.caseNumber,
  'title': report.title,
  'description': report.description,
  'category': report.category,
  'locationLabel': report.locationLabel,
  'location': {
    'latitude': report.location.latitude,
    'longitude': report.location.longitude,
  },
  'status': report.status.name,
  'priority': report.priority,
  'submittedAt': report.submittedAt.toUtc().toIso8601String(),
  'lastUpdated': report.lastUpdated.toUtc().toIso8601String(),
  'department': report.department,
  'ownerUserId': report.ownerUserId,
  'assignedOfficer': report.assignedOfficer,
  'attachments': report.attachments,
  'updates': report.updates
      .map(
        (u) => {
          'status': u.status.name,
          'message': u.message,
          'date': u.date.toUtc().toIso8601String(),
          'isPublic': u.isPublic,
        },
      )
      .toList(),
  'followerIds': report.followerIds.toList(),
  'internalNotes': report.internalNotes,
  'revision': report.revision,
  'comments': report.comments
      .map(
        (c) => {
          'id': c.id,
          'author': c.author,
          'message': c.message,
          'createdAt': c.createdAt.toUtc().toIso8601String(),
          'isVerified': c.isVerified,
        },
      )
      .toList(),
};

CivicReport reportFromJson(Json data) => CivicReport(
  id: data['id'] as String,
  caseNumber: data['caseNumber'] as String,
  title: data['title'] as String,
  description: data['description'] as String,
  category: data['category'] as String,
  locationLabel: data['locationLabel'] as String,
  location: pointFromJson(Json.from(data['location'] as Map)),
  status: ReportStatus.values.byName(data['status'] as String),
  priority: data['priority'] as String,
  submittedAt: DateTime.parse(data['submittedAt'] as String),
  lastUpdated: DateTime.parse(data['lastUpdated'] as String),
  department: data['department'] as String,
  ownerUserId: data['ownerUserId'] as String,
  assignedOfficer: data['assignedOfficer'] as String?,
  attachments: strings(data['attachments']),
  updates: objects(data['updates'])
      .map(
        (u) => ReportUpdate(
          status: ReportStatus.values.byName(u['status'] as String),
          message: u['message'] as String,
          date: DateTime.parse(u['date'] as String),
          isPublic: u['isPublic'] == true,
        ),
      )
      .toList(),
  followerIds: strings(data['followerIds']).toSet(),
  internalNotes: strings(data['internalNotes']),
  revision: data['revision'] as int? ?? 0,
  comments: objects(data['comments'])
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

AppNotification notificationFromJson(Json data) => AppNotification(
  id: data['id'] as String,
  title: data['title'] as String,
  message: data['message'] as String,
  category: data['category'] as String,
  createdAt: DateTime.parse(data['createdAt'] as String),
  isRead: data['isRead'] == true,
  route: data['route'] as String?,
);
