import '../../data/models/transaction_model.dart';

enum PaymentStatus {
  pending,
  partial,
  paid,
  overdue,
}

class TransactionBalance {
  final double totalDebt;
  final double totalPaid;
  final double totalRefunded;
  final double outstandingBalance;
  final double remainingCredit;
  final double creditLimit;

  TransactionBalance({
    required this.totalDebt,
    required this.totalPaid,
    required this.totalRefunded,
    required this.outstandingBalance,
    required this.remainingCredit,
    required this.creditLimit,
  });
}

class AgingCategory {
  final String label;
  int customerCount;
  double totalBalance;
  final List<String> customerIds;

  AgingCategory({
    required this.label,
    this.customerCount = 0,
    this.totalBalance = 0,
    required this.customerIds,
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

  static double calculateTotalRefunds(List<TransactionModel> transactions) {
    return transactions
        .where((t) => t.type == 'refund')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  static double calculateRemainingBalance(List<TransactionModel> transactions) {
    final totalCredits = calculateTotalCredits(transactions);
    final totalPayments = calculateTotalPayments(transactions);
    final totalRefunds = calculateTotalRefunds(transactions);
    
    // Balance = Total Debt - Total Payments - Total Refunds
    // Cannot be negative
    final balance = (totalCredits - totalPayments - totalRefunds).clamp(0.0, double.infinity);
    
    // Ensure we don't have weird floating point issues near zero
    if (balance < 0.001) return 0.0;
    
    return balance;
  }

  static TransactionBalance calculateCustomerBalance(List<TransactionModel> transactions, double creditLimit) {
    final totalDebt = calculateTotalCredits(transactions);
    final totalPaid = calculateTotalPayments(transactions);
    final totalRefunded = calculateTotalRefunds(transactions);
    final outstanding = calculateRemainingBalance(transactions);
    
    // For remaining credit, we only care about positive outstanding balances
    final effectiveOutstanding = outstanding > 0 ? outstanding : 0.0;
    final remainingCredit = (creditLimit - effectiveOutstanding).clamp(0.0, creditLimit);

    return TransactionBalance(
      totalDebt: totalDebt,
      totalPaid: totalPaid,
      totalRefunded: totalRefunded,
      outstandingBalance: outstanding,
      remainingCredit: remainingCredit,
      creditLimit: creditLimit,
    );
  }

  static PaymentStatus calculatePaymentStatus(List<TransactionModel> transactions) {
    final remaining = calculateRemainingBalance(transactions);

    final totalCredits = calculateTotalCredits(transactions);
    final totalPayments = calculateTotalPayments(transactions);
    final totalRefunds = calculateTotalRefunds(transactions);

    if (totalCredits == 0) {
      return (totalPayments + totalRefunds) > 0 ? PaymentStatus.paid : PaymentStatus.pending;
    }

    if (remaining <= 0) {
      return PaymentStatus.paid;
    }

    // Check for overdue credits
    final credits = transactions.where((t) => t.type == 'credit').toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Net payments available to apply to credits = payments + refunds
    double paymentsLeftToApply = (totalPayments + totalRefunds).clamp(0.0, double.infinity);
    bool hasOverdueUnpaid = false;
    
    for (var credit in credits) {
      if (paymentsLeftToApply >= credit.amount) {
        paymentsLeftToApply -= credit.amount;
      } else {
        // This credit is partially or fully unpaid
        if (credit.dueDate != null && credit.dueDate!.isBefore(DateTime.now())) {
          hasOverdueUnpaid = true;
          break;
        }
      }
    }

    if (hasOverdueUnpaid) {
      return PaymentStatus.overdue;
    }

    if ((totalPayments + totalRefunds) > 0 && remaining > 0) {
      return PaymentStatus.partial;
    }

    return PaymentStatus.pending;
  }

  static PaymentStatus calculateSingleTransactionStatus(TransactionModel tx, List<TransactionModel> allTransactions) {
    if (tx.type == 'payment' || tx.type == 'refund') return PaymentStatus.paid;

    final totalPayments = calculateTotalPayments(allTransactions);
    final totalRefunds = calculateTotalRefunds(allTransactions);
    
    // Net payments available = total payments + total refunds
    double paymentsLeft = (totalPayments + totalRefunds).clamp(0.0, double.infinity);
    
    final allCredits = allTransactions
        .where((t) => t.type == 'credit')
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    for (var credit in allCredits) {
      if (credit.id == tx.id) {
        final isFullyPaid = paymentsLeft >= credit.amount;
        final isPartiallyPaid = paymentsLeft > 0 && paymentsLeft < credit.amount;
        
        if (isFullyPaid) return PaymentStatus.paid;
        
        // Check for overdue if not fully paid
        final isOverdue = tx.dueDate != null && tx.dueDate!.isBefore(DateTime.now());
        if (isOverdue) return PaymentStatus.overdue;
        
        return isPartiallyPaid ? PaymentStatus.partial : PaymentStatus.pending;
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

  static List<AgingCategory> calculateAgingAnalysis(
    List<TransactionModel> allTransactions,
    List<String> allCustomerIds,
  ) {
    final now = DateTime.now();
    final categories = [
      AgingCategory(
        label: 'Current',
        customerCount: 0,
        totalBalance: 0,
        customerIds: [],
      ),
      AgingCategory(
        label: '1–7 Days',
        customerCount: 0,
        totalBalance: 0,
        customerIds: [],
      ),
      AgingCategory(
        label: '8–30 Days',
        customerCount: 0,
        totalBalance: 0,
        customerIds: [],
      ),
      AgingCategory(
        label: '30+ Days',
        customerCount: 0,
        totalBalance: 0,
        customerIds: [],
      ),
    ];

    for (var customerId in allCustomerIds) {
      final customerTxs = allTransactions
          .where((t) => t.customerId == customerId)
          .toList();
      final balance = calculateRemainingBalance(customerTxs);
      if (balance <= 0) continue;

      // Find the oldest unpaid credit for this customer
      final unpaidCredits =
          customerTxs.where((t) => t.type == 'credit').toList()
            ..sort((a, b) => a.date.compareTo(b.date));

      double paymentsLeft = calculateTotalPayments(customerTxs) + calculateTotalRefunds(customerTxs);
      TransactionModel? oldestUnpaid;

      for (var credit in unpaidCredits) {
        if (paymentsLeft >= credit.amount) {
          paymentsLeft -= credit.amount;
        } else {
          oldestUnpaid = credit;
          break;
        }
      }

      if (oldestUnpaid == null) continue; // Should not happen if balance > 0

      final dueDate = oldestUnpaid.dueDate ?? oldestUnpaid.date;
      if (dueDate.isAfter(now)) {
        // Current
        categories[0].customerIds.add(customerId);
        categories[0].customerCount++;
        categories[0].totalBalance += balance;
      } else {
        final daysOverdue = now.difference(dueDate).inDays;
        if (daysOverdue <= 7) {
          categories[1].customerIds.add(customerId);
          categories[1].customerCount++;
          categories[1].totalBalance += balance;
        } else if (daysOverdue <= 30) {
          categories[2].customerIds.add(customerId);
          categories[2].customerCount++;
          categories[2].totalBalance += balance;
        } else {
          categories[3].customerIds.add(customerId);
          categories[3].customerCount++;
          categories[3].totalBalance += balance;
        }
      }
    }

    return categories;
  }
}
