import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../models/dashboard_summary.dart';
import '../models/order.dart';
import '../providers/darzi_provider.dart';
import 'add_order_screen.dart';
import 'order_details_screen.dart';

const _kEmerald = Color(0xFF065F46);

Customer _unknownCustomer() => Customer(
  name: 'Unknown',
  phone: '',
  length: 0,
  chest: 0,
  shoulder: 0,
  sleeves: 0,
  collar: 0,
  shalwar: 0,
);

class DashboardScreen extends StatelessWidget {
  final ValueChanged<int>? onNavigate;

  const DashboardScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddOrderScreen()),
        ),
        backgroundColor: _kEmerald,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Order'),
      ),
      // 🚀 Use Selector instead of Consumer to only rebuild when dashboard changes
      body: Selector<DarziProvider, DashboardSummary>(
        selector: (context, provider) => provider.dashboardSummary,
        builder: (context, dashboard, _) {
          final monthName = DateFormat('MMMM').format(DateTime.now());

          return RefreshIndicator(
            color: _kEmerald,
            onRefresh: () => context.read<DarziProvider>().init(),
            child: CustomScrollView(
              slivers: [
                // ── Gradient App Bar ─────────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 130,
                  floating: false,
                  pinned: true,
                  backgroundColor: _kEmerald,
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF047857), _kEmerald],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Tailor Master',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const _DateDisplay(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Welcome back, Ustad! 👋',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Stats Cards ─────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                        child: Row(
                          children: [
                            _StatCard(
                              icon: Icons.people_alt_rounded,
                              label: 'Customers',
                              value: '${dashboard.customerCount}',
                              color: const Color(0xFF0284C7),
                              onTap: () => onNavigate?.call(1),
                            ),
                            const SizedBox(width: 8),
                            _StatCard(
                              icon: Icons.assignment_rounded,
                              label: 'Orders',
                              value: '${dashboard.orderCount}',
                              color: _kEmerald,
                              onTap: () => onNavigate?.call(3),
                            ),
                            const SizedBox(width: 8),
                            _StatCard(
                              icon: Icons.access_time_rounded,
                              label: 'Pending',
                              value: '${dashboard.pendingCount}',
                              color: Colors.orange.shade700,
                              onTap: () => onNavigate?.call(3),
                            ),
                            const SizedBox(width: 8),
                            _StatCard(
                              icon: Icons.account_balance_wallet_rounded,
                              label: 'Udhaar',
                              value: dashboard.totalDues > 0
                                  ? 'Rs ${(dashboard.totalDues / 1000).toStringAsFixed(1)}k'
                                  : 'Rs 0',
                              color: Colors.red.shade600,
                              onTap: () => onNavigate?.call(2),
                            ),
                          ],
                        ),
                      ),

                      // ── Monthly Revenue ───────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF047857), _kEmerald],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.bar_chart_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$monthName Revenue',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Rs ${dashboard.monthRevenue.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${dashboard.thisMonthOrders.length} orders',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Collected: Rs ${dashboard.monthCollected.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Urgent Deliveries ────────────────────────────────────
                      if (dashboard.urgentOrders.isNotEmpty) ...[
                        _SectionHeader(
                          icon: Icons.warning_amber_rounded,
                          title: 'Urgent Deliveries',
                          count: dashboard.urgentOrders.length,
                          color: Colors.red.shade600,
                        ),
                        ...dashboard.urgentOrders.map((order) {
                          final customer =
                              dashboard.customerFor(order.customerId) ??
                              _unknownCustomer();
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: _UrgentOrderCard(
                              order: order,
                              customer: customer,
                            ),
                          );
                        }),
                      ] else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.green.shade600,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'No urgent deliveries today!',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),

                      // ── Upcoming Orders ──────────────────────────────────────
                      _SectionHeader(
                        icon: Icons.calendar_month_rounded,
                        title: 'Upcoming Orders',
                        count: dashboard.upcomingOrders.length,
                        color: _kEmerald,
                      ),
                      if (dashboard.upcomingOrders.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            'No pending orders. Tap + to add one.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        )
                      else
                        ...dashboard.upcomingOrders.map((order) {
                          final customer =
                              dashboard.customerFor(order.customerId) ??
                              _unknownCustomer();
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: _UpcomingOrderCard(
                              order: order,
                              customer: customer,
                            ),
                          );
                        }),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 7),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Urgent Order Card ────────────────────────────────────────────────────────

class _UrgentOrderCard extends StatelessWidget {
  final Order order;
  final Customer customer;

  const _UrgentOrderCard({required this.order, required this.customer});

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DarziProvider>();
    final formattedDate = DateFormat('d MMM').format(order.deliveryDate);
    final isToday = _isToday(order.deliveryDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isToday ? Colors.red.shade300 : Colors.orange.shade300,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailsScreen(orderId: order.id!),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ✅ Add cloth image thumbnail if available
              if (order.clothImagePath != null)
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey[200],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: kIsWeb
                        ? const Center(
                            child: Icon(
                              Icons.image_rounded,
                              color: Colors.grey,
                            ),
                          )
                        : Image.file(
                            File(order.clothImagePath!),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              if (order.clothImagePath != null) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isToday
                                ? Colors.red.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isToday
                                  ? Colors.red.shade300
                                  : Colors.orange.shade300,
                            ),
                          ),
                          child: Text(
                            isToday ? 'Today' : 'Tomorrow',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isToday
                                  ? Colors.red.shade700
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${customer.phone}  •  $formattedDate  •  Order #${order.shortId}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Rs ${order.totalCost.toStringAsFixed(0)}  •  Advance: Rs ${order.advancePaid.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () async {
                  await provider.updateOrderStatus(order.id!, 'Completed');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Order marked as Completed!'),
                        backgroundColor: _kEmerald,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kEmerald,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Upcoming Order Card ──────────────────────────────────────────────────────

class _UpcomingOrderCard extends StatelessWidget {
  final Order order;
  final Customer customer;

  const _UpcomingOrderCard({required this.order, required this.customer});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE, d MMM').format(order.deliveryDate);
    final daysLeft = order.deliveryDate.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: SizedBox(
          width: 50,
          height: 50,
          child: order.clothImagePath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: kIsWeb
                      ? Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image_rounded,
                            color: Colors.grey,
                          ),
                        )
                      : Image.file(
                          File(order.clothImagePath!),
                          fit: BoxFit.cover,
                        ),
                )
              : CircleAvatar(
                  backgroundColor: _kEmerald.withValues(alpha: 0.12),
                  child: Text(
                    order.shortId,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kEmerald,
                    ),
                  ),
                ),
        ),
        title: Text(
          customer.name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '📅 $date  •  Rs ${order.totalCost.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: daysLeft <= 2 ? Colors.red.shade50 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            daysLeft <= 0
                ? 'Today'
                : daysLeft == 1
                ? '1 day'
                : '$daysLeft days',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: daysLeft <= 2 ? Colors.red.shade700 : Colors.blue.shade700,
            ),
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailsScreen(orderId: order.id!),
            ),
          );
        },
      ),
    );
  }
}

/// Const widget for date display to avoid recalculation every rebuild
class _DateDisplay extends StatelessWidget {
  const _DateDisplay();

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEE, d MMM').format(DateTime.now());
    return Text(
      formattedDate,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
