import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer.dart';
import '../models/order.dart';
import '../providers/darzi_provider.dart';
import 'add_order_screen.dart';
import 'order_details_screen.dart';

class UdhaarScreen extends StatelessWidget {
  final VoidCallback? onBack;

  const UdhaarScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Udhaar (Pending Dues)'),
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
      ),
      body: Consumer<DarziProvider>(
        builder: (context, provider, _) {
          final orders = provider.udhaarOrders;
          final customers = provider.customers;

          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 84,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No pending dues!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'All payments are cleared.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
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
                key: ValueKey('udhaar_${order.id ?? index}'),
                direction: DismissDirection.horizontal,
                background: const _SwipeAction(
                  color: Color(0xFF065F46),
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
                    await provider.deleteOrder(order.id!);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Order deleted.')),
                      );
                    }
                  }
                  return confirmed;
                },
                child: _UdhaarCard(order: order, customer: customer),
              );
            },
          );
        },
      ),
    );
  }

  Future<bool> _confirmDeleteOrder(BuildContext context, Order order) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Order?'),
        content: Text('Delete order #${order.id}? This cannot be undone.'),
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

// ─── Udhaar Card ──────────────────────────────────────────────────────────────

class _UdhaarCard extends StatelessWidget {
  final Order order;
  final Customer customer;

  const _UdhaarCard({required this.order, required this.customer});

  Future<void> _sendWhatsAppReminder(BuildContext context) async {
    // Strip spaces, dashes, parentheses for a clean number.
    final phone = customer.phone.replaceAll(RegExp(r'[\s\-()]'), '');
    final balance = order.remainingBalance.toStringAsFixed(0);

    final message = Uri.encodeComponent(
      'Your suit is ready. Remaining payment: Rs $balance. Please collect it.',
    );

    final uri = Uri.parse('https://wa.me/$phone?text=$message');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open WhatsApp. Please check the phone number.',
            ),
          ),
        );
      }
    }
  }

  void _showPaymentDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final balance = order.remainingBalance;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record Payment — ${customer.name}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pending: Rs ${balance.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount Received (Rs)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<DarziProvider>().recordPayment(
                order.id!,
                balance,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${customer.name} — fully paid!'),
                    backgroundColor: const Color(0xFF065F46),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF065F46),
            ),
            child: const Text('Mark Fully Paid'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final amount = double.parse(amountCtrl.text.trim());
              Navigator.pop(ctx);
              await context.read<DarziProvider>().recordPayment(
                order.id!,
                amount,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Rs ${amount.toStringAsFixed(0)} recorded for ${customer.name}',
                    ),
                    backgroundColor: const Color(0xFF065F46),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF065F46),
              foregroundColor: Colors.white,
            ),
            child: const Text('Record Payment'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailsScreen(orderId: order.id!),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      customer.phone,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _CostPill(
                          label: 'Total',
                          value: order.totalCost,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 8),
                        _CostPill(
                          label: 'Paid',
                          value: order.advancePaid,
                          color: const Color(0xFF065F46),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        'Pending: Rs ${order.remainingBalance.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Order #${order.id}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => _showPaymentDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF065F46),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(64, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Pay'),
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    onPressed: () => _sendWhatsAppReminder(context),
                    icon: const Icon(Icons.chat_rounded),
                    tooltip: 'Send WhatsApp Reminder',
                    iconSize: 26,
                    color: const Color(0xFF25D366),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF25D366,
                      ).withValues(alpha: 0.12),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                  Text(
                    'Remind',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Cost Pill ────────────────────────────────────────────────────────────────

class _CostPill extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _CostPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: Rs ${value.toStringAsFixed(0)}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
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
        borderRadius: BorderRadius.circular(14),
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
