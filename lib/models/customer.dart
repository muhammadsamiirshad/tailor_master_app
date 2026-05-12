import 'dart:convert';

import '../services/security_service.dart';

class Customer {
  final String? id; // Realtime Database push key (String)
  final String name;
  final String phone;

  // Standard measurements (in inches)
  final double length;
  final double chest;
  final double shoulder;
  final double sleeves;
  final double collar;
  final double shalwar;

  /// Any extra/custom measurements the tailor wants to record (JSON in DB).
  final Map<String, double> customMeasurements;

  /// Optional note / custom message for this customer.
  final String notes;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    required this.length,
    required this.chest,
    required this.shoulder,
    required this.sleeves,
    required this.collar,
    required this.shalwar,
    Map<String, double>? customMeasurements,
    this.notes = '',
  }) : customMeasurements = customMeasurements ?? {};

  factory Customer.unknown() {
    return Customer(
      name: 'Unknown',
      phone: '',
      length: 0,
      chest: 0,
      shoulder: 0,
      sleeves: 0,
      collar: 0,
      shalwar: 0,
    );
  }

  /// Creates a [Customer] from a Firebase RTDB snapshot map.
  factory Customer.fromMap(String id, Map<dynamic, dynamic> map) {
    Map<String, double> custom = {};
    try {
      final rawCustom = map['customMeasurements'];
      if (rawCustom != null) {
        if (rawCustom is String && rawCustom.isNotEmpty) {
          final decoded = jsonDecode(rawCustom) as Map<String, dynamic>;
          custom = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
        } else if (rawCustom is Map) {
          custom = Map<String, double>.fromEntries(
            rawCustom.entries.map(
              (e) => MapEntry(e.key.toString(), (e.value as num).toDouble()),
            ),
          );
        }
      }
    } catch (_) {}

    // Decrypt the phone number; falls back to plain-text for legacy rows.
    final rawPhone = map['phone'] as String? ?? '';
    final decryptedPhone = SecurityService.instance.decryptData(rawPhone);

    return Customer(
      id: id,
      name: map['name'] as String? ?? '',
      phone: decryptedPhone,
      length: (map['length'] as num?)?.toDouble() ?? 0,
      chest: (map['chest'] as num?)?.toDouble() ?? 0,
      shoulder: (map['shoulder'] as num?)?.toDouble() ?? 0,
      sleeves: (map['sleeves'] as num?)?.toDouble() ?? 0,
      collar: (map['collar'] as num?)?.toDouble() ?? 0,
      shalwar: (map['shalwar'] as num?)?.toDouble() ?? 0,
      customMeasurements: custom,
      notes: map['notes'] as String? ?? '',
    );
  }

  /// Converts this [Customer] to a Firebase RTDB map.
  /// The phone number is AES-encrypted before being persisted.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': SecurityService.instance.encryptData(phone),
      'length': length,
      'chest': chest,
      'shoulder': shoulder,
      'sleeves': sleeves,
      'collar': collar,
      'shalwar': shalwar,
      'customMeasurements': jsonEncode(customMeasurements),
      'notes': notes,
    };
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    double? length,
    double? chest,
    double? shoulder,
    double? sleeves,
    double? collar,
    double? shalwar,
    Map<String, double>? customMeasurements,
    String? notes,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      length: length ?? this.length,
      chest: chest ?? this.chest,
      shoulder: shoulder ?? this.shoulder,
      sleeves: sleeves ?? this.sleeves,
      collar: collar ?? this.collar,
      shalwar: shalwar ?? this.shalwar,
      customMeasurements:
          customMeasurements ?? Map.from(this.customMeasurements),
      notes: notes ?? this.notes,
    );
  }
}
