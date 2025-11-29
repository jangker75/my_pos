import 'package:flutter/material.dart';
import 'new_transaction_page.dart';
import 'transaction_detail_page.dart';
import 'product_list_page.dart';
import '../data/transaction_db.dart';
import '../models/transaction_model.dart';
import 'package:device_info_plus/device_info_plus.dart';

class Transaction {
  final String id;
  final DateTime date;
  final String customer;
  final String itemsSummary;
  final double total;
  final double paid;
  final String time;
  final bool isPaid;
  final String status;

  Transaction({
    required this.id,
    required this.date,
    required this.customer,
    required this.itemsSummary,
    required this.total,
    required this.paid,
    required this.time,
    required this.isPaid,
    required this.status,
  });
}

class TransactionListPage extends StatefulWidget {
  TransactionListPage({Key? key}) : super(key: key);

  @override
  _TransactionListPageState createState() => _TransactionListPageState();
}

class _TransactionListPageState extends State<TransactionListPage> {
  List<TransactionModel> _items = [];
  final _db = TransactionDb();
  bool _loading = true;
  DateTime? _filterDate;
  String _filterStatus = 'all'; // all, in_progress, paid, canceled

  // expansion state per date key (YYYY-MM-DD)
  final Set<String> _expandedGroups = {};

  bool get _hasFilters => _filterStatus != 'all' || _filterDate != null;

  void _clearFilters() {
    setState(() {
      _filterDate = null;
      _filterStatus = 'all';
    });
  }

  // initialize expanded groups after load
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _db.getAllTransactions();
    setState(() {
      _items = list;
      _loading = false;
    });

    // Auto-expand groups that have at least one transaction in_progress or draft
    final inProgressKeys = <String>{};
    for (var m in list) {
      if (m.status == 'in_progress' || m.status == 'draft') {
        final d = DateTime.tryParse(m.createdAt) ?? DateTime.now();
        final key = _dateHeader(d);
        inProgressKeys.add(key);
      }
    }
    setState(() {
      _expandedGroups.clear();
      _expandedGroups.addAll(inProgressKeys);
    });
  }

  Future<void> _sync() async {
    // build full payload, then only send paid transactions
    try {
      final clientId = await _getDeviceId();
      final payload = await _db.buildSyncPayload(clientId);
      final allTx = (payload['transactions'] as List<dynamic>?) ?? [];
      final paid = allTx.where((t) => (t['status'] ?? '') == 'paid').toList();
      if (paid.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nothing to sync (no paid transactions)')));
        return;
      }

      // fake sending only paid transactions
      await Future.delayed(Duration(seconds: 2));

      // mark only the paid transactions as synced
      final ids = paid.map((e) => e['localId']).whereType<int>().toList();
      if (ids.isNotEmpty) await _db.markAsSynced(ids);
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Synced ${ids.length} transactions')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    }
  }

  Future<String> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } catch (e) {
      return 'unknown-device';
    }
  }

  String _monthAbbr(int m) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    return months[m - 1];
  }

  String _dateHeader(DateTime d) {
    // header groups by date only (YYYY-MM-DD)
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss';
  }

  Map<String, List<Transaction>> _groupByDate(List<Transaction> list) {
    final map = <String, List<Transaction>>{};
    for (var t in list) {
      final key = _dateHeader(t.date);
      map.putIfAbsent(key, () => []).add(t);
    }
    return Map.fromEntries(map.entries.toList()
      ..sort((a, b) => b.value.first.date.compareTo(a.value.first.date)));
  }

  Widget _buildHeader(String date, List<Transaction> items) {
    // only count totals for transactions that are paid
    final total = items
        .where((t) => t.status == 'paid')
        .fold<int>(0, (s, t) => s + t.total.toInt());
    // header shows date only (key) and can be tapped to expand/collapse
    final isExpanded = _expandedGroups.contains(date);
    return InkWell(
      onTap: () {
        setState(() {
          if (isExpanded)
            _expandedGroups.remove(date);
          else
            _expandedGroups.add(date);
        });
      },
      child: Container(
        color: Colors.grey[200],
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(date, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Text('Rp ${_formatCurrency(total)}',
                style:
                    TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            SizedBox(width: 12),
            Text('${items.length}',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(int value) {
    // Simple formatter: 129000 -> 129.000
    final s = value.toString();
    final parts = <String>[];
    for (int i = s.length; i > 0; i -= 3) {
      final start = i - 3 < 0 ? 0 : i - 3;
      parts.insert(0, s.substring(start, i));
    }
    return parts.join('.');
  }

  Widget _buildTransactionRow(Transaction t) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Rp ${_formatCurrency(t.total.toInt())}',
                        style: TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    // status chip
                    Builder(builder: (_) {
                      final s = t.status;
                      final label = s == 'paid'
                          ? 'LUNAS'
                          : s == 'canceled'
                              ? 'BATAL'
                              : s == 'draft'
                                  ? 'DRAFT'
                                  : 'ON PROGRESS';
                      final color = s == 'paid'
                          ? Colors.green
                          : s == 'canceled'
                              ? Colors.red
                              : s == 'draft'
                                  ? Colors.grey
                                  : Colors.orange;
                      return Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(label,
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                      );
                    }),
                  ],
                ),
                SizedBox(height: 6),
                Text(t.customer),
              ],
            ),
          ),
          Column(
            children: [
              Text(t.time),
              SizedBox(height: 6),
              SizedBox(
                width: 220,
                child: Text(t.itemsSummary,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center),
              ),
            ],
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(t.id),
              SizedBox(height: 6),
              Text(
                  t.isPaid
                      ? 'Paid'
                      : '- Rp ${_formatCurrency((t.total - t.paid).toInt())}',
                  style:
                      TextStyle(color: t.isPaid ? Colors.green : Colors.red)),
            ],
          ),
        ],
      ),
      onTap: () async {
        TransactionModel? model;
        try {
          model = _items.firstWhere((m) => m.txnNumber == t.id);
        } catch (e) {
          model = null;
        }
        if (model != null) {
          // if draft, open editor; otherwise show detail
          if (model.status == 'draft') {
            Navigator.of(context)
                .push(MaterialPageRoute(
                    builder: (_) => NewTransactionPage(initial: model)))
                .then((saved) {
              if (saved == true) _load();
            });
          } else {
            Navigator.of(context)
                .push(MaterialPageRoute(
                    builder: (_) => TransactionDetailPage(model: model!)))
                .then((changed) {
              if (changed == true) _load();
            });
          }
        }
      },
      onLongPress: () async {
        // if draft or in_progress, allow delete
        TransactionModel? model;
        try {
          model = _items.firstWhere((m) => m.txnNumber == t.id);
        } catch (e) {
          model = null;
        }
        if (model != null &&
            (model.status == 'in_progress' || model.status == 'draft')) {
          final isDraft = model.status == 'draft';
          final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                    title: Text(isDraft ? 'Hapus Draft' : 'Hapus Transaksi'),
                    content: Text(isDraft
                        ? 'Hapus transaksi draft ini?'
                        : 'Hapus transaksi ini?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text('Batal')),
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text('Hapus'))
                    ],
                  ));
          if (confirm == true) {
            await _db.deleteTransactionByTxn(model.txnNumber);
            await _load();
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return Scaffold(body: Center(child: CircularProgressIndicator()));

    // apply filters to _items
    final filteredModels = _items.where((m) {
      if (_filterStatus != 'all' && m.status != _filterStatus) return false;
      if (_filterDate != null) {
        final d = DateTime.parse(m.createdAt);
        if (!(d.year == _filterDate!.year &&
            d.month == _filterDate!.month &&
            d.day == _filterDate!.day)) return false;
      }
      return true;
    }).toList();

    // convert TransactionModel to the local Transaction struct for display
    final display = filteredModels
        .map((m) => Transaction(
              id: m.txnNumber,
              date: DateTime.parse(m.createdAt),
              customer: (m.customer.isNotEmpty
                  ? m.customer
                  : (m.getItemsList().isNotEmpty
                      ? m.getItemsList().first['name']
                      : '-')),
              itemsSummary: m
                  .getItemsList()
                  .map((e) => '${e['name']}:${e['qty']}')
                  .join(' '),
              total: m.total,
              paid: 0,
              time: _formatDateTime(DateTime.parse(m.createdAt)),
              isPaid: m.status == 'paid',
              status: m.status,
            ))
        .toList();

    final grouped = _groupByDate(display);
    final entries = grouped.entries.toList();

    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: Colors.blue[800]),
                child: Text('Menu',
                    style: TextStyle(color: Colors.white, fontSize: 20)),
              ),
              ListTile(
                leading: Icon(Icons.list),
                title: Text('Transactions'),
                onTap: () {
                  Navigator.of(context).pop(); // close drawer
                },
              ),
              ListTile(
                leading: Icon(Icons.inventory),
                title: Text('Products'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ProductListPage()));
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Text('Transaction List'),
        // default hamburger appears when Drawer is provided
        actions: [
          IconButton(icon: Icon(Icons.sync), onPressed: _sync),
          if (_hasFilters)
            IconButton(
                icon: Icon(Icons.clear),
                tooltip: 'Clear filters',
                onPressed: _clearFilters),
          IconButton(
              icon: Icon(Icons.filter_list),
              onPressed: () async {
                // open filter dialog
                final result = await showDialog<bool>(
                  context: context,
                  builder: (ctx) {
                    DateTime? pickedDate = _filterDate;
                    String pickedStatus = _filterStatus;
                    return StatefulBuilder(builder: (ctx, setStateDialog) {
                      return AlertDialog(
                        title: Text('Filter Transaksi'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              title: Text('Tanggal'),
                              subtitle: Text(pickedDate != null
                                  ? '${pickedDate!.year.toString().padLeft(4, '0')}-${pickedDate!.month.toString().padLeft(2, '0')}-${pickedDate!.day.toString().padLeft(2, '0')}'
                                  : 'Semua'),
                              trailing: IconButton(
                                  icon: Icon(Icons.date_range),
                                  onPressed: () async {
                                    final d = await showDatePicker(
                                        context: ctx,
                                        initialDate:
                                            pickedDate ?? DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100));
                                    if (d != null)
                                      setStateDialog(() {
                                        pickedDate = d;
                                      });
                                  }),
                            ),
                            DropdownButton<String>(
                              value: pickedStatus,
                              items: [
                                DropdownMenuItem(
                                    value: 'all', child: Text('Semua')),
                                DropdownMenuItem(
                                    value: 'in_progress',
                                    child: Text('On Progress')),
                                DropdownMenuItem(
                                    value: 'draft', child: Text('Draft')),
                                DropdownMenuItem(
                                    value: 'paid', child: Text('Paid')),
                                DropdownMenuItem(
                                    value: 'canceled', child: Text('Cancel')),
                              ],
                              onChanged: (v) => setStateDialog(() {
                                if (v != null) pickedStatus = v;
                              }),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: Text('Batal')),
                          TextButton(
                              onPressed: () {
                                // apply
                                _filterDate = pickedDate;
                                _filterStatus = pickedStatus;
                                Navigator.of(ctx).pop(true);
                              },
                              child: Text('Terapkan')),
                          TextButton(
                              onPressed: () {
                                // clear
                                _filterDate = null;
                                _filterStatus = 'all';
                                Navigator.of(ctx).pop(true);
                              },
                              child: Text('Reset')),
                        ],
                      );
                    });
                  },
                );
                if (result == true) setState(() {});
              }),
        ],
      ),
      body: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, __) => Divider(height: 1),
        itemBuilder: (context, index) {
          final date = entries[index].key;
          final items = entries[index].value;
          final isExpanded = _expandedGroups.contains(date);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(date, items),
              if (isExpanded)
                ...items.map((t) => _buildTransactionRow(t)).toList(),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add_shopping_cart),
        onPressed: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => NewTransactionPage()))
              .then((saved) {
            if (saved == true) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Transaksi tersimpan')));
            }
            _load();
          });
        },
      ),
    );
  }
}
