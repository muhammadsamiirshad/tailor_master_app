import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer.dart';
import '../models/order.dart';
import '../providers/tailor_provider.dart';
import 'add_order_screen.dart';

const _kEmerald = Color(0xFF065F46);

class OrderDetailsScreen extends StatelessWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Consumer<TailorProvider>(
      builder: (context, provider, _) {
        final order = provider.orderFor(orderId);
        if (order == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Order Details')),
            body: Center(
              child: Text(
                'Order not found.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ),
          );
        }

        final customer =
            provider.customerFor(order.customerId) ?? Customer.unknown();

        return Scaffold(
          appBar: AppBar(
            title: Text('Order #${order.shortId}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                tooltip: 'Edit Order',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddOrderScreen(existingOrder: order),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded),
                tooltip: 'Delete Order',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Order?'),
                      content: Text(
                        'Delete order #${order.shortId}? This cannot be undone.',
                      ),
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
                  if (confirmed == true && context.mounted) {
                    await provider.deleteOrder(order.id!);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Order deleted.')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _CustomerCard(customer: customer, order: order),
              const SizedBox(height: 12),
              _OrderSummaryCard(order: order),
              const SizedBox(height: 12),
              _ClothPhotoCard(path: order.clothImagePath),
              const SizedBox(height: 12),
              _OrderActions(order: order, customer: customer),
            ],
          ),
        );
      },
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final Order order;

  const _CustomerCard({required this.customer, required this.order});

  String _normalizeWhatsAppPhone(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.startsWith('+')) return cleaned;
    if (cleaned.startsWith('0')) return '+92${cleaned.substring(1)}';
    if (cleaned.startsWith('92')) return '+$cleaned';
    return cleaned;
  }

  Future<void> _launchCall(BuildContext context) async {
    if (customer.phone.trim().isEmpty) return;
    final uri = Uri.parse('tel:${customer.phone.trim()}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open dialer.')));
    }
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    if (customer.phone.trim().isEmpty) return;
    final phone = _normalizeWhatsAppPhone(customer.phone);
    final webPhone = phone.startsWith('+') ? phone.substring(1) : phone;
    final msg = Uri.encodeComponent(
      'Hello ${customer.name}, this is a message regarding your order #${order.shortId} from Tailor Master.',
    );

    final appUri = Uri.parse('whatsapp://send?phone=$phone&text=$msg');
    final webUri = Uri.parse('https://wa.me/$webPhone?text=$msg');

    bool launched = false;
    if (!kIsWeb && Platform.isAndroid) {
      launched = await launchUrl(appUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
      }
    } else {
      launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _kEmerald,
                  radius: 22,
                  child: Text(
                    customer.name.isNotEmpty
                        ? customer.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer.phone,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchCall(context),
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kEmerald,
                      side: BorderSide(color: _kEmerald.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchWhatsApp(context),
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text('WhatsApp'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF25D366),
                      side: BorderSide(
                        color: const Color(0xFF25D366).withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final Order order;

  const _OrderSummaryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE, d MMMM yyyy').format(order.deliveryDate);
    final balance = order.remainingBalance;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  order.isPending ? 'Pending' : 'Completed',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: order.isPending
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                  ),
                ),
                const Spacer(),
                Text(
                  'Rs ${order.totalCost.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(date, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 10),
            Row(
              children: [
                _SummaryPill(
                  label: 'Advance',
                  value: order.advancePaid,
                  color: _kEmerald,
                ),
                const SizedBox(width: 8),
                _SummaryPill(
                  label: 'Balance',
                  value: balance,
                  color: balance > 0
                      ? Colors.red.shade600
                      : Colors.grey.shade600,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
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

class _ClothPhotoCard extends StatelessWidget {
  final String? path;

  const _ClothPhotoCard({required this.path});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cloth Photo',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (path == null)
              Text('No photo added.', style: TextStyle(color: Colors.grey[600]))
            else if (kIsWeb)
              Text(
                'Photo preview is not available on web.',
                style: TextStyle(color: Colors.grey[600]),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(path!),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OrderActions extends StatelessWidget {
  final Order order;
  final Customer customer;

  const _OrderActions({required this.order, required this.customer});

  void _showPaymentDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final balance = order.remainingBalance;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record Payment - ${customer.name}'),
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
              await context.read<TailorProvider>().recordPayment(
                order.id!,
                balance,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${customer.name} - fully paid!'),
                    backgroundColor: _kEmerald,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: _kEmerald),
            child: const Text('Mark Fully Paid'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final amount = double.parse(amountCtrl.text.trim());
              Navigator.pop(ctx);
              await context.read<TailorProvider>().recordPayment(
                order.id!,
                amount,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Rs ${amount.toStringAsFixed(0)} recorded for ${customer.name}',
                    ),
                    backgroundColor: _kEmerald,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kEmerald,
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
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (order.isPending)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await context.read<TailorProvider>().updateOrderStatus(
                      order.id!,
                      'Completed',
                    );
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
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Mark Completed'),
                ),
              ),
            if (order.remainingBalance > 0) ...[
              if (order.isPending) const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showPaymentDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kEmerald,
                    side: BorderSide(color: _kEmerald.withValues(alpha: 0.4)),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Record Payment'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
