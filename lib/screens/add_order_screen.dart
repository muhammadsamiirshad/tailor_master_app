import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'add_customer_dialog.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../providers/darzi_provider.dart';

class AddOrderScreen extends StatefulWidget {
  final Order? existingOrder;

  const AddOrderScreen({super.key, this.existingOrder});

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _totalCostController = TextEditingController();
  final _advancePaidController = TextEditingController();
  final _customerSearchCtrl = TextEditingController();

  Customer? _selectedCustomer;
  List<Customer> _searchResults = [];
  bool _showResults = false;
  String? _clothImagePath;
  DateTime? _deliveryDate;
  bool _isSaving = false;
  bool _didInit = false;

  @override
  void dispose() {
    _totalCostController.dispose();
    _advancePaidController.dispose();
    _customerSearchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    final existing = widget.existingOrder;
    if (existing == null) return;

    _totalCostController.text = existing.totalCost.toStringAsFixed(0);
    _advancePaidController.text = existing.advancePaid.toStringAsFixed(0);
    _deliveryDate = existing.deliveryDate;
    _clothImagePath = existing.clothImagePath;

    final provider = context.read<DarziProvider>();
    final customer = provider.customers.firstWhere(
      (c) => c.id == existing.customerId,
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
    _selectedCustomer = customer.id == null ? null : customer;
    _customerSearchCtrl.text = customer.id == null ? '' : customer.name;
  }

  void _onCustomerSearch(String query, DarziProvider provider) {
    if (_selectedCustomer != null) return;
    setState(() {
      _searchResults = provider.filterCustomers(query);
      _showResults = query.trim().isNotEmpty;
    });
  }

  void _selectCustomer(Customer c) {
    setState(() {
      _selectedCustomer = c;
      _customerSearchCtrl.text = c.name;
      _searchResults = [];
      _showResults = false;
    });
  }

  void _clearCustomer() {
    setState(() {
      _selectedCustomer = null;
      _customerSearchCtrl.clear();
      _searchResults = [];
      _showResults = false;
    });
  }

  Future<void> _showAddCustomerDialog() async {
    final customer = await showDialog<Customer>(
      context: context,
      builder: (_) => const AddCustomerDialog(),
    );
    if (customer != null && mounted) {
      _selectCustomer(customer);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _clothImagePath = picked.path);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_clothImagePath != null)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _clothImagePath = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate ?? now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF065F46),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _deliveryDate = picked);
  }

  // Returns 0.0 for empty/invalid — never crashes
  double _parseAmount(String text) => double.tryParse(text.trim()) ?? 0.0;

  Future<void> _saveOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCustomer == null) {
      _showSnackBar('Please select a customer.');
      return;
    }
    if (_deliveryDate == null) {
      _showSnackBar('Please select a delivery date.');
      return;
    }

    setState(() => _isSaving = true);

    final totalCost = _parseAmount(_totalCostController.text);
    final advancePaid = _parseAmount(_advancePaidController.text);

    final order = Order(
      id: widget.existingOrder?.id,
      customerId: _selectedCustomer!.id!,
      clothImagePath: _clothImagePath,
      totalCost: totalCost,
      advancePaid: advancePaid,
      deliveryDate: _deliveryDate!,
      status: widget.existingOrder?.status ?? 'Pending',
    );

    final provider = context.read<DarziProvider>();
    if (widget.existingOrder != null) {
      await provider.updateOrder(order);
    } else {
      await provider.addOrder(order);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    _showSnackBar(
      widget.existingOrder != null ? 'Order Updated!' : 'Order Saved!',
      success: true,
    );

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      _resetForm();
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _totalCostController.clear();
    _advancePaidController.clear();
    setState(() {
      _selectedCustomer = null;
      _customerSearchCtrl.clear();
      _searchResults = [];
      _showResults = false;
      _clothImagePath = null;
      _deliveryDate = null;
    });
  }

  void _showSnackBar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF065F46) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const emerald = Color(0xFF065F46);
    final isEditing = widget.existingOrder != null;
    final provider = context.watch<DarziProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Order' : 'New Order')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Customer Search ────────────────────────────────────────
                const _SectionLabel('Customer'),
                const SizedBox(height: 8),
                _CustomerSearchField(
                  controller: _customerSearchCtrl,
                  selectedCustomer: _selectedCustomer,
                  searchResults: _searchResults,
                  showResults: _showResults,
                  onSearch: (q) => _onCustomerSearch(q, provider),
                  onSelect: _selectCustomer,
                  onClear: _clearCustomer,
                ),
                if (_selectedCustomer == null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _showAddCustomerDialog,
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Add new customer'),
                      style: TextButton.styleFrom(
                        foregroundColor: emerald,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                    ),
                  ),
                if (provider.customers.isEmpty && _selectedCustomer == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: emerald.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: emerald.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No customers yet.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 40,
                            child: ElevatedButton.icon(
                              onPressed: _showAddCustomerDialog,
                              icon: const Icon(Icons.person_add_rounded),
                              label: const Text('Add Customer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: emerald,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // ── Cloth Photo ────────────────────────────────────────────────
                const _SectionLabel('Cloth Photo'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: emerald.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: emerald.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: _clothImagePath != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: kIsWeb
                                    ? Image.network(
                                        _clothImagePath!,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        File(_clothImagePath!),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Retake',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt_rounded,
                                size: 52,
                                color: emerald.withValues(alpha: 0.45),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Tap to take a photo of the fabric',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: emerald.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '(Optional)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Pricing ────────────────────────────────────────────────────
                const _SectionLabel('Pricing'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _totalCostController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: 'Total Cost (Rs)',
                    hintText: '0',
                    prefixIcon: const Icon(Icons.sell_outlined),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
                    ),
                  ),
                  validator: (v) {
                    // Empty = treated as 0 (valid)
                    if (v != null && v.trim().isNotEmpty) {
                      final parsed = double.tryParse(v.trim());
                      if (parsed == null) return 'Enter a valid number';
                      if (parsed < 0) return 'Cost cannot be negative';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _advancePaidController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: 'Advance Paid (Rs)',
                    hintText: '0',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
                    ),
                  ),
                  validator: (v) {
                    // Empty = treated as 0 (valid)
                    if (v != null && v.trim().isNotEmpty) {
                      final advance = double.tryParse(v.trim());
                      if (advance == null) return 'Enter a valid number';
                      if (advance < 0) return 'Advance cannot be negative';
                      final total =
                          double.tryParse(_totalCostController.text.trim()) ?? 0;
                      if (advance > total) {
                        return 'Advance cannot exceed total (Rs ${total.toStringAsFixed(0)})';
                      }
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // ── Delivery Date ──────────────────────────────────────────────
                const _SectionLabel('Delivery Date'),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.date_range_rounded),
                    ),
                    child: Text(
                      _deliveryDate != null
                          ? DateFormat(
                              'EEEE, d MMMM yyyy',
                            ).format(_deliveryDate!)
                          : 'Select delivery date',
                      style: TextStyle(
                        fontSize: 15,
                        color: _deliveryDate != null
                            ? Colors.black87
                            : Colors.grey[500],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // ── Submit Button ──────────────────────────────────────────────
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: emerald,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: emerald.withValues(alpha: 0.5),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Icon(
                          isEditing ? Icons.check_rounded : Icons.save_rounded,
                        ),
                  label: Text(
                    _isSaving
                        ? 'Saving…'
                        : isEditing
                        ? 'Update Order'
                        : 'Save Order',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Customer Search Field ──────────────────────────────────────────────────

class _CustomerSearchField extends StatelessWidget {
  final TextEditingController controller;
  final Customer? selectedCustomer;
  final List<Customer> searchResults;
  final bool showResults;
  final ValueChanged<String> onSearch;
  final ValueChanged<Customer> onSelect;
  final VoidCallback onClear;

  const _CustomerSearchField({
    required this.controller,
    required this.selectedCustomer,
    required this.searchResults,
    required this.showResults,
    required this.onSearch,
    required this.onSelect,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    const emerald = Color(0xFF065F46);

    if (selectedCustomer != null) {
      // Show selected customer card
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: emerald.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: emerald.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: emerald,
              radius: 22,
              child: Text(
                selectedCustomer!.name.isNotEmpty
                    ? selectedCustomer!.name[0].toUpperCase()
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
                    selectedCustomer!.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedCustomer!.phone,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Change customer',
              color: Colors.grey.shade600,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onSearch,
          decoration: InputDecoration(
            hintText: 'Type name or phone to search…',
            prefixIcon: const Icon(Icons.person_search_rounded),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: onClear,
                  )
                : null,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: emerald, width: 1.5),
            ),
          ),
        ),
        if (showResults && searchResults.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'No customers found.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ),
        if (showResults && searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: searchResults.length,
                separatorBuilder: (_, a) =>
                    Divider(height: 1, color: Colors.grey.shade100, indent: 56),
                itemBuilder: (context, i) {
                  final c = searchResults[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: emerald.withValues(alpha: 0.12),
                      radius: 20,
                      child: Text(
                        c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: emerald,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    title: Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      c.phone,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    onTap: () => onSelect(c),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF065F46),
        letterSpacing: 0.8,
      ),
    );
  }
}
