import '../models/domain_models.dart';

/// The UI only talks to this contract. Replace [DemoCivicRepository] with a
/// Supabase- or REST-backed implementation without changing screen code.
abstract class CivicRepository {
  Future<InitialCivicData> loadInitialData();
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

class DemoCivicRepository implements CivicRepository {
  @override
  Future<InitialCivicData> loadInitialData() async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final now = DateTime.now();
    final authorities = <LocalAuthority>[
      const LocalAuthority(
        id: 'la-kumbukgate',
        name: 'Kumbukgate Pradeshiya Sabha',
        type: 'Pradeshiya Sabha',
        district: 'Kurunegala',
        province: 'North Western Province',
        center: GeoPoint(7.4864, 80.3642),
      ),
      const LocalAuthority(
        id: 'la-riverbend',
        name: 'Riverbend Urban Council',
        type: 'Urban Council',
        district: 'Kurunegala',
        province: 'North Western Province',
        center: GeoPoint(7.5032, 80.3489),
      ),
      const LocalAuthority(
        id: 'la-lakeview',
        name: 'Lakeview Municipal Council',
        type: 'Municipal Council',
        district: 'Kandy',
        province: 'Central Province',
        center: GeoPoint(7.2906, 80.6337),
      ),
    ];

    final departments = <Department>[
      const Department(
        id: 'engineering',
        name: 'Engineering',
        headName: 'N. Perera',
        categories: <String>[
          'Road Damage',
          'Drainage',
          'Public Property Damage',
        ],
        officerCount: 8,
      ),
      const Department(
        id: 'waste',
        name: 'Waste Management',
        headName: 'A. Fernando',
        categories: <String>['Garbage', 'Waste Collection'],
        officerCount: 6,
      ),
      const Department(
        id: 'environment',
        name: 'Environment',
        headName: 'S. Jayasinghe',
        categories: <String>['Dangerous Tree', 'Environmental Issue'],
        officerCount: 4,
      ),
      const Department(
        id: 'public-health',
        name: 'Public Health',
        headName: 'R. Silva',
        categories: <String>[
          'Public Health',
          'Water Issue',
          'Noise/Public Nuisance',
        ],
        officerCount: 5,
      ),
      const Department(
        id: 'community',
        name: 'Community Development',
        headName: 'M. Kumar',
        categories: <String>['Community Proposals', 'Consultations'],
        officerCount: 3,
      ),
    ];

    final users = <AppUser>[
      const AppUser(
        id: 'u-citizen',
        fullName: 'Kasun Perera',
        email: 'citizen@smart-sabha.lk',
        role: UserRole.verifiedResident,
        localAuthorityId: 'la-kumbukgate',
        ward: 'Ward 04',
        gnDivision: 'Kumbukgate South',
        phone: '+94 77 123 4567',
        preferredLanguage: 'en',
        onboardingComplete: true,
        isActive: true,
        residentialArea: GeoPoint(7.4857, 80.3627),
      ),
      const AppUser(
        id: 'u-officer',
        fullName: 'Nimali Fernando',
        email: 'officer@smart-sabha.lk',
        role: UserRole.departmentAdmin,
        localAuthorityId: 'la-kumbukgate',
        ward: 'Ward 04',
        gnDivision: 'Kumbukgate South',
        phone: '+94 71 222 3344',
        preferredLanguage: 'en',
        onboardingComplete: true,
        isActive: true,
      ),
      const AppUser(
        id: 'u-officer-2',
        fullName: 'Dilan Weerasekara',
        email: 'dilan.w@smart-sabha.lk',
        role: UserRole.officer,
        localAuthorityId: 'la-kumbukgate',
        ward: 'Ward 02',
        gnDivision: 'Kumbukgate North',
        phone: '+94 76 555 8800',
        preferredLanguage: 'en',
        onboardingComplete: true,
        isActive: true,
      ),
    ];

    final projects = <Project>[
      Project(
        id: 'p-road-renewal',
        title: 'Ward 04 Road Surface Renewal',
        description:
            'Renewing the damaged 1.8 km section between the weekly fair and the public library, including drainage repairs and pedestrian safety markings.',
        category: 'Roads & Transport',
        locationLabel: 'Lake Road, Ward 04',
        location: const GeoPoint(7.4877, 80.3621),
        status: ProjectStatus.inProgress,
        progress: 62,
        startDate: now.subtract(const Duration(days: 70)),
        expectedCompletion: now.add(const Duration(days: 38)),
        department: 'Engineering',
        budget: 12500000,
        spent: 7700000,
        isBudgetPublic: true,
        contractor: 'Lanka Civic Engineering Ltd.',
        projectManager: 'D. Weerasekara',
        followerIds: <String>{'u-citizen'},
        milestones: <ProjectMilestone>[
          ProjectMilestone(
            title: 'Planning complete',
            description: 'Technical design and public notice completed.',
            percentage: 15,
            expectedDate: now.subtract(const Duration(days: 95)),
            completedDate: now.subtract(const Duration(days: 98)),
            isComplete: true,
          ),
          ProjectMilestone(
            title: 'Tender complete',
            description:
                'Contractor selected through the public procurement process.',
            percentage: 25,
            expectedDate: now.subtract(const Duration(days: 72)),
            completedDate: now.subtract(const Duration(days: 70)),
            isComplete: true,
          ),
          ProjectMilestone(
            title: 'Construction in progress',
            description: 'Base layers and drainage works are under way.',
            percentage: 65,
            expectedDate: now.add(const Duration(days: 7)),
            completedDate: null,
            isComplete: false,
          ),
          ProjectMilestone(
            title: 'Safety inspection',
            description: 'Independent inspection before opening the road.',
            percentage: 90,
            expectedDate: now.add(const Duration(days: 31)),
            completedDate: null,
            isComplete: false,
          ),
        ],
        updates: <ProjectUpdate>[
          ProjectUpdate(
            title: 'Drainage work completed on the western section',
            message:
                'The team has completed the culvert and side-drain repair. Temporary traffic guidance remains in place.',
            date: now.subtract(const Duration(days: 4)),
            isPublic: true,
          ),
          ProjectUpdate(
            title: 'Works began',
            message: 'Site preparation started after the public notice period.',
            date: now.subtract(const Duration(days: 62)),
            isPublic: true,
          ),
        ],
        documents: const <PublicDocument>[
          PublicDocument(
            name: 'Project summary',
            kind: 'PDF',
            sizeLabel: '1.2 MB',
          ),
          PublicDocument(
            name: 'Approved budget',
            kind: 'PDF',
            sizeLabel: '346 KB',
          ),
        ],
      ),
      Project(
        id: 'p-water-upgrade',
        title: 'Community Water Point Upgrade',
        description:
            'Replacing ageing taps, installing accessible wash points and improving drainage at three public water collection points.',
        category: 'Water & Sanitation',
        locationLabel: 'Temple Lane, Ward 02',
        location: const GeoPoint(7.4963, 80.3514),
        status: ProjectStatus.planned,
        progress: 18,
        startDate: now.add(const Duration(days: 25)),
        expectedCompletion: now.add(const Duration(days: 150)),
        department: 'Public Health',
        budget: 4200000,
        spent: 0,
        isBudgetPublic: true,
        contractor: null,
        projectManager: 'R. Silva',
        followerIds: <String>{},
        milestones: <ProjectMilestone>[
          ProjectMilestone(
            title: 'Community needs assessment',
            description:
                'Completed with local residents and public-health officers.',
            percentage: 18,
            expectedDate: now.subtract(const Duration(days: 2)),
            completedDate: now.subtract(const Duration(days: 3)),
            isComplete: true,
          ),
          ProjectMilestone(
            title: 'Tender preparation',
            description: 'Procurement documents are being prepared.',
            percentage: 30,
            expectedDate: now.add(const Duration(days: 20)),
            completedDate: null,
            isComplete: false,
          ),
          ProjectMilestone(
            title: 'Installation',
            description: 'Public water points will be upgraded in stages.',
            percentage: 80,
            expectedDate: now.add(const Duration(days: 125)),
            completedDate: null,
            isComplete: false,
          ),
        ],
        updates: <ProjectUpdate>[
          ProjectUpdate(
            title: 'Project approved for the annual plan',
            message:
                'The council approved the project after reviewing resident feedback.',
            date: now.subtract(const Duration(days: 5)),
            isPublic: true,
          ),
        ],
        documents: const <PublicDocument>[
          PublicDocument(
            name: 'Community needs summary',
            kind: 'PDF',
            sizeLabel: '540 KB',
          ),
        ],
      ),
      Project(
        id: 'p-park-renewal',
        title: 'Kumbukgate Public Park Renewal',
        description:
            'Creating safer play areas, shaded seating, accessible paths and a small community garden in the central public park.',
        category: 'Public Spaces',
        locationLabel: 'Main Street, Ward 01',
        location: const GeoPoint(7.4819, 80.3698),
        status: ProjectStatus.completed,
        progress: 100,
        startDate: now.subtract(const Duration(days: 250)),
        expectedCompletion: now.subtract(const Duration(days: 16)),
        department: 'Community Development',
        budget: 8600000,
        spent: 8480000,
        isBudgetPublic: true,
        contractor: 'Green Space Lanka',
        projectManager: 'M. Kumar',
        followerIds: <String>{'u-citizen'},
        milestones: <ProjectMilestone>[
          ProjectMilestone(
            title: 'Design consultation',
            description: 'Residents selected the preferred layout.',
            percentage: 20,
            expectedDate: now.subtract(const Duration(days: 230)),
            completedDate: now.subtract(const Duration(days: 232)),
            isComplete: true,
          ),
          ProjectMilestone(
            title: 'Renewal complete',
            description: 'The park reopened after final safety inspection.',
            percentage: 100,
            expectedDate: now.subtract(const Duration(days: 16)),
            completedDate: now.subtract(const Duration(days: 16)),
            isComplete: true,
          ),
        ],
        updates: <ProjectUpdate>[
          ProjectUpdate(
            title: 'Park reopened',
            message: 'The park is now open daily from 5.30 am to 8.00 pm.',
            date: now.subtract(const Duration(days: 16)),
            isPublic: true,
          ),
        ],
        documents: const <PublicDocument>[
          PublicDocument(
            name: 'Completion report',
            kind: 'PDF',
            sizeLabel: '2.8 MB',
          ),
        ],
      ),
      Project(
        id: 'p-drainage',
        title: 'Lake Road Drainage Improvement',
        description:
            'Improving rainwater flow around the market junction to reduce regular flooding during the monsoon season.',
        category: 'Drainage',
        locationLabel: 'Market Junction, Ward 04',
        location: const GeoPoint(7.4897, 80.3662),
        status: ProjectStatus.delayed,
        progress: 41,
        startDate: now.subtract(const Duration(days: 115)),
        expectedCompletion: now.add(const Duration(days: 55)),
        department: 'Engineering',
        budget: 6400000,
        spent: 3100000,
        isBudgetPublic: true,
        contractor: 'Civic Build Solutions',
        projectManager: 'N. Perera',
        followerIds: <String>{},
        milestones: <ProjectMilestone>[
          ProjectMilestone(
            title: 'Utility survey',
            description: 'Completed in coordination with utility providers.',
            percentage: 20,
            expectedDate: now.subtract(const Duration(days: 98)),
            completedDate: now.subtract(const Duration(days: 93)),
            isComplete: true,
          ),
          ProjectMilestone(
            title: 'Pipe installation',
            description: 'Awaiting the delivery of revised pipe fittings.',
            percentage: 60,
            expectedDate: now.subtract(const Duration(days: 7)),
            completedDate: null,
            isComplete: false,
          ),
        ],
        updates: <ProjectUpdate>[
          ProjectUpdate(
            title: 'Material delivery rescheduled',
            message:
                'The contractor has confirmed a revised delivery date. The estimated completion date has been updated.',
            date: now.subtract(const Duration(days: 2)),
            isPublic: true,
          ),
        ],
        documents: const <PublicDocument>[
          PublicDocument(
            name: 'Delay notice',
            kind: 'PDF',
            sizeLabel: '182 KB',
          ),
        ],
      ),
    ];

    final reports = <CivicReport>[
      CivicReport(
        id: 'r-drain-001',
        caseNumber: 'SS-2026-0418',
        title: 'Blocked roadside drain near the market',
        description:
            'Rainwater is collecting at the corner and pedestrians have to walk on the road.',
        category: 'Drainage',
        locationLabel: 'Market Junction, Ward 04',
        location: const GeoPoint(7.4898, 80.3660),
        status: ReportStatus.inProgress,
        priority: 'High',
        submittedAt: now.subtract(const Duration(days: 12)),
        lastUpdated: now.subtract(const Duration(days: 1)),
        department: 'Engineering',
        ownerUserId: 'u-citizen',
        assignedOfficer: 'Dilan Weerasekara',
        attachments: const <String>['drain-photo.jpg'],
        followerIds: <String>{'u-citizen'},
        updates: <ReportUpdate>[
          ReportUpdate(
            status: ReportStatus.submitted,
            message: 'Your report was received and given a case number.',
            date: now.subtract(const Duration(days: 12)),
            isPublic: true,
          ),
          ReportUpdate(
            status: ReportStatus.acknowledged,
            message: 'Engineering has acknowledged the report.',
            date: now.subtract(const Duration(days: 10)),
            isPublic: true,
          ),
          ReportUpdate(
            status: ReportStatus.inProgress,
            message: 'Cleaning work has been scheduled for this week.',
            date: now.subtract(const Duration(days: 1)),
            isPublic: true,
          ),
        ],
      ),
      CivicReport(
        id: 'r-light-018',
        caseNumber: 'SS-2026-0396',
        title: 'Street light not working',
        description:
            'The lamp near the bus stop has been off for several nights.',
        category: 'Street Light',
        locationLabel: 'Station Road, Ward 04',
        location: const GeoPoint(7.4841, 80.3603),
        status: ReportStatus.resolved,
        priority: 'Normal',
        submittedAt: now.subtract(const Duration(days: 35)),
        lastUpdated: now.subtract(const Duration(days: 4)),
        department: 'Engineering',
        ownerUserId: 'u-citizen',
        assignedOfficer: 'Dilan Weerasekara',
        attachments: const <String>['street-light.jpg'],
        followerIds: <String>{},
        updates: <ReportUpdate>[
          ReportUpdate(
            status: ReportStatus.submitted,
            message: 'Your report was received.',
            date: now.subtract(const Duration(days: 35)),
            isPublic: true,
          ),
          ReportUpdate(
            status: ReportStatus.resolved,
            message:
                'The lamp was replaced and tested by the maintenance team.',
            date: now.subtract(const Duration(days: 4)),
            isPublic: true,
          ),
        ],
      ),
      CivicReport(
        id: 'r-garbage-006',
        caseNumber: 'SS-2026-0421',
        title: 'Missed waste collection',
        description:
            'Waste was not collected from the public collection point this week.',
        category: 'Garbage',
        locationLabel: 'Temple Lane, Ward 02',
        location: const GeoPoint(7.4968, 80.3519),
        status: ReportStatus.acknowledged,
        priority: 'Normal',
        submittedAt: now.subtract(const Duration(days: 2)),
        lastUpdated: now.subtract(const Duration(hours: 9)),
        department: 'Waste Management',
        ownerUserId: 'u-other',
        assignedOfficer: null,
        attachments: const <String>[],
        followerIds: <String>{},
        updates: <ReportUpdate>[
          ReportUpdate(
            status: ReportStatus.submitted,
            message: 'Report received.',
            date: now.subtract(const Duration(days: 2)),
            isPublic: true,
          ),
          ReportUpdate(
            status: ReportStatus.acknowledged,
            message: 'Waste Management is reviewing the route schedule.',
            date: now.subtract(const Duration(hours: 9)),
            isPublic: true,
          ),
        ],
      ),
    ];

    final announcements = <Announcement>[
      Announcement(
        id: 'a-waste',
        title: 'Ward 04 waste collection moved to Saturday',
        body:
            'This week\'s collection is moved to Saturday, 28 September due to scheduled vehicle maintenance. Please place sorted waste out by 6.30 am.',
        type: AnnouncementType.wasteCollection,
        department: 'Waste Management',
        publishedAt: now.subtract(const Duration(hours: 8)),
        targetLabel: 'Ward 04',
        isPinned: true,
        isPublished: true,
      ),
      Announcement(
        id: 'a-clinic',
        title: 'Free dengue prevention inspection programme',
        body:
            'Public Health Inspectors will visit selected streets in Ward 02 and Ward 04 next week. Residents may request advice through Smart Sabha.',
        type: AnnouncementType.publicHealth,
        department: 'Public Health',
        publishedAt: now.subtract(const Duration(days: 2)),
        targetLabel: 'Ward 02 and Ward 04',
        isPinned: false,
        isPublished: true,
      ),
      Announcement(
        id: 'a-draft',
        title: 'Draft notice: October community clean-up',
        body:
            'A draft announcement awaiting approval by the Community Development department.',
        type: AnnouncementType.event,
        department: 'Community Development',
        publishedAt: now.add(const Duration(days: 4)),
        targetLabel: 'All wards',
        isPinned: false,
        isPublished: false,
      ),
    ];

    final feedItems = <FeedItem>[
      FeedItem(
        id: 'f-road-update',
        title: 'Road renewal: drainage stage completed',
        body:
            'The western section drainage work is complete. Surface preparation continues this week.',
        kind: 'Project update',
        department: 'Engineering',
        locationLabel: 'Lake Road, Ward 04',
        date: now.subtract(const Duration(days: 4)),
        reactionCount: 18,
        commentCount: 4,
        reactedUserIds: <String>{'u-citizen'},
        savedUserIds: <String>{},
      ),
      FeedItem(
        id: 'f-park',
        title: 'Public park renewal is complete',
        body:
            'The central public park has reopened with accessible paths, shade and a new play area.',
        kind: 'Completed project',
        department: 'Community Development',
        locationLabel: 'Main Street, Ward 01',
        date: now.subtract(const Duration(days: 16)),
        reactionCount: 47,
        commentCount: 9,
        reactedUserIds: <String>{},
        savedUserIds: <String>{'u-citizen'},
      ),
      FeedItem(
        id: 'f-consultation',
        title: 'Share your ideas for safer walking routes',
        body:
            'The authority is collecting views on school-zone crossings and footpath priorities.',
        kind: 'Consultation',
        department: 'Community Development',
        locationLabel: 'All wards',
        date: now.subtract(const Duration(days: 1)),
        reactionCount: 12,
        commentCount: 2,
        reactedUserIds: <String>{},
        savedUserIds: <String>{},
      ),
    ];

    final proposals = <Proposal>[
      Proposal(
        id: 'pr-bus-shelter',
        title: 'Accessible bus shelter near the library',
        description:
            'Install a covered seating area and a clear timetable board near the main library bus stop.',
        category: 'Transport & Access',
        locationLabel: 'Library Road, Ward 04',
        expectedBenefit:
            'Safer, more comfortable public transport access for students, older residents and daily commuters.',
        status: ProposalStatus.communityReview,
        author: 'Verified Resident · Ward 04',
        createdAt: now.subtract(const Duration(days: 8)),
        attachments: const <String>[],
        supporterIds: <String>{'u-citizen', 'u-other', 'u-third'},
        followerIds: <String>{},
        comments: <CivicComment>[
          CivicComment(
            id: 'pc-1',
            author: 'Verified Resident · Ward 04',
            message:
                'This would be especially helpful during the rainy season.',
            createdAt: now.subtract(const Duration(days: 5)),
            isVerified: true,
          ),
        ],
      ),
      Proposal(
        id: 'pr-compost',
        title: 'Neighbourhood compost collection point',
        description:
            'Create a small managed compost point for market vegetable waste and home-garden contributions.',
        category: 'Environment',
        locationLabel: 'Market Lane, Ward 03',
        expectedBenefit:
            'Less organic waste sent to landfill and compost for community gardens.',
        status: ProposalStatus.technicalReview,
        author: 'Resident · Ward 03',
        createdAt: now.subtract(const Duration(days: 20)),
        attachments: const <String>[],
        supporterIds: <String>{'u-other', 'u-third'},
        followerIds: <String>{'u-citizen'},
        comments: const <CivicComment>[],
      ),
    ];

    final consultations = <Consultation>[
      Consultation(
        id: 'c-walking',
        title: 'Safer walking routes around schools',
        description:
            'Help prioritise the next improvements to crossings, footpaths and traffic calming around schools.',
        openingDate: now.subtract(const Duration(days: 3)),
        closingDate: now.add(const Duration(days: 18)),
        department: 'Engineering',
        respondedUserIds: <String>{},
        questions: const <ConsultationQuestion>[
          ConsultationQuestion(
            id: 'q1',
            question: 'Which improvement should be prioritised first?',
            options: <String>[
              'Pedestrian crossings',
              'Footpaths',
              'Traffic calming',
              'Street lighting',
            ],
            allowsLongText: false,
          ),
          ConsultationQuestion(
            id: 'q2',
            question: 'Tell us about a location that needs attention.',
            options: <String>[],
            allowsLongText: true,
          ),
        ],
      ),
      Consultation(
        id: 'c-budget',
        title: '2027 community budget priorities',
        description:
            'Share what local services or public spaces should be considered in the next annual plan.',
        openingDate: now.subtract(const Duration(days: 12)),
        closingDate: now.add(const Duration(days: 6)),
        department: 'Administration',
        respondedUserIds: <String>{'u-citizen'},
        questions: const <ConsultationQuestion>[
          ConsultationQuestion(
            id: 'q3',
            question: 'Which broad area matters most to you?',
            options: <String>[
              'Roads',
              'Waste services',
              'Water',
              'Public spaces',
              'Health',
            ],
            allowsLongText: false,
          ),
        ],
      ),
    ];

    final notifications = <AppNotification>[
      AppNotification(
        id: 'n-drain',
        title: 'Work is scheduled for your drainage report',
        message: 'Engineering has scheduled cleaning work for SS-2026-0418.',
        category: 'Report update',
        createdAt: now.subtract(const Duration(days: 1)),
        isRead: false,
        route: '/reports/r-drain-001',
      ),
      AppNotification(
        id: 'n-road',
        title: 'A project you follow has an update',
        message: 'Ward 04 Road Surface Renewal posted a progress update.',
        category: 'Project update',
        createdAt: now.subtract(const Duration(days: 4)),
        isRead: false,
        route: '/projects/p-road-renewal',
      ),
      AppNotification(
        id: 'n-waste',
        title: 'Waste collection schedule changed',
        message: 'Ward 04 collection has moved to Saturday this week.',
        category: 'Announcement',
        createdAt: now.subtract(const Duration(hours: 8)),
        isRead: true,
        route: '/announcements/a-waste',
      ),
    ];

    return InitialCivicData(
      authorities: authorities,
      departments: departments,
      users: users,
      projects: projects,
      reports: reports,
      announcements: announcements,
      feedItems: feedItems,
      proposals: proposals,
      consultations: consultations,
      notifications: notifications,
    );
  }
}
