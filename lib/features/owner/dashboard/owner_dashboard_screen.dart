import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/controller/auth_controller.dart';
import '../../../data/services/supabase_service.dart';
import '../../../shared/utils/financial_calculator.dart';

import '../../../data/models/transaction_model.dart';
import '../../../data/models/customer_model.dart';

final dashboardStatsProvider = FutureProvider((ref) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  final customers = await supabaseService.getCustomers();
  final transactions = await supabaseService.getAllTransactions();

  final totalDebt = FinancialCalculator.calculateTotalCredits(transactions);
  final totalCollected = FinancialCalculator.calculateTotalPayments(
    transactions,
  );
  final totalOutstanding = FinancialCalculator.calculateRemainingBalance(
    transactions,
  );

  int overdueCustomersCount = 0;
  double overdueBalance = 0;
  int overdueTransactionsCount = 0;

  for (var customer in customers) {
    final customerTransactions = transactions
        .where((t) => t.customerId == customer.id)
        .toList();
    final status = FinancialCalculator.calculatePaymentStatus(
      customerTransactions,
    );
    if (status == PaymentStatus.overdue) {
      overdueCustomersCount++;

      for (var tx in customerTransactions) {
        if (tx.type == 'credit') {
          final txStatus = FinancialCalculator.calculateSingleTransactionStatus(
            tx,
            customerTransactions,
          );
          if (txStatus == PaymentStatus.overdue) {
            overdueTransactionsCount++;
          }
        }
      }
      overdueBalance += FinancialCalculator.calculateRemainingBalance(
        customerTransactions,
      );
    }
  }

  // Aging Analysis
  final agingAnalysis = FinancialCalculator.calculateAgingAnalysis(
    transactions,
    customers.map((c) => c.id).toList(),
  );

  return {
    'customersCount': customers.length,
    'totalDebt': totalDebt,
    'totalCollected': totalCollected,
    'totalOutstanding': totalOutstanding,
    'overdueCustomersCount': overdueCustomersCount,
    'overdueBalance': overdueBalance,
    'overdueTransactionsCount': overdueTransactionsCount,
    'agingAnalysis': agingAnalysis,
    'recentTransactions': transactions.take(10).toList(),
    'recentPayments': transactions
        .where((t) => t.type == 'payment')
        .take(10)
        .toList(),
    'customers': customers,
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
                    content: const Text(
                      'Are you sure you want to permanently delete your account and all associated data?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await ref
                        .read(supabaseServiceProvider)
                        .deleteOwnerAccount();
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
              const PopupMenuItem(
                value: 'delete_account',
                child: Text(
                  'Delete Account',
                  style: TextStyle(color: Colors.red),
                ),
              ),
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
                return statsAsync.when(
                  data: (stats) => Column(
                    children: [
                      Card(
                        color: AppColors.primary,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Text(
                                'Total Outstanding',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: AppColors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                FinancialCalculator.formatCurrency(
                                  stats['totalOutstanding'] as double,
                                ),
                                style: Theme.of(context).textTheme.displayMedium
                                    ?.copyWith(color: AppColors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMiniStat(
                              context,
                              'Total Debt',
                              FinancialCalculator.formatCurrency(
                                stats['totalDebt'] as double,
                              ),
                              Colors.blueGrey.shade700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMiniStat(
                              context,
                              'Collected',
                              FinancialCalculator.formatCurrency(
                                stats['totalCollected'] as double,
                              ),
                              Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) =>
                      Text('Error', style: TextStyle(color: Colors.red)),
                );
              },
            ),
            const SizedBox(height: 24),
            // Overdue Summary Card
            Consumer(
              builder: (context, ref, child) {
                final statsAsync = ref.watch(dashboardStatsProvider);
                return statsAsync.when(
                  data: (stats) {
                    final overdueCount = stats['overdueCustomersCount'] as int;
                    if (overdueCount == 0) return const SizedBox.shrink();

                    return Card(
                      color: Colors.red.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Overdue Summary',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Colors.red.shade900,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildOverdueStat(
                                  context,
                                  'Customers',
                                  overdueCount.toString(),
                                ),
                                _buildOverdueStat(
                                  context,
                                  'Balance',
                                  FinancialCalculator.formatCurrency(
                                    stats['overdueBalance'] as double,
                                  ),
                                ),
                                _buildOverdueStat(
                                  context,
                                  'Invoices',
                                  stats['overdueTransactionsCount'].toString(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => const SizedBox.shrink(),
                );
              },
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
            const SizedBox(height: 24),
            // Recent Activity
            Consumer(
              builder: (context, ref, child) {
                final statsAsync = ref.watch(dashboardStatsProvider);
                return statsAsync.when(
                  data: (stats) {
                    final recentTxs =
                        stats['recentTransactions'] as List<TransactionModel>;
                    if (recentTxs.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Activity',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            TextButton(
                              onPressed: () =>
                                  context.push('/owner/transactions'),
                              child: const Text('View All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...recentTxs.take(5).map((tx) {
                          final TransactionModel transaction = tx;
                          final isCredit = transaction.type == 'credit';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    (isCredit ? Colors.red : Colors.green)
                                        .withValues(alpha: 0.1),
                                child: Icon(
                                  isCredit
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  color: isCredit ? Colors.red : Colors.green,
                                  size: 16,
                                ),
                              ),
                              title: Text(
                                transaction.title ??
                                    (isCredit ? 'Credit' : 'Payment'),
                              ),
                              subtitle: Text(
                                transaction.date.toString().split(' ')[0],
                              ),
                              trailing: Text(
                                FinancialCalculator.formatCurrency(
                                  transaction.amount,
                                ),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCredit ? Colors.red : Colors.green,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => const SizedBox.shrink(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverdueStat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.red.shade900.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.red.shade900,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
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
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
