import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:provider/provider.dart';

import 'add_customer_dialog.dart';
import '../models/customer.dart';
import '../providers/tailor_provider.dart';
import '../widgets/ad_banner_widget.dart';

class CustomersScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const CustomersScreen({super.key, this.onBack});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();
  List<Customer>? _searchResults;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// ✅ Use local in-memory search instead of database queries (INSTANT, NO LAG)
  Future<void> _onSearchChanged(String query, TailorProvider provider) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = null;
        _isSearching = false;
      });
      return;
    }
    // ✅ Use synchronous local filtering (no DB call)
    setState(() => _isSearching = true);
    final results = provider.filterCustomers(query.trim());
    // Add tiny delay to show loading state briefly (optional)
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  void _showAddCustomerDialog(
    BuildContext context, {
    String initialName = '',
    String initialPhone = '',
    Customer? existingCustomer,
  }) {
    showDialog(
      context: context,
      builder: (_) => AddCustomerDialog(
        initialName: initialName,
        initialPhone: initialPhone,
        existingCustomer: existingCustomer,
      ),
    );
  }

  Future<void> _showEditCustomerDialog(
    BuildContext context,
    TailorProvider provider,
    Customer customer,
  ) async {
    await showDialog(
      context: context,
      builder: (_) => AddCustomerDialog(existingCustomer: customer),
    );
    if (!mounted) return;
    if (_searchController.text.trim().isNotEmpty) {
      await _onSearchChanged(_searchController.text, provider);
    }
  }

  Future<bool> _confirmDeleteCustomer(
    BuildContext context,
    Customer customer,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text(
          'Delete ${customer.name} and all related orders? This cannot be undone.',
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
    return result ?? false;
  }

  Future<void> _importFromContacts(BuildContext context) async {
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Contacts permission denied. Please allow it in Settings.',
            ),
          ),
        );
      }
      return;
    }

    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );
    final withPhones = contacts.where((c) => c.phones.isNotEmpty).toList();

    if (!context.mounted) return;

    final selected = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ContactPickerSheet(contacts: withPhones),
    );

    if (selected != null && context.mounted) {
      _showAddCustomerDialog(
        context,
        initialName: selected.displayName,
        initialPhone: selected.phones.first.number,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Measurement Book'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              widget.onBack?.call();
            }
          },
        ),
        actions: [
          IconButton(
            onPressed: () => _importFromContacts(context),
            icon: const Icon(Icons.contacts_rounded),
            tooltip: 'Import from Contacts',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCustomerDialog(context),
        backgroundColor: const Color(0xFF065F46),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'Add Customer',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Selector<TailorProvider, List<Customer>>(
        selector: (context, provider) => provider.customers,
        builder: (context, allCustomers, _) {
          final displayList = _searchResults ?? allCustomers;
          // 🚀 Get provider reference for search operations
          final provider = context.read<TailorProvider>();

          return Column(
            children: [
              // ── Search bar ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (q) => _onSearchChanged(q, provider),
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('', provider);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF065F46),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              if (_isSearching)
                const LinearProgressIndicator(
                  color: Color(0xFF065F46),
                  minHeight: 2,
                ),
              // ── Customer count ────────────────────────────────────────────
              if (displayList.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        _searchController.text.isNotEmpty
                            ? '${displayList.length} result${displayList.length == 1 ? '' : 's'}'
                            : '${displayList.length} customer${displayList.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              const TailorAdBanner(),

              // ── List ──────────────────────────────────────────────────────
              Expanded(
                child: displayList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_search_rounded,
                              size: 72,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No customers found'
                                  : 'No customers yet.\nTap + to add one.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                        itemCount: displayList.length,
                        itemBuilder: (context, index) {
                          final customer = displayList[index];
                          return Dismissible(
                            key: ValueKey('customer_${customer.id ?? index}'),
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
                                await _showEditCustomerDialog(
                                  context,
                                  provider,
                                  customer,
                                );
                                return false;
                              }

                              final canDelete = await _confirmDeleteCustomer(
                                context,
                                customer,
                              );
                              if (!canDelete) return false;

                              if (customer.id != null) {
                                await provider.deleteCustomer(customer.id!);
                                if (mounted &&
                                    _searchController.text.trim().isNotEmpty) {
                                  await _onSearchChanged(
                                    _searchController.text,
                                    provider,
                                  );
                                }
                              }
                              return canDelete;
                            },
                            child: _CustomerTile(
                              customer: customer,
                              onEdit: () => _showEditCustomerDialog(
                                context,
                                provider,
                                customer,
                              ),
                              onDelete: () async {
                                final canDelete = await _confirmDeleteCustomer(
                                  context,
                                  customer,
                                );
                                if (canDelete && customer.id != null) {
                                  await provider.deleteCustomer(customer.id!);
                                  if (mounted &&
                                      _searchController.text
                                          .trim()
                                          .isNotEmpty) {
                                    await _onSearchChanged(
                                      _searchController.text,
                                      provider,
                                    );
                                  }
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Customer Tile ────────────────────────────────────────────────────────────

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomerTile({
    required this.customer,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF065F46),
          radius: 24,
          child: Text(
            customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              customer.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  Icons.phone_outlined,
                  size: 13,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  customer.phone,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                if (customer.notes.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.notes_rounded,
                    size: 12,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      customer.notes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 14),
          _MeasurementsGrid(customer: customer),
          if (customer.notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notes_rounded,
                    size: 16,
                    color: Colors.amber.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customer.notes,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[800],
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF065F46),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_rounded, size: 18),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Measurements Grid ────────────────────────────────────────────────────────

class _MeasurementsGrid extends StatelessWidget {
  final Customer customer;
  const _MeasurementsGrid({required this.customer});

  @override
  Widget build(BuildContext context) {
    final measurements = [
      ('Length', customer.length),
      ('Chest', customer.chest),
      ('Shoulder', customer.shoulder),
      ('Sleeves', customer.sleeves),
      ('Collar', customer.collar),
      ('Shalwar', customer.shalwar),
      ...customer.customMeasurements.entries.map((e) => (e.key, e.value)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent:
            64, // Fixed height to prevent vertical overflow on narrow screens
      ),
      itemCount: measurements.length,
      itemBuilder: (context, index) {
        final (label, value) = measurements[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF065F46).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${value.toStringAsFixed(1)}"',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF065F46),
                ),
              ),
            ],
          ),
        );
      },
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

// ─── Contact Picker Sheet ─────────────────────────────────────────────────────

class _ContactPickerSheet extends StatefulWidget {
  final List<Contact> contacts;

  const _ContactPickerSheet({required this.contacts});

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Contact> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.contacts;
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.contacts
          : widget.contacts
                .where(
                  (c) =>
                      c.displayName.toLowerCase().contains(q) ||
                      c.phones.any((p) => p.number.contains(q)),
                )
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select Contact',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search name or number…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No contacts found',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final contact = _filtered[index];
                        final phone = contact.phones.first.number;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(
                              0xFF065F46,
                            ).withValues(alpha: 0.15),
                            child: Text(
                              contact.displayName.isNotEmpty
                                  ? contact.displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ),
                          title: Text(contact.displayName),
                          subtitle: Text(phone),
                          onTap: () => Navigator.pop(context, contact),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
