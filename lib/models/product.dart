/// A saleable item in the product master used by GST sales invoices.
class Product {
  final int? id;
  final String name;
  final String hsnCode; // HSN for goods, SAC (starts with 99) for services
  final String unit; // UQC code, e.g. NOS, KGS
  final double price;
  final double gstRate;
  final bool priceIncludesTax;
  final DateTime lastUpdated;

  Product({
    this.id,
    required this.name,
    required this.hsnCode,
    this.unit = 'NOS',
    required this.price,
    required this.gstRate,
    this.priceIncludesTax = false,
    required this.lastUpdated,
  });

  bool get isService => hsnCode.startsWith('99');

  Product copyWith({int? id}) => Product(
        id: id ?? this.id,
        name: name,
        hsnCode: hsnCode,
        unit: unit,
        price: price,
        gstRate: gstRate,
        priceIncludesTax: priceIncludesTax,
        lastUpdated: lastUpdated,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'hsnCode': hsnCode,
        'unit': unit,
        'price': price,
        'gstRate': gstRate,
        'priceIncludesTax': priceIncludesTax ? 1 : 0,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as int?,
        name: map['name'] as String,
        hsnCode: (map['hsnCode'] ?? '') as String,
        unit: (map['unit'] ?? 'NOS') as String,
        price: ((map['price'] ?? 0) as num).toDouble(),
        gstRate: ((map['gstRate'] ?? 0) as num).toDouble(),
        priceIncludesTax: map['priceIncludesTax'] == 1,
        lastUpdated: DateTime.parse(map['lastUpdated'] as String),
      );
}
