import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/tailor_provider.dart';
import '../widgets/ad_banner_widget.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const SettingsScreen({super.key, this.onBack});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _newFieldCtrl = TextEditingController();
  final _newFieldFocus = FocusNode();

  static const emerald = Color(0xFF065F46);

  @override
  void dispose() {
    _newFieldCtrl.dispose();
    _newFieldFocus.dispose();
    super.dispose();
  }

  void _addField(TailorProvider provider) {
    final label = _newFieldCtrl.text.trim();
    if (label.isEmpty) {
      _newFieldFocus.requestFocus();
      return;
    }

    // Check for duplicate field names
    if (provider.globalMeasurementFields
        .map((s) => s.toLowerCase())
        .contains(label.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$label" already exists.'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    provider.addGlobalMeasurementField(label);
    _newFieldCtrl.clear();
    _newFieldFocus.requestFocus();
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out?'),
        content: const Text(
          'You will be signed out of your account. Your data will remain saved in Firebase.',
          style: TextStyle(fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              // ✅ Use provider instead of direct Firebase call
              await context.read<TailorProvider>().signOut();
              // AuthGate will automatically redirect to login.
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    TailorProvider provider,
    int index,
    String label,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Field?'),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 15, color: Colors.black87),
            children: [
              const TextSpan(text: 'Remove "'),
              TextSpan(
                text: label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(
                text:
                    '" from global fields?\n\nThis won\'t affect existing customers.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              provider.removeGlobalMeasurementField(index);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
      ),
      body: Selector<TailorProvider, List<String>>(
        selector: (context, provider) => provider.globalMeasurementFields,
        builder: (context, customFields, _) {
          // 🚀 Get provider reference for modification operations
          final provider = context.read<TailorProvider>();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            children: [
              // ── Info card ─────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: emerald.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: emerald.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: emerald, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Measurement fields defined here will automatically appear for every new customer you add.',
                        style: TextStyle(fontSize: 14, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const TailorAdBanner(),
              const SizedBox(height: 20),

              // ── Measurement Fields ────────────────────────────────────────
              _SectionHeader(
                icon: Icons.tune_rounded,
                title: 'Measurement Fields',
                subtitle: customFields.isEmpty
                    ? 'None added yet'
                    : '${customFields.length} field${customFields.length == 1 ? '' : 's'}',
              ),
              const SizedBox(height: 10),

              if (customFields.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 28,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.add_circle_outline_rounded,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No measurement fields yet.\nAdd one below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: customFields.length,
                    onReorder: (oldIndex, newIndex) => provider
                        .reorderGlobalMeasurementFields(oldIndex, newIndex),
                    itemBuilder: (context, index) {
                      final field = customFields[index];
                      final isLast = index == customFields.length - 1;
                      return Column(
                        key: ValueKey(field),
                        children: [
                          ListTile(
                            dense: true,
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: emerald.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.straighten_rounded,
                                size: 16,
                                color: emerald,
                              ),
                            ),
                            title: Text(
                              field,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.red.shade400,
                                    size: 20,
                                  ),
                                  onPressed: () => _confirmDelete(
                                    context,
                                    provider,
                                    index,
                                    field,
                                  ),
                                  tooltip: 'Remove',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                ),
                                const Icon(
                                  Icons.drag_handle_rounded,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                          if (!isLast)
                            Divider(
                              height: 1,
                              indent: 56,
                              color: Colors.grey.shade100,
                            ),
                        ],
                      );
                    },
                  ),
                ),

              const SizedBox(height: 20),

              // ── Add New Field ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Add New Field',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: emerald,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newFieldCtrl,
                            focusNode: _newFieldFocus,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: 'e.g. Hip, Thigh, Waist…',
                              prefixIcon: const Icon(
                                Icons.straighten_rounded,
                                size: 20,
                              ),
                              isDense: true,
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
                            ),
                            onSubmitted: (_) => _addField(provider),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => _addField(provider),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: emerald,
                              foregroundColor: Colors.white,
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Danger Zone ────────────────────────────────────────────────
              _SectionHeader(
                icon: Icons.security_rounded,
                title: 'Account',
                // ✅ Use provider instead of direct Firebase call
                subtitle: context.read<TailorProvider>().currentUserEmail ?? '',
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: Colors.red.shade600,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                  subtitle: Text(
                    'Sign out of your account',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.red.shade300,
                  ),
                  onTap: () => _confirmLogout(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF065F46).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF065F46)),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ],
    );
  }
}
