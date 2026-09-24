const verificationStatuses = ['pending', 'verified', 'rejected'];

String? verificationKindFor(String? accountType) {
  return switch (accountType) {
    'worker' => 'identity',
    'business' => 'business',
    'company' => 'company',
    _ => null,
  };
}

String? validateReview({required String body, required String rating}) {
  final text = body.trim();
  final score = int.tryParse(rating.trim());
  if (text.isEmpty) return 'Write what the work was like.';
  if (text.length > 1000) return 'Keep the review under 1000 characters.';
  if (score == null || score < 1 || score > 5) return 'Choose a rating from 1 to 5.';
  return null;
}

class VerificationRecord {
  const VerificationRecord({required this.id, required this.kind, required this.status, required this.createdAt});

  final String id;
  final String kind;
  final String status;
  final DateTime createdAt;
}

class ReviewRecord {
  const ReviewRecord({required this.id, required this.rating, required this.body, required this.createdAt});

  final String id;
  final int rating;
  final String body;
  final DateTime createdAt;
}
