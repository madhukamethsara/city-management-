import 'package:flutter/material.dart';

enum UserRole {
  guest,
  citizen,
  verifiedResident,
  officer,
  departmentAdmin,
  localAuthorityAdmin,
  platformAdmin,
}

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
    UserRole.guest => 'Guest',
    UserRole.citizen => 'Citizen',
    UserRole.verifiedResident => 'Verified resident',
    UserRole.officer => 'Officer',
    UserRole.departmentAdmin => 'Department admin',
    UserRole.localAuthorityAdmin => 'Local authority admin',
    UserRole.platformAdmin => 'Platform admin',
  };

  bool get canManageAuthority => switch (this) {
    UserRole.officer ||
    UserRole.departmentAdmin ||
    UserRole.localAuthorityAdmin ||
    UserRole.platformAdmin => true,
    _ => false,
  };
}

enum ProjectStatus {
  proposed,
  underReview,
  planned,
  funded,
  tendering,
  inProgress,
  paused,
  delayed,
  completed,
  cancelled,
}

extension ProjectStatusInfo on ProjectStatus {
  String get label => switch (this) {
    ProjectStatus.proposed => 'Proposed',
    ProjectStatus.underReview => 'Under review',
    ProjectStatus.planned => 'Planned',
    ProjectStatus.funded => 'Funded',
    ProjectStatus.tendering => 'Tendering',
    ProjectStatus.inProgress => 'In progress',
    ProjectStatus.paused => 'Paused',
    ProjectStatus.delayed => 'Delayed',
    ProjectStatus.completed => 'Completed',
    ProjectStatus.cancelled => 'Cancelled',
  };

  Color get color => switch (this) {
    ProjectStatus.proposed ||
    ProjectStatus.underReview => const Color(0xFF566573),
    ProjectStatus.planned ||
    ProjectStatus.funded ||
    ProjectStatus.tendering => const Color(0xFF2C6EAA),
    ProjectStatus.inProgress => const Color(0xFF087E6A),
    ProjectStatus.paused || ProjectStatus.delayed => const Color(0xFFB56900),
    ProjectStatus.completed => const Color(0xFF327343),
    ProjectStatus.cancelled => const Color(0xFFB33C32),
  };
}

enum ReportStatus {
  submitted,
  acknowledged,
  assigned,
  inProgress,
  resolved,
  rejected,
}

extension ReportStatusInfo on ReportStatus {
  String get label => switch (this) {
    ReportStatus.submitted => 'Submitted',
    ReportStatus.acknowledged => 'Acknowledged',
    ReportStatus.assigned => 'Assigned',
    ReportStatus.inProgress => 'In progress',
    ReportStatus.resolved => 'Resolved',
    ReportStatus.rejected => 'Rejected',
  };

  Color get color => switch (this) {
    ReportStatus.submitted => const Color(0xFF566573),
    ReportStatus.acknowledged => const Color(0xFF2C6EAA),
    ReportStatus.assigned => const Color(0xFF805AD5),
    ReportStatus.inProgress => const Color(0xFF087E6A),
    ReportStatus.resolved => const Color(0xFF327343),
    ReportStatus.rejected => const Color(0xFFB33C32),
  };
}

enum ProposalStatus {
  submitted,
  communityReview,
  technicalReview,
  costEstimation,
  councilReview,
  approved,
  rejected,
  convertedToProject,
}

extension ProposalStatusInfo on ProposalStatus {
  String get label => switch (this) {
    ProposalStatus.submitted => 'Submitted',
    ProposalStatus.communityReview => 'Community review',
    ProposalStatus.technicalReview => 'Technical review',
    ProposalStatus.costEstimation => 'Cost estimation',
    ProposalStatus.councilReview => 'Council review',
    ProposalStatus.approved => 'Approved',
    ProposalStatus.rejected => 'Rejected',
    ProposalStatus.convertedToProject => 'Converted to project',
  };
}

enum AnnouncementType {
  normal,
  serviceInterruption,
  roadClosure,
  emergency,
  wasteCollection,
  publicHealth,
  event,
}

extension AnnouncementTypeInfo on AnnouncementType {
  String get label => switch (this) {
    AnnouncementType.normal => 'Notice',
    AnnouncementType.serviceInterruption => 'Service interruption',
    AnnouncementType.roadClosure => 'Road closure',
    AnnouncementType.emergency => 'Emergency',
    AnnouncementType.wasteCollection => 'Waste collection',
    AnnouncementType.publicHealth => 'Public health',
    AnnouncementType.event => 'Community event',
  };

  IconData get icon => switch (this) {
    AnnouncementType.normal => Icons.campaign_outlined,
    AnnouncementType.serviceInterruption => Icons.build_circle_outlined,
    AnnouncementType.roadClosure => Icons.signpost_outlined,
    AnnouncementType.emergency => Icons.warning_amber_rounded,
    AnnouncementType.wasteCollection => Icons.delete_outline,
    AnnouncementType.publicHealth => Icons.health_and_safety_outlined,
    AnnouncementType.event => Icons.groups_outlined,
  };
}

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  String get shortLabel =>
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
}

class LocalAuthority {
  const LocalAuthority({
    required this.id,
    required this.name,
    required this.type,
    required this.district,
    required this.province,
    required this.center,
  });

  final String id;
  final String name;
  final String type;
  final String district;
  final String province;
  final GeoPoint center;
}

class Department {
  const Department({
    required this.id,
    required this.name,
    required this.headName,
    required this.categories,
    required this.officerCount,
  });

  final String id;
  final String name;
  final String headName;
  final List<String> categories;
  final int officerCount;

  Department copyWith({
    String? name,
    String? headName,
    List<String>? categories,
    int? officerCount,
  }) => Department(
    id: id,
    name: name ?? this.name,
    headName: headName ?? this.headName,
    categories: categories ?? this.categories,
    officerCount: officerCount ?? this.officerCount,
  );
}

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.localAuthorityId,
    required this.ward,
    required this.gnDivision,
    required this.phone,
    required this.preferredLanguage,
    required this.onboardingComplete,
    required this.isActive,
    this.residentialArea,
  });

  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final String localAuthorityId;
  final String ward;
  final String gnDivision;
  final String phone;
  final String preferredLanguage;
  final bool onboardingComplete;
  final bool isActive;
  final GeoPoint? residentialArea;

  bool get isGuest => role == UserRole.guest;
  bool get isOfficer => role.canManageAuthority;
  bool get isVerified =>
      role == UserRole.verifiedResident || role.canManageAuthority;
  String get firstName => fullName.trim().split(' ').first;

  AppUser copyWith({
    String? fullName,
    String? email,
    UserRole? role,
    String? localAuthorityId,
    String? ward,
    String? gnDivision,
    String? phone,
    String? preferredLanguage,
    bool? onboardingComplete,
    bool? isActive,
    GeoPoint? residentialArea,
  }) {
    return AppUser(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      localAuthorityId: localAuthorityId ?? this.localAuthorityId,
      ward: ward ?? this.ward,
      gnDivision: gnDivision ?? this.gnDivision,
      phone: phone ?? this.phone,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      isActive: isActive ?? this.isActive,
      residentialArea: residentialArea ?? this.residentialArea,
    );
  }
}

class ProjectMilestone {
  const ProjectMilestone({
    required this.title,
    required this.description,
    required this.percentage,
    required this.expectedDate,
    required this.completedDate,
    required this.isComplete,
  });

  final String title;
  final String description;
  final int percentage;
  final DateTime expectedDate;
  final DateTime? completedDate;
  final bool isComplete;
}

class ProjectUpdate {
  const ProjectUpdate({
    required this.title,
    required this.message,
    required this.date,
    required this.isPublic,
  });

  final String title;
  final String message;
  final DateTime date;
  final bool isPublic;
}

class PublicDocument {
  const PublicDocument({
    required this.name,
    required this.kind,
    required this.sizeLabel,
  });

  final String name;
  final String kind;
  final String sizeLabel;
}

class Project {
  const Project({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.locationLabel,
    required this.location,
    required this.status,
    required this.progress,
    required this.startDate,
    required this.expectedCompletion,
    required this.department,
    required this.budget,
    required this.spent,
    required this.isBudgetPublic,
    required this.milestones,
    required this.updates,
    required this.documents,
    required this.followerIds,
    this.imageLabels = const <String>[],
    this.contractor,
    this.projectManager,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String locationLabel;
  final GeoPoint location;
  final ProjectStatus status;
  final int progress;
  final DateTime startDate;
  final DateTime expectedCompletion;
  final String department;
  final int budget;
  final int spent;
  final bool isBudgetPublic;
  final List<ProjectMilestone> milestones;
  final List<ProjectUpdate> updates;
  final List<PublicDocument> documents;
  final Set<String> followerIds;
  final List<String> imageLabels;
  final String? contractor;
  final String? projectManager;

  int get remaining => budget - spent;

  Project copyWith({
    String? title,
    String? description,
    String? category,
    String? locationLabel,
    GeoPoint? location,
    ProjectStatus? status,
    int? progress,
    DateTime? startDate,
    DateTime? expectedCompletion,
    String? department,
    int? budget,
    int? spent,
    bool? isBudgetPublic,
    List<ProjectMilestone>? milestones,
    List<ProjectUpdate>? updates,
    List<PublicDocument>? documents,
    Set<String>? followerIds,
    List<String>? imageLabels,
    String? contractor,
    String? projectManager,
  }) {
    return Project(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      locationLabel: locationLabel ?? this.locationLabel,
      location: location ?? this.location,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      startDate: startDate ?? this.startDate,
      expectedCompletion: expectedCompletion ?? this.expectedCompletion,
      department: department ?? this.department,
      budget: budget ?? this.budget,
      spent: spent ?? this.spent,
      isBudgetPublic: isBudgetPublic ?? this.isBudgetPublic,
      milestones: milestones ?? this.milestones,
      updates: updates ?? this.updates,
      documents: documents ?? this.documents,
      followerIds: followerIds ?? this.followerIds,
      imageLabels: imageLabels ?? this.imageLabels,
      contractor: contractor ?? this.contractor,
      projectManager: projectManager ?? this.projectManager,
    );
  }
}

class ReportUpdate {
  const ReportUpdate({
    required this.status,
    required this.message,
    required this.date,
    required this.isPublic,
  });

  final ReportStatus status;
  final String message;
  final DateTime date;
  final bool isPublic;
}

class CivicReport {
  const CivicReport({
    required this.id,
    required this.caseNumber,
    required this.title,
    required this.description,
    required this.category,
    required this.locationLabel,
    required this.location,
    required this.status,
    required this.priority,
    required this.submittedAt,
    required this.lastUpdated,
    required this.department,
    required this.ownerUserId,
    required this.attachments,
    required this.updates,
    required this.followerIds,
    this.internalNotes = const <String>[],
    this.assignedOfficer,
  });

  final String id;
  final String caseNumber;
  final String title;
  final String description;
  final String category;
  final String locationLabel;
  final GeoPoint location;
  final ReportStatus status;
  final String priority;
  final DateTime submittedAt;
  final DateTime lastUpdated;
  final String department;
  final String ownerUserId;
  final String? assignedOfficer;
  final List<String> attachments;
  final List<ReportUpdate> updates;
  final Set<String> followerIds;
  final List<String> internalNotes;

  CivicReport copyWith({
    ReportStatus? status,
    String? priority,
    DateTime? lastUpdated,
    String? department,
    String? assignedOfficer,
    List<String>? attachments,
    List<ReportUpdate>? updates,
    Set<String>? followerIds,
    List<String>? internalNotes,
  }) {
    return CivicReport(
      id: id,
      caseNumber: caseNumber,
      title: title,
      description: description,
      category: category,
      locationLabel: locationLabel,
      location: location,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      submittedAt: submittedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      department: department ?? this.department,
      ownerUserId: ownerUserId,
      assignedOfficer: assignedOfficer ?? this.assignedOfficer,
      attachments: attachments ?? this.attachments,
      updates: updates ?? this.updates,
      followerIds: followerIds ?? this.followerIds,
      internalNotes: internalNotes ?? this.internalNotes,
    );
  }
}

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.department,
    required this.publishedAt,
    required this.targetLabel,
    required this.isPinned,
    required this.isPublished,
  });

  final String id;
  final String title;
  final String body;
  final AnnouncementType type;
  final String department;
  final DateTime publishedAt;
  final String targetLabel;
  final bool isPinned;
  final bool isPublished;

  Announcement copyWith({
    String? title,
    String? body,
    AnnouncementType? type,
    String? department,
    DateTime? publishedAt,
    String? targetLabel,
    bool? isPinned,
    bool? isPublished,
  }) => Announcement(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    type: type ?? this.type,
    department: department ?? this.department,
    publishedAt: publishedAt ?? this.publishedAt,
    targetLabel: targetLabel ?? this.targetLabel,
    isPinned: isPinned ?? this.isPinned,
    isPublished: isPublished ?? this.isPublished,
  );
}

class FeedItem {
  const FeedItem({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.department,
    required this.locationLabel,
    required this.date,
    required this.reactionCount,
    required this.commentCount,
    required this.reactedUserIds,
    required this.savedUserIds,
  });

  final String id;
  final String title;
  final String body;
  final String kind;
  final String department;
  final String locationLabel;
  final DateTime date;
  final int reactionCount;
  final int commentCount;
  final Set<String> reactedUserIds;
  final Set<String> savedUserIds;

  FeedItem copyWith({
    int? reactionCount,
    int? commentCount,
    Set<String>? reactedUserIds,
    Set<String>? savedUserIds,
  }) {
    return FeedItem(
      id: id,
      title: title,
      body: body,
      kind: kind,
      department: department,
      locationLabel: locationLabel,
      date: date,
      reactionCount: reactionCount ?? this.reactionCount,
      commentCount: commentCount ?? this.commentCount,
      reactedUserIds: reactedUserIds ?? this.reactedUserIds,
      savedUserIds: savedUserIds ?? this.savedUserIds,
    );
  }
}

class CivicComment {
  const CivicComment({
    required this.id,
    required this.author,
    required this.message,
    required this.createdAt,
    required this.isVerified,
  });

  final String id;
  final String author;
  final String message;
  final DateTime createdAt;
  final bool isVerified;
}

class Proposal {
  const Proposal({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.locationLabel,
    required this.expectedBenefit,
    required this.status,
    required this.author,
    required this.createdAt,
    required this.attachments,
    required this.supporterIds,
    required this.comments,
    required this.followerIds,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String locationLabel;
  final String expectedBenefit;
  final ProposalStatus status;
  final String author;
  final DateTime createdAt;
  final List<String> attachments;
  final Set<String> supporterIds;
  final List<CivicComment> comments;
  final Set<String> followerIds;

  Proposal copyWith({
    List<String>? attachments,
    Set<String>? supporterIds,
    List<CivicComment>? comments,
    Set<String>? followerIds,
  }) => Proposal(
    id: id,
    title: title,
    description: description,
    category: category,
    locationLabel: locationLabel,
    expectedBenefit: expectedBenefit,
    status: status,
    author: author,
    createdAt: createdAt,
    attachments: attachments ?? this.attachments,
    supporterIds: supporterIds ?? this.supporterIds,
    comments: comments ?? this.comments,
    followerIds: followerIds ?? this.followerIds,
  );
}

class ConsultationQuestion {
  const ConsultationQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.allowsLongText,
  });

  final String id;
  final String question;
  final List<String> options;
  final bool allowsLongText;
}

class Consultation {
  const Consultation({
    required this.id,
    required this.title,
    required this.description,
    required this.openingDate,
    required this.closingDate,
    required this.department,
    required this.questions,
    required this.respondedUserIds,
  });

  final String id;
  final String title;
  final String description;
  final DateTime openingDate;
  final DateTime closingDate;
  final String department;
  final List<ConsultationQuestion> questions;
  final Set<String> respondedUserIds;

  bool get isOpen => DateTime.now().isBefore(closingDate);

  Consultation copyWith({Set<String>? respondedUserIds}) => Consultation(
    id: id,
    title: title,
    description: description,
    openingDate: openingDate,
    closingDate: closingDate,
    department: department,
    questions: questions,
    respondedUserIds: respondedUserIds ?? this.respondedUserIds,
  );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.createdAt,
    required this.isRead,
    this.route,
  });

  final String id;
  final String title;
  final String message;
  final String category;
  final DateTime createdAt;
  final bool isRead;
  final String? route;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    title: title,
    message: message,
    category: category,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
    route: route,
  );
}

class DashboardMetrics {
  const DashboardMetrics({
    required this.newComplaints,
    required this.assignedComplaints,
    required this.overdueComplaints,
    required this.activeProjects,
    required this.delayedProjects,
    required this.openConsultations,
    required this.citizenProposals,
    required this.averageResolutionDays,
  });

  final int newComplaints;
  final int assignedComplaints;
  final int overdueComplaints;
  final int activeProjects;
  final int delayedProjects;
  final int openConsultations;
  final int citizenProposals;
  final double averageResolutionDays;
}
