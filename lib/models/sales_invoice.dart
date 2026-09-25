import '../gst/gst_calculator.dart';

/// One line on a GST sales invoice. Name/HSN/rate are copied from the
/// product at billing time so later product edits don't change old bills.
class SalesInvoiceItem {
  final int? id;
  final int invoiceId;
  final int? productId;
  final String name;
  final String hsnCode;
  final String unit;
  final double quantity;
  final double rate;
  final double discountPercent;
  final double gstRate;
  final bool priceIncludesTax;

  SalesInvoiceItem({
    this.id,
    this.invoiceId = 0,
    this.productId,
    required this.name,
    required this.hsnCode,
    this.unit = 'NOS',
    required this.quantity,
    required this.rate,
    this.discountPercent = 0,
    required this.gstRate,
    this.priceIncludesTax = false,
  });

  GstLineInput get gstInput => GstLineInput(
        quantity: quantity,
        rate: rate,
        discountPercent: discountPercent,
        gstRate: gstRate,
        priceIncludesTax: priceIncludesTax,
        hsnCode: hsnCode,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoiceId': invoiceId,
        'productId': productId,
        'name': name,
        'hsnCode': hsnCode,
        'unit': unit,
        'quantity': quantity,
        'rate': rate,
        'discountPercent': discountPercent,
        'gstRate': gstRate,
        'priceIncludesTax': priceIncludesTax ? 1 : 0,
      };

  factory SalesInvoiceItem.fromMap(Map<String, dynamic> map) => SalesInvoiceItem(
        id: map['id'] as int?,
        invoiceId: (map['invoiceId'] ?? 0) as int,
        productId: map['productId'] as int?,
        name: map['name'] as String,
        hsnCode: (map['hsnCode'] ?? '') as String,
        unit: (map['unit'] ?? 'NOS') as String,
        quantity: ((map['quantity'] ?? 0) as num).toDouble(),
        rate: ((map['rate'] ?? 0) as num).toDouble(),
        discountPercent: ((map['discountPercent'] ?? 0) as num).toDouble(),
        gstRate: ((map['gstRate'] ?? 0) as num).toDouble(),
        priceIncludesTax: map['priceIncludesTax'] == 1,
      );
}

/// Transport details for Part-B of an e-way bill.
class TransportDetails {
  /// 1 = Road, 2 = Rail, 3 = Air, 4 = Ship.
  final int transMode;
  final int distanceKm; // 0 lets the portal calculate from PIN codes
  final String? transporterId;
  final String? transporterName;
  final String? vehicleNo;
  final String? transDocNo;
  final DateTime? transDocDate;

  const TransportDetails({
    this.transMode = 1,
    this.distanceKm = 0,
    this.transporterId,
    this.transporterName,
    this.vehicleNo,
    this.transDocNo,
    this.transDocDate,
  });

  static const modeLabels = {1: 'Road', 2: 'Rail', 3: 'Air', 4: 'Ship'};
}

/// A GST tax invoice. Buyer details are a snapshot taken at billing time.
class SalesInvoice {
  final int? id;
  final String invoiceNo;
  final DateTime invoiceDate;
  final int? customerId;
  final String buyerName;
  final String? buyerGstin; // null/empty = unregistered (B2C)
  final String? buyerPhone;
  final String? buyerAddress;
  final String? buyerPlace;
  final String? buyerPincode;
  final int placeOfSupplyStateCode;
  final int sellerStateCode;
  final double paidAmount;
  final String? notes;
  final TransportDetails transport;
  final String? ewbNo;
  final DateTime? ewbDate;
  final DateTime? ewbValidUpto;
  final DateTime lastUpdated;
  final List<SalesInvoiceItem> items;

  SalesInvoice({
    this.id,
    required this.invoiceNo,
    required this.invoiceDate,
    this.customerId,
    required this.buyerName,
    this.buyerGstin,
    this.buyerPhone,
    this.buyerAddress,
    this.buyerPlace,
    this.buyerPincode,
    required this.placeOfSupplyStateCode,
    required this.sellerStateCode,
    this.paidAmount = 0,
    this.notes,
    this.transport = const TransportDetails(),
    this.ewbNo,
    this.ewbDate,
    this.ewbValidUpto,
    required this.lastUpdated,
    required this.items,
  });

  bool get isB2B => buyerGstin != null && buyerGstin!.isNotEmpty;

  bool get isInterState => GstCalculator.isInterState(
        sellerStateCode: sellerStateCode,
        placeOfSupplyStateCode: placeOfSupplyStateCode,
      );

  GstInvoiceTotals get totals =>
      GstCalculator.computeInvoice(items.map((i) => i.gstInput).toList(), interState: isInterState);

  double get balanceAmount {
    final balance = totals.grandTotal - paidAmount;
    return balance < 0 ? 0 : round2(balance);
  }

  bool get hasEwayBill => ewbNo != null && ewbNo!.isNotEmpty;

  SalesInvoice copyWith({
    int? id,
    double? paidAmount,
    TransportDetails? transport,
    String? ewbNo,
    DateTime? ewbDate,
    DateTime? ewbValidUpto,
    bool clearEwb = false,
    List<SalesInvoiceItem>? items,
    DateTime? lastUpdated,
  }) =>
      SalesInvoice(
        id: id ?? this.id,
        invoiceNo: invoiceNo,
        invoiceDate: invoiceDate,
        customerId: customerId,
        buyerName: buyerName,
        buyerGstin: buyerGstin,
        buyerPhone: buyerPhone,
        buyerAddress: buyerAddress,
        buyerPlace: buyerPlace,
        buyerPincode: buyerPincode,
        placeOfSupplyStateCode: placeOfSupplyStateCode,
        sellerStateCode: sellerStateCode,
        paidAmount: paidAmount ?? this.paidAmount,
        notes: notes,
        transport: transport ?? this.transport,
        ewbNo: clearEwb ? null : (ewbNo ?? this.ewbNo),
        ewbDate: clearEwb ? null : (ewbDate ?? this.ewbDate),
        ewbValidUpto: clearEwb ? null : (ewbValidUpto ?? this.ewbValidUpto),
        lastUpdated: lastUpdated ?? this.lastUpdated,
        items: items ?? this.items,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoiceNo': invoiceNo,
        'invoiceDate': invoiceDate.toIso8601String(),
        'customerId': customerId,
        'buyerName': buyerName,
        'buyerGstin': buyerGstin,
        'buyerPhone': buyerPhone,
        'buyerAddress': buyerAddress,
        'buyerPlace': buyerPlace,
        'buyerPincode': buyerPincode,
        'placeOfSupplyStateCode': placeOfSupplyStateCode,
        'sellerStateCode': sellerStateCode,
        'paidAmount': paidAmount,
        'notes': notes,
        'transMode': transport.transMode,
        'transDistance': transport.distanceKm,
        'transporterId': transport.transporterId,
        'transporterName': transport.transporterName,
        'vehicleNo': transport.vehicleNo,
        'transDocNo': transport.transDocNo,
        'transDocDate': transport.transDocDate?.toIso8601String(),
        'ewbNo': ewbNo,
        'ewbDate': ewbDate?.toIso8601String(),
        'ewbValidUpto': ewbValidUpto?.toIso8601String(),
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  static DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v as String);

  factory SalesInvoice.fromMap(Map<String, dynamic> map, {List<SalesInvoiceItem> items = const []}) =>
      SalesInvoice(
        id: map['id'] as int?,
        invoiceNo: map['invoiceNo'] as String,
        invoiceDate: DateTime.parse(map['invoiceDate'] as String),
        customerId: map['customerId'] as int?,
        buyerName: map['buyerName'] as String,
        buyerGstin: map['buyerGstin'] as String?,
        buyerPhone: map['buyerPhone'] as String?,
        buyerAddress: map['buyerAddress'] as String?,
        buyerPlace: map['buyerPlace'] as String?,
        buyerPincode: map['buyerPincode'] as String?,
        placeOfSupplyStateCode: (map['placeOfSupplyStateCode'] ?? 0) as int,
        sellerStateCode: (map['sellerStateCode'] ?? 0) as int,
        paidAmount: ((map['paidAmount'] ?? 0) as num).toDouble(),
        notes: map['notes'] as String?,
        transport: TransportDetails(
          transMode: (map['transMode'] ?? 1) as int,
          distanceKm: (map['transDistance'] ?? 0) as int,
          transporterId: map['transporterId'] as String?,
          transporterName: map['transporterName'] as String?,
          vehicleNo: map['vehicleNo'] as String?,
          transDocNo: map['transDocNo'] as String?,
          transDocDate: _date(map['transDocDate']),
        ),
        ewbNo: map['ewbNo'] as String?,
        ewbDate: _date(map['ewbDate']),
        ewbValidUpto: _date(map['ewbValidUpto']),
        lastUpdated: DateTime.parse(map['lastUpdated'] as String),
        items: items,
      );
}
