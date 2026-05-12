import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/customer.dart';
import '../models/order.dart';

/// Exception wrapper for database errors with friendly messages.
class DatabaseFailure implements Exception {
  final String message;
  const DatabaseFailure(this.message);

  @override
  String toString() => message;
}

/// Service that wraps Firebase Realtime Database CRUD with error handling & offline support.
///
/// Data is stored per-user under:
///   users/{uid}/customers/{pushKey}
///   users/{uid}/orders/{pushKey}
///   users/{uid}/settings/{key}
///
/// Offline Support: Data is cached locally via Firebase Persistence.
/// Connection State: Stream available via [connectionStream].
class RTDBService {
  // Singleton
  RTDBService._internal() {
    _initializeOfflinePersistence();
  }
  static final RTDBService instance = RTDBService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Initialize offline persistence once on app startup.
  void _initializeOfflinePersistence() {
    try {
      _db.setPersistenceEnabled(true);
      _db.setLoggingEnabled(false); // Set to true for debugging
    } catch (e) {
      // Persistence may already be enabled; ignore.
      print('Note: Offline persistence may already be enabled or unavailable.');
    }
  }

  /// Stream to monitor connection state.
  /// Emits `true` when online, `false` when offline.
  Stream<bool> get connectionStream => FirebaseDatabase.instance
      .ref('.info/connected')
      .onValue
      .map((event) => event.snapshot.value == true);

  /// Current authenticated user's UID. Throws if not logged in.
  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw DatabaseFailure('User not authenticated. Please log in first.');
    }
    return uid;
  }

  DatabaseReference get _usersRef => _db.ref('users/$_uid');
  DatabaseReference get _customersRef => _usersRef.child('customers');
  DatabaseReference get _ordersRef => _usersRef.child('orders');
  DatabaseReference get _settingsRef => _usersRef.child('settings');

  // ─── Customers ─────────────────────────────────────────────────────────────

  /// Insert a new customer.
  ///
  /// Throws [DatabaseFailure] on error.
  Future<String> insertCustomer(Customer customer) async {
    try {
      final ref = _customersRef.push();
      await ref.set(customer.toMap());
      return ref.key!;
    } catch (e) {
      throw DatabaseFailure('Failed to save customer: $e');
    }
  }

  /// Retrieve all customers for the current user.
  ///
  /// Returns empty list if no customers exist or user is offline.
  /// Throws [DatabaseFailure] on database error.
  Future<List<Customer>> getAllCustomers() async {
    try {
      final snapshot = await _customersRef.get();
      if (!snapshot.exists || snapshot.value == null) return [];
      final data = snapshot.value as Map<dynamic, dynamic>;
      final list = data.entries
          .map((e) => Customer.fromMap(e.key as String, e.value as Map))
          .toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (e) {
      throw DatabaseFailure(
        'Failed to load customers: $e. Data may be cached.',
      );
    }
  }

  /// Search customers by name or phone.
  ///
  /// Throws [DatabaseFailure] on error.
  Future<List<Customer>> searchCustomers(String query) async {
    try {
      final all = await getAllCustomers();
      final lower = query.toLowerCase();
      return all
          .where(
            (c) =>
                c.name.toLowerCase().contains(lower) || c.phone.contains(lower),
          )
          .toList();
    } catch (e) {
      throw DatabaseFailure('Search failed: $e');
    }
  }

  /// Update an existing customer.
  ///
  /// Throws [DatabaseFailure] if customer has no ID or on database error.
  Future<void> updateCustomer(Customer customer) async {
    try {
      if (customer.id == null) {
        throw DatabaseFailure('Customer must have an ID to update.');
      }
      await _customersRef.child(customer.id!).update(customer.toMap());
    } catch (e) {
      if (e is DatabaseFailure) rethrow;
      throw DatabaseFailure('Failed to update customer: $e');
    }
  }

  /// Delete a customer and all their orders.
  ///
  /// Throws [DatabaseFailure] on error.
  Future<void> deleteCustomer(String id) async {
    try {
      // Delete all orders for this customer first
      final orders = await getOrdersByCustomer(id);
      for (final o in orders) {
        if (o.id != null) await _ordersRef.child(o.id!).remove();
      }
      // Then delete the customer
      await _customersRef.child(id).remove();
    } catch (e) {
      if (e is DatabaseFailure) rethrow;
      throw DatabaseFailure('Failed to delete customer: $e');
    }
  }

  // ─── Orders ────────────────────────────────────────────────────────────────

  /// Insert a new order.
  ///
  /// Throws [DatabaseFailure] on error.
  Future<String> insertOrder(Order order) async {
    try {
      final ref = _ordersRef.push();
      await ref.set(order.toMap());
      return ref.key!;
    } catch (e) {
      throw DatabaseFailure('Failed to create order: $e');
    }
  }

  /// Retrieve all orders for the current user.
  ///
  /// Returns empty list if no orders exist.
  /// Throws [DatabaseFailure] on database error.
  Future<List<Order>> getAllOrders() async {
    try {
      final snapshot = await _ordersRef.get();
      if (!snapshot.exists || snapshot.value == null) return [];
      final data = snapshot.value as Map<dynamic, dynamic>;
      final list = data.entries
          .map((e) => Order.fromMap(e.key as String, e.value as Map))
          .toList();
      list.sort((a, b) => a.deliveryDate.compareTo(b.deliveryDate));
      return list;
    } catch (e) {
      throw DatabaseFailure('Failed to load orders: $e. Data may be cached.');
    }
  }

  /// Get orders for a specific customer.
  ///
  /// Throws [DatabaseFailure] on error.
  Future<List<Order>> getOrdersByCustomer(String customerId) async {
    try {
      final all = await getAllOrders();
      return all.where((o) => o.customerId == customerId).toList();
    } catch (e) {
      if (e is DatabaseFailure) rethrow;
      throw DatabaseFailure('Failed to load orders for this customer: $e');
    }
  }

  /// Returns pending orders due today or tomorrow.
  ///
  /// Throws [DatabaseFailure] on error.
  Future<List<Order>> getUrgentOrders() async {
    try {
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
    } catch (e) {
      if (e is DatabaseFailure) rethrow;
      throw DatabaseFailure('Failed to load urgent orders: $e');
    }
  }

  /// Returns completed orders with outstanding balance (udhaar).
  ///
  /// Throws [DatabaseFailure] on error.
  Future<List<Order>> getUdhaarOrders() async {
    try {
      final all = await getAllOrders();
      return all.where((o) => o.isCompleted && o.remainingBalance > 0).toList();
    } catch (e) {
      if (e is DatabaseFailure) rethrow;
      throw DatabaseFailure('Failed to load outstanding dues: $e');
    }
  }

  /// Update an existing order.
  ///
  /// Throws [DatabaseFailure] if order has no ID or on database error.
  Future<void> updateOrder(Order order) async {
    try {
      if (order.id == null) {
        throw DatabaseFailure('Order must have an ID to update.');
      }
      await _ordersRef.child(order.id!).update(order.toMap());
    } catch (e) {
      if (e is DatabaseFailure) rethrow;
      throw DatabaseFailure('Failed to update order: $e');
    }
  }

  /// Update the status of an order.
  ///
  /// Throws [DatabaseFailure] on error.
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _ordersRef.child(orderId).update({'status': status});
    } catch (e) {
      throw DatabaseFailure('Failed to update order status: $e');
    }
  }

  /// Delete an order.
  ///
  /// Throws [DatabaseFailure] on error.
  Future<void> deleteOrder(String id) async {
    try {
      await _ordersRef.child(id).remove();
    } catch (e) {
      throw DatabaseFailure('Failed to delete order: $e');
    }
  }

  /// Record a payment for an order (adds to advancePaid, capped at totalCost).
  ///
  /// Throws [DatabaseFailure] if order not found or on database error.
  Future<void> recordAdvancePaid(String orderId, double payment) async {
    try {
      if (payment <= 0) {
        throw DatabaseFailure('Payment amount must be greater than 0.');
      }
      final snapshot = await _ordersRef.child(orderId).get();
      if (!snapshot.exists) {
        throw DatabaseFailure('Order not found.');
      }
      final data = snapshot.value as Map<dynamic, dynamic>;
      final order = Order.fromMap(orderId, data);
      final newAdvance = (order.advancePaid + payment).clamp(
        0,
        order.totalCost,
      );
      await _ordersRef.child(orderId).update({'advancePaid': newAdvance});
    } catch (e) {
      if (e is DatabaseFailure) rethrow;
      throw DatabaseFailure('Failed to record payment: $e');
    }
  }

  // ─── Settings ──────────────────────────────────────────────────────────────

  /// Get a user setting by key.
  ///
  /// Returns null if setting doesn't exist.
  /// Throws [DatabaseFailure] on error.
  Future<String?> getSetting(String key) async {
    try {
      final snapshot = await _settingsRef.child(key).get();
      if (!snapshot.exists) return null;
      return snapshot.value as String?;
    } catch (e) {
      throw DatabaseFailure('Failed to load setting: $e');
    }
  }

  /// Set a user setting.
  ///
  /// Throws [DatabaseFailure] on error.
  Future<void> setSetting(String key, String value) async {
    try {
      await _settingsRef.child(key).set(value);
    } catch (e) {
      throw DatabaseFailure('Failed to save setting: $e');
    }
  }
}
