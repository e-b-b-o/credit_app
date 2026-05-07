import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard/owner_dashboard_screen.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: statsAsync.when(
        data: (stats) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.people),
                    title: const Text('Total Active Customers'),
                    trailing: Text(stats['customersCount'].toString(), style: const TextStyle(fontSize: 20)),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.attach_money),
                    title: const Text('Total Outstanding'),
                    trailing: Text('\$${(stats['totalOutstanding'] as double).toStringAsFixed(2)}', style: const TextStyle(fontSize: 20)),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
