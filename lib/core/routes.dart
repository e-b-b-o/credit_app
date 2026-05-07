import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/controller/auth_controller.dart';
import '../features/auth/screens/role_selection_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/owner/dashboard/owner_dashboard_screen.dart';
import '../features/owner/customers/customer_list_screen.dart';
import '../features/owner/customers/customer_ledger_screen.dart';
import '../features/owner/transactions/transaction_screen.dart';
import '../data/models/customer_model.dart';
import '../features/owner/reports/reports_screen.dart';
import '../features/owner/complaints/complaints_screen.dart';
import '../features/customer/dashboard/customer_dashboard_screen.dart';
import '../features/customer/history/customer_history_screen.dart';
import '../core/services/reminder_service.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authControllerProvider, (prev, next) {
      if (next.value != null) {
        _ref.read(reminderServiceProvider).checkAndGenerateReminders();
      }
      notifyListeners();
    });
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authControllerProvider);
    final isAuth = authState.value != null;
    final isSplash = state.matchedLocation == '/';
    final isLoggingIn = state.matchedLocation == '/login';
    final isSelectingRole = state.matchedLocation == '/role';

    if (authState.isLoading && !authState.hasValue) return null;

    if (!isAuth && !isLoggingIn && !isSelectingRole) {
      return '/role';
    }

    if (isAuth) {
      final actualRole = authState.value?.userMetadata?['role'] as String? ?? 'owner';
      final isOwnerPath = state.matchedLocation.startsWith('/owner');
      final isCustomerPath = state.matchedLocation.startsWith('/customer');

      // 1. If at entry screens (splash, login, role selection), go to their dashboard
      if (isSplash || isLoggingIn || isSelectingRole) {
        return actualRole == 'owner' ? '/owner' : '/customer';
      }

      // 2. Strict enforcement: if on wrong path, redirect to correct dashboard
      if (actualRole == 'owner' && isCustomerPath) {
        return '/owner';
      }
      if (actualRole == 'customer' && isOwnerPath) {
        return '/customer';
      }
    }

    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
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
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final customer = state.extra as CustomerModel;
                  return CustomerLedgerScreen(customer: customer);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'transactions',
            builder: (context, state) => const TransactionScreen(),
          ),
          GoRoute(
            path: 'reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: 'complaints',
            builder: (context, state) => const ComplaintsScreen(),
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
