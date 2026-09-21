class Customer {
  final int? id;
  final String name;
  final String phone;
  final String? address;
  final DateTime createdDate;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    this.address,
    required this.createdDate,
  });

  // Convert Customer to JSON for Google Drive sync
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'address': address,
    'createdDate': createdDate.toIso8601String(),
  };

  // Create Customer from JSON
  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'],
    name: json['name'],
    phone: json['phone'],
    address: json['address'],
    createdDate: DateTime.parse(json['createdDate']),
  );

  // Convert to Map for SQLite
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'address': address,
    'createdDate': createdDate.toIso8601String(),
  };

  // Create Customer from SQLite Map
  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
    id: map['id'],
    name: map['name'],
    phone: map['phone'],
    address: map['address'],
    createdDate: DateTime.parse(map['createdDate']),
  );
}
