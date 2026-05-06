import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/services/supabase_service.dart';
import '../../../data/models/transaction_model.dart';

final allTransactionsProvider = FutureProvider<List<TransactionModel>>((ref) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return supabaseService.getAllTransactions();
});

class TransactionScreen extends ConsumerWidget {
  const TransactionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(allTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
      ),
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
              return ListTile(
                leading: Icon(
                  isCredit ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isCredit ? Colors.red : Colors.green,
                ),
                title: Text(isCredit ? 'Credit Given' : 'Payment Received'),
                subtitle: Text(tx.date.toString().split(' ')[0]),
                trailing: Text(
                  '\$${tx.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isCredit ? Colors.red : Colors.green,
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
        onPressed: () {
          // Open add transaction modal
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
