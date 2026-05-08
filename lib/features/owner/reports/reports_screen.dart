import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard/owner_dashboard_screen.dart';
import '../../../shared/utils/financial_calculator.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Analytics')),
      body: statsAsync.when(
        data: (stats) {
          final aging = stats['agingAnalysis'] as List<AgingCategory>;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Business Overview
                Text(
                  'Business Overview',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.4,
                  children: [
                    _buildStatCard(
                      context,
                      'Total Customers',
                      stats['customersCount'].toString(),
                      Icons.people,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      context,
                      'Debt Issued',
                      FinancialCalculator.formatCurrency(
                        stats['totalDebt'] as double,
                      ),
                      Icons.trending_up,
                      Colors.red,
                    ),
                    _buildStatCard(
                      context,
                      'Repayments',
                      FinancialCalculator.formatCurrency(
                        stats['totalCollected'] as double,
                      ),
                      Icons.payments,
                      Colors.green,
                    ),
                    _buildStatCard(
                      context,
                      'Outstanding',
                      FinancialCalculator.formatCurrency(
                        stats['totalOutstanding'] as double,
                      ),
                      Icons.account_balance_wallet,
                      Colors.orange,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 2. Overdue Status
                Text(
                  'Overdue Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Card(
                  color: Colors.red.shade50,
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.red.shade100),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20.0,
                      horizontal: 16.0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSimpleStat(
                            'Overdue Customers',
                            stats['overdueCustomersCount'].toString(),
                            Colors.red.shade900,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.red.shade100,
                        ),
                        Expanded(
                          child: _buildSimpleStat(
                            'Overdue Amount',
                            FinancialCalculator.formatCurrency(
                              stats['overdueBalance'] as double,
                            ),
                            Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 3. Aging Analysis
                Text(
                  'Aging Analysis',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...aging
                    .map((category) => _buildAgingRow(context, category)),

                const SizedBox(height: 24),

                // 4. Payment Performance
                Text(
                  'Collection Rate',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _buildCollectionProgress(
                  context,
                  stats['totalDebt'] as double,
                  stats['totalCollected'] as double,
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

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAgingRow(BuildContext context, AgingCategory category) {
    final bool isCurrent = category.label == 'Current';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 4,
          height: 32,
          decoration: BoxDecoration(
            color: isCurrent ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(
          category.label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${category.customerCount} Customers',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          FinancialCalculator.formatCurrency(category.totalBalance),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isCurrent ? Colors.green : Colors.red,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionProgress(
    BuildContext context,
    double totalDebt,
    double totalCollected,
  ) {
    final double percentage = totalDebt > 0 ? (totalCollected / totalDebt) : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Collection Progress'),
                Text(
                  '${(percentage * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                percentage > 0.7 ? Colors.green : Colors.orange,
              ),
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 8),
            Text(
              'Collected ${FinancialCalculator.formatCurrency(totalCollected)} out of ${FinancialCalculator.formatCurrency(totalDebt)} debt issued.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
