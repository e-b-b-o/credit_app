import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/supabase_service.dart';

import '../../shared/utils/financial_calculator.dart';
import '../../data/models/notification_model.dart';

final reminderServiceProvider = Provider((ref) {
  return ReminderService(ref);
});

class ReminderService {
  final Ref _ref;

  ReminderService(this._ref);

  Future<void> checkAndGenerateReminders() async {
    final supabaseService = _ref.read(supabaseServiceProvider);
    final user = supabaseService.currentUser;
    if (user == null) return;

    // Only owners can trigger reminder generation for their customers
    final role = user.userMetadata?['role'] as String? ?? 'owner';
    if (role != 'owner') return;

    final customers = await supabaseService.getCustomers();
    final allNotifications = await supabaseService.getNotifications();
    final now = DateTime.now();

    for (var customer in customers) {
      final transactions = await supabaseService.getTransactionsForCustomer(
        customer.id,
      );

      for (var tx in transactions) {
        if (tx.type != 'credit' || tx.dueDate == null) continue;

        final status = FinancialCalculator.calculateSingleTransactionStatus(
          tx,
          transactions,
        );
        if (status == PaymentStatus.paid) continue;

        final dueDate = tx.dueDate!;
        final daysUntilDue = dueDate.difference(now).inDays;

        // 1. Due Tomorrow Reminder
        if (daysUntilDue == 1) {
          await _sendUniqueNotification(
            customerId: customer.id,
            ownerId: customer.ownerId,
            transactionId: tx.id,
            title: 'Payment Due Tomorrow',
            message:
                'Your payment of ${FinancialCalculator.formatCurrency(tx.amount)} is due tomorrow.',
            type: 'reminder',
            allNotifications: allNotifications,
          );
        }
        // 2. Due Today Reminder
        else if (daysUntilDue == 0 && dueDate.day == now.day) {
          await _sendUniqueNotification(
            customerId: customer.id,
            ownerId: customer.ownerId,
            transactionId: tx.id,
            title: 'Payment Due Today',
            message:
                'Your payment of ${FinancialCalculator.formatCurrency(tx.amount)} is due today.',
            type: 'reminder',
            allNotifications: allNotifications,
          );
        }
        // 3. Overdue Alert
        else if (status == PaymentStatus.overdue) {
          await _sendUniqueNotification(
            customerId: customer.id,
            ownerId: customer.ownerId,
            transactionId: tx.id,
            title: 'Payment Overdue',
            message:
                'Your payment of ${FinancialCalculator.formatCurrency(tx.amount)} is now overdue.',
            type: 'alert',
            allNotifications: allNotifications,
          );
        }
      }
    }
  }

  Future<void> _sendUniqueNotification({
    required String customerId,
    required String ownerId,
    required String transactionId,
    required String title,
    required String message,
    required String type,
    required List<NotificationModel> allNotifications,
  }) async {
    // Check if a similar notification was already sent in the last 24 hours for this transaction
    final alreadySent = allNotifications.any(
      (n) =>
          n.transactionId == transactionId &&
          n.title == title &&
          DateTime.now().difference(n.createdAt).inHours < 24,
    );

    if (!alreadySent) {
      await _ref
          .read(supabaseServiceProvider)
          .sendNotification(
            customerId: customerId,
            ownerId: ownerId,
            title: title,
            message: message,
            type: type,
            transactionId: transactionId,
          );
    }
  }
}
