import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class CustomerDb {
  static final CustomerDb _instance = CustomerDb._internal();
  factory CustomerDb() => _instance;
  CustomerDb._internal();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'customers.db');

    return await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute('''
        CREATE TABLE customers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          description TEXT
        )
      ''');

      final seed = [
        {'name': 'Novi', 'description': 'Just regular person'},
        {'name': 'Andi', 'description': 'Loyal customer'},
        {'name': 'Sari', 'description': 'Frequent buyer'},
      ];

      for (final p in seed) {
        await db.insert('customers', {'name': p['name'], 'description': p['description']});
      }
    });
  }

  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    final database = await db;
    final rows = await database.query('customers', orderBy: 'name');
    return rows;
  }

  Future<int> insertCustomer(String name, String description) async {
    final database = await db;
    return database.insert('customers', {
      'name': name,
      'description': description,
    });
  }

  Future<int> clearAllCustomers() async {
    final database = await db;
    return database.delete('customers');
  }

  Future<void> replaceCustomers(List<Map<String, dynamic>> customers) async {
    final database = await db;
    final batch = database.batch();
    batch.delete('customers');
    for (final c in customers) {
      final name = c['name'] ?? '';
      final description = c['description'] ?? '';
      batch.insert('customers', {
        'name': name,
        'description': description,
      });
    }
    await batch.commit(noResult: true);
  }
}
