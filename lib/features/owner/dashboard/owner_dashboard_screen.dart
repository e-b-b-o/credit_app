import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/controller/auth_controller.dart';
import '../../../data/services/supabase_service.dart';
import '../../../shared/utils/financial_calculator.dart';

final dashboardStatsProvider = FutureProvider((ref) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  final customers = await supabaseService.getCustomers();
  final transactions = await supabaseService.getAllTransactions();
  final totalOutstanding = FinancialCalculator.calculateRemainingBalance(transactions);
  return {
    'customersCount': customers.length,
    'totalOutstanding': totalOutstanding,
  };
});

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                ref.read(authControllerProvider.notifier).signOut();
              } else if (value == 'delete_account') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Account'),
                    content: const Text('Are you sure you want to permanently delete your account and all associated data?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true), 
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  )
                );
                if (confirm == true) {
                  try {
                    await ref.read(supabaseServiceProvider).deleteOwnerAccount();
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
              const PopupMenuItem(value: 'delete_account', child: Text('Delete Account', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary Card
            Consumer(
              builder: (context, ref, child) {
                final statsAsync = ref.watch(dashboardStatsProvider);
                return Card(
                  color: AppColors.primary,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          'Total Outstanding',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.white.withValues(alpha: 0.8),
                              ),
                        ),
                        const SizedBox(height: 8),
                        statsAsync.when(
                          data: (stats) => Text(
                            FinancialCalculator.formatCurrency(stats['totalOutstanding'] as double),
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  color: AppColors.white,
                                ),
                          ),
                          loading: () => const CircularProgressIndicator(color: Colors.white),
                          error: (e, st) => Text('Error', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                );
              }
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
                    icon: Icons.chat,
                    title: 'Complaints',
                    onTap: () => context.push('/owner/complaints'),
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
