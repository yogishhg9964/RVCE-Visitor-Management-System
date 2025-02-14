// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'host_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$hostServiceHash() => r'894cd3ab880d18fe92e0dcf467547b69afb0078a';

/// See also [hostService].
@ProviderFor(hostService)
final hostServiceProvider = Provider<HostService>.internal(
  hostService,
  name: r'hostServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$hostServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HostServiceRef = ProviderRef<HostService>;
String _$pendingApprovalsCountHash() =>
    r'5cbd3907516159d652efa524deadcbc25c429ec8';

/// See also [pendingApprovalsCount].
@ProviderFor(pendingApprovalsCount)
final pendingApprovalsCountProvider = AutoDisposeStreamProvider<int>.internal(
  pendingApprovalsCount,
  name: r'pendingApprovalsCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pendingApprovalsCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PendingApprovalsCountRef = AutoDisposeStreamProviderRef<int>;
String _$visitHistoryCountHash() => r'2ae0d440ea66ad0167683f4aac0fcb64a3243497';

/// See also [visitHistoryCount].
@ProviderFor(visitHistoryCount)
final visitHistoryCountProvider = AutoDisposeStreamProvider<int>.internal(
  visitHistoryCount,
  name: r'visitHistoryCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$visitHistoryCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VisitHistoryCountRef = AutoDisposeStreamProviderRef<int>;
String _$currentHostHash() => r'60e765694308b3f03b3ce410e6fa28692356f5ba';

/// See also [currentHost].
@ProviderFor(currentHost)
final currentHostProvider = AutoDisposeStreamProvider<Host?>.internal(
  currentHost,
  name: r'currentHostProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$currentHostHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentHostRef = AutoDisposeStreamProviderRef<Host?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
