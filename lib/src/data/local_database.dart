import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'my_pos.db');

    return await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute('''
        CREATE TABLE products (
          id INTEGER PRIMARY KEY,
          code TEXT,
          name TEXT,
          price REAL,
          stock INTEGER
        )
      ''');

      // Seed initial products for trial/testing
      await db.insert('products', {
        'id': 1,
        'code': 'ESP',
        'name': 'Espresso',
        'price': 15000.0,
        'stock': 50
      });
      await db.insert('products', {
        'id': 2,
        'code': 'LAT',
        'name': 'Latte',
        'price': 25000.0,
        'stock': 40
      });
      await db.insert('products', {
        'id': 3,
        'code': 'CAP',
        'name': 'Cappuccino',
        'price': 23000.0,
        'stock': 30
      });
      await db.insert('products', {
        'id': 4,
        'code': 'SND',
        'name': 'Sandwich',
        'price': 30000.0,
        'stock': 20
      });
      await db.insert('products', {
        'id': 5,
        'code': 'CKE',
        'name': 'Cake Slice',
        'price': 20000.0,
        'stock': 15
      });

      // columns names match TransactionModel.toJson keys
      await db.execute('''
        CREATE TABLE transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          txnNumber TEXT,
          items TEXT,
          total REAL,
          status TEXT,
          createdAt TEXT
        )
      ''');
    });
  }
}
