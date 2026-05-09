import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/customer.dart';
import '../models/order.dart';
import '../services/rtdb_service.dart';

class DarziProvider extends ChangeNotifier {
  final RTDBService _db = RTDBService.instance;

  List<Customer> _customers = [];
  List<Order> _urgentOrders = [];
  List<Order> _udhaarOrders = [];
  List<Order> _allOrders = [];
  List<String> _globalMeasurementFields = [];

  List<Customer> get customers => List.unmodifiable(_customers);
  List<Order> get urgentOrders => List.unmodifiable(_urgentOrders);
  List<Order> get udhaarOrders => List.unmodifiable(_udhaarOrders);
  List<Order> get allOrders => List.unmodifiable(_allOrders);

  /// Global extra measurement field names defined in Settings.
  List<String> get globalMeasurementFields =>
      List.unmodifiable(_globalMeasurementFields);

  // ─── Initialization ────────────────────────────────────────────────────────

  /// Call once after login to pre-load all data from Firebase RTDB.
  Future<void> init() async {
    await Future.wait([
      _loadCustomers(),
      _loadUrgentOrders(),
      _loadUdhaarOrders(),
      _loadAllOrders(),
      _loadGlobalMeasurementFields(),
    ]);
    notifyListeners();
  }

  // ─── Customers ─────────────────────────────────────────────────────────────

  Future<void> _loadCustomers() async {
    _customers = await _db.getAllCustomers();
  }

  Future<void> refreshCustomers() async {
    await _loadCustomers();
    notifyListeners();
  }

  /// Persists a new [Customer] and refreshes the customer list.
  /// Returns the newly assigned database ID.
  Future<String> addCustomer(Customer customer) async {
    final id = await _db.insertCustomer(customer);
    await _loadCustomers();
    notifyListeners();
    return id;
  }

  Future<void> updateCustomer(Customer customer) async {
    await _db.updateCustomer(customer);
    await _loadCustomers();
    notifyListeners();
  }

  Future<void> deleteCustomer(String id) async {
    await _db.deleteCustomer(id);
    // Cascade delete affects urgent/udhaar lists too.
    await Future.wait([
      _loadCustomers(),
      _loadUrgentOrders(),
      _loadUdhaarOrders(),
      _loadAllOrders(),
    ]);
    notifyListeners();
  }

  /// Live search — does NOT mutate [_customers]; returns a separate list.
  Future<List<Customer>> searchCustomers(String query) {
    return _db.searchCustomers(query);
  }

  /// Synchronous in-memory search for instant filtering.
  List<Customer> filterCustomers(String query) {
    if (query.trim().isEmpty) return [];
    final lower = query.toLowerCase();
    return _customers
        .where(
          (c) =>
              c.name.toLowerCase().contains(lower) || c.phone.contains(lower),
        )
        .take(10)
        .toList();
  }

  // ─── Settings / Global Measurement Fields ──────────────────────────────────

  Future<void> _loadGlobalMeasurementFields() async {
    final raw = await _db.getSetting('global_measurement_fields');
    if (raw != null && raw.isNotEmpty) {
      try {
        _globalMeasurementFields = List<String>.from(jsonDecode(raw) as List);
      } catch (_) {
        _globalMeasurementFields = [];
      }
    }
  }

  Future<void> _saveGlobalMeasurementFields() async {
    await _db.setSetting(
      'global_measurement_fields',
      jsonEncode(_globalMeasurementFields),
    );
  }

  Future<void> addGlobalMeasurementField(String label) async {
    if (_globalMeasurementFields.contains(label)) return;
    _globalMeasurementFields = [..._globalMeasurementFields, label];
    await _saveGlobalMeasurementFields();
    notifyListeners();
  }

  Future<void> removeGlobalMeasurementField(int index) async {
    final updated = List<String>.from(_globalMeasurementFields);
    updated.removeAt(index);
    _globalMeasurementFields = updated;
    await _saveGlobalMeasurementFields();
    notifyListeners();
  }

  Future<void> reorderGlobalMeasurementFields(
    int oldIndex,
    int newIndex,
  ) async {
    final updated = List<String>.from(_globalMeasurementFields);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    _globalMeasurementFields = updated;
    await _saveGlobalMeasurementFields();
    notifyListeners();
  }

  // ─── Orders ────────────────────────────────────────────────────────────────

  Future<void> _loadUrgentOrders() async {
    _urgentOrders = await _db.getUrgentOrders();
  }

  Future<void> _loadUdhaarOrders() async {
    _udhaarOrders = await _db.getUdhaarOrders();
  }

  Future<void> _loadAllOrders() async {
    _allOrders = await _db.getAllOrders();
  }

  /// Persists a new [Order] and refreshes all order-related lists.
  /// Returns the newly assigned database ID.
  Future<String> addOrder(Order order) async {
    final id = await _db.insertOrder(order);
    await Future.wait([
      _loadUrgentOrders(),
      _loadUdhaarOrders(),
      _loadAllOrders(),
    ]);
    notifyListeners();
    return id;
  }

  /// Updates an existing [Order] and refreshes all order-related lists.
  Future<void> updateOrder(Order order) async {
    await _db.updateOrder(order);
    await Future.wait([
      _loadUrgentOrders(),
      _loadUdhaarOrders(),
      _loadAllOrders(),
    ]);
    notifyListeners();
  }

  /// Marks an order as [status] ('Pending' or 'Completed') and refreshes.
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _db.updateOrderStatus(orderId, status);
    await Future.wait([
      _loadUrgentOrders(),
      _loadUdhaarOrders(),
      _loadAllOrders(),
    ]);
    notifyListeners();
  }

  Future<void> deleteOrder(String id) async {
    await _db.deleteOrder(id);
    await Future.wait([
      _loadUrgentOrders(),
      _loadUdhaarOrders(),
      _loadAllOrders(),
    ]);
    notifyListeners();
  }

  /// Records a partial (or full) payment on an udhaar order.
  Future<void> recordPayment(String orderId, double amount) async {
    await _db.recordAdvancePaid(orderId, amount);
    await Future.wait([_loadUdhaarOrders(), _loadAllOrders()]);
    notifyListeners();
  }

  /// Returns all orders for a specific customer (used on the customer detail screen).
  Future<List<Order>> getOrdersForCustomer(String customerId) {
    return _db.getOrdersByCustomer(customerId);
  }
}
