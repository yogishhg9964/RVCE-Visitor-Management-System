import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../features/auth/data/services/auth_service.dart';
import '../../features/auth/data/services/session_service.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/visitor_management/presentation/screens/main_screen.dart';
import '../../features/host_management/presentation/screens/host_home_screen.dart';
import '../../features/host_management/presentation/screens/pending_approvals_screen.dart';
import '../../features/host_management/presentation/screens/visit_history_screen.dart';
import '../../features/host_management/presentation/screens/host_profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final sessionState = ref.watch(sessionServiceProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';

      // Handle loading state
      if (sessionState.isLoading || authState.isLoading) {
        return null;
      }

      // If not logged in and trying to access protected route, redirect to login
      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      // If logged in and on auth route, redirect based on role
      if (isLoggedIn && isAuthRoute) {
        final userRole = sessionState.valueOrNull?.role?.toLowerCase();
        if (userRole == 'security') {
          return '/register';
        }
        return '/host';
      }

      return null;
    },
    refreshListenable: GoRouterRefreshStream(
      ref.read(authProvider.notifier).stream,
    ),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const MainScreen(),
      ),
      // New route for visitor management home screen
      GoRoute(
        path: '/home',
        builder: (context, state) => const MainScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HostHomeScreen(child: child),
        routes: [
          GoRoute(
            path: '/host',
            builder: (context, state) => const HostDashboard(),
          ),
          
          
          GoRoute(
            path: '/host/pending-approvals',
            builder: (context, state) => const PendingApprovalsScreen(),
          ),
          GoRoute(
            path: '/host/visit-history',
            builder: (context, state) => const VisitHistoryScreen(),
          ),
          GoRoute(
            path: '/host/profile',
            builder: (context, state) => const HostProfileScreen(),
          ),
        ],
      ),
    ],
  );
});

// Update the refresh stream implementation
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen(
      (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
