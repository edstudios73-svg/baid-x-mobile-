const accessStatuses = ['pending', 'approved', 'rejected'];

bool canRequestCompanyAccess(String? accountType) => accountType == 'project_manager';

bool canReviewCompanyAccess(String? accountType) => accountType == 'company';

String? validateProjectTitle(String title) {
  if (title.trim().isEmpty) return 'Add a project title.';
  if (title.trim().length > 120) return 'Keep the title under 120 characters.';
  return null;
}

String? validateExpenseAmount(String amount) {
  final value = double.tryParse(amount.trim());
  if (value == null || value < 0) return 'Enter an amount of zero or more.';
  return null;
}

Map<String, dynamic> newProjectRow({
  required String userId,
  required String title,
  required String summary,
  String? companyId,
}) {
  return {
    'owner_profile_id': userId,
    'company_id': companyId,
    'title': title.trim(),
    'summary': summary.trim(),
    'status': 'draft',
    'is_public': false,
  };
}

Map<String, dynamic> projectMemberRow({
  required String projectId,
  required String profileId,
  required String role,
}) {
  final allowed = role == 'worker' || role == 'project_manager';
  return {
    'project_id': projectId,
    'profile_id': profileId,
    'member_role': allowed ? role : 'worker',
  };
}

class CompanyRecord {
  const CompanyRecord({required this.id, required this.name, required this.industry, required this.publicCode});

  final String id;
  final String name;
  final String industry;
  final String publicCode;
}

class AccessRequestRecord {
  const AccessRequestRecord({required this.id, required this.companyId, required this.status});

  final String id;
  final String companyId;
  final String status;
}

class ProjectRecord {
  const ProjectRecord({
    required this.id,
    required this.title,
    required this.summary,
    required this.status,
    required this.ownerId,
    this.companyId,
    this.publicCode = '',
  });

  final String id;
  final String title;
  final String summary;
  final String status;
  final String ownerId;
  final String? companyId;
  final String publicCode;
}
