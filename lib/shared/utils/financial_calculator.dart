import '../../data/models/transaction_model.dart';

enum PaymentStatus {
  pending,
  partial,
  paid,
  overdue,
}

class FinancialCalculator {
  static double calculateTotalCredits(List<TransactionModel> transactions) {
    return transactions
        .where((t) => t.type == 'credit')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  static double calculateTotalPayments(List<TransactionModel> transactions) {
    return transactions
        .where((t) => t.type == 'payment')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  static double calculateRemainingBalance(List<TransactionModel> transactions) {
    final totalCredits = calculateTotalCredits(transactions);
    final totalPayments = calculateTotalPayments(transactions);
    return totalCredits - totalPayments;
  }

  static PaymentStatus calculatePaymentStatus(List<TransactionModel> transactions) {
    final totalCredits = calculateTotalCredits(transactions);
    final totalPayments = calculateTotalPayments(transactions);
    final remaining = totalCredits - totalPayments;

    if (totalCredits == 0) return PaymentStatus.paid; // No credits

    if (remaining <= 0) {
      return PaymentStatus.paid;
    }

    // Check for overdue credits
    // An overdue credit is a credit whose dueDate has passed AND the remaining balance > 0
    // To be precise, we compare total payments against credits sorted by date.
    // If unpaid credits have a due date in the past, it's overdue.
    final credits = transactions.where((t) => t.type == 'credit').toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    double paymentsLeftToApply = totalPayments;
    
    for (var credit in credits) {
      if (paymentsLeftToApply >= credit.amount) {
        paymentsLeftToApply -= credit.amount;
      } else {
        // This credit is partially or fully unpaid
        // Is it overdue?
        if (credit.dueDate != null && credit.dueDate!.isBefore(DateTime.now())) {
          return PaymentStatus.overdue;
        }
      }
    }

    if (totalPayments > 0 && remaining > 0) {
      return PaymentStatus.partial;
    }

    return PaymentStatus.pending;
  }

  static String getStatusText(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.partial:
        return 'Partial';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.overdue:
        return 'Overdue';
    }
  }
}
