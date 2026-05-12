import 'customer.dart';
import 'order.dart';

class DashboardSummary {
  final List<Customer> customers;
  final List<Order> urgentOrders;
  final List<Order> allOrders;
  final List<Order> upcomingOrders;
  final List<Order> thisMonthOrders;
  final double totalDues;
  final double monthRevenue;
  final double monthCollected;

  const DashboardSummary({
    required this.customers,
    required this.urgentOrders,
    required this.allOrders,
    required this.upcomingOrders,
    required this.thisMonthOrders,
    required this.totalDues,
    required this.monthRevenue,
    required this.monthCollected,
  });

  factory DashboardSummary.empty() {
    return const DashboardSummary(
      customers: <Customer>[],
      urgentOrders: <Order>[],
      allOrders: <Order>[],
      upcomingOrders: <Order>[],
      thisMonthOrders: <Order>[],
      totalDues: 0,
      monthRevenue: 0,
      monthCollected: 0,
    );
  }

  int get customerCount => customers.length;

  int get orderCount => allOrders.length;

  int get pendingCount => allOrders.where((order) => order.isPending).length;

  Map<String, Customer> get customersById {
    return {
      for (final customer in customers)
        if (customer.id != null) customer.id!: customer,
    };
  }

  Customer? customerFor(String customerId) => customersById[customerId];
}
