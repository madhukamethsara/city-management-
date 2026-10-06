import '../models/domain_models.dart';
import 'report_codec.dart';

Json proposalToJson(Proposal p) => {
  'id': p.id,
  'title': p.title,
  'description': p.description,
  'category': p.category,
  'locationLabel': p.locationLabel,
  'expectedBenefit': p.expectedBenefit,
  'attachments': p.attachments,
};

Proposal proposalFromJson(Json p) => Proposal(
  id: p['id'] as String,
  title: p['title'] as String,
  description: p['description'] as String,
  category: p['category'] as String,
  locationLabel: p['locationLabel'] as String,
  expectedBenefit: p['expectedBenefit'] as String,
  status: ProposalStatus.values.byName(p['status'] as String),
  author: p['author'] as String,
  createdAt: DateTime.parse(p['createdAt'] as String),
  attachments: strings(p['attachments']),
  supporterIds: strings(p['supporterIds']).toSet(),
  followerIds: strings(p['followerIds']).toSet(),
  supportCount: p['supportCount'] as int,
  revision: p['revision'] as int,
  comments: objects(p['comments'])
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

Json consultationToJson(Consultation c) => {
  'id': c.id,
  'title': c.title,
  'description': c.description,
  'department': c.department,
  'openingDate': c.openingDate.toUtc().toIso8601String(),
  'closingDate': c.closingDate.toUtc().toIso8601String(),
  'questions': c.questions
      .map(
        (q) => {
          'id': q.id,
          'question': q.question,
          'options': q.options,
          'allowsLongText': q.allowsLongText,
        },
      )
      .toList(),
};

Consultation consultationFromJson(Json c) => Consultation(
  id: c['id'] as String,
  title: c['title'] as String,
  description: c['description'] as String,
  department: c['department'] as String,
  openingDate: DateTime.parse(c['openingDate'] as String),
  closingDate: DateTime.parse(c['closingDate'] as String),
  questions: objects(c['questions'])
      .map(
        (q) => ConsultationQuestion(
          id: q['id'] as String,
          question: q['question'] as String,
          options: strings(q['options']),
          allowsLongText: q['allowsLongText'] == true,
        ),
      )
      .toList(),
  respondedUserIds: strings(c['respondedUserIds']).toSet(),
  responseCount: c['responseCount'] as int,
  answers: {
    for (final entry in Json.from(c['answers'] as Map? ?? {}).entries)
      entry.key: Map<String, String>.from(entry.value as Map),
  },
);
