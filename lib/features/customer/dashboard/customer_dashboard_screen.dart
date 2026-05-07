import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/controller/auth_controller.dart';
import '../../../data/services/supabase_service.dart';
import '../../../shared/utils/financial_calculator.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/transaction_model.dart';

final customerDashboardProvider = FutureProvider((ref) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  final profile = await supabaseService.getCurrentCustomerProfile();
  // Scope transactions to this customer only — never use getAllTransactions() here
  final transactions = await supabaseService.getTransactionsForCustomer(
    profile.id,
  );
  final balance = FinancialCalculator.calculateRemainingBalance(transactions);
  final totalCredit = FinancialCalculator.calculateTotalCredits(transactions);
  final totalPaid = FinancialCalculator.calculateTotalPayments(transactions);
  final status = FinancialCalculator.calculatePaymentStatus(transactions);
  return {
    'profile': profile,
    'balance': balance,
    'totalCredit': totalCredit,
    'totalPaid': totalPaid,
    'status': status,
    'transactions': transactions,
  };
});

class CustomerDashboardScreen extends ConsumerWidget {
  const CustomerDashboardScreen({Key? key}) : super(key: key);

  void _showSubmitComplaintDialog(
    BuildContext context,
    WidgetRef ref,
    CustomerModel profile,
  ) {
    final messageController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Submit Complaint / Request'),
            content: TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (messageController.text.trim().isEmpty) return;
                        setState(() => isLoading = true);
                        try {
                          await ref
                              .read(supabaseServiceProvider)
                              .submitComplaint(
                                profile.id,
                                profile.ownerId,
                                messageController.text.trim(),
                              );
                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Message submitted successfully'),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                          setState(() => isLoading = false);
                        }
                      },
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLimitInfo(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

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
            Consumer(
              builder: (context, ref, child) {
                final dashboardAsync = ref.watch(customerDashboardProvider);
                return dashboardAsync.when(
                  data: (data) {
                    final profile = data['profile'] as CustomerModel;
                    final transactions =
                        data['transactions'] as List<TransactionModel>;
                    final balances =
                        FinancialCalculator.calculateCustomerBalance(
                          transactions,
                          profile.creditLimit,
                        );

                    final balance = balances.outstandingBalance;
                    final status = data['status'] as PaymentStatus;
                    final statusText = FinancialCalculator.getStatusText(
                      status,
                    );

                    Color statusColor = Colors.white;
                    if (status == PaymentStatus.overdue)
                      statusColor = Colors.redAccent;
                    if (status == PaymentStatus.paid)
                      statusColor = Colors.greenAccent;

                    return Card(
                      color: AppColors.primary,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Text(
                              'My Balance',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: AppColors.white.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              FinancialCalculator.formatCurrency(balance),
                              style: Theme.of(context).textTheme.displayMedium
                                  ?.copyWith(color: AppColors.white),
                            ),
                            const SizedBox(height: 8),
                            Chip(
                              label: Text(statusText),
                              backgroundColor: statusColor.withValues(
                                alpha: 0.2,
                              ),
                              labelStyle: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                              side: BorderSide(color: statusColor),
                            ),
                            if (profile.creditLimit > 0) ...[
                              const SizedBox(height: 16),
                              const Divider(color: Colors.white24),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildLimitInfo(
                                    context,
                                    'Credit Limit',
                                    FinancialCalculator.formatCurrency(
                                      profile.creditLimit,
                                    ),
                                  ),
                                  _buildLimitInfo(
                                    context,
                                    'Remaining',
                                    FinancialCalculator.formatCurrency(
                                      balances.remainingCredit,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error: $e')),
                );
              },
            ),
            const SizedBox(height: 24),
            // Actions
            Text('Menu', style: Theme.of(context).textTheme.titleLarge),
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
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, child) {
                final dashboardAsync = ref.watch(customerDashboardProvider);
                final profile =
                    dashboardAsync.value?['profile'] as CustomerModel?;
                return Card(
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(
                      Icons.feedback,
                      color: AppColors.primary,
                    ),
                    title: const Text('Submit Complaint / Request'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: profile == null
                        ? null
                        : () =>
                              _showSubmitComplaintDialog(context, ref, profile),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
