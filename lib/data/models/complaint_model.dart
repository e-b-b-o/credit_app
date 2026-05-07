class ComplaintModel {
  final String id;
  final String customerId;
  final String ownerId;
  final String message;
  final String status; // 'pending' | 'in_progress' | 'completed'
  final DateTime createdAt;

  ComplaintModel({
    required this.id,
    required this.customerId,
    required this.ownerId,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      id: json['id'],
      customerId: json['customer_id'],
      ownerId: json['owner_id'],
      message: json['message'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'owner_id': ownerId,
      'message': message,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
