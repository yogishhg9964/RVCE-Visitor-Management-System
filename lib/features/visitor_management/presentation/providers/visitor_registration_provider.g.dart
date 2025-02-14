// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visitor_registration_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$visitorRegistrationServiceHash() =>
    r'549a6870057d5a580a088df5be2ec2cca7c89d62';

/// See also [visitorRegistrationService].
@ProviderFor(visitorRegistrationService)
final visitorRegistrationServiceProvider =
    AutoDisposeProvider<VisitorRegistrationService>.internal(
  visitorRegistrationService,
  name: r'visitorRegistrationServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$visitorRegistrationServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VisitorRegistrationServiceRef
    = AutoDisposeProviderRef<VisitorRegistrationService>;
String _$visitorRegistrationHash() =>
    r'33b9c11c12e7376d0345f7416a033a88988aa642';

/// See also [VisitorRegistration].
@ProviderFor(VisitorRegistration)
final visitorRegistrationProvider =
    AutoDisposeAsyncNotifierProvider<VisitorRegistration, void>.internal(
  VisitorRegistration.new,
  name: r'visitorRegistrationProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$visitorRegistrationHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$VisitorRegistration = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
