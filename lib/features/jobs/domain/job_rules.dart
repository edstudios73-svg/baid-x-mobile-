enum ApplyDecision { allowed, needsSignIn, notWorker, closed, ownJob, alreadyApplied }

ApplyDecision decideApply({
  required bool signedIn,
  required String? accountType,
  required String jobStatus,
  required bool isOwner,
  required bool alreadyApplied,
}) {
  if (!signedIn) return ApplyDecision.needsSignIn;
  if (accountType != 'worker') return ApplyDecision.notWorker;
  if (isOwner) return ApplyDecision.ownJob;
  if (jobStatus != 'open') return ApplyDecision.closed;
  if (alreadyApplied) return ApplyDecision.alreadyApplied;
  return ApplyDecision.allowed;
}

String? validateJobDraft({
  required String title,
  required String description,
  required String location,
}) {
  if (title.trim().isEmpty) return 'Add a job title.';
  if (title.trim().length > 120) return 'Keep the title under 120 characters.';
  if (description.trim().length > 4000) return 'Keep the description under 4000 characters.';
  if (location.trim().length > 120) return 'Keep the location under 120 characters.';
  return null;
}

class JobRecord {
  const JobRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.locationLabel,
    required this.status,
    required this.isPublic,
    required this.ownerId,
    this.createdAt,
    this.applicationCount = 0,
  });

  final String id;
  final String title;
  final String description;
  final String locationLabel;
  final String status;
  final bool isPublic;
  final String ownerId;
  final DateTime? createdAt;
  final int applicationCount;
}

class ApplicationRecord {
  const ApplicationRecord({
    required this.id,
    required this.jobId,
    required this.status,
    required this.message,
    required this.jobTitle,
    this.createdAt,
    this.workerProfileId = '',
    this.ownerProfileId = '',
  });

  final String id;
  final String jobId;
  final String status;
  final String message;
  final String jobTitle;
  final DateTime? createdAt;
  final String workerProfileId;
  final String ownerProfileId;
}

class WorkerCard {
  const WorkerCard({
    required this.id,
    required this.name,
    required this.trade,
    required this.location,
    required this.summary,
    required this.verified,
  });

  final String id;
  final String name;
  final String trade;
  final String location;
  final String summary;
  final bool verified;
}
