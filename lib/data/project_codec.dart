import '../models/domain_models.dart';
import 'report_codec.dart';

Json projectToJson(Project p) => {
  'id': p.id,
  'authorityId': p.authorityId,
  'revision': p.revision,
  'title': p.title,
  'description': p.description,
  'category': p.category,
  'locationLabel': p.locationLabel,
  'location': {
    'latitude': p.location.latitude,
    'longitude': p.location.longitude,
  },
  'status': p.status.name,
  'progress': p.progress,
  'startDate': p.startDate.toUtc().toIso8601String(),
  'expectedCompletion': p.expectedCompletion.toUtc().toIso8601String(),
  'department': p.department,
  'budget': p.budget,
  'spent': p.spent,
  'isBudgetPublic': p.isBudgetPublic,
  'contractor': p.contractor,
  'projectManager': p.projectManager,
  'milestones': p.milestones
      .map(
        (m) => {
          'title': m.title,
          'description': m.description,
          'percentage': m.percentage,
          'expectedDate': m.expectedDate.toUtc().toIso8601String(),
          'completedDate': m.completedDate?.toUtc().toIso8601String(),
          'isComplete': m.isComplete,
        },
      )
      .toList(),
  'updates': p.updates
      .map(
        (u) => {
          'title': u.title,
          'message': u.message,
          'date': u.date.toUtc().toIso8601String(),
          'isPublic': u.isPublic,
        },
      )
      .toList(),
  'documents': p.documents
      .map(
        (d) => {
          'name': d.name,
          'kind': d.kind,
          'sizeLabel': d.sizeLabel,
          'url': d.url,
        },
      )
      .toList(),
};

Project projectFromJson(Json d) => Project(
  id: d['id'] as String,
  authorityId: d['authorityId'] as String,
  revision: d['revision'] as int,
  title: d['title'] as String,
  description: d['description'] as String,
  category: d['category'] as String,
  locationLabel: d['locationLabel'] as String,
  location: pointFromJson(Json.from(d['location'] as Map)),
  status: ProjectStatus.values.byName(d['status'] as String),
  progress: d['progress'] as int,
  startDate: DateTime.parse(d['startDate'] as String),
  expectedCompletion: DateTime.parse(d['expectedCompletion'] as String),
  department: d['department'] as String,
  budget: d['budget'] as int,
  spent: d['spent'] as int,
  isBudgetPublic: d['isBudgetPublic'] == true,
  contractor: d['contractor'] as String?,
  projectManager: d['projectManager'] as String?,
  milestones: objects(d['milestones'])
      .map(
        (m) => ProjectMilestone(
          title: m['title'] as String,
          description: m['description'] as String,
          percentage: m['percentage'] as int,
          expectedDate: DateTime.parse(m['expectedDate'] as String),
          completedDate: m['completedDate'] == null
              ? null
              : DateTime.parse(m['completedDate'] as String),
          isComplete: m['isComplete'] == true,
        ),
      )
      .toList(),
  updates: objects(d['updates'])
      .map(
        (u) => ProjectUpdate(
          title: u['title'] as String,
          message: u['message'] as String,
          date: DateTime.parse(u['date'] as String),
          isPublic: u['isPublic'] == true,
        ),
      )
      .toList(),
  documents: objects(d['documents'])
      .map(
        (v) => PublicDocument(
          name: v['name'] as String,
          kind: v['kind'] as String,
          sizeLabel: v['sizeLabel'] as String,
          url: v['url'] as String?,
        ),
      )
      .toList(),
  followerIds: strings(d['followerIds']).toSet(),
);
