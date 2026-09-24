class ListedItem {
  const ListedItem({required this.title, this.detail = ''});

  final String title;
  final String detail;
}

class RoleDashboard {
  const RoleDashboard({
    required this.name,
    required this.location,
    required this.headline,
    required this.completionPercent,
    this.trade = '',
    this.availability = '',
    this.verified = false,
    this.reviewCount = 0,
    this.jobs = const [],
    this.applications = const [],
    this.people = const [],
    this.listings = const [],
    this.projects = const [],
    this.tasks = const [],
    this.reports = const [],
    this.expenses = const [],
    this.team = const [],
  });

  final String name;
  final String location;
  final String headline;
  final int completionPercent;
  final String trade;
  final String availability;
  final bool verified;
  final int reviewCount;
  final List<ListedItem> jobs;
  final List<ListedItem> applications;
  final List<ListedItem> people;
  final List<ListedItem> listings;
  final List<ListedItem> projects;
  final List<ListedItem> tasks;
  final List<ListedItem> reports;
  final List<ListedItem> expenses;
  final List<ListedItem> team;
}

int completionOf(List<String> values) {
  if (values.isEmpty) return 0;
  final filled = values.where((value) => value.trim().isNotEmpty).length;
  return ((filled / values.length) * 100).round();
}
