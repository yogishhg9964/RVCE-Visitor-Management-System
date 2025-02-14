import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/services/visitor_registration_service.dart';
import '../../domain/models/visitor.dart';

part 'visitor_registration_provider.g.dart';

@riverpod
VisitorRegistrationService visitorRegistrationService(
    VisitorRegistrationServiceRef ref) {
  return VisitorRegistrationService();
}

@riverpod
class VisitorRegistration extends _$VisitorRegistration {
  @override
  FutureOr<void> build() {
    return null;
  }

  Future<void> registerVisitor(Visitor visitor, String hostEmail) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref
        .read(visitorRegistrationServiceProvider)
        .registerVisitorWithHost(
          visitor: visitor,
          hostEmail: hostEmail,
        ));
  }

  Future<void> updateStatus(
      String visitorId, String hostEmail, String status) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref
        .read(visitorRegistrationServiceProvider)
        .updateVisitorStatus(
          visitorId: visitorId,
          hostEmail: hostEmail,
          status: status,
        ));
  }
}
