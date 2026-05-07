import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/services/supabase_service.dart';
import '../../../shared/utils/financial_calculator.dart';
import '../../../core/theme/app_colors.dart';
import '../transactions/transaction_screen.dart' show allTransactionsProvider;
import '../dashboard/owner_dashboard_screen.dart' show dashboardStatsProvider;

// Family provider — keyed by customerId. All watchers auto-refresh on invalidation.
final customerLedgerProvider =
    FutureProvider.family<List<TransactionModel>, String>((
      ref,
      customerId,
    ) async {
      return ref
          .watch(supabaseServiceProvider)
          .getTransactionsForCustomer(customerId);
    });

class CustomerLedgerScreen extends ConsumerWidget {
  final CustomerModel customer;
  const CustomerLedgerScreen({super.key, required this.customer});

  // ─── Add / Edit Transaction Dialog ────────────────────────────────────────
  void _showTransactionDialog(
    BuildContext context,
    WidgetRef ref, {
    String defaultType = 'credit',
    TransactionModel? existing,
    List<TransactionModel> transactions = const [],
  }) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final amountController = TextEditingController(
      text: existing != null ? existing.amount.toStringAsFixed(2) : '',
    );
    final noteController = TextEditingController(text: existing?.note ?? '');
    DateTime? selectedDueDate = existing?.dueDate;
    String type = existing?.type ?? defaultType;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(
            existing == null
                ? (type == 'credit' ? 'Add Credit' : 'Record Payment')
                : 'Edit Transaction',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (existing == null)
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: type,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'credit',
                            child: Text('Credit (give goods)'),
                          ),
                          DropdownMenuItem(
                            value: 'payment',
                            child: Text('Payment (receive money)'),
                          ),
                        ],
                        onChanged: (v) => setState(() => type = v!),
                      ),
                    ),
                  ),
                if (existing == null) const SizedBox(height: 10),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title / Item (e.g. Rice and Oil)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    prefixText: 'ETB ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                if (type == 'credit') ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            selectedDueDate ??
                            DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 5),
                        ),
                      );
                      if (picked != null) {
                        setState(() => selectedDueDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Due Date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        selectedDueDate == null
                            ? 'No due date set'
                            : '${selectedDueDate!.day}/${selectedDueDate!.month}/${selectedDueDate!.year}',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final amount = double.tryParse(amountController.text);
                      if (amount == null || amount <= 0) return;

                      if (existing == null && type == 'credit') {
                        final currentBalance =
                            FinancialCalculator.calculateRemainingBalance(
                              transactions,
                            );
                        final newBalance = currentBalance + amount;

                        if (newBalance > customer.creditLimit &&
                            customer.creditLimit > 0) {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Credit Limit Exceeded'),
                              content: Text(
                                'Adding this credit will bring the balance to ${FinancialCalculator.formatCurrency(newBalance)}, '
                                'which exceeds the customer\'s limit of ${FinancialCalculator.formatCurrency(customer.creditLimit)}. '
                                'Do you want to proceed anyway?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Proceed'),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                        }
                      }

                      setState(() => isLoading = true);
                      try {
                        if (existing == null) {
                          await ref
                              .read(supabaseServiceProvider)
                              .addTransaction(
                                customer.id,
                                amount,
                                type,
                                title: titleController.text.trim().isEmpty
                                    ? null
                                    : titleController.text.trim(),
                                note: noteController.text.trim().isEmpty
                                    ? null
                                    : noteController.text.trim(),
                                dueDate: selectedDueDate,
                              );
                        } else {
                          await ref
                              .read(supabaseServiceProvider)
                              .updateTransaction(
                                existing.id,
                                amount: amount,
                                title: titleController.text.trim().isEmpty
                                    ? null
                                    : titleController.text.trim(),
                                note: noteController.text.trim().isEmpty
                                    ? null
                                    : noteController.text.trim(),
                                dueDate: selectedDueDate,
                              );
                        }
                        // Invalidate all providers that depend on transactions
                        ref.invalidate(customerLedgerProvider(customer.id));
                        ref.invalidate(allTransactionsProvider);
                        ref.invalidate(dashboardStatsProvider);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              existing == null
                                  ? 'Transaction added'
                                  : 'Transaction updated',
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        setState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Delete Confirmation ──────────────────────────────────────────────────
  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TransactionModel tx,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Delete "${tx.title ?? tx.type}" for ${FinancialCalculator.formatCurrency(tx.amount)}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(supabaseServiceProvider).deleteTransaction(tx.id);
        ref.invalidate(customerLedgerProvider(customer.id));
        ref.invalidate(allTransactionsProvider);
        ref.invalidate(dashboardStatsProvider);
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaction deleted')));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ─── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(customerLedgerProvider(customer.id));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(customerLedgerProvider(customer.id)),
        child: CustomScrollView(
          slivers: [
            // ── App Bar ────────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              stretch: true,
              backgroundColor: AppColors.primary,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              centerTitle: true,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: Text(
                  customer.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                            child: Text(
                              customer.name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            customer.phone,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 40,
                        ), // Space for title when expanded
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Summary + Actions ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: ledgerAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text('Error loading ledger: $e')),
                ),
                data: (transactions) {
                  final balances = FinancialCalculator.calculateCustomerBalance(
                    transactions,
                    customer.creditLimit,
                  );
                  final status = FinancialCalculator.calculatePaymentStatus(
                    transactions,
                  );

                  final totalCredit = balances.totalDebt;
                  final totalPaid = balances.totalPaid;
                  final balance = balances.outstandingBalance;
                  final remainingCredit = balances.remainingCredit;

                  Color statusColor;
                  IconData statusIcon;
                  switch (status) {
                    case PaymentStatus.overdue:
                      statusColor = Colors.red;
                      statusIcon = Icons.warning_rounded;
                      break;
                    case PaymentStatus.paid:
                      statusColor = Colors.green;
                      statusIcon = Icons.check_circle;
                      break;
                    case PaymentStatus.partial:
                      statusColor = Colors.orange;
                      statusIcon = Icons.timelapse;
                      break;
                    default:
                      statusColor = Colors.grey;
                      statusIcon = Icons.radio_button_unchecked;
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Status badge
                        Center(
                          child: Chip(
                            avatar: Icon(
                              statusIcon,
                              color: statusColor,
                              size: 16,
                            ),
                            label: Text(
                              FinancialCalculator.getStatusText(status),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: statusColor.withValues(alpha: 0.1),
                            side: BorderSide(color: statusColor),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Credit Limit Info
                        if (customer.creditLimit > 0)
                          Card(
                            color: Colors.blueGrey.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _SummarySmall(
                                    label: 'Limit',
                                    value: FinancialCalculator.formatCurrency(
                                      customer.creditLimit,
                                    ),
                                  ),
                                  _SummarySmall(
                                    label: 'Available',
                                    value: FinancialCalculator.formatCurrency(
                                      remainingCredit,
                                    ),
                                    color:
                                        remainingCredit <
                                            (customer.creditLimit * 0.1)
                                        ? Colors.red
                                        : Colors.blueGrey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        // Summary row
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 8,
                            ),
                            child: Row(
                              children: [
                                _SummaryCell(
                                  label: 'Total Credit',
                                  value: FinancialCalculator.formatCurrency(
                                    totalCredit,
                                  ),
                                  color: Colors.red.shade700,
                                ),
                                _divider(),
                                _SummaryCell(
                                  label: 'Total Paid',
                                  value: FinancialCalculator.formatCurrency(
                                    totalPaid,
                                  ),
                                  color: Colors.green.shade700,
                                ),
                                _divider(),
                                _SummaryCell(
                                  label: 'Balance',
                                  value: FinancialCalculator.formatCurrency(
                                    balance,
                                  ),
                                  color: balance > 0
                                      ? Colors.orange.shade800
                                      : Colors.green.shade700,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Quick action buttons
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Credit'),
                                onPressed: () => _showTransactionDialog(
                                  context,
                                  ref,
                                  defaultType: 'credit',
                                  transactions: transactions,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                ),
                                icon: const Icon(Icons.payments),
                                label: const Text('Record Payment'),
                                onPressed: () => _showTransactionDialog(
                                  context,
                                  ref,
                                  defaultType: 'payment',
                                  transactions: transactions,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Transaction History',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Transaction List ───────────────────────────────────────────
            ledgerAsync.when(
              loading: () => const SliverToBoxAdapter(child: SizedBox()),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox()),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No transactions yet',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final tx = transactions[index];
                    final isCredit = tx.type == 'credit';
                    final color = isCredit
                        ? Colors.red.shade600
                        : Colors.green.shade600;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.12),
                            child: Icon(
                              isCredit
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: color,
                              size: 20,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tx.title?.isNotEmpty == true
                                      ? tx.title!
                                      : (isCredit ? 'Credit' : 'Payment'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isCredit)
                                _StatusBadge(
                                  status:
                                      FinancialCalculator.calculateSingleTransactionStatus(
                                        tx,
                                        transactions,
                                      ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (tx.note?.isNotEmpty == true)
                                Text(
                                  tx.note!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              Text(
                                _formatDate(tx.date),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              if (tx.dueDate != null &&
                                  tx.dueDate!.isBefore(DateTime.now()) &&
                                  isCredit)
                                const Text(
                                  'OVERDUE',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          isThreeLine: tx.note?.isNotEmpty == true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                FinancialCalculator.formatCurrency(tx.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 4),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18),
                                onSelected: (val) {
                                  if (val == 'edit') {
                                    _showTransactionDialog(
                                      context,
                                      ref,
                                      existing: tx,
                                      transactions: transactions,
                                    );
                                  } else if (val == 'delete') {
                                    _confirmDelete(context, ref, tx);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }, childCount: transactions.length),
                );
              },
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 40, color: Colors.grey.shade200);

  Widget _SummarySmall({
    required String label,
    required String value,
    Color color = Colors.blueGrey,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _StatusBadge({required PaymentStatus status}) {
    Color color;
    switch (status) {
      case PaymentStatus.paid:
        color = Colors.green;
        break;
      case PaymentStatus.partial:
        color = Colors.orange;
        break;
      case PaymentStatus.overdue:
        color = Colors.red;
        break;
      case PaymentStatus.pending:
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        FinancialCalculator.getStatusText(status).toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryCell({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
