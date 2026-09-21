import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/customer.dart';
import '../models/booking.dart';
import '../models/delivery.dart';

class DatabaseHelper {
  static const String _dbName = 'rental_app.db';
  static const int _dbVersion = 5;

  static const String customersTable = 'customers';
  static const String bookingsTable = 'bookings';
  static const String bookingItemsTable = 'booking_items';
  static const String deliveriesTable = 'deliveries';
  static const String remindersTable = 'reminders';

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _addColumnIfMissing(db, deliveriesTable, 'returnDate', 'TEXT');
    await _addColumnIfMissing(db, deliveriesTable, 'returnCondition', 'TEXT');
    await _addColumnIfMissing(db, deliveriesTable, 'packingPhotoPaths', 'TEXT');
    await _addColumnIfMissing(db, bookingsTable, 'totalAmount', 'REAL NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, bookingsTable, 'depositAmount', 'REAL NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, bookingsTable, 'paidAmount', 'REAL NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, bookingsTable, 'balancePaid', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, bookingsTable, 'balancePaidDate', 'TEXT');
  }

  // Safely add a column only if it doesn't already exist (guards against partial/duplicate migrations).
  Future<void> _addColumnIfMissing(Database db, String table, String column, String type) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((c) => c['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create customers table
    await db.execute('''
      CREATE TABLE $customersTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT,
        createdDate TEXT NOT NULL
      )
    ''');

    // Create bookings table
    await db.execute('''
      CREATE TABLE $bookingsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customerId INTEGER NOT NULL,
        eventDate TEXT NOT NULL,
        bookingDate TEXT NOT NULL,
        totalAmount REAL NOT NULL DEFAULT 0,
        depositAmount REAL NOT NULL DEFAULT 0,
        paidAmount REAL NOT NULL DEFAULT 0,
        balancePaid INTEGER NOT NULL DEFAULT 0,
        balancePaidDate TEXT,
        specialNotes TEXT,
        lastUpdated TEXT NOT NULL,
        FOREIGN KEY (customerId) REFERENCES $customersTable (id)
      )
    ''');

    // Create booking_items table
    await db.execute('''
      CREATE TABLE $bookingItemsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookingId INTEGER NOT NULL,
        itemName TEXT NOT NULL,
        category TEXT,
        quantity INTEGER NOT NULL,
        photoPaths TEXT,
        FOREIGN KEY (bookingId) REFERENCES $bookingsTable (id)
      )
    ''');

    // Create deliveries table
    await db.execute('''
      CREATE TABLE $deliveriesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookingId INTEGER NOT NULL,
        courierName TEXT,
        trackingNumber TEXT,
        status TEXT NOT NULL,
        deliveryDate TEXT,
        notes TEXT,
        lastUpdated TEXT NOT NULL,
        returnDate TEXT,
        returnCondition TEXT,
        packingPhotoPaths TEXT,
        FOREIGN KEY (bookingId) REFERENCES $bookingsTable (id)
      )
    ''');

    // Create reminders table
    await db.execute('''
      CREATE TABLE $remindersTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookingId INTEGER NOT NULL,
        eventDate TEXT NOT NULL,
        lastNotifiedDate TEXT,
        isSent INTEGER NOT NULL DEFAULT 0,
        notificationCount INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (bookingId) REFERENCES $bookingsTable (id)
      )
    ''');
  }

  // ==================== CUSTOMER OPERATIONS ====================

  Future<int> insertCustomer(Customer customer) async {
    final db = await database;
    return await db.insert(customersTable, customer.toMap());
  }

  Future<Customer?> getCustomer(int id) async {
    final db = await database;
    final result = await db.query(
      customersTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? Customer.fromMap(result.first) : null;
  }

  Future<List<Customer>> getAllCustomers() async {
    final db = await database;
    final result = await db.query(customersTable);
    return result.map((map) => Customer.fromMap(map)).toList();
  }

  Future<int> updateCustomer(Customer customer) async {
    final db = await database;
    return await db.update(
      customersTable,
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return await db.delete(
      customersTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== BOOKING OPERATIONS ====================

  Future<int> insertBooking(Booking booking) async {
    final db = await database;
    final bookingId = await db.insert(bookingsTable, booking.toMap());
    
    // Insert booking items
    for (var item in booking.items) {
      await db.insert(bookingItemsTable, {
        ...item.toMap(),
        'bookingId': bookingId,
      });
    }
    
    // Create reminder
    await db.insert(remindersTable, {
      'bookingId': bookingId,
      'eventDate': booking.eventDate.toIso8601String(),
      'isSent': 0,
      'notificationCount': 0,
    });
    
    return bookingId;
  }

  Future<Booking?> getBooking(int id) async {
    final db = await database;
    final result = await db.query(
      bookingsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (result.isEmpty) return null;
    
    final booking = Booking.fromMap(result.first);
    final itemsResult = await db.query(
      bookingItemsTable,
      where: 'bookingId = ?',
      whereArgs: [id],
    );
    
    return Booking(
      id: booking.id,
      customerId: booking.customerId,
      eventDate: booking.eventDate,
      bookingDate: booking.bookingDate,
      totalAmount: booking.totalAmount,
      depositAmount: booking.depositAmount,
      paidAmount: booking.paidAmount,
      specialNotes: booking.specialNotes,
      lastUpdated: booking.lastUpdated,
      items: itemsResult.map((map) => BookingItem.fromMap(map)).toList(),
    );
  }

  Future<List<Booking>> getAllBookings() async {
    final db = await database;
    final result = await db.query(bookingsTable);
    
    List<Booking> bookings = [];
    for (var map in result) {
      final booking = Booking.fromMap(map);
      final items = await db.query(
        bookingItemsTable,
        where: 'bookingId = ?',
        whereArgs: [booking.id],
      );
      
      bookings.add(Booking(
        id: booking.id,
        customerId: booking.customerId,
        eventDate: booking.eventDate,
        bookingDate: booking.bookingDate,
        totalAmount: booking.totalAmount,
        depositAmount: booking.depositAmount,
        paidAmount: booking.paidAmount,
        specialNotes: booking.specialNotes,
        lastUpdated: booking.lastUpdated,
        items: items.map((m) => BookingItem.fromMap(m)).toList(),
      ));
    }
    
    return bookings;
  }

  Future<int> updateBooking(Booking booking) async {
    final db = await database;
    await db.update(
      bookingsTable,
      booking.toMap(),
      where: 'id = ?',
      whereArgs: [booking.id],
    );
    
    // Update items
    await db.delete(bookingItemsTable, where: 'bookingId = ?', whereArgs: [booking.id]);
    for (var item in booking.items) {
      await db.insert(bookingItemsTable, {
        ...item.toMap(),
        'bookingId': booking.id,
      });
    }
    
    return booking.id!;
  }

  Future<int> deleteBooking(int id) async {
    final db = await database;
    await db.delete(bookingItemsTable, where: 'bookingId = ?', whereArgs: [id]);
    await db.delete(deliveriesTable, where: 'bookingId = ?', whereArgs: [id]);
    await db.delete(remindersTable, where: 'bookingId = ?', whereArgs: [id]);
    return await db.delete(bookingsTable, where: 'id = ?', whereArgs: [id]);
  }

  // ==================== DELIVERY OPERATIONS ====================

  // Insert a new delivery, or update the existing one for the booking.
  Future<int> insertDelivery(Delivery delivery) async {
    final db = await database;
    final existing = await getDelivery(delivery.bookingId);
    if (existing != null) {
      await db.update(
        deliveriesTable,
        delivery.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return existing.id!;
    }
    return await db.insert(deliveriesTable, delivery.toMap()..remove('id'));
  }

  Future<Delivery?> getDelivery(int bookingId) async {
    final db = await database;
    final result = await db.query(
      deliveriesTable,
      where: 'bookingId = ?',
      whereArgs: [bookingId],
    );
    return result.isNotEmpty ? Delivery.fromMap(result.first) : null;
  }

  Future<List<Delivery>> getAllDeliveries() async {
    final db = await database;
    final result = await db.query(deliveriesTable);
    return result.map((map) => Delivery.fromMap(map)).toList();
  }

  Future<int> updateDelivery(Delivery delivery) async {
    final db = await database;
    return await db.update(
      deliveriesTable,
      delivery.toMap(),
      where: 'id = ?',
      whereArgs: [delivery.id],
    );
  }

  // ==================== REMINDER OPERATIONS ====================

  Future<List<Map<String, dynamic>>> getPendingReminders() async {
    final db = await database;

    // Get reminders for bookings 5-10 days from now
    final result = await db.rawQuery('''
      SELECT r.* FROM $remindersTable r
      JOIN $bookingsTable b ON r.bookingId = b.id
      WHERE r.isSent = 0
      AND julianday(r.eventDate) - julianday('now') BETWEEN 0 AND 10
      ORDER BY r.eventDate ASC
    ''');
    
    return result;
  }

  Future<int> updateReminder(int id, bool isSent, int notificationCount) async {
    final db = await database;
    return await db.update(
      remindersTable,
      {
        'isSent': isSent ? 1 : 0,
        'notificationCount': notificationCount,
        'lastNotifiedDate': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== SYNC OPERATIONS ====================

  Future<Map<String, dynamic>> getAllDataForSync() async {
    final db = await database;

    return {
      'customers': await db.query(customersTable),
      'bookings': await db.query(bookingsTable),
      'bookingItems': await db.query(bookingItemsTable),
      'deliveries': await db.query(deliveriesTable),
      'reminders': await db.query(remindersTable),
    };
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(remindersTable);
    await db.delete(deliveriesTable);
    await db.delete(bookingItemsTable);
    await db.delete(bookingsTable);
    await db.delete(customersTable);
  }

  // Wipe local tables and replace them with rows from a Drive backup, preserving ids.
  Future<void> restoreFromBackup(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(remindersTable);
      await txn.delete(deliveriesTable);
      await txn.delete(bookingItemsTable);
      await txn.delete(bookingsTable);
      await txn.delete(customersTable);

      for (final row in (data['customers'] as List? ?? [])) {
        await txn.insert(customersTable, Map<String, dynamic>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in (data['bookings'] as List? ?? [])) {
        await txn.insert(bookingsTable, Map<String, dynamic>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in (data['bookingItems'] as List? ?? [])) {
        await txn.insert(bookingItemsTable, Map<String, dynamic>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in (data['deliveries'] as List? ?? [])) {
        await txn.insert(deliveriesTable, Map<String, dynamic>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in (data['reminders'] as List? ?? [])) {
        await txn.insert(remindersTable, Map<String, dynamic>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
