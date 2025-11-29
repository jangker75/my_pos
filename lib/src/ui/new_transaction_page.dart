import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/transaction_db.dart';
import '../models/transaction_model.dart';
import '../data/product_db.dart';

class NewTransactionPage extends StatefulWidget {
  final TransactionModel? initial;
  NewTransactionPage({Key? key, this.initial}) : super(key: key);

  @override
  _NewTransactionPageState createState() => _NewTransactionPageState();
}

class _NewTransactionPageState extends State<NewTransactionPage> {
  final _customerController = TextEditingController();
  final _db = TransactionDb();
  final _productDb = ProductDb();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _cart = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _customerController.text = 'umum';
    // if initial transaction provided, populate fields
    if (widget.initial != null) {
      final m = widget.initial!;
      _customerController.text = m.customer;
      final items = m.getItemsList();
      setState(() {
        _cart = items
            .map((e) => {
                  'name': e['name'],
                  'price': e['price'] is int
                      ? e['price']
                      : int.tryParse(e['price'].toString()) ?? 0,
                  'qty': e['qty'] is int
                      ? e['qty']
                      : int.tryParse(e['qty'].toString()) ?? 1,
                  'discount': e['discount'] ?? 0,
                  'discountType': e['discountType'] ?? 'nominal',
                })
            .toList();
      });
    }
    _customerController.addListener(_onCustomerChanged);
  }

  void _onCustomerChanged() {
    // rebuild to update suffix icon visibility
    setState(() {});
  }

  @override
  void dispose() {
    _customerController.removeListener(_onCustomerChanged);
    _customerController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final p = await _productDb.getAllProducts();
    setState(() {
      _products = p;
    });
  }

  int _calcTotal() => _cart.fold<int>(0, (s, i) {
        final qty = (i['qty'] as int);
        final price = (i['price'] as int);
        final discountType = (i['discountType'] as String?) ?? 'nominal';
        final rawDisc = (i['discount'] as int?) ?? 0;
        int discAmount = 0;
        if (discountType == 'percentage') {
          // percentage applies to line total
          discAmount = ((price * qty * rawDisc) ~/ 100);
        } else {
          // nominal discount per line
          discAmount = rawDisc;
        }
        final line = qty * price - discAmount;
        return s + (line > 0 ? line : 0);
      });

  String _formatCurrency(int value) {
    final s = value.toString();
    final parts = <String>[];
    for (int i = s.length; i > 0; i -= 3) {
      final start = i - 3 < 0 ? 0 : i - 3;
      parts.insert(0, s.substring(start, i));
    }
    return 'Rp ${parts.join('.')}';
  }

  Future<void> _checkout() async {
    final total = _calcTotal();
    if (_customerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Isi nama pelanggan')));
      return;
    }

    // attach customer as first item meta so list view can show customer name
    try {
      if (widget.initial != null) {
        // update existing transaction (preserve txnNumber and createdAt)
        final updated = TransactionModel(
          id: widget.initial!.id,
          txnNumber: widget.initial!.txnNumber,
          items: jsonEncode(_cart),
          total: total.toDouble(),
          status: 'in_progress',
          createdAt: widget.initial!.createdAt,
          customer: _customerController.text.trim(),
        );
        await _db.updateTransaction(updated);
      } else {
        final model = TransactionModel.createNew(
            itemsList: _cart,
            total: total.toDouble(),
            customer: _customerController.text.trim());
        await _db.insertTransaction(model);
      }
      // return success to caller
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menyimpan transaksi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // total calculated on demand via _calcTotal()

    return Scaffold(
      appBar: AppBar(
        title: Text('New Transaction'),
        backgroundColor: Colors.blue[800],
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer field
            Text('Customer', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            TextField(
              controller: _customerController,
              decoration: InputDecoration(
                hintText: 'Nama pelanggan',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: _customerController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _customerController.clear();
                        },
                      )
                    : null,
              ),
            ),
            SizedBox(height: 12),

            // Items header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.search),
                      onPressed: () async {
                        // open search dialog
                        final query = await showDialog<String>(
                            context: context,
                            builder: (ctx) {
                              final controller = TextEditingController();
                              return AlertDialog(
                                title: Text('Cari Produk'),
                                content: TextField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                      hintText: 'Ketik nama produk'),
                                  autofocus: true,
                                ),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(),
                                      child: Text('Batal')),
                                  TextButton(
                                      onPressed: () => Navigator.of(ctx)
                                          .pop(controller.text.trim()),
                                      child: Text('Cari')),
                                ],
                              );
                            });

                        if (query != null && query.isNotEmpty) {
                          final results = _products
                              .where((p) => (p['name'] as String)
                                  .toLowerCase()
                                  .contains(query.toLowerCase()))
                              .toList();
                          if (results.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Produk tidak ditemukan')));
                            return;
                          }

                          final picked =
                              await showModalBottomSheet<Map<String, dynamic>>(
                                  context: context,
                                  builder: (_) {
                                    return ListView.separated(
                                      itemCount: results.length,
                                      separatorBuilder: (_, __) =>
                                          Divider(height: 1),
                                      itemBuilder: (context, idx) {
                                        final p = results[idx];
                                        return ListTile(
                                          title: Text(p['name']),
                                          trailing: Text('Rp ${p['price']}'),
                                          onTap: () =>
                                              Navigator.of(context).pop(p),
                                        );
                                      },
                                    );
                                  });

                          if (picked != null) {
                            setState(() {
                              _cart.add({
                                'name': picked['name'],
                                'price': picked['price'],
                                'qty': 1,
                                'discount': 0,
                                'discountType': 'nominal'
                              });
                            });
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.add_box),
                      onPressed: () async {
                        // open product picker
                        final picked =
                            await showModalBottomSheet<Map<String, dynamic>>(
                                context: context,
                                builder: (_) {
                                  return ListView.separated(
                                    itemCount: _products.length,
                                    separatorBuilder: (_, __) =>
                                        Divider(height: 1),
                                    itemBuilder: (context, idx) {
                                      final p = _products[idx];
                                      return ListTile(
                                        title: Text(p['name']),
                                        trailing: Text('Rp ${p['price']}'),
                                        onTap: () =>
                                            Navigator.of(context).pop(p),
                                      );
                                    },
                                  );
                                });

                        if (picked != null) {
                          setState(() {
                            _cart.add({
                              'name': picked['name'],
                              'price': picked['price'],
                              'qty': 1,
                              'discount': 0,
                              'discountType': 'nominal'
                            });
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),

            // Items list
            Expanded(
              child: Card(
                elevation: 1,
                child: ListView.separated(
                  padding: EdgeInsets.all(8),
                  itemCount: _cart.length,
                  separatorBuilder: (_, __) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final it = _cart[index];
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: Colors.grey[200]),
                      title: Text(it['name']),
                      subtitle: Builder(builder: (_) {
                        final discountType =
                            (it['discountType'] as String?) ?? 'nominal';
                        final raw = (it['discount'] as int?) ?? 0;
                        final qty = (it['qty'] as int);
                        final price = (it['price'] as int);
                        final discAmount = discountType == 'percentage'
                            ? ((price * qty * raw) ~/ 100)
                            : raw;
                        return Text(
                            'Qty: ${it['qty']}  |  Disc: ${discountType == 'percentage' ? '${raw}% (Rp ${_formatCurrency(discAmount)})' : _formatCurrency(raw)}');
                      }),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.delete,
                                size: 22, color: Colors.grey[700]),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _cart.removeAt(index);
                              });
                            },
                          ),
                          SizedBox(width: 8),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                  _formatCurrency((it['qty'] as int) *
                                      (it['price'] as int)),
                                  style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold)),
                              Builder(builder: (_) {
                                final discountType =
                                    (it['discountType'] as String?) ??
                                        'nominal';
                                final raw = (it['discount'] as int?) ?? 0;
                                if (raw > 0) {
                                  final qty = (it['qty'] as int);
                                  final price = (it['price'] as int);
                                  final discAmount =
                                      discountType == 'percentage'
                                          ? ((price * qty * raw) ~/ 100)
                                          : raw;
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (discountType == 'percentage')
                                        Text('- ${raw}%',
                                            style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 12)),
                                      Text('- ${_formatCurrency(discAmount)}',
                                          style: TextStyle(
                                              color: Colors.red, fontSize: 12)),
                                    ],
                                  );
                                }
                                return SizedBox.shrink();
                              }),
                            ],
                          ),
                        ],
                      ),
                      onTap: () async {
                        // open edit qty/discount dialog
                        final result = await showDialog<Map<String, dynamic>>(
                            context: context,
                            builder: (ctx) {
                              final qtyController = TextEditingController(
                                  text: it['qty'].toString());
                              final discController = TextEditingController(
                                  text: (it['discount'] ?? 0).toString());
                              String selectedType =
                                  (it['discountType'] as String?) ?? 'nominal';
                              return StatefulBuilder(
                                  builder: (ctx2, setStateDialog) {
                                return AlertDialog(
                                  title: Text('Edit ${it['name']}'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(
                                        controller: qtyController,
                                        keyboardType: TextInputType.number,
                                        decoration:
                                            InputDecoration(labelText: 'Qty'),
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text('Tipe Diskon:'),
                                          SizedBox(width: 12),
                                          DropdownButton<String>(
                                            value: selectedType,
                                            items: [
                                              DropdownMenuItem(
                                                  value: 'nominal',
                                                  child: Text('Nominal')),
                                              DropdownMenuItem(
                                                  value: 'percentage',
                                                  child: Text('Percentage')),
                                            ],
                                            onChanged: (v) {
                                              if (v != null)
                                                setStateDialog(() {
                                                  selectedType = v;
                                                });
                                            },
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      TextField(
                                        controller: discController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                            labelText:
                                                selectedType == 'percentage'
                                                    ? 'Discount (%)'
                                                    : 'Discount (Rp)'),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(),
                                        child: Text('Batal')),
                                    TextButton(
                                        onPressed: () {
                                          final q = int.tryParse(
                                                  qtyController.text) ??
                                              it['qty'];
                                          final d = int.tryParse(
                                                  discController.text) ??
                                              (it['discount'] ?? 0);
                                          Navigator.of(ctx).pop({
                                            'qty': q,
                                            'discount': d,
                                            'discountType': selectedType
                                          });
                                        },
                                        child: Text('Simpan')),
                                  ],
                                );
                              });
                            });

                        if (result != null) {
                          setState(() {
                            _cart[index]['qty'] =
                                (result['qty'] as int?) ?? it['qty'];
                            _cart[index]['discount'] =
                                (result['discount'] as int?) ?? it['discount'];
                            _cart[index]['discountType'] =
                                (result['discountType'] as String?) ??
                                    it['discountType'] ??
                                    'nominal';
                          });
                        }
                      },
                      onLongPress: () {
                        // remove item from cart
                        setState(() {
                          _cart.removeAt(index);
                        });
                      },
                    );
                  },
                ),
              ),
            ),

            // Summary row moved to bottomBar
            SizedBox(height: 12),
          ],
        ),
      ),
      floatingActionButton: null,
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  SizedBox(height: 4),
                  Text(_formatCurrency(_calcTotal()),
                      style: TextStyle(
                          fontSize: 20,
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.payment),
                label: Text('Checkout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Konfirmasi Checkout'),
                      content:
                          Text('Yakin ingin menyimpan transaksi dan checkout?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text('Batal')),
                        TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: Text('Ya')),
                      ],
                    ),
                  );
                  if (confirm == true) await _checkout();
                },
              ),
              SizedBox(width: 12),
              TextButton.icon(
                icon: Icon(Icons.save),
                label: Text('Draft'),
                onPressed: () async {
                  // save as draft (status = 'draft'); update if editing existing
                  final total = _calcTotal();
                  try {
                    if (widget.initial != null) {
                      final updated = TransactionModel(
                        id: widget.initial!.id,
                        txnNumber: widget.initial!.txnNumber,
                        items: jsonEncode(_cart),
                        total: total.toDouble(),
                        status: 'draft',
                        createdAt: widget.initial!.createdAt,
                        customer: _customerController.text.trim(),
                      );
                      await _db.updateTransaction(updated);
                    } else {
                      final model = TransactionModel.createNew(
                          itemsList: _cart,
                          total: total.toDouble(),
                          customer: _customerController.text.trim());
                      // override status to draft
                      final draft = TransactionModel(
                          id: model.id,
                          txnNumber: model.txnNumber,
                          items: model.items,
                          total: model.total,
                          status: 'draft',
                          createdAt: model.createdAt,
                          customer: model.customer);
                      await _db.insertTransaction(draft);
                    }
                    if (!mounted) return;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) Navigator.of(context).pop(true);
                    });
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal menyimpan draft')));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
