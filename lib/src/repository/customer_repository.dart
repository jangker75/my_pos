import 'package:flutter/foundation.dart';
import 'package:my_pos/src/models/customer.dart';
import 'package:sqflite/sqflite.dart';
import '../data/customer_db.dart';

class CustomerRepository {
  final CustomerDb _db = CustomerDb();

  Future<List<Customer>> getAll() async {
    final rows = await _db.getAllCustomers();
    return rows.map((e) => Customer.fromJson(e)).toList();
  }

  Future<void> upsert(Customer c) async {
    final database = await _db.db;
    await database.insert('customers', c.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> replaceAll(List<Customer> customers) async {
    debugPrint('CustomerRepository.replaceAll: start with ${customers.length} customers');
    final database = await _db.db;
    debugPrint('CustomerRepository.replaceAll: got db');
    
    // Delete all existing customers first
    await database.delete('customers');
    debugPrint('CustomerRepository.replaceAll: deleted old customers');
    
    // Insert new customers one by one
    for (int i = 0; i < customers.length; i++) {
      final c = customers[i];
      await database.insert('customers', c.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
      if (i % 10 == 0) {
        debugPrint('CustomerRepository.replaceAll: inserted ${i + 1}/${customers.length}');
      }
    }
    
    debugPrint('CustomerRepository.replaceAll: done');
  }
}
