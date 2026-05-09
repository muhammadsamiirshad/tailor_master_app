class Order {
  final String? id;         // Realtime Database push key
  final String customerId;  // Customer push key (String)
  final String? clothImagePath;
  final double totalCost;
  final double advancePaid;
  final DateTime deliveryDate;
  final String status; // 'Pending' | 'Completed'

  const Order({
    this.id,
    required this.customerId,
    this.clothImagePath,
    required this.totalCost,
    required this.advancePaid,
    required this.deliveryDate,
    required this.status,
  });

  /// Remaining balance — always derived, never stored.
  double get remainingBalance => totalCost - advancePaid;

  bool get isPending => status == 'Pending';
  bool get isCompleted => status == 'Completed';

  /// Creates an [Order] from a Firebase RTDB snapshot map.
  factory Order.fromMap(String id, Map<dynamic, dynamic> map) {
    return Order(
      id: id,
      customerId: map['customerId'] as String? ?? '',
      clothImagePath: map['clothImagePath'] as String?,
      totalCost: (map['totalCost'] as num?)?.toDouble() ?? 0,
      advancePaid: (map['advancePaid'] as num?)?.toDouble() ?? 0,
      deliveryDate: DateTime.parse(map['deliveryDate'] as String),
      status: map['status'] as String? ?? 'Pending',
    );
  }

  /// Converts this [Order] to a Firebase RTDB map.
  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'clothImagePath': clothImagePath,
      'totalCost': totalCost,
      'advancePaid': advancePaid,
      'deliveryDate': deliveryDate.toIso8601String(),
      'status': status,
    };
  }

  Order copyWith({
    String? id,
    String? customerId,
    String? clothImagePath,
    double? totalCost,
    double? advancePaid,
    DateTime? deliveryDate,
    String? status,
  }) {
    return Order(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      clothImagePath: clothImagePath ?? this.clothImagePath,
      totalCost: totalCost ?? this.totalCost,
      advancePaid: advancePaid ?? this.advancePaid,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      status: status ?? this.status,
    );
  }
}
