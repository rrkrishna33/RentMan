class Delivery {
  final int? id;
  final int bookingId;
  final String? courierName;
  final String? trackingNumber;
  final String status; // pending, dispatched, delivered, returned
  final DateTime? deliveryDate;
  final String? notes;
  final DateTime lastUpdated;
  final DateTime? returnDate;
  final String? returnCondition; // good, damaged, missing_items
  final String? packingPhotoPaths; // comma-separated local file paths

  Delivery({
    this.id,
    required this.bookingId,
    this.courierName,
    this.trackingNumber,
    required this.status,
    this.deliveryDate,
    this.notes,
    required this.lastUpdated,
    this.returnDate,
    this.returnCondition,
    this.packingPhotoPaths,
  });

  List<String> get packingPhotos =>
      (packingPhotoPaths == null || packingPhotoPaths!.isEmpty) ? [] : packingPhotoPaths!.split(',');

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookingId': bookingId,
    'courierName': courierName,
    'trackingNumber': trackingNumber,
    'status': status,
    'deliveryDate': deliveryDate?.toIso8601String(),
    'notes': notes,
    'lastUpdated': lastUpdated.toIso8601String(),
    'returnDate': returnDate?.toIso8601String(),
    'returnCondition': returnCondition,
    'packingPhotoPaths': packingPhotoPaths,
  };

  factory Delivery.fromJson(Map<String, dynamic> json) => Delivery(
    id: json['id'],
    bookingId: json['bookingId'],
    courierName: json['courierName'],
    trackingNumber: json['trackingNumber'],
    status: json['status'],
    deliveryDate: json['deliveryDate'] != null ? DateTime.parse(json['deliveryDate']) : null,
    notes: json['notes'],
    lastUpdated: DateTime.parse(json['lastUpdated']),
    returnDate: json['returnDate'] != null ? DateTime.parse(json['returnDate']) : null,
    returnCondition: json['returnCondition'],
    packingPhotoPaths: json['packingPhotoPaths'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'bookingId': bookingId,
    'courierName': courierName,
    'trackingNumber': trackingNumber,
    'status': status,
    'deliveryDate': deliveryDate?.toIso8601String(),
    'notes': notes,
    'lastUpdated': lastUpdated.toIso8601String(),
    'returnDate': returnDate?.toIso8601String(),
    'returnCondition': returnCondition,
    'packingPhotoPaths': packingPhotoPaths,
  };

  factory Delivery.fromMap(Map<String, dynamic> map) => Delivery(
    id: map['id'],
    bookingId: map['bookingId'],
    courierName: map['courierName'],
    trackingNumber: map['trackingNumber'],
    status: map['status'],
    deliveryDate: map['deliveryDate'] != null ? DateTime.parse(map['deliveryDate']) : null,
    notes: map['notes'],
    lastUpdated: DateTime.parse(map['lastUpdated']),
    returnDate: map['returnDate'] != null ? DateTime.parse(map['returnDate']) : null,
    returnCondition: map['returnCondition'],
    packingPhotoPaths: map['packingPhotoPaths'],
  );
}

class Reminder {
  final int? id;
  final int bookingId;
  final DateTime eventDate;
  final DateTime? lastNotifiedDate;
  final bool isSent;
  final int notificationCount;

  Reminder({
    this.id,
    required this.bookingId,
    required this.eventDate,
    this.lastNotifiedDate,
    required this.isSent,
    required this.notificationCount,
  });

  // Check if should send reminder (5-10 days before event)
  bool get shouldSendReminder {
    if (isSent) return false;
    final daysUntil = eventDate.difference(DateTime.now()).inDays;
    return daysUntil > 0 && daysUntil <= 10;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'bookingId': bookingId,
    'eventDate': eventDate.toIso8601String(),
    'lastNotifiedDate': lastNotifiedDate?.toIso8601String(),
    'isSent': isSent ? 1 : 0,
    'notificationCount': notificationCount,
  };

  factory Reminder.fromMap(Map<String, dynamic> map) => Reminder(
    id: map['id'],
    bookingId: map['bookingId'],
    eventDate: DateTime.parse(map['eventDate']),
    lastNotifiedDate: map['lastNotifiedDate'] != null ? DateTime.parse(map['lastNotifiedDate']) : null,
    isSent: map['isSent'] == 1,
    notificationCount: map['notificationCount'],
  );
}
