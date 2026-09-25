import 'package:flutter/material.dart';

import '../../gst/gst_master.dart';
import '../../theme/app_theme.dart';

/// Shared formatting + small widgets for the GST billing screens.
class BillingFormat {
  BillingFormat._();

  static String money(double v) {
    final negative = v < 0;
    final fixed = v.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    var whole = parts[0];
    if (whole.length > 3) {
      final last3 = whole.substring(whole.length - 3);
      var rest = whole.substring(0, whole.length - 3);
      final groups = <String>[];
      while (rest.length > 2) {
        groups.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) groups.insert(0, rest);
      whole = '${groups.join(',')},$last3';
    }
    return '${negative ? '-' : ''}₹$whole.${parts[1]}';
  }

  static String date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String qty(double q) => q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();

  /// Parses user-typed numbers, tolerating commas and a leading ₹.
  static double? parse(String text) => double.tryParse(text.replaceAll(RegExp(r'[,₹\s]'), ''));
}

/// Dropdown of GST states / UTs.
class GstStateDropdown extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  final String hint;
  final bool required;

  const GstStateDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = 'State',
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final known = GstMaster.stateByCode(value) != null;
    return DropdownButtonFormField<int>(
      value: known ? value : null,
      isExpanded: true,
      decoration: InputDecoration(hintText: hint, prefixIcon: const Icon(Icons.map_outlined)),
      items: GstMaster.states
          .map((s) => DropdownMenuItem(value: s.code, child: Text(s.toString(), overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
      validator: required ? (v) => v == null ? 'Please select a state' : null : null,
    );
  }
}

/// Screen header matching the rest of the app.
class BillingHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;

  const BillingHeader({super.key, required this.title, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return GradientHeader(
      height: 120,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String label;
  final bool required;

  const FieldLabel(this.label, {super.key, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Colors.black87, fontSize: 13.5, fontWeight: FontWeight.w600),
          children: required ? const [TextSpan(text: ' *', style: TextStyle(color: AppTheme.danger))] : null,
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const SectionCard({super.key, required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class TotalsRow extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  final Color? color;

  const TotalsRow(this.label, this.value, {super.key, this.strong = false, this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: strong ? 16 : 14,
      fontWeight: strong ? FontWeight.bold : FontWeight.w500,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
