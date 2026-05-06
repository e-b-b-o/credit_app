import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/controller/auth_controller.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
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
            // Summary Card
            Card(
              color: AppColors.primary,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      'Total Outstanding',
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
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.people,
                    title: 'Customers',
                    onTap: () => context.push('/owner/customers'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.receipt_long,
                    title: 'Transactions',
                    onTap: () => context.push('/owner/transactions'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.bar_chart,
                    title: 'Reports',
                    onTap: () => context.push('/owner/reports'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.notifications,
                    title: 'Reminders',
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Column(
            children: [
              Icon(icon, size: 40, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
