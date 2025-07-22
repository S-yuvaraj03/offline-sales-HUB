import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await initDB();
    return _db!;
  }

  Future<Database> initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'juice_pos.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            price REAL,
            cost REAL,
            categoryId INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            productId INTEGER,
            quantity INTEGER,
            date TEXT,
            billId INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE bills (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            billNo TEXT,
            kotNo TEXT,
            total REAL,
            profit REAL,
            timestamp TEXT,
            paymentStatus TEXT,
            paymentMethod TEXT,
            upiApp TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE bill_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            billId INTEGER,
            productName TEXT,
            quantity INTEGER,
            price REAL,
            FOREIGN KEY (billId) REFERENCES bills(id)
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE held_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            productId INTEGER,
            quantity INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE inventory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            productId INTEGER UNIQUE,
            stock INTEGER
          )
        ''');

        await db.insert('settings', {'key': 'kot_counter', 'value': '0'});
      },
    );
  }

  // =====================================
  // KOT Number with Daily Reset
  // =====================================
  Future<int> getNextKOTNumber() async {
    final db = await database;
    final today = DateTime.now();
    final todayStr = "${today.year}-${today.month}-${today.day}";

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    final lastReset = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['kot_last_reset_date'],
    );

    if (lastReset.isEmpty || lastReset.first['value'] != todayStr) {
      await db.insert(
        'settings',
        {'key': 'kot_counter', 'value': '0'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.insert(
        'settings',
        {'key': 'kot_last_reset_date', 'value': todayStr},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final result = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['kot_counter'],
    );

    int current = int.parse(result.first['value'] as String);
    int next = current + 1;

    await db.update(
      'settings',
      {'value': next.toString()},
      where: 'key = ?',
      whereArgs: ['kot_counter'],
    );

    return next;
  }

  // =============================
  // CATEGORY
  // =============================
  Future<int> insertCategory(String name) async {
    final db = await database;
    return await db.insert('categories', {'name': name});
  }

  Future<List<Category>> getCategories() async {
    final db = await database;
    final result = await db.query('categories');
    return result.map((e) => Category.fromMap(e)).toList();
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    await db.delete('products', where: 'categoryId = ?', whereArgs: [id]);
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // =============================
  // PRODUCT
  // =============================
  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getProducts() async {
    final db = await database;
    final result = await db.query('products');
    return result.map((e) => Product.fromMap(e)).toList();
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // =============================
  // ORDERS
  // =============================
  Future<void> insertOrder({
    required int productId,
    required int quantity,
    required int billId,
  }) async {
    final db = await database;
    await db.insert('orders', {
      'productId': productId,
      'quantity': quantity,
      'date': DateTime.now().toIso8601String(),
      'billId': billId,
    });
  }

  Future<List<Map<String, dynamic>>> getOrders() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT o.id, p.name, o.quantity, o.date, p.price, p.cost
      FROM orders o
      JOIN products p ON o.productId = p.id
      ORDER BY o.date DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getOrdersWithBillDetails() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        o.id AS orderId,
        o.productId,
        o.quantity,
        o.date,
        p.name AS name,
        p.price AS price,
        b.billNo, 
        b.kotNo, 
        b.paymentMethod, 
        b.upiApp,
        b.timestamp AS date
      FROM orders o
      JOIN products p ON o.productId = p.id
      JOIN bills b ON o.billId = b.id
      ORDER BY b.timestamp DESC
    ''');
  }

  // =============================
  // BILLS
  // =============================
  Future<int> insertBill({
    required String billNo,
    required String kotNo,
    required double total,
    required double profit,
    required String paymentStatus,
    required String paymentMethod,
    String? upiApp,
  }) async {
    final db = await database;
    return await db.insert('bills', {
      'billNo': billNo,
      'kotNo': kotNo,
      'total': total,
      'profit': profit,
      'timestamp': DateTime.now().toIso8601String(),
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'upiApp': upiApp,
    });
  }

  Future<void> insertBillItem({
    required int billId,
    required String productName,
    required int quantity,
    required double price,
  }) async {
    final db = await database;
    await db.insert('bill_items', {
      'billId': billId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
    });
  }

  Future<List<Map<String, dynamic>>> getAllBills() async {
    final db = await database;
    return await db.query('bills', orderBy: 'timestamp DESC');
  }

  Future<List<Map<String, dynamic>>> getBillItems(int billId) async {
    final db = await database;
    return await db.query(
      'bill_items',
      where: 'billId = ?',
      whereArgs: [billId],
    );
  }

  Future<void> updatePaymentStatus(int billId, String newStatus) async {
    final db = await database;
    await db.update(
      'bills',
      {'paymentStatus': newStatus},
      where: 'id = ?',
      whereArgs: [billId],
    );
  }

  // =============================
  // HELD ORDERS
  // =============================
  Future<void> insertHeldItem({
    required int productId,
    required int quantity,
  }) async {
    final db = await database;
    await db.insert('held_items', {
      'productId': productId,
      'quantity': quantity,
    });
  }

  Future<List<Map<String, dynamic>>> getHeldItems() async {
    final db = await database;
    return await db.query('held_items');
  }

  Future<void> clearHeldItems() async {
    final db = await database;
    await db.delete('held_items');
  }

  // =============================
  // Inventory Items
  // =============================
  Future<void> setStock(int productId, int quantity) async {
    final db = await database;
    await db.insert(
      'inventory',
      {'productId': productId, 'stock': quantity},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getStock(int productId) async {
    final db = await database;
    final result = await db.query(
      'inventory',
      where: 'productId = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (result.isEmpty) return 0;
    return result.first['stock'] as int;
  }

  Future<void> updateStockAfterSale(int productId, int quantitySold) async {
    final currentStock = await getStock(productId);
    final newStock = currentStock - quantitySold;
    await setStock(productId, newStock.clamp(0, 99999));
  }

  Future<List<Map<String, dynamic>>> getInventoryWithProductDetails() async {
    final db = await database;
    return await db.rawQuery('''
    SELECT p.id, p.name, p.categoryId, i.stock
    FROM products p
    LEFT JOIN inventory i ON p.id = i.productId
    ORDER BY p.categoryId ASC
  ''');
  }

  // =============================
  // UTIL
  // =============================
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('orders');
    await db.delete('bill_items');
    await db.delete('bills');
    await db.delete('products');
    await db.delete('categories');
    await db.delete('held_items');
    await db.delete('settings');
  }
}
