import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/controller/auth_controller.dart';

class CustomerDashboardScreen extends ConsumerWidget {
  const CustomerDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Balance Card
            Card(
              color: AppColors.primary,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      'My Balance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.white.withOpacity(0.8),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$0.00', // Placeholder
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            color: AppColors.white,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Actions
            Text(
              'Menu',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.history, color: AppColors.primary),
                title: const Text('Transaction History'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/customer/history'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
