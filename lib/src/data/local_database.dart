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
      // Create products table
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
      
      // Create customers table
      await db.execute('''
        CREATE TABLE "customers" (
          id INTEGER PRIMARY KEY,
          name TEXT,
          description TEXT
        )
      ''');

      // Seed initial customers for trial/testing
      await db.insert('customers', {
        'id': 1,
        'name': 'John Doe',
        'description': 'Just a regular customer',
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
