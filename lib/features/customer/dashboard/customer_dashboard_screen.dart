import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/controller/auth_controller.dart';
import '../../../data/services/supabase_service.dart';
import '../../../shared/utils/financial_calculator.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/models/notification_model.dart';

final notificationsProvider = FutureProvider<List<NotificationModel>>((
  ref,
) async {
  return ref.watch(supabaseServiceProvider).getNotifications();
});

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

  Widget _StatusBadge({required PaymentStatus status}) {
    Color color;
    switch (status) {
      case PaymentStatus.paid:
        color = Colors.greenAccent;
        break;
      case PaymentStatus.partial:
        color = Colors.orangeAccent;
        break;
      case PaymentStatus.overdue:
        color = Colors.redAccent;
        break;
      case PaymentStatus.pending:
        color = Colors.white70;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        FinancialCalculator.getStatusText(status).toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  void _showNotificationsBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reminders & Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final notificationsAsync = ref.watch(notificationsProvider);
                  return notificationsAsync.when(
                    data: (notifications) {
                      if (notifications.isEmpty) {
                        return const Center(
                          child: Text('No notifications yet.'),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          final isUnread = !notification.isRead;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: notification.type == 'alert'
                                  ? Colors.red.shade100
                                  : Colors.blue.shade100,
                              child: Icon(
                                notification.type == 'alert'
                                    ? Icons.warning
                                    : Icons.notifications,
                                color: notification.type == 'alert'
                                    ? Colors.red
                                    : Colors.blue,
                              ),
                            ),
                            title: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: isUnread
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(notification.message),
                                Text(
                                  '${notification.createdAt.day}/${notification.createdAt.month}/${notification.createdAt.year}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              if (isUnread) {
                                ref
                                    .read(supabaseServiceProvider)
                                    .markNotificationAsRead(notification.id);
                                ref.invalidate(notificationsProvider);
                              }
                            },
                            tileColor: isUnread
                                ? Colors.blue.withValues(alpha: 0.05)
                                : null,
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dashboard'),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final notificationsAsync = ref.watch(notificationsProvider);
              final unreadCount =
                  notificationsAsync.value?.where((n) => !n.isRead).length ?? 0;

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () =>
                        _showNotificationsBottomSheet(context, ref),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
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

                    return Card(
                      color: AppColors.primary,
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Text(
                              'My Outstanding Balance',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: AppColors.white.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: Text(
                                  FinancialCalculator.formatCurrency(balance),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(color: AppColors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _StatusBadge(status: status),
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
                                    'Available Credit',
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
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, st) => Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error: $e',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
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
