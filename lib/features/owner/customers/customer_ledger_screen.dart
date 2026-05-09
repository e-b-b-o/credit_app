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
    FutureProvider.autoDispose.family<List<TransactionModel>, String>((
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
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'credit',
                            child: Text('Credit (Debt)'),
                          ),
                          DropdownMenuItem(
                            value: 'payment',
                            child: Text('Repayment'),
                          ),
                          DropdownMenuItem(
                            value: 'refund',
                            child: Text('Refund / Discount'),
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

                      if (type == 'payment' || type == 'refund') {
                        final currentBalance =
                            FinancialCalculator.calculateRemainingBalance(
                              transactions,
                            );
                        final oldAmount = existing?.amount ?? 0.0;
                        if (amount > currentBalance + oldAmount + 0.001) {
                          final action = type == 'payment' ? 'Payment' : 'Refund';
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('$action exceeds remaining outstanding balance.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }

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
              expandedHeight: 200,
              pinned: true,
              stretch: true,
              backgroundColor: AppColors.primary,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              centerTitle: true,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: LayoutBuilder(
                  builder: (context, constraints) {
                    // Only show title text when the bar is collapsed (or nearly collapsed)
                    final double opacity = (constraints.maxHeight < 100)
                        ? 1.0
                        : 0.0;
                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: opacity,
                      child: Text(
                        customer.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    );
                  },
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
                        const SizedBox(height: 40),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                            child: Text(
                              customer.name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          customer.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
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
                        const SizedBox(height: 20),
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
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Status badge
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, color: statusColor, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  FinancialCalculator.getStatusText(
                                    status,
                                  ).toUpperCase(),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Summary row
                        Card(
                          elevation: 2,
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 12,
                            ),
                            child: Row(
                              children: [
                                _SummaryCell(
                                  label: 'Debt',
                                  value: FinancialCalculator.formatCurrency(
                                    totalCredit,
                                  ),
                                  color: Colors.red.shade700,
                                ),
                                _divider(),
                                _SummaryCell(
                                  label: 'Repayments',
                                  value: FinancialCalculator.formatCurrency(
                                    totalPaid,
                                  ),
                                  color: Colors.green.shade700,
                                ),
                                _divider(),
                                _SummaryCell(
                                  label: 'Outstanding',
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
                        // Credit Limit Info
                        if (customer.creditLimit > 0)
                          Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            color: Colors.blueGrey.shade50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.blueGrey.shade100),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _summarySmall(
                                    label: 'Credit Limit',
                                    value: FinancialCalculator.formatCurrency(
                                      customer.creditLimit,
                                    ),
                                  ),
                                  _summarySmall(
                                    label: 'Available Credit',
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
                        const SizedBox(height: 20),
                        // Quick action buttons
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.add_shopping_cart,
                                  size: 20,
                                ),
                                label: const Text('Add Debt'),
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
                                  backgroundColor: Colors.green.shade700,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.account_balance_wallet,
                                  size: 20,
                                ),
                                label: const Text('Repayment'),
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
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                          icon: const Icon(
                            Icons.money_off,
                            size: 20,
                          ),
                          label: const Text('Add Refund / Discount'),
                          onPressed: () => _showTransactionDialog(
                            context,
                            ref,
                            defaultType: 'refund',
                            transactions: transactions,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Icon(
                              Icons.history,
                              size: 20,
                              color: AppColors.textLight,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Debt History',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
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
              error: (_, stack) => const SliverToBoxAdapter(child: SizedBox()),
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
                    final isRefund = tx.type == 'refund';
                    final color = isCredit
                        ? Colors.red.shade600
                        : (isRefund ? Colors.blue.shade600 : Colors.green.shade600);

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Card(
                        elevation: 1,
                        child: InkWell(
                          onTap: () {
                            _showTransactionDialog(
                              context,
                              ref,
                              existing: tx,
                              transactions: transactions,
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Row 1: Title and Amount
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: color.withValues(
                                        alpha: 0.1,
                                      ),
                                      child: Icon(
                                        isCredit
                                            ? Icons.arrow_upward
                                            : (isRefund ? Icons.money_off : Icons.arrow_downward),
                                        color: color,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tx.title?.isNotEmpty == true
                                                ? tx.title!
                                                : (isRefund
                                                      ? 'Refund / Discount'
                                                      : (isCredit
                                                            ? 'Credit'
                                                            : 'Payment')),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          _statusBadge(
                                            status:
                                                FinancialCalculator.calculateSingleTransactionStatus(
                                                  tx,
                                                  transactions,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            FinancialCalculator.formatCurrency(
                                              tx.amount,
                                            ),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          icon: const Icon(
                                            Icons.more_horiz,
                                            size: 20,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
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
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (tx.note?.isNotEmpty == true) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      tx.note!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.blueGrey.shade700,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                // Row 3: Date and Due Date
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 12,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDate(tx.date),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (tx.dueDate != null && isCredit)
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.event_available,
                                            size: 12,
                                            color:
                                                tx.dueDate!.isBefore(
                                                  DateTime.now(),
                                                )
                                                ? Colors.red
                                                : Colors.blueGrey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Due: ${_formatDate(tx.dueDate!)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight:
                                                  tx.dueDate!.isBefore(
                                                    DateTime.now(),
                                                  )
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color:
                                                  tx.dueDate!.isBefore(
                                                    DateTime.now(),
                                                  )
                                                  ? Colors.red
                                                  : Colors.blueGrey,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                            ),
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

  Widget _summarySmall({
    required String label,
    required String value,
    Color color = Colors.blueGrey,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge({required PaymentStatus status}) {
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
