bool canPurchaseVerification(String? status) => status != 'pending' && status != 'verified';

String verificationStateLabel(String? status) {
  return switch (status) {
    'pending' => 'Under review',
    'verified' => 'Verified',
    'rejected' => 'Rejected',
    _ => 'Not requested',
  };
}

String? listingSelectionError({required int selected, required int limit}) {
  if (selected < 1) return 'Choose at least one listing.';
  if (selected > limit) return 'This package covers $limit listings.';
  return null;
}

bool xidAllowed(String? accountType, String service) {
  return switch (service) {
    'professional' => accountType == 'worker' || accountType == 'employer' || accountType == 'project_manager',
    'digital_card' => accountType != null && accountType != 'company',
    'business' => accountType == 'business',
    'company' => accountType == 'company',
    _ => false,
  };
}

String? profileBoostTarget(String? accountType) {
  return switch (accountType) {
    'worker' => 'worker_profile',
    'project_manager' => 'project_manager_profile',
    _ => null,
  };
}

const capacityLabels = {
  'organization_capacity': 'Organization members',
  'project_capacity': 'Active projects',
  'job_posting_capacity': 'Job postings per month',
  'organization_admins': 'Organization admins',
  'collaborators_per_project': 'Collaborators per project',
};

List<String> capacityLines(Map<String, dynamic> entitlements) {
  return [
    for (final entry in capacityLabels.entries)
      if (entitlements[entry.key] != null) '${entry.value}: ${entitlements[entry.key]}',
  ];
}
