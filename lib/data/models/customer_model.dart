class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String ownerId;
  final String? authUserId;
  final double creditLimit;
  final bool isActive;
  final DateTime createdAt;

  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.ownerId,
    this.authUserId,
    this.creditLimit = 0.0,
    this.isActive = true,
    required this.createdAt,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      ownerId: json['owner_id'],
      authUserId: json['auth_user_id'],
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'owner_id': ownerId,
      'auth_user_id': authUserId,
      'credit_limit': creditLimit,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
