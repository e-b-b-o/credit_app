import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/services/supabase_service.dart';
import '../../../data/models/customer_model.dart';
import '../../../core/theme/app_colors.dart';
import '../dashboard/owner_dashboard_screen.dart' show dashboardStatsProvider;

final customersProvider = FutureProvider<List<CustomerModel>>((ref) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return supabaseService.getCustomers();
});

class CustomerListScreen extends ConsumerWidget {
  const CustomerListScreen({super.key});

  void _showCreateCredentialsDialog(
    BuildContext context,
    WidgetRef ref,
    CustomerModel customer,
  ) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create Login Credentials'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
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
                        if (emailController.text.isEmpty ||
                            passwordController.text.isEmpty) {
                          return;
                        }
                        setState(() => isLoading = true);
                        try {
                          await ref
                              .read(supabaseServiceProvider)
                              .createCustomerCredentials(
                                emailController.text.trim(),
                                passwordController.text.trim(),
                                customer.id,
                              );
                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Credentials created successfully'),
                            ),
                          );
                          ref.invalidate(customersProvider);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                          setState(() => isLoading = false);
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final creditLimitController = TextEditingController(text: '0');
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Customer'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: creditLimitController,
                    decoration: const InputDecoration(
                      labelText: 'Credit Limit (ETB)',
                      hintText: 'e.g. 5000',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
              ),
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
                        if (nameController.text.trim().isEmpty ||
                            phoneController.text.trim().isEmpty) {
                          return;
                        }
                        final creditLimit =
                            double.tryParse(creditLimitController.text) ?? 0.0;

                        setState(() => isLoading = true);
                        try {
                          final customer = await ref
                              .read(supabaseServiceProvider)
                              .addCustomer(
                                nameController.text.trim(),
                                phoneController.text.trim(),
                                creditLimit: creditLimit,
                              );
                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          ref.invalidate(customersProvider);
                          ref.invalidate(dashboardStatsProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Customer added successfully'),
                            ),
                          );

                          // Prompt to create login
                          _showCreateCredentialsDialog(context, ref, customer);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                          setState(() => isLoading = false);
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUpdateLimitDialog(
    BuildContext context,
    WidgetRef ref,
    CustomerModel customer,
  ) {
    final limitController = TextEditingController(
      text: customer.creditLimit.toString(),
    );
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Update Credit Limit'),
            content: TextField(
              controller: limitController,
              decoration: const InputDecoration(
                labelText: 'Credit Limit (ETB)',
                hintText: 'e.g. 5000',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
                        final limit = double.tryParse(limitController.text);
                        if (limit == null || limit < 0) return;

                        setState(() => isLoading = true);
                        try {
                          await ref
                              .read(supabaseServiceProvider)
                              .updateCustomerCreditLimit(customer.id, limit);
                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          ref.invalidate(customersProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Credit limit updated'),
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
                    : const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: customersAsync.when(
        data: (customers) {
          if (customers.isEmpty) {
            return const Center(child: Text('No customers found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    foregroundColor: AppColors.primary,
                    child: Text(customer.name[0].toUpperCase()),
                  ),
                  title: Text(
                    customer.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(customer.phone),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          context.push(
                            '/owner/customers/${customer.id}',
                            extra: customer,
                          );
                        },
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'create_login') {
                            _showCreateCredentialsDialog(
                              context,
                              ref,
                              customer,
                            );
                          } else if (value == 'set_limit') {
                            _showUpdateLimitDialog(context, ref, customer);
                          } else if (value == 'deactivate') {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Deactivate Customer'),
                                content: const Text(
                                  'Are you sure you want to deactivate this customer? They will no longer appear in the active lists.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text(
                                      'Deactivate',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await ref
                                  .read(supabaseServiceProvider)
                                  .deactivateCustomer(customer.id);
                              ref.invalidate(customersProvider);
                              ref.invalidate(dashboardStatsProvider);
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          if (customer.authUserId == null)
                            const PopupMenuItem(
                              value: 'create_login',
                              child: Text('Create Login'),
                            ),
                          const PopupMenuItem(
                            value: 'set_limit',
                            child: Text('Set Credit Limit'),
                          ),
                          const PopupMenuItem(
                            value: 'deactivate',
                            child: Text(
                              'Deactivate',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () {
                    context.push(
                      '/owner/customers/${customer.id}',
                      extra: customer,
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCustomerDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
