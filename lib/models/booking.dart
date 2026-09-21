class Booking {
  final int? id;
  final int customerId;
  final DateTime eventDate;
  final DateTime bookingDate;
  final double totalAmount;
  final double depositAmount;
  final double paidAmount;
  final bool balancePaid;
  final DateTime? balancePaidDate;
  final String? specialNotes;
  final DateTime lastUpdated;
  final List<BookingItem> items;

  Booking({
    this.id,
    required this.customerId,
    required this.eventDate,
    required this.bookingDate,
    this.totalAmount = 0,
    required this.depositAmount,
    this.paidAmount = 0,
    this.balancePaid = false,
    this.balancePaidDate,
    this.specialNotes,
    required this.lastUpdated,
    required this.items,
  });

  // Get days until event
  int get daysUntilEvent => eventDate.difference(DateTime.now()).inDays;

  // Check if reminder should be sent (5-10 days before)
  bool get shouldRemind => daysUntilEvent > 0 && daysUntilEvent <= 10;

  // Total amount is the sum of rent and deposit, and the remaining due is total minus paid.
  double get balanceAmount => (totalAmount - paidAmount).clamp(0, double.infinity);

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'eventDate': eventDate.toIso8601String(),
    'bookingDate': bookingDate.toIso8601String(),
    'totalAmount': totalAmount,
    'depositAmount': depositAmount,
    'paidAmount': paidAmount,
    'balancePaid': balancePaid,
    'balancePaidDate': balancePaidDate?.toIso8601String(),
    'specialNotes': specialNotes,
    'lastUpdated': lastUpdated.toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(),
  };

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
    id: json['id'],
    customerId: json['customerId'],
    eventDate: DateTime.parse(json['eventDate']),
    bookingDate: DateTime.parse(json['bookingDate']),
    totalAmount: (json['totalAmount'] ?? 0).toDouble(),
    depositAmount: (json['depositAmount'] ?? 0).toDouble(),
    paidAmount: (json['paidAmount'] ?? 0).toDouble(),
    balancePaid: (json['balancePaid'] ?? false) == true || json['balancePaid'] == 1,
    balancePaidDate: json['balancePaidDate'] != null ? DateTime.parse(json['balancePaidDate']) : null,
    specialNotes: json['specialNotes'],
    lastUpdated: DateTime.parse(json['lastUpdated']),
    items: (json['items'] as List)
        .map((item) => BookingItem.fromJson(item))
        .toList(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'customerId': customerId,
    'eventDate': eventDate.toIso8601String(),
    'bookingDate': bookingDate.toIso8601String(),
    'totalAmount': totalAmount,
    'depositAmount': depositAmount,
    'paidAmount': paidAmount,
    'balancePaid': balancePaid ? 1 : 0,
    'balancePaidDate': balancePaidDate?.toIso8601String(),
    'specialNotes': specialNotes,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory Booking.fromMap(Map<String, dynamic> map) => Booking(
    id: map['id'],
    customerId: map['customerId'],
    eventDate: DateTime.parse(map['eventDate']),
    bookingDate: DateTime.parse(map['bookingDate']),
    totalAmount: (map['totalAmount'] ?? 0).toDouble(),
    depositAmount: (map['depositAmount'] ?? 0).toDouble(),
    paidAmount: (map['paidAmount'] ?? 0).toDouble(),
    balancePaid: map['balancePaid'] == 1,
    balancePaidDate: map['balancePaidDate'] != null ? DateTime.parse(map['balancePaidDate']) : null,
    specialNotes: map['specialNotes'],
    lastUpdated: DateTime.parse(map['lastUpdated']),
    items: [],
  );
}

class BookingItem {
  final int? id;
  final int bookingId;
  final String itemName;
  final String? category; // dress, jewelry, accessory
  final int quantity;
  final String? photoPaths; // comma-separated paths

  BookingItem({
    this.id,
    required this.bookingId,
    required this.itemName,
    this.category,
    required this.quantity,
    this.photoPaths,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookingId': bookingId,
    'itemName': itemName,
    'category': category,
    'quantity': quantity,
    'photoPaths': photoPaths,
  };

  factory BookingItem.fromJson(Map<String, dynamic> json) => BookingItem(
    id: json['id'],
    bookingId: json['bookingId'],
    itemName: json['itemName'],
    category: json['category'],
    quantity: json['quantity'],
    photoPaths: json['photoPaths'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'bookingId': bookingId,
    'itemName': itemName,
    'category': category,
    'quantity': quantity,
    'photoPaths': photoPaths,
  };

  factory BookingItem.fromMap(Map<String, dynamic> map) => BookingItem(
    id: map['id'],
    bookingId: map['bookingId'],
    itemName: map['itemName'],
    category: map['category'],
    quantity: map['quantity'],
    photoPaths: map['photoPaths'],
  );
}
