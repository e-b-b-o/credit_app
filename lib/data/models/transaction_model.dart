class TransactionModel {
  final String id;
  final String customerId;
  final String ownerId;
  final double amount;
  final String type; // 'credit' or 'payment'
  final String? title;
  final DateTime date;
  final DateTime? dueDate;
  final String? note;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.customerId,
    required this.ownerId,
    required this.amount,
    required this.type,
    this.title,
    required this.date,
    this.dueDate,
    this.note,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      customerId: json['customer_id'],
      ownerId: json['owner_id'] ?? '',
      amount: (json['amount'] as num).toDouble(),
      type: json['type'],
      title: json['title'],
      date: DateTime.parse(json['date']),
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      note: json['note'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'owner_id': ownerId,
      'amount': amount,
      'type': type,
      'title': title,
      'date': date.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
