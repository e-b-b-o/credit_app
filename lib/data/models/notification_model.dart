class NotificationModel {
  final String id;
  final String customerId;
  final String ownerId;
  final String title;
  final String message;
  final String type; // 'reminder', 'alert', 'info'
  final bool isRead;
  final String? transactionId;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.customerId,
    required this.ownerId,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    this.transactionId,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      customerId: json['customer_id'],
      ownerId: json['owner_id'],
      title: json['title'],
      message: json['message'],
      type: json['type'],
      isRead: json['is_read'] ?? false,
      transactionId: json['transaction_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'owner_id': ownerId,
      'title': title,
      'message': message,
      'type': type,
      'is_read': isRead,
      'transaction_id': transactionId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
