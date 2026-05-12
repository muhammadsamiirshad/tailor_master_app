import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../providers/darzi_provider.dart';

class AddCustomerDialog extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final Customer? existingCustomer;

  const AddCustomerDialog({
    super.key,
    this.initialName = '',
    this.initialPhone = '',
    this.existingCustomer,
  });

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  final _notesCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _chestCtrl = TextEditingController();
  final _shoulderCtrl = TextEditingController();
  final _sleevesCtrl = TextEditingController();
  final _collarCtrl = TextEditingController();
  final _shalwarCtrl = TextEditingController();

  // Custom measurement rows: each entry is (labelCtrl, valueCtrl)
  final List<(TextEditingController, TextEditingController)> _customFields = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingCustomer;
    _nameCtrl = TextEditingController(
      text: existing?.name ?? widget.initialName,
    );
    _phoneCtrl = TextEditingController(
      text: existing?.phone ?? widget.initialPhone,
    );
    _notesCtrl.text = existing?.notes ?? '';

    if (existing != null) {
      _lengthCtrl.text = _formatMeasurement(existing.length);
      _chestCtrl.text = _formatMeasurement(existing.chest);
      _shoulderCtrl.text = _formatMeasurement(existing.shoulder);
      _sleevesCtrl.text = _formatMeasurement(existing.sleeves);
      _collarCtrl.text = _formatMeasurement(existing.collar);
      _shalwarCtrl.text = _formatMeasurement(existing.shalwar);

      for (final entry in existing.customMeasurements.entries) {
        _customFields.add((
          TextEditingController(text: entry.key),
          TextEditingController(text: _formatMeasurement(entry.value)),
        ));
      }
    }

    // Pre-populate with global measurement fields from settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final globalFields = context
          .read<DarziProvider>()
          .globalMeasurementFields;
      if (globalFields.isNotEmpty) {
        setState(() {
          final existingLabels = _customFields
              .map((pair) => pair.$1.text.trim().toLowerCase())
              .where((label) => label.isNotEmpty)
              .toSet();
          for (final label in globalFields) {
            if (existingLabels.contains(label.toLowerCase())) continue;
            _customFields.add((
              TextEditingController(text: label),
              TextEditingController(),
            ));
          }
        });
      }
    });
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _notesCtrl,
      _lengthCtrl,
      _chestCtrl,
      _shoulderCtrl,
      _sleevesCtrl,
      _collarCtrl,
      _shalwarCtrl,
    ]) {
      c.dispose();
    }
    for (final (a, b) in _customFields) {
      a.dispose();
      b.dispose();
    }
    super.dispose();
  }

  void _addCustomField() {
    setState(
      () =>
          _customFields.add((TextEditingController(), TextEditingController())),
    );
  }

  void _removeCustomField(int index) {
    final (a, b) = _customFields[index];
    a.dispose();
    b.dispose();
    setState(() => _customFields.removeAt(index));
  }

  // Returns 0.0 if empty or invalid — never fails
  double _parse(String text) => double.tryParse(text.trim()) ?? 0.0;

  String _formatMeasurement(double value) {
    if (value == 0) return '';
    final rounded = value.toStringAsFixed(1);
    return rounded.endsWith('.0') ? value.toStringAsFixed(0) : rounded;
  }

  // Validate a measurement field — optional, but must be a number if filled
  String? _validateMeasurement(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional → treated as 0
    final parsed = double.tryParse(v.trim());
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0) return 'Cannot be negative';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<DarziProvider>();
    final newPhone = _phoneCtrl.text.trim();

    // Check for duplicate phone number
    final isDuplicate = provider.customerHasPhone(
      newPhone,
      excludeCustomerId: widget.existingCustomer?.id,
    );

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'A customer with this phone number already exists.',
          ),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final customMeasurements = <String, double>{};
    for (final (labelCtrl, valueCtrl) in _customFields) {
      final label = labelCtrl.text.trim();
      if (label.isNotEmpty) {
        customMeasurements[label] = _parse(valueCtrl.text);
      }
    }

    final customer = Customer(
      id: widget.existingCustomer?.id,
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      length: _parse(_lengthCtrl.text),
      chest: _parse(_chestCtrl.text),
      shoulder: _parse(_shoulderCtrl.text),
      sleeves: _parse(_sleevesCtrl.text),
      collar: _parse(_collarCtrl.text),
      shalwar: _parse(_shalwarCtrl.text),
      customMeasurements: customMeasurements,
      notes: _notesCtrl.text.trim(),
    );

    try {
      final provider = context.read<DarziProvider>();
      if (widget.existingCustomer != null) {
        await provider.updateCustomer(customer);
      } else {
        await provider.addCustomer(customer);
      }
      if (!mounted) return;
      Navigator.pop(context, customer);
    } catch (e, st) {
      debugPrint('AddCustomer save failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save customer: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const emerald = Color(0xFF065F46);
    final isEditing = widget.existingCustomer != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF065F46), Color(0xFF0A7B5C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEditing ? 'Edit Customer' : 'Add Customer',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Name ──────────────────────────────────────────────
                      _DialogField(
                        controller: _nameCtrl,
                        label: 'Full Name *',
                        icon: Icons.person_outline_rounded,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Customer name is required';
                          }
                          if (v.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // ── Phone ─────────────────────────────────────────────
                      _DialogField(
                        controller: _phoneCtrl,
                        label: 'Phone *',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+\-\s()]'),
                          ),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Phone number is required';
                          }
                          final digits = v.replaceAll(RegExp(r'\D'), '');
                          if (digits.length < 7) {
                            return 'Enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // ── Measurements ──────────────────────────────────────
                      _FormSectionHeader(
                        icon: Icons.straighten_rounded,
                        label: 'MEASUREMENTS (inches)  — empty = 0',
                      ),
                      const SizedBox(height: 10),
                      _MeasurementRow(
                        label1: 'Length',
                        ctrl1: _lengthCtrl,
                        validator1: _validateMeasurement,
                        label2: 'Chest',
                        ctrl2: _chestCtrl,
                        validator2: _validateMeasurement,
                      ),
                      const SizedBox(height: 10),
                      _MeasurementRow(
                        label1: 'Shoulder',
                        ctrl1: _shoulderCtrl,
                        validator1: _validateMeasurement,
                        label2: 'Sleeves',
                        ctrl2: _sleevesCtrl,
                        validator2: _validateMeasurement,
                      ),
                      const SizedBox(height: 10),
                      _MeasurementRow(
                        label1: 'Collar',
                        ctrl1: _collarCtrl,
                        validator1: _validateMeasurement,
                        label2: 'Shalwar',
                        ctrl2: _shalwarCtrl,
                        validator2: _validateMeasurement,
                      ),
                      const SizedBox(height: 20),

                      // ── Extra Measurements ────────────────────────────────
                      Row(
                        children: [
                          const Expanded(
                            child: _FormSectionHeader(
                              icon: Icons.tune_rounded,
                              label: 'EXTRA MEASUREMENTS',
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addCustomField,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add'),
                            style: TextButton.styleFrom(
                              foregroundColor: emerald,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: const Size(0, 32),
                            ),
                          ),
                        ],
                      ),
                      if (_customFields.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No extra fields. Tap "Add" or define globally in Settings.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ...List.generate(_customFields.length, (i) {
                        final (labelCtrl, valueCtrl) = _customFields[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: labelCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    labelText: 'Label',
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: emerald,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Label required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: valueCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.]'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Value',
                                    hintText: '0',
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: emerald,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  validator: _validateMeasurement,
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: () => _removeCustomField(i),
                                icon: Icon(
                                  Icons.remove_circle_outline_rounded,
                                  color: Colors.red.shade400,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 20),

                      _FormSectionHeader(
                        icon: Icons.notes_rounded,
                        label: 'NOTES (optional)',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText:
                              'e.g. Preferred color, style notes, fitting remarks...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: emerald,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: emerald,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isEditing ? 'Update Customer' : 'Save Customer',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormSectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FormSectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF065F46)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF065F46),
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _DialogField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF065F46), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  final String label1;
  final TextEditingController ctrl1;
  final String? Function(String?)? validator1;
  final String label2;
  final TextEditingController ctrl2;
  final String? Function(String?)? validator2;

  const _MeasurementRow({
    required this.label1,
    required this.ctrl1,
    this.validator1,
    required this.label2,
    required this.ctrl2,
    this.validator2,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: ctrl1,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: label1,
              hintText: '0',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF065F46),
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
              ),
            ),
            validator: validator1,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: ctrl2,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: label2,
              hintText: '0',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF065F46),
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
              ),
            ),
            validator: validator2,
          ),
        ),
      ],
    );
  }
}
