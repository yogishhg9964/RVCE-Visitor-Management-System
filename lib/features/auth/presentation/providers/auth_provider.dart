import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/services/auth_service.dart';

part 'auth_provider.g.dart';

@riverpod
Auth auth(AuthRef ref) {
  return Auth();
}

@riverpod
Stream<User?> authStateChanges(AuthStateChangesRef ref) {
  return ref.watch(authProvider).stream;
}
