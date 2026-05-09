import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/services/supabase_service.dart';
import '../../../data/models/transaction_model.dart';
import '../customers/customer_ledger_screen.dart' show customerLedgerProvider;
import '../../../shared/utils/financial_calculator.dart';
import '../dashboard/owner_dashboard_screen.dart' show dashboardStatsProvider;

final allTransactionsProvider = FutureProvider.autoDispose<List<TransactionModel>>((
  ref,
) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return supabaseService.getAllTransactions();
});

class TransactionScreen extends ConsumerWidget {
  const TransactionScreen({super.key});

  void _showAddTransactionDialog(BuildContext context, WidgetRef ref) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final customers = await ref.read(supabaseServiceProvider).getCustomers();
    if (!context.mounted) return;
    if (customers.isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Add a customer first')),
      );
      return;
    }

    String? selectedCustomerId = customers.first.id;
    String type = 'credit';
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Transaction'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Customer',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedCustomerId,
                      isDense: true,
                      items: customers
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => selectedCustomerId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
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
                        DropdownMenuItem<String>(
                          value: 'credit',
                          child: Text('Give Credit'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'payment',
                          child: Text('Receive Payment'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'refund',
                          child: Text('Refund / Discount'),
                        ),
                      ],
                      onChanged: (v) => setState(() => type = v!),
                    ),
                  ),
                ),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title / Item (e.g. Rice and Oil)',
                  ),
                ),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (Optional)',
                  ),
                ),
              ],
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
                        final amount = double.tryParse(amountController.text);
                        if (amount == null ||
                            amount <= 0 ||
                            selectedCustomerId == null) {
                          return;
                        }

                        if (type == 'payment' || type == 'refund') {
                          final customerTransactions = await ref.read(supabaseServiceProvider).getTransactionsForCustomer(selectedCustomerId!);
                          final currentBalance = FinancialCalculator.calculateRemainingBalance(customerTransactions);
                          if (amount > currentBalance + 0.001) {
                            final action = type == 'payment' ? 'Payment' : 'Refund';
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$action exceeds remaining outstanding balance.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                        }

                        setState(() => isLoading = true);
                        try {
                          await ref
                              .read(supabaseServiceProvider)
                              .addTransaction(
                                selectedCustomerId!,
                                amount,
                                type,
                                title: titleController.text.trim().isEmpty
                                    ? null
                                    : titleController.text.trim(),
                                note: noteController.text.trim().isEmpty
                                    ? null
                                    : noteController.text.trim(),
                              );
                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          ref.invalidate(allTransactionsProvider);
                          ref.invalidate(dashboardStatsProvider);
                          // Also invalidate the customer's ledger if it's open
                          ref.invalidate(
                            customerLedgerProvider(selectedCustomerId!),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Transaction added')),
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
                    : const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(allTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('All Transactions')),
      body: transactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(child: Text('No transactions found.'));
          }
          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              final isCredit = tx.type == 'credit';
              final isRefund = tx.type == 'refund';
              final iconColor = isCredit ? Colors.red : (isRefund ? Colors.blue : Colors.green);
              final icon = isRefund ? Icons.money_off : (isCredit ? Icons.arrow_upward : Icons.arrow_downward);
              final titleText = isRefund ? 'Refund Issued' : (isCredit ? 'Credit Given' : 'Payment Received');
              
              return ListTile(
                leading: Icon(
                  icon,
                  color: iconColor,
                ),
                title: Text(tx.title?.isNotEmpty == true ? tx.title! : titleText),
                subtitle: Text(tx.date.toString().split(' ')[0]),
                trailing: Text(
                  FinancialCalculator.formatCurrency(tx.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: iconColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransactionDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
