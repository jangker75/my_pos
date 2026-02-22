import 'dart:developer';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';

class TransactionDb {
  static final TransactionDb _instance = TransactionDb._internal();
  factory TransactionDb() => _instance;
  TransactionDb._internal();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'transactions.db');

    return await openDatabase(path, version: 4,
        onCreate: (Database db, int version) async {
      await db.execute('''
        CREATE TABLE transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          txn_number TEXT,
          items TEXT,
          total REAL,
          status TEXT,
          created_at TEXT,
          customer TEXT,
          synced INTEGER DEFAULT 0,
          payment_method TEXT,
          notes TEXT
        )
      ''');
    }, onUpgrade: (Database db, int oldVersion, int newVersion) async {
      if (oldVersion < 2) {
        // Add customer column for older databases created without it
        try {
          await db.execute(
              "ALTER TABLE transactions ADD COLUMN customer TEXT DEFAULT '-'");
        } catch (e) {
          // ignore if cannot add (already exists)
        }
      }
      if (oldVersion < 3) {
        // Add payment_method column
        try {
          await db.execute(
              "ALTER TABLE transactions ADD COLUMN payment_method TEXT");
        } catch (e) {
          // ignore if cannot add (already exists)
        }
      }
      if (oldVersion < 4) {
        // Add notes column
        try {
          await db.execute("ALTER TABLE transactions ADD COLUMN notes TEXT");
        } catch (e) {
          // ignore if cannot add (already exists)
        }
      }
    });
  }

  // Helper to convert model json (camelCase) to DB map (snake_case)
  Map<String, dynamic> _toDbMap(Map<String, dynamic> modelJson) {
    final map = <String, dynamic>{};
    if (modelJson.containsKey('txnNumber'))
      map['txn_number'] = modelJson['txnNumber'];
    if (modelJson.containsKey('items')) map['items'] = modelJson['items'];
    if (modelJson.containsKey('total')) map['total'] = modelJson['total'];
    if (modelJson.containsKey('status')) map['status'] = modelJson['status'];
    if (modelJson.containsKey('createdAt'))
      map['created_at'] = modelJson['createdAt'];
    if (modelJson.containsKey('customer'))
      map['customer'] = modelJson['customer'];
    if (modelJson.containsKey('synced'))
      map['synced'] = modelJson['synced']; // ← TAMBAHKAN INI
    if (modelJson.containsKey('paymentMethod'))
      map['payment_method'] =
          modelJson['paymentMethod']; // ← OPTIONAL, biar konsisten
    if (modelJson.containsKey('notes')) map['notes'] = modelJson['notes'];
    return map;
  }

  // Helper to convert DB row (snake_case) to model json (camelCase)
  Map<String, dynamic> _fromDbRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'txnNumber': row['txn_number'],
      'items': row['items'],
      'total': (row['total'] is int)
          ? (row['total'] as int).toDouble()
          : row['total'],
      'status': row['status'],
      'createdAt': row['created_at'],
      'customer': row['customer'] ?? '-',
      'synced': row['synced'] as int,
      'paymentMethod': row['payment_method'],
      'notes': row['notes'],
    };
  }

  Future<int> insertTransaction(TransactionModel t) async {
    final database = await db;
    final modelJson = t.toJson();
    modelJson['synced'] = 0;
    // convert to DB keys
    final dbMap = _toDbMap(modelJson);
    print('[TransactionDb] insertTransaction txn=${t.txnNumber} -> synced=0');
    return await database.insert('transactions', dbMap);
  }

  Future<TransactionModel?> getTransactionByTxnNumber(String txnNumber) async {
    final database = await db;
    final rows = await database.query('transactions',
        where: 'txn_number = ?', whereArgs: [txnNumber]);
    if (rows.isEmpty) return null;
    final converted = _fromDbRow(rows.first);
    return TransactionModel.fromJson(converted);
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final database = await db;
    final rows =
        await database.query('transactions', orderBy: 'created_at DESC');
    final list = <TransactionModel>[];
    for (var r in rows) {
      final converted = _fromDbRow(r);
      list.add(TransactionModel.fromJson(converted));
    }
    return list;
  }

  Future<List<TransactionModel>> getUnsyncedTransactions() async {
    final database = await db;
    final rows = await database
        .query('transactions', where: 'synced = ?', whereArgs: [0]);
    final list = <TransactionModel>[];
    for (var r in rows) {
      final converted = _fromDbRow(r);
      list.add(TransactionModel.fromJson(converted));
    }
    print('[TransactionDb] getUnsyncedTransactions count=${list.length}');
    return list;
  }

  Future<int> markAsSynced(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final database = await db;
    final idsStr = ids.map((e) => e.toString()).join(',');
    print('[TransactionDb] markAsSynced ids=$idsStr');
    return await database
        .rawUpdate('UPDATE transactions SET synced = 1 WHERE id IN ($idsStr)');
  }

  Future<int> updateStatusByTxn(
      String txnNumber, String status, String? paymentMethod) async {
    final database = await db;
    final updateMap = {'status': status, 'synced': 0};
    if (paymentMethod != null) {
      updateMap['payment_method'] = paymentMethod;
    }
    print(
        '[TransactionDb] updateStatusByTxn txn=$txnNumber status=$status set synced=0 paymentMethod=$paymentMethod');
    final count = await database.update('transactions', updateMap,
        where: 'txn_number = ?', whereArgs: [txnNumber]);
    return count;
  }

  Future<int> updateTransaction(TransactionModel t) async {
    final database = await db;
    final map = t.toJson();
    map['synced'] = 0;
    // convert keys
    final dbMap = _toDbMap(map);
    log('[TransactionDb] updateTransaction txn=${t.txnNumber} status=${t.status} set synced=0');
    // do not change created_at
    final count = await database.update('transactions', dbMap,
        where: 'txn_number = ?', whereArgs: [t.txnNumber]);
    log('[TransactionDb] updateTransaction affected=$count for txn=${t.txnNumber}');
    return count;
  }

  Future<int> deleteTransactionByTxn(String txnNumber) async {
    final database = await db;
    return await database.delete('transactions',
        where: 'txn_number = ?', whereArgs: [txnNumber]);
  }

  /// Build payload for unsynced transactions to send to server.
  /// Returns a Map matching:
  /// { "clientId": "...", "transactions": [ { localId, txnNumber, status, createdAt, customer, total, items: [...] } ] }
  Future<Map<String, dynamic>> buildSyncPayload(String clientId) async {
    final unsynced = await getUnsyncedTransactions();
    final txns = unsynced.map((t) {
      final items = t.getItemsList().map((it) {
        final price = it['price'] is int
            ? it['price'] as int
            : int.tryParse(it['price']?.toString() ?? '0') ?? 0;
        final qty = it['qty'] is int
            ? it['qty'] as int
            : int.tryParse(it['qty']?.toString() ?? '1') ?? 1;
        final discount = it['discount'] is int
            ? it['discount'] as int
            : int.tryParse(it['discount']?.toString() ?? '0') ?? 0;
        final discountType = (it['discountType'] as String?) ?? 'nominal';
        final lineTotal = discountType == 'percentage'
            ? (price * qty - ((price * qty * discount) ~/ 100))
            : (price * qty - discount);
        return {
          'name': it['name'] ?? '',
          'sku': it['sku'] ?? '',
          'price': price,
          'qty': qty,
          'discount': discount,
          'discountType': discountType,
          'lineTotal': lineTotal,
        };
      }).toList();

      return {
        'localId': t.id,
        'txnNumber': t.txnNumber,
        'status': t.status,
        'createdAt': t.createdAt,
        'customer': t.customer,
        'total': t.total,
        'items': items,
        'notes': t.notes,
        'paymentMethod': t.paymentMethod,
      };
    }).toList();

    return {'clientId': clientId, 'transactions': txns};
  }
}
