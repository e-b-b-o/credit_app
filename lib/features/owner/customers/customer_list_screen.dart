import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/services/supabase_service.dart';
import '../../../data/models/customer_model.dart';

final customersProvider = FutureProvider<List<CustomerModel>>((ref) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return supabaseService.getCustomers();
});

class CustomerListScreen extends ConsumerWidget {
  const CustomerListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
      ),
      body: customersAsync.when(
        data: (customers) {
          if (customers.isEmpty) {
            return const Center(child: Text('No customers found.'));
          }
          return ListView.builder(
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(customer.name[0].toUpperCase()),
                ),
                title: Text(customer.name),
                subtitle: Text(customer.phone),
                onTap: () {
                  // Navigate to customer details
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Open add customer modal
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
