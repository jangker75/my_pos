import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
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
    debugPrint('ProductRepository.replaceAll: start with ${products.length} products');
    final db = await dbProvider.db;
    debugPrint('ProductRepository.replaceAll: got db');
    
    // Delete all existing products first
    await db.delete('products');
    debugPrint('ProductRepository.replaceAll: deleted old products');
    
    // Insert new products one by one
    for (int i = 0; i < products.length; i++) {
      final p = products[i];
      await db.insert('products', p.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
      if (i % 10 == 0) {
        debugPrint('ProductRepository.replaceAll: inserted ${i + 1}/${products.length}');
      }
    }
    
    debugPrint('ProductRepository.replaceAll: done');
  }
}
