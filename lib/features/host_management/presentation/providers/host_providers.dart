import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/services/host_service.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../domain/models/host.dart';

part 'host_providers.g.dart';

@Riverpod(keepAlive: true)
HostService hostService(HostServiceRef ref) {
  return HostService();
}

@riverpod
Stream<int> pendingApprovalsCount(PendingApprovalsCountRef ref) {
  final hostService = ref.watch(hostServiceProvider);
  final user = ref.watch(authProvider).value;
  if (user == null) return Stream.value(0);

  return hostService.getPendingApprovalsCount(user.email!);
}

@riverpod
Stream<int> visitHistoryCount(VisitHistoryCountRef ref) {
  final hostService = ref.watch(hostServiceProvider);
  final user = ref.watch(authProvider).value;
  if (user == null) return Stream.value(0);

  return hostService.getVisitHistoryCount(user.email!);
}

@riverpod
Stream<Host?> currentHost(CurrentHostRef ref) {
  final hostService = ref.watch(hostServiceProvider);
  final user = ref.watch(authProvider).value;
  if (user == null) return Stream.value(null);

  return hostService.getHostStream(user.email!);
}

final hostVisitorHistoryProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentHost = ref.watch(currentHostProvider);
  return currentHost.when(
    data: (host) {
      if (host == null) return Stream.value([]);
      return ref.read(hostServiceProvider).getHostVisitorHistory(host.email);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});
