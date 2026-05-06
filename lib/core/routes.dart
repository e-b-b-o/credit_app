import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/controller/auth_controller.dart';
import '../features/auth/screens/role_selection_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/owner/dashboard/owner_dashboard_screen.dart';
import '../features/owner/customers/customer_list_screen.dart';
import '../features/owner/transactions/transaction_screen.dart';
import '../features/owner/reports/reports_screen.dart';
import '../features/customer/dashboard/customer_dashboard_screen.dart';
import '../features/customer/history/customer_history_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuth = authState.value != null;
      final isSplash = state.matchedLocation == '/';
      final isLoggingIn = state.matchedLocation == '/login';
      final isSelectingRole = state.matchedLocation == '/role';

      if (authState.isLoading) return null; // Don't redirect while loading

      if (!isAuth && !isLoggingIn && !isSelectingRole) {
        return '/role';
      }

      if (isAuth && (isSplash || isLoggingIn || isSelectingRole)) {
        final role = authState.value?.userMetadata?['role'] ?? ref.read(selectedRoleProvider) ?? 'owner';
        if (role == 'owner') {
          return '/owner';
        } else {
          return '/customer';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      GoRoute(
        path: '/role',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // Owner Routes
      GoRoute(
        path: '/owner',
        builder: (context, state) => const OwnerDashboardScreen(),
        routes: [
          GoRoute(
            path: 'customers',
            builder: (context, state) => const CustomerListScreen(),
          ),
          GoRoute(
            path: 'transactions',
            builder: (context, state) => const TransactionScreen(),
          ),
          GoRoute(
            path: 'reports',
            builder: (context, state) => const ReportsScreen(),
          ),
        ],
      ),
      // Customer Routes
      GoRoute(
        path: '/customer',
        builder: (context, state) => const CustomerDashboardScreen(),
        routes: [
          GoRoute(
            path: 'history',
            builder: (context, state) => const CustomerHistoryScreen(),
          ),
        ],
      ),
    ],
  );
});
