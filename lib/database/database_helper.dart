import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/customer.dart';
import '../models/booking.dart';
import '../models/delivery.dart';
import '../models/product.dart';
import '../models/sales_invoice.dart';

class DatabaseHelper {
  static const String _dbName = 'rental_app.db';
  static const int _dbVersion = 7;

  static const String customersTable = 'customers';
  static const String bookingsTable = 'bookings';
  static const String bookingItemsTable = 'booking_items';
  static const String deliveriesTable = 'deliveries';
  static const String remindersTable = 'reminders';
  static const String productsTable = 'products';
  static const String salesInvoicesTable = 'sales_invoices';
  static const String salesInvoiceItemsTable = 'sales_invoice_items';

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
    await _renameColumnIfNeeded(db, bookingsTable, 'eventDate', 'rentalDate');
    await _renameColumnIfNeeded(db, remindersTable, 'eventDate', 'rentalDate');
    // v7: GST billing
    await _addColumnIfMissing(db, customersTable, 'gstin', 'TEXT');
    await _addColumnIfMissing(db, customersTable, 'stateCode', 'INTEGER');
    await _addColumnIfMissing(db, customersTable, 'city', 'TEXT');
    await _addColumnIfMissing(db, customersTable, 'pincode', 'TEXT');
    await _createBillingTables(db);
  }

  // GST billing tables. Uses IF NOT EXISTS so it is safe from both onCreate and onUpgrade.
  Future<void> _createBillingTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $productsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        hsnCode TEXT NOT NULL,
        unit TEXT NOT NULL DEFAULT 'NOS',
        price REAL NOT NULL DEFAULT 0,
        gstRate REAL NOT NULL DEFAULT 0,
        priceIncludesTax INTEGER NOT NULL DEFAULT 0,
        lastUpdated TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $salesInvoicesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceNo TEXT NOT NULL UNIQUE,
        invoiceDate TEXT NOT NULL,
        customerId INTEGER,
        buyerName TEXT NOT NULL,
        buyerGstin TEXT,
        buyerPhone TEXT,
        buyerAddress TEXT,
        buyerPlace TEXT,
        buyerPincode TEXT,
        placeOfSupplyStateCode INTEGER NOT NULL,
        sellerStateCode INTEGER NOT NULL,
        paidAmount REAL NOT NULL DEFAULT 0,
        notes TEXT,
        transMode INTEGER NOT NULL DEFAULT 1,
        transDistance INTEGER NOT NULL DEFAULT 0,
        transporterId TEXT,
        transporterName TEXT,
        vehicleNo TEXT,
        transDocNo TEXT,
        transDocDate TEXT,
        ewbNo TEXT,
        ewbDate TEXT,
        ewbValidUpto TEXT,
        lastUpdated TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $salesInvoiceItemsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceId INTEGER NOT NULL,
        productId INTEGER,
        name TEXT NOT NULL,
        hsnCode TEXT NOT NULL,
        unit TEXT NOT NULL DEFAULT 'NOS',
        quantity REAL NOT NULL,
        rate REAL NOT NULL,
        discountPercent REAL NOT NULL DEFAULT 0,
        gstRate REAL NOT NULL DEFAULT 0,
        priceIncludesTax INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (invoiceId) REFERENCES $salesInvoicesTable (id)
      )
    ''');
  }

  // Safely add a column only if it doesn't already exist (guards against partial/duplicate migrations).
  Future<void> _addColumnIfMissing(Database db, String table, String column, String type) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((c) => c['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  // Renames a column if the old name is present and the new one isn't yet (guards against partial/duplicate migrations).
  Future<void> _renameColumnIfNeeded(Database db, String table, String oldName, String newName) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final hasOld = columns.any((c) => c['name'] == oldName);
    final hasNew = columns.any((c) => c['name'] == newName);
    if (hasOld && !hasNew) {
      await db.execute('ALTER TABLE $table RENAME COLUMN $oldName TO $newName');
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
        createdDate TEXT NOT NULL,
        gstin TEXT,
        stateCode INTEGER,
        city TEXT,
        pincode TEXT
      )
    ''');

    // Create bookings table
    await db.execute('''
      CREATE TABLE $bookingsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customerId INTEGER NOT NULL,
        rentalDate TEXT NOT NULL,
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
        rentalDate TEXT NOT NULL,
        lastNotifiedDate TEXT,
        isSent INTEGER NOT NULL DEFAULT 0,
        notificationCount INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (bookingId) REFERENCES $bookingsTable (id)
      )
    ''');

    await _createBillingTables(db);
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
      'rentalDate': booking.rentalDate.toIso8601String(),
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
      rentalDate: booking.rentalDate,
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
        rentalDate: booking.rentalDate,
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
      AND julianday(r.rentalDate) - julianday('now') BETWEEN 0 AND 10
      ORDER BY r.rentalDate ASC
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

  // ==================== PRODUCT OPERATIONS ====================

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final result = await db.query(productsTable, orderBy: 'name COLLATE NOCASE');
    return result.map(Product.fromMap).toList();
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return db.insert(productsTable, product.toMap()..remove('id'));
  }

  Future<void> updateProduct(Product product) async {
    final db = await database;
    await db.update(productsTable, product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.delete(productsTable, where: 'id = ?', whereArgs: [id]);
  }

  // ==================== SALES INVOICE OPERATIONS ====================

  Future<List<SalesInvoice>> getAllSalesInvoices() async {
    final db = await database;
    final rows = await db.query(salesInvoicesTable, orderBy: 'invoiceDate DESC, id DESC');
    final itemRows = await db.query(salesInvoiceItemsTable, orderBy: 'id');
    final itemsByInvoice = <int, List<SalesInvoiceItem>>{};
    for (final row in itemRows) {
      final item = SalesInvoiceItem.fromMap(row);
      itemsByInvoice.putIfAbsent(item.invoiceId, () => []).add(item);
    }
    return rows
        .map((row) => SalesInvoice.fromMap(row, items: itemsByInvoice[row['id']] ?? const []))
        .toList();
  }

  Future<bool> invoiceNoExists(String invoiceNo, {int? excludingId}) async {
    final db = await database;
    final result = await db.query(
      salesInvoicesTable,
      columns: ['id'],
      where: excludingId == null ? 'invoiceNo = ?' : 'invoiceNo = ? AND id != ?',
      whereArgs: excludingId == null ? [invoiceNo] : [invoiceNo, excludingId],
    );
    return result.isNotEmpty;
  }

  /// Inserts or replaces an invoice and all its items in one transaction. Returns the invoice id.
  Future<int> saveSalesInvoice(SalesInvoice invoice) async {
    final db = await database;
    return db.transaction((txn) async {
      int id;
      if (invoice.id == null) {
        id = await txn.insert(salesInvoicesTable, invoice.toMap()..remove('id'));
      } else {
        id = invoice.id!;
        await txn.update(salesInvoicesTable, invoice.toMap(), where: 'id = ?', whereArgs: [id]);
        await txn.delete(salesInvoiceItemsTable, where: 'invoiceId = ?', whereArgs: [id]);
      }
      for (final item in invoice.items) {
        await txn.insert(salesInvoiceItemsTable, {
          ...item.toMap()..remove('id'),
          'invoiceId': id,
        });
      }
      return id;
    });
  }

  /// Updates only the invoice header row (payment, transport, e-way bill fields).
  Future<void> updateSalesInvoiceHeader(SalesInvoice invoice) async {
    final db = await database;
    await db.update(salesInvoicesTable, invoice.toMap(), where: 'id = ?', whereArgs: [invoice.id]);
  }

  Future<void> deleteSalesInvoice(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(salesInvoiceItemsTable, where: 'invoiceId = ?', whereArgs: [id]);
      await txn.delete(salesInvoicesTable, where: 'id = ?', whereArgs: [id]);
    });
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
      'products': await db.query(productsTable),
      'salesInvoices': await db.query(salesInvoicesTable),
      'salesInvoiceItems': await db.query(salesInvoiceItemsTable),
    };
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(salesInvoiceItemsTable);
    await db.delete(salesInvoicesTable);
    await db.delete(productsTable);
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
      await txn.delete(salesInvoiceItemsTable);
      await txn.delete(salesInvoicesTable);
      await txn.delete(productsTable);
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
      // Older backups (before GST billing) simply have no rows for these.
      for (final row in (data['products'] as List? ?? [])) {
        await txn.insert(productsTable, Map<String, dynamic>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in (data['salesInvoices'] as List? ?? [])) {
        await txn.insert(salesInvoicesTable, Map<String, dynamic>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in (data['salesInvoiceItems'] as List? ?? [])) {
        await txn.insert(salesInvoiceItemsTable, Map<String, dynamic>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
