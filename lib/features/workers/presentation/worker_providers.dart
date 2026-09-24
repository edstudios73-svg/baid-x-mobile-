import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../jobs/domain/job_rules.dart';
import '../data/worker_repository.dart';

typedef WorkerQuery = ({String query, String location, int offset});

final workerRepositoryProvider = Provider<WorkerRepository>((ref) => SupabaseWorkerRepository());

final workerSearchProvider = FutureProvider.autoDispose.family<List<WorkerCard>, WorkerQuery>((ref, query) {
  return ref.watch(workerRepositoryProvider).search(query: query.query, location: query.location, offset: query.offset);
});

final workerProfileProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, id) {
  return ref.watch(workerRepositoryProvider).publicProfile(id);
});
