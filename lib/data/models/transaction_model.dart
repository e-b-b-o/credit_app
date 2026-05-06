class TransactionModel {
  final String id;
  final String customerId;
  final double amount;
  final String type; // 'credit' or 'payment'
  final DateTime date;
  final String? note;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.type,
    required this.date,
    this.note,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      customerId: json['customer_id'],
      amount: (json['amount'] as num).toDouble(),
      type: json['type'],
      date: DateTime.parse(json['date']),
      note: json['note'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'amount': amount,
      'type': type,
      'date': date.toIso8601String(),
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
