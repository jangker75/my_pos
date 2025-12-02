import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:my_pos/src/constant/const.dart';
import 'package:my_pos/src/ui/customer_list_page.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import '../theme.dart';
import 'new_transaction_page.dart';
import 'transaction_detail_page.dart';
import 'product_list_page.dart';
import '../data/transaction_db.dart';
import '../models/transaction_model.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

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
  final int? synced;
  Transaction(
      {required this.id,
      required this.date,
      required this.customer,
      required this.itemsSummary,
      required this.total,
      required this.paid,
      required this.time,
      required this.isPaid,
      required this.status,
      this.synced});
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
  String _filterStatus = 'all'; // all, on progress, paid, canceled

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
    for (final t in list) {
      log('[TransactionListPage] load txn=${t.txnNumber} status=${t.status} synced=${t.synced}');
    }
    setState(() {
      _items = list;
      _loading = false;
    });
    log('Loaded ${list.length} transactions');
    log('data : ${list.map((e) => e.toJson())}');
    // Auto-expand groups that have at least one transaction on progress or draft
    final inProgressKeys = <String>{};
    for (var m in list) {
      if (m.status == 'on progress' || m.status == 'draft' || m.synced == 0) {
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
      // dari semua transaksi UNSYNCED, hanya kirim yang status-nya paid/on progress/canceled
      final toSync = allTx
          .where((t) =>
              (t['status'] ?? '') == 'paid' ||
              (t['status'] ?? '') == 'on progress' ||
              (t['status'] ?? '') == 'canceled')
          .toList();
      log('sending ${toSync.length} of ${allTx.length} unsynced transactions for sync');
      if (toSync.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Nothing to sync (no paid/on progress/canceled transactions)')));
        return;
      }
      log('Sending sync payload: ${{
        'clientId': clientId,
        'transactions': toSync,
      }}');
      final uri = Uri.parse('${baseUrlBackend}sync-transaction');
      // final uri = Uri.parse('http://localhost:8001/sync-transaction');
      log('Syncing to $uri');
      final resp = await http.post(uri,
          body: jsonEncode({
            'clientId': clientId,
            'transactions': toSync,
          }),
          headers: {
            'Content-Type': 'application/json',
          }).timeout(Duration(seconds: 15));
      log('Got sync response: ${resp.statusCode} ${resp.body}');
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      // fake sending only paid transactions
      // await Future.delayed(Duration(seconds: 2));

      // tandai hanya transaksi yang dikirim sebagai synced
      final ids = toSync.map((e) => e['localId']).whereType<int>().toList();
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

  Future<DateTime?> _pickDateBottomSheet(BuildContext context, DateTime? initial) async {
    final now = DateTime.now();
    final first = DateTime(2000);
    final last = DateTime(2100);
    DateTime selected = initial ?? now;

    return await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Pilih Tanggal',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.brandDark,
                  ),
                ),
                SizedBox(height: 8),
                SizedBox(
                  height: 320,
                  child: CalendarDatePicker(
                    initialDate: selected,
                    firstDate: first,
                    lastDate: last,
                    onDateChanged: (d) {
                      Navigator.of(ctx).pop(d);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
      color: AppColors.brandDark.withOpacity(0.06),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
        child: Row(
          children: [
            Expanded(
              child: Text(date, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Text('Rp ${_formatCurrency(total)}',
              style:
                TextStyle(color: AppColors.brandDark, fontWeight: FontWeight.bold)),
            SizedBox(width: 3.w),
            Text('${items.length}',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(width: 2.w),
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
      contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
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
                        color: AppColors.brandDark, fontWeight: FontWeight.bold)),
                    SizedBox(width: 2.w),
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
                        padding: EdgeInsets.symmetric(
                            horizontal: 2.w, vertical: 1.h),
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(label,
                            style:
                                TextStyle(color: Colors.white, fontSize: 12.sp)),
                      );
                    }),
                  ],
                ),
                SizedBox(height: 0.8.h),
                Text(t.customer),
              ],
            ),
          ),
          (Device.orientation == Orientation.portrait)
              ? SizedBox.shrink()
              : Column(
                  children: [
                    Text(t.time),
                    SizedBox(height: 0.8.h),
                    SizedBox(
                      width: 55.w,
                      child: Text(t.itemsSummary,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center),
                    ),
                  ],
                ),
          (Device.orientation == Orientation.portrait)
              ? SizedBox.shrink()
              : SizedBox(width: 3.w),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(t.id),
                    SizedBox(height: 0.8.h),
                    Text(
                        t.isPaid
                            ? 'Paid'
                            : '- Rp ${_formatCurrency((t.total - t.paid).toInt())}',
                        style: TextStyle(
                            color: t.isPaid ? Colors.green : Colors.red)),
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
          // if draft or on progress, open editor; otherwise show detail
          if (model.status == 'draft' || model.status == 'on progress') {
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
        // if draft or on progress, allow delete
        TransactionModel? model;
        try {
          model = _items.firstWhere((m) => m.txnNumber == t.id);
        } catch (e) {
          model = null;
        }
        if (model != null &&
            (model.status == 'on progress' || model.status == 'draft')) {
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
              synced: m.synced,
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
                decoration: BoxDecoration(color: AppColors.brandDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('My POS',
                      style: TextStyle(
                        color: AppColors.brandYellow,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold)),
                    SizedBox(height: 1.h),
                    Text('Cafe Kopilibrasi',
                        style: TextStyle(color: Colors.white70, fontSize: 16.sp),),
                    Text('"Ketika orang perlu interaksi, literasi & Kolaborasi"',
                      style: TextStyle(color: Colors.white70, fontSize: 14.sp)),
                  ],
                ),
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
              ListTile(
                leading: Icon(Icons.person),
                title: Text('Customers'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => CustomerListPage()));
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: AppColors.brandDark,
        iconTheme: IconThemeData(color: AppColors.brandYellow),
        title: Text('Transaction List', style: TextStyle(color: AppColors.brandYellow)),
        // default hamburger appears when Drawer is provided
        actions: [
          IconButton(icon: Icon(Icons.sync, color: AppColors.brandYellow,), onPressed: _sync),
          if (_hasFilters)
            IconButton(
                icon: Icon(Icons.clear, color: AppColors.brandYellow,),
                tooltip: 'Clear filters',
                onPressed: _clearFilters),
          IconButton(
              icon: Icon(Icons.filter_list, color: AppColors.brandYellow,),
              onPressed: () async {
                // open filter dialog
                final result = await showDialog<bool>(
                  context: context,
                  builder: (ctx) {
                    DateTime? pickedDate = _filterDate;
                    String pickedStatus = _filterStatus;
                    return StatefulBuilder(builder: (ctx, setStateDialog) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        titlePadding: EdgeInsets.fromLTRB(24, 20, 24, 0),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        actionsPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(
                          'Filter Transaksi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.brandDark,
                          ),
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Tanggal',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandDark,
                                ),
                              ),
                              subtitle: Text(
                                pickedDate != null
                                    ? '${pickedDate!.year.toString().padLeft(4, '0')}-${pickedDate!.month.toString().padLeft(2, '0')}-${pickedDate!.day.toString().padLeft(2, '0')}'
                                    : 'Semua',
                              ),
                              trailing: IconButton(
                                  icon: Icon(Icons.date_range,
                                      color: AppColors.brandDark),
                                  onPressed: () async {
                                    final d = await _pickDateBottomSheet(
                                        ctx, pickedDate);
                                    if (d != null) {
                                      setStateDialog(() {
                                        pickedDate = d;
                                      });
                                    }
                                  }),
                            ),
                            SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Status',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandDark,
                                ),
                              ),
                            ),
                            SizedBox(height: 4),
                            Container(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      AppColors.brandDark.withOpacity(0.15),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: pickedStatus,
                                  items: [
                                    DropdownMenuItem(
                                        value: 'all', child: Text('Semua')),
                                    DropdownMenuItem(
                                        value: 'on progress',
                                        child: Text('On Progress')),
                                    DropdownMenuItem(
                                        value: 'draft',
                                        child: Text('Draft')),
                                    DropdownMenuItem(
                                        value: 'paid', child: Text('Paid')),
                                    DropdownMenuItem(
                                        value: 'canceled',
                                        child: Text('Cancel')),
                                  ],
                                  onChanged: (v) => setStateDialog(() {
                                    if (v != null) pickedStatus = v;
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: Text(
                                'Batal',
                                style: TextStyle(color: Colors.grey[700]),
                              )),
                          TextButton(
                              onPressed: () {
                                // clear
                                _filterDate = null;
                                _filterStatus = 'all';
                                Navigator.of(ctx).pop(true);
                              },
                              child: Text(
                                'Reset',
                                style:
                                    TextStyle(color: AppColors.brandDark),
                              )),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandYellow,
                              foregroundColor: AppColors.brandDark,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () {
                              // apply
                              _filterDate = pickedDate;
                              _filterStatus = pickedStatus;
                              Navigator.of(ctx).pop(true);
                            },
                            child: Text('Terapkan'),
                          ),
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
