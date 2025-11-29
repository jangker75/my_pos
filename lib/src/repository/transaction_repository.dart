import 'dart:convert';
import '../data/local_database.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final dbProvider = LocalDatabase();

  Future<List<TransactionModel>> getActive() async {
    final db = await dbProvider.db;
    final res = await db
        .query('transactions', where: "status != ?", whereArgs: ['paid']);
    return res.map((e) => TransactionModel.fromJson(e)).toList();
  }

  Future<void> insert(TransactionModel t) async {
    final db = await dbProvider.db;
    await db.insert('transactions', t.toJson());
  }

  Future<void> updateStatus(int id, String status) async {
    final db = await dbProvider.db;
    await db.update('transactions', {'status': status},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Update items (qty or discount) on a transaction. ItemsList is a list of maps, each map must contain id, unit_price (unchanged), qty, discount
  Future<void> updateItems(int id, List<Map<String, dynamic>> itemsList) async {
    final db = await dbProvider.db;
    final total = itemsList.fold<double>(0.0, (s, it) {
      final unit = (it['price'] ?? it['unit_price'] ?? 0).toDouble();
      final qty = (it['qty'] ?? 0).toDouble();
      final disc = (it['discount'] ?? 0).toDouble();
      return s + (unit * qty) - disc;
    });
    await db.update(
        'transactions', {'items': jsonEncode(itemsList), 'total': total},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markPaid(int id) async {
    await updateStatus(id, 'paid');
  }
}
