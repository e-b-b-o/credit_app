import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/services/supabase_service.dart';
import '../../../data/models/complaint_model.dart';

final complaintsProvider = FutureProvider.autoDispose<List<ComplaintModel>>((ref) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return supabaseService.getComplaints();
});

class ComplaintsScreen extends ConsumerWidget {
  const ComplaintsScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'in_progress': return Colors.orange;
      case 'completed': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'in_progress': return 'In Progress';
      case 'completed': return 'Completed';
      default: return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaintsAsync = ref.watch(complaintsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Complaints'),
      ),
      body: complaintsAsync.when(
        data: (complaints) {
          if (complaints.isEmpty) {
            return const Center(child: Text('No complaints found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: complaints.length,
            itemBuilder: (context, index) {
              final complaint = complaints[index];
              final status = complaint.status;
              final statusColor = _statusColor(status);
              final statusLabel = _statusLabel(status);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              complaint.message,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          Chip(
                            label: Text(statusLabel),
                            backgroundColor: statusColor.withValues(alpha: 0.15),
                            labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                            side: BorderSide(color: statusColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Submitted: ${complaint.createdAt.toString().split(' ')[0]}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      // Action buttons depending on current status
                      if (status == 'pending')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start Working'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                            onPressed: () async {
                              try {
                                await ref.read(supabaseServiceProvider).resolveComplaint(complaint.id, 'in_progress');
                                ref.invalidate(complaintsProvider);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as In Progress')));
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            },
                          ),
                        )
                      else if (status == 'in_progress')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Mark Completed'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: () async {
                              try {
                                await ref.read(supabaseServiceProvider).resolveComplaint(complaint.id, 'completed');
                                ref.invalidate(complaintsProvider);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as Completed')));
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            },
                          ),
                        )
                      else
                        const Row(
                          children: [
                            Icon(Icons.done_all, color: Colors.green, size: 18),
                            SizedBox(width: 6),
                            Text('Issue resolved', style: TextStyle(color: Colors.green)),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
