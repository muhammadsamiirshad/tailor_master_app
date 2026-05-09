import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../models/order.dart';
import '../providers/darzi_provider.dart';
import 'add_order_screen.dart';
import 'order_details_screen.dart';

const _kEmerald = Color(0xFF065F46);

class OrdersScreen extends StatelessWidget {
  final VoidCallback? onBack;

  const OrdersScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Orders'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                onBack?.call();
              }
            },
          ),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Pending'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
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
        body: Consumer<DarziProvider>(
          builder: (context, provider, _) {
            final all = provider.allOrders;
            final pending = all.where((o) => o.isPending).toList();
            final completed = all.where((o) => o.isCompleted).toList();
            final customers = provider.customers;

            return TabBarView(
              children: [
                _OrdersList(orders: all, customers: customers),
                _OrdersList(orders: pending, customers: customers),
                _OrdersList(orders: completed, customers: customers),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Orders List ──────────────────────────────────────────────────────────────

class _OrdersList extends StatelessWidget {
  final List<Order> orders;
  final List<Customer> customers;

  const _OrdersList({required this.orders, required this.customers});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No orders here yet',
              style: TextStyle(
                fontSize: 17,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final customer = customers.firstWhere(
          (c) => c.id == order.customerId,
          orElse: () => Customer(
            name: 'Unknown',
            phone: '',
            length: 0,
            chest: 0,
            shoulder: 0,
            sleeves: 0,
            collar: 0,
            shalwar: 0,
          ),
        );
        return Dismissible(
          key: ValueKey('order_${order.id ?? index}'),
          direction: DismissDirection.horizontal,
          background: const _SwipeAction(
            color: _kEmerald,
            icon: Icons.edit_rounded,
            label: 'Edit',
            alignment: Alignment.centerLeft,
          ),
          secondaryBackground: const _SwipeAction(
            color: Color(0xFFE11D48),
            icon: Icons.delete_rounded,
            label: 'Delete',
            alignment: Alignment.centerRight,
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddOrderScreen(existingOrder: order),
                ),
              );
              return false;
            }

            final confirmed = await _confirmDeleteOrder(context, order);
            if (!confirmed) return false;

            if (order.id != null) {
              await context.read<DarziProvider>().deleteOrder(order.id!);
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Order deleted.')));
              }
            }
            return confirmed;
          },
          child: _OrderCard(
            order: order,
            customer: customer,
            onEdit: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddOrderScreen(existingOrder: order),
                ),
              );
            },
            onDelete: () async {
              final confirmed = await _confirmDeleteOrder(context, order);
              if (confirmed && order.id != null) {
                await context.read<DarziProvider>().deleteOrder(order.id!);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Order deleted.')),
                  );
                }
              }
            },
          ),
        );
      },
    );
  }

  Future<bool> _confirmDeleteOrder(BuildContext context, Order order) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Order?'),
        content: Text('Delete order #${order.shortId}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ─── Order Card ───────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final Order order;
  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _OrderCard({
    required this.order,
    required this.customer,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DarziProvider>();
    final date = DateFormat('d MMM yyyy').format(order.deliveryDate);
    final isPending = order.isPending;
    final balance = order.remainingBalance;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      customer.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _StatusChip(isPending: isPending),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18, color: _kEmerald),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded, size: 18, color: Colors.red.shade600),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                customer.phone,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: _kEmerald,
                  ),
                  const SizedBox(width: 4),
                  Text(date, style: const TextStyle(fontSize: 13)),
                  const Spacer(),
                  Text(
                    'Rs ${order.totalCost.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (balance > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Balance due: Rs ${balance.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (isPending) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
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
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Mark Complete'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Status Chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final bool isPending;

  const _StatusChip({required this.isPending});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPending ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPending ? Colors.orange.shade300 : Colors.green.shade300,
        ),
      ),
      child: Text(
        isPending ? 'Pending' : 'Completed',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isPending ? Colors.orange.shade800 : Colors.green.shade700,
        ),
      ),
    );
  }
}

class _SwipeAction extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  const _SwipeAction({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
