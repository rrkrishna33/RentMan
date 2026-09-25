import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../gst/eway_bill_json.dart';
import '../../gst/gst_master.dart';
import '../../models/sales_invoice.dart';
import '../../services/billing_provider.dart';
import '../../services/eway_bill_export_service.dart';
import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';
import 'billing_widgets.dart';

/// Prepare the e-way bill for an invoice:
/// 1. enter transport (Part-B) details,
/// 2. check the data against portal rules,
/// 3. export the bulk-upload JSON,
/// 4. after uploading on the portal, record the 12-digit EWB number.
class EwayBillScreen extends StatefulWidget {
  final int invoiceId;

  const EwayBillScreen({super.key, required this.invoiceId});

  @override
  State<EwayBillScreen> createState() => _EwayBillScreenState();
}

class _EwayBillScreenState extends State<EwayBillScreen> {
  final _transportKey = GlobalKey<FormState>();
  final _ewbKey = GlobalKey<FormState>();
  late SalesInvoice _invoice;
  late int _mode;
  late final TextEditingController _distance;
  late final TextEditingController _vehicle;
  late final TextEditingController _transporterId;
  late final TextEditingController _transporterName;
  late final TextEditingController _docNo;
  DateTime? _docDate;
  late final TextEditingController _ewbNo;
  DateTime? _ewbDate;
  DateTime? _ewbValidUpto;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _invoice = context.read<BillingProvider>().getInvoice(widget.invoiceId)!;
    final t = _invoice.transport;
    _mode = t.transMode;
    _distance = TextEditingController(text: t.distanceKm.toString());
    _vehicle = TextEditingController(text: t.vehicleNo);
    _transporterId = TextEditingController(text: t.transporterId);
    _transporterName = TextEditingController(text: t.transporterName);
    _docNo = TextEditingController(text: t.transDocNo);
    _docDate = t.transDocDate;
    _ewbNo = TextEditingController(text: _invoice.ewbNo);
    _ewbDate = _invoice.ewbDate;
    _ewbValidUpto = _invoice.ewbValidUpto;
  }

  @override
  void dispose() {
    for (final c in [_distance, _vehicle, _transporterId, _transporterName, _docNo, _ewbNo]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _orNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  /// Invoice with the transport fields as currently typed (not yet saved).
  SalesInvoice get _draft => _invoice.copyWith(
        transport: TransportDetails(
          transMode: _mode,
          distanceKm: int.tryParse(_distance.text.trim()) ?? 0,
          vehicleNo: _orNull(_vehicle) == null ? null : EwayBillJson.normalizeVehicleNo(_vehicle.text),
          transporterId: _orNull(_transporterId)?.toUpperCase(),
          transporterName: _orNull(_transporterName),
          transDocNo: _orNull(_docNo),
          transDocDate: _docDate,
        ),
      );

  Future<void> _saveTransport({bool quiet = false}) async {
    if (!_transportKey.currentState!.validate()) return;
    _invoice = await context.read<BillingProvider>().updateInvoiceHeader(_draft);
    if (!mounted || quiet) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transport details saved')));
  }

  Future<void> _export({required bool share}) async {
    if (!_transportKey.currentState!.validate()) return;
    final seller = context.read<SettingsService>().ewbSeller;
    final check = EwayBillJson.validate(_draft, seller);
    if (!check.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fix the items marked in red before exporting')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _saveTransport(quiet: true);
      if (share) {
        await EwayBillExportService.share(_invoice, seller);
      } else {
        await Clipboard.setData(ClipboardData(text: EwayBillJson.encode([_invoice], seller)));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON copied to clipboard')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveEwb() async {
    if (!_ewbKey.currentState!.validate()) return;
    _invoice = await context.read<BillingProvider>().updateInvoiceHeader(_invoice.copyWith(
          ewbNo: _ewbNo.text.trim(),
          ewbDate: _ewbDate ?? DateTime.now(),
          ewbValidUpto: _ewbValidUpto,
        ));
    if (!mounted) return;
    setState(() => _ewbDate = _invoice.ewbDate);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E-way bill number saved')));
  }

  Future<void> _clearEwb() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove e-way bill number?'),
        content: const Text('Use this after cancelling the e-way bill on the portal. It does not cancel it for you.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _invoice = await context.read<BillingProvider>().updateInvoiceHeader(_invoice.copyWith(clearEwb: true));
    if (!mounted) return;
    setState(() {
      _ewbNo.clear();
      _ewbDate = null;
      _ewbValidUpto = null;
    });
  }

  Future<DateTime?> _pickDate(DateTime? initial, {DateTime? last}) => showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime(2017, 7, 1),
        lastDate: last ?? DateTime.now().add(const Duration(days: 365)),
      );

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final check = EwayBillJson.validate(_draft, settings.ewbSeller);
    final totals = _invoice.totals;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          BillingHeader(title: 'E-Way Bill · ${_invoice.invoiceNo}'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                SectionCard(
                  title: 'Consignment',
                  child: Column(
                    children: [
                      TotalsRow('Buyer', _invoice.buyerName),
                      TotalsRow('To GSTIN', _invoice.isB2B ? _invoice.buyerGstin! : 'URP (unregistered)'),
                      TotalsRow('To state', GstMaster.stateLabel(_invoice.placeOfSupplyStateCode)),
                      TotalsRow('Invoice value', BillingFormat.money(totals.grandTotal), strong: true),
                    ],
                  ),
                ),
                SectionCard(
                  title: 'Transport (Part-B)',
                  child: Form(
                    key: _transportKey,
                    onChanged: () => setState(() {}),
                    child: Column(
                      children: [
                        DropdownButtonFormField<int>(
                          value: _mode,
                          decoration: const InputDecoration(labelText: 'Mode'),
                          items: TransportDetails.modeLabels.entries
                              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                              .toList(),
                          onChanged: (v) => setState(() => _mode = v ?? 1),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _distance,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Approx. distance (km)',
                            helperText: '0 = let the portal calculate from PIN codes',
                          ),
                          validator: (v) {
                            final n = int.tryParse((v ?? '').trim());
                            return (n == null || n < 0 || n > 4000) ? '0 to 4000' : null;
                          },
                        ),
                        const SizedBox(height: 12),
                        if (_mode == 1)
                          TextFormField(
                            controller: _vehicle,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(labelText: 'Vehicle number', hintText: 'e.g. TN01AB1234'),
                          )
                        else ...[
                          TextFormField(
                            controller: _docNo,
                            decoration: const InputDecoration(labelText: 'RR / Airway bill / Bill of lading no *'),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final d = await _pickDate(_docDate, last: DateTime.now());
                              if (d != null) setState(() => _docDate = d);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Transport document date *'),
                              child: Text(_docDate == null ? 'Select' : BillingFormat.date(_docDate!)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _transporterId,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(labelText: 'Transporter ID (GSTIN / TRANSIN)'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _transporterName,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Transporter name'),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _saveTransport,
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: const Text('Save transport details'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SectionCard(
                  title: 'Checks',
                  trailing: Icon(
                    check.isValid ? Icons.check_circle : Icons.error_outline,
                    color: check.isValid ? AppTheme.success : AppTheme.danger,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (check.errors.isEmpty && check.warnings.isEmpty)
                        const Text('Everything looks ready for upload.'),
                      ...check.errors.map((e) => _CheckLine(text: e, error: true)),
                      ...check.warnings.map((w) => _CheckLine(text: w, error: false)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy || !check.isValid ? null : () => _export(share: false),
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copy JSON'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _busy || !check.isValid ? null : () => _export(share: true),
                        icon: const Icon(Icons.ios_share),
                        label: const Text('Export JSON'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'How to generate',
                  child: const Text(
                    '1. Export the JSON and save it (e.g. to Files or Google Drive).\n'
                    '2. Open ${EwayBillExportService.portalUrl} and log in with your GSTIN.\n'
                    '3. Go to e-Waybill > Generate Bulk, choose the JSON file and upload.\n'
                    '4. Copy the 12-digit EWB number shown and save it below. It will print on the invoice.',
                  ),
                ),
                SectionCard(
                  title: 'E-way bill number',
                  trailing: _invoice.hasEwayBill
                      ? IconButton(
                          tooltip: 'Remove',
                          onPressed: _clearEwb,
                          icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                        )
                      : null,
                  child: Form(
                    key: _ewbKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _ewbNo,
                          keyboardType: TextInputType.number,
                          maxLength: 12,
                          decoration: const InputDecoration(labelText: 'EWB No (12 digits)', counterText: ''),
                          validator: (v) =>
                              RegExp(r'^[0-9]{12}$').hasMatch((v ?? '').trim()) ? null : 'Enter the 12-digit number',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final d = await _pickDate(_ewbDate, last: DateTime.now());
                                  if (d != null) setState(() => _ewbDate = d);
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Generated on'),
                                  child: Text(_ewbDate == null ? 'Today' : BillingFormat.date(_ewbDate!)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final d = await _pickDate(_ewbValidUpto);
                                  if (d != null) setState(() => _ewbValidUpto = d);
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Valid until'),
                                  child: Text(_ewbValidUpto == null ? 'Optional' : BillingFormat.date(_ewbValidUpto!)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saveEwb,
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Save EWB number'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  final String text;
  final bool error;

  const _CheckLine({required this.text, required this.error});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? Icons.cancel_outlined : Icons.info_outline,
            size: 18,
            color: error ? AppTheme.danger : AppTheme.warning,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
