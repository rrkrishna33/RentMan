class Customer {
  final int? id;
  final String name;
  final String phone;
  final String? address;
  final DateTime createdDate;
  // GST billing details (all optional; empty GSTIN = unregistered buyer)
  final String? gstin;
  final int? stateCode;
  final String? city;
  final String? pincode;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    this.address,
    required this.createdDate,
    this.gstin,
    this.stateCode,
    this.city,
    this.pincode,
  });

  bool get isGstRegistered => gstin != null && gstin!.isNotEmpty;

  // Convert Customer to JSON for Google Drive sync
  Map<String, dynamic> toJson() => toMap();

  // Create Customer from JSON
  factory Customer.fromJson(Map<String, dynamic> json) => Customer.fromMap(json);

  // Convert to Map for SQLite
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'address': address,
    'createdDate': createdDate.toIso8601String(),
    'gstin': gstin,
    'stateCode': stateCode,
    'city': city,
    'pincode': pincode,
  };

  // Create Customer from SQLite Map
  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
    id: map['id'],
    name: map['name'],
    phone: map['phone'],
    address: map['address'],
    createdDate: DateTime.parse(map['createdDate']),
    gstin: map['gstin'],
    stateCode: map['stateCode'],
    city: map['city'],
    pincode: map['pincode'],
  );
}
