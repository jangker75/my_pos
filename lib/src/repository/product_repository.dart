import 'package:sqflite/sqflite.dart';
import '../models/product.dart';
import '../data/local_database.dart';

class ProductRepository {
  final dbProvider = LocalDatabase();

  Future<List<Product>> getAll() async {
    final db = await dbProvider.db;
    final res = await db.query('products');
    return res.map((e) => Product.fromJson(e)).toList();
  }

  Future<void> upsert(Product p) async {
    final db = await dbProvider.db;
    await db.insert('products', p.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> replaceAll(List<Product> products) async {
    final db = await dbProvider.db;
    await db.transaction((txn) async {
      await txn.delete('products');
      for (var p in products) {
        await txn.insert('products', p.toJson());
      }
    });
  }
}
