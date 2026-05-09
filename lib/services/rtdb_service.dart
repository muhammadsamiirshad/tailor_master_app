import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/customer.dart';
import '../models/order.dart';

/// Service that wraps Firebase Realtime Database CRUD.
///
/// Data is stored per-user under:
///   users/{uid}/customers/{pushKey}
///   users/{uid}/orders/{pushKey}
///   users/{uid}/settings/{key}
class RTDBService {
  // Singleton
  RTDBService._internal();
  static final RTDBService instance = RTDBService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Current authenticated user's UID. Throws if not logged in.
  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated.');
    return uid;
  }

  DatabaseReference get _usersRef => _db.ref('users/$_uid');
  DatabaseReference get _customersRef => _usersRef.child('customers');
  DatabaseReference get _ordersRef => _usersRef.child('orders');
  DatabaseReference get _settingsRef => _usersRef.child('settings');

  // ─── Customers ─────────────────────────────────────────────────────────────

  Future<String> insertCustomer(Customer customer) async {
    final ref = _customersRef.push();
    await ref.set(customer.toMap());
    return ref.key!;
  }

  Future<List<Customer>> getAllCustomers() async {
    final snapshot = await _customersRef.get();
    if (!snapshot.exists || snapshot.value == null) return [];
    final data = snapshot.value as Map<dynamic, dynamic>;
    final list = data.entries
        .map((e) => Customer.fromMap(e.key as String, e.value as Map))
        .toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<List<Customer>> searchCustomers(String query) async {
    final all = await getAllCustomers();
    final lower = query.toLowerCase();
    return all
        .where(
          (c) =>
              c.name.toLowerCase().contains(lower) ||
              c.phone.contains(lower),
        )
        .toList();
  }

  Future<void> updateCustomer(Customer customer) async {
    if (customer.id == null) throw ArgumentError('Customer has no ID.');
    await _customersRef.child(customer.id!).update(customer.toMap());
  }

  Future<void> deleteCustomer(String id) async {
    await _customersRef.child(id).remove();
    // Also delete all orders for this customer.
    final orders = await getOrdersByCustomer(id);
    for (final o in orders) {
      if (o.id != null) await _ordersRef.child(o.id!).remove();
    }
  }

  // ─── Orders ────────────────────────────────────────────────────────────────

  Future<String> insertOrder(Order order) async {
    final ref = _ordersRef.push();
    await ref.set(order.toMap());
    return ref.key!;
  }

  Future<List<Order>> getAllOrders() async {
    final snapshot = await _ordersRef.get();
    if (!snapshot.exists || snapshot.value == null) return [];
    final data = snapshot.value as Map<dynamic, dynamic>;
    final list = data.entries
        .map((e) => Order.fromMap(e.key as String, e.value as Map))
        .toList();
    list.sort((a, b) => a.deliveryDate.compareTo(b.deliveryDate));
    return list;
  }

  Future<List<Order>> getOrdersByCustomer(String customerId) async {
    final all = await getAllOrders();
    return all.where((o) => o.customerId == customerId).toList();
  }

  /// Returns Pending orders whose delivery date is today or tomorrow.
  Future<List<Order>> getUrgentOrders() async {
    final all = await getAllOrders();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    return all.where((o) {
      if (!o.isPending) return false;
      final d = DateTime(
        o.deliveryDate.year,
        o.deliveryDate.month,
        o.deliveryDate.day,
      );
      return d == today || d == tomorrow;
    }).toList();
  }

  /// Returns Completed orders that still have a remaining balance.
  Future<List<Order>> getUdhaarOrders() async {
    final all = await getAllOrders();
    return all
        .where((o) => o.isCompleted && o.remainingBalance > 0)
        .toList();
  }

  Future<void> updateOrder(Order order) async {
    if (order.id == null) throw ArgumentError('Order has no ID.');
    await _ordersRef.child(order.id!).update(order.toMap());
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _ordersRef.child(orderId).update({'status': status});
  }

  Future<void> deleteOrder(String id) async {
    await _ordersRef.child(id).remove();
  }

  /// Adds [payment] to advancePaid (capped at totalCost).
  Future<void> recordAdvancePaid(String orderId, double payment) async {
    final snapshot = await _ordersRef.child(orderId).get();
    if (!snapshot.exists) return;
    final data = snapshot.value as Map<dynamic, dynamic>;
    final order = Order.fromMap(orderId, data);
    final newAdvance = (order.advancePaid + payment).clamp(
      0,
      order.totalCost,
    );
    await _ordersRef.child(orderId).update({'advancePaid': newAdvance});
  }

  // ─── Settings ──────────────────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final snapshot = await _settingsRef.child(key).get();
    if (!snapshot.exists) return null;
    return snapshot.value as String?;
  }

  Future<void> setSetting(String key, String value) async {
    await _settingsRef.child(key).set(value);
  }
}
