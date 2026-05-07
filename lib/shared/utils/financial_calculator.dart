import '../../data/models/transaction_model.dart';

enum PaymentStatus { pending, partial, paid, overdue }

class TransactionBalance {
  final double totalDebt;
  final double totalPaid;
  final double outstandingBalance;
  final double remainingCredit;
  final double creditLimit;

  TransactionBalance({
    required this.totalDebt,
    required this.totalPaid,
    required this.outstandingBalance,
    required this.remainingCredit,
    required this.creditLimit,
  });
}

class FinancialCalculator {
  static String formatCurrency(double amount) {
    // Ethiopian currency formatting
    return 'ETB ${amount.toStringAsFixed(2)}';
  }

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
    final balance = totalCredits - totalPayments;

    // Ensure we don't have weird floating point issues near zero
    if (balance.abs() < 0.001) return 0.0;

    return balance;
  }

  static PaymentStatus calculatePaymentStatus(
    List<TransactionModel> transactions,
  ) {
    final totalCredits = calculateTotalCredits(transactions);
    final totalPayments = calculateTotalPayments(transactions);
    final remaining = calculateRemainingBalance(transactions);

    if (totalCredits == 0) {
      return totalPayments > 0 ? PaymentStatus.paid : PaymentStatus.pending;
    }

    if (remaining <= 0) {
      return PaymentStatus.paid;
    }

    // Check for overdue credits
    final credits = transactions.where((t) => t.type == 'credit').toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    double paymentsLeftToApply = totalPayments;
    bool hasOverdueUnpaid = false;

    for (var credit in credits) {
      if (paymentsLeftToApply >= credit.amount) {
        paymentsLeftToApply -= credit.amount;
      } else {
        // This credit is partially or fully unpaid
        if (credit.dueDate != null &&
            credit.dueDate!.isBefore(DateTime.now())) {
          hasOverdueUnpaid = true;
          break;
        }
      }
    }

    if (hasOverdueUnpaid) {
      return PaymentStatus.overdue;
    }

    if (totalPayments > 0 && remaining > 0) {
      return PaymentStatus.partial;
    }

    return PaymentStatus.pending;
  }

  static TransactionBalance calculateCustomerBalance(
    List<TransactionModel> transactions,
    double creditLimit,
  ) {
    final totalDebt = calculateTotalCredits(transactions);
    final totalPaid = calculateTotalPayments(transactions);
    final outstanding = calculateRemainingBalance(transactions);
    final remainingCredit = (creditLimit - outstanding).clamp(0.0, creditLimit);

    return TransactionBalance(
      totalDebt: totalDebt,
      totalPaid: totalPaid,
      outstandingBalance: outstanding,
      remainingCredit: remainingCredit,
      creditLimit: creditLimit,
    );
  }

  static PaymentStatus calculateSingleTransactionStatus(
    TransactionModel tx,
    List<TransactionModel> allTransactions,
  ) {
    if (tx.type == 'payment') return PaymentStatus.paid;

    final totalPayments = calculateTotalPayments(allTransactions);
    final creditsBeforeAndThis =
        allTransactions.where((t) => t.type == 'credit').toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    double paymentsLeft = totalPayments;
    for (var credit in creditsBeforeAndThis) {
      if (credit.id == tx.id) {
        if (paymentsLeft >= credit.amount) return PaymentStatus.paid;
        if (paymentsLeft > 0) return PaymentStatus.partial;
        if (tx.dueDate != null && tx.dueDate!.isBefore(DateTime.now()))
          return PaymentStatus.overdue;
        return PaymentStatus.pending;
      }
      paymentsLeft = (paymentsLeft - credit.amount).clamp(0.0, double.infinity);
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
