import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ProductDb {
  static final ProductDb _instance = ProductDb._internal();
  factory ProductDb() => _instance;
  ProductDb._internal();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'products.db');

    return await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute('''
        CREATE TABLE products (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          price INTEGER
        )
      ''');

      // insert sample products from provided JSON
      final seed = [
        {'name': 'Cappuccino', 'price': 15000},
        {'name': 'Butterscotch', 'price': 18000},
        {'name': 'Brown Sugar', 'price': 15000},
        {'name': 'Caramel Latte', 'price': 19000},
        {'name': 'Hazelnut Latte', 'price': 19000},
        {'name': 'Havana Rum', 'price': 16000},
        {'name': 'Roasted Almond', 'price': 17000},
        {'name': 'Salted Caramel', 'price': 18000},
        {'name': 'Irish Cream', 'price': 16000},
        {'name': 'French Mocca', 'price': 16000},
        {'name': 'Kopilibrasi', 'price': 18000},
      ];

      for (final p in seed) {
        await db.insert('products', {'name': p['name'], 'price': p['price']});
      }
    });
  }

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final database = await db;
    final rows = await database.query('products', orderBy: 'name');
    return rows;
  }

  Future<int> insertProduct(String name, int price) async {
    final database = await db;
    return database.insert('products', {'name': name, 'price': price});
  }

  Future<int> clearAllProducts() async {
    final database = await db;
    return database.delete('products');
  }

  Future<void> replaceProducts(List<Map<String, dynamic>> products) async {
    final database = await db;
    final batch = database.batch();
    batch.delete('products');
    for (final p in products) {
      final name = p['name'] ?? p['nama'] ?? '';
      final price = p['price'] is int
          ? p['price']
          : int.tryParse(p['price'].toString()) ?? 0;
      batch.insert('products', {'name': name, 'price': price});
    }
    await batch.commit(noResult: true);
  }
}
