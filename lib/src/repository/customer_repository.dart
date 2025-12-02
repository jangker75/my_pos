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
    final database = await _db.db;
    await database.transaction((txn) async {
      await txn.delete('customers');
      for (var c in customers) {
        await txn.insert('customers', c.toJson());
      }
    });
  }
}
