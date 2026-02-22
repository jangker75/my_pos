import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import '../data/transaction_db.dart';
import '../models/transaction_model.dart';
import '../repository/product_repository.dart';
import '../bloc/customer/customer_bloc.dart';
import 'transaction_detail_page.dart';

class NewTransactionPage extends StatefulWidget {
  final TransactionModel? initial;
  NewTransactionPage({Key? key, this.initial}) : super(key: key);

  @override
  _NewTransactionPageState createState() => _NewTransactionPageState();
}

class _NewTransactionPageState extends State<NewTransactionPage> {
  final _customerController = TextEditingController();
  final _notesController = TextEditingController();
  final List<String> _customerSuggestions = [];
  final FocusNode _customerFocusNode = FocusNode();
  final GlobalKey _customerFieldKey = GlobalKey();
  final _db = TransactionDb();
  final _productRepo = ProductRepository();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _cart = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    log("widget.initial: ${widget.initial?.toJson().toString()}");
    // pastikan CustomerBloc memuat data pelanggan untuk dropdown/autocomplete
    context.read<CustomerBloc>().add(LoadCustomers());
    _customerFocusNode.addListener(_onCustomerFocus);
    // if initial transaction provided, populate fields
    if (widget.initial != null) {
      final m = widget.initial!;
      _customerController.text = m.customer;
      _notesController.text = m.notes ?? '';
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
    _customerFocusNode.removeListener(_onCustomerFocus);
    _customerController.dispose();
    _notesController.dispose();
    _customerFocusNode.dispose();
    super.dispose();
  }

  void _onCustomerFocus() {
    // rebuild when focus changes so Autocomplete can show options on focus
    setState(() {});
  }

  Future<void> _showCustomerDropdown(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) {
        final height = MediaQuery.of(ctx).size.height * 0.5;
        return Container(
          height: height,
          child: Column(
            children: [
              SizedBox(height: 1.h),
              Container(
                width: 10.w,
                height: 0.8.h,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              SizedBox(height: 1.h),
              Expanded(
                child: ListView.separated(
                  itemCount: _customerSuggestions.length,
                  separatorBuilder: (_, __) => Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final s = _customerSuggestions[idx];
                    return ListTile(
                      title: Text(s),
                      onTap: () => Navigator.of(ctx).pop(s),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      _customerController.text = selected;
      setState(() {});
    }
  }

  Future<void> _loadProducts() async {
    final products = await _productRepo.getAll();
    setState(() {
      // Convert Product model to Map for compatibility with existing cart logic
      _products = products.map((p) => {
        'id': p.id,
        'name': p.name,
        'price': p.price.toInt(),
      }).toList();
      // Sort by product name alphabetically
      _products.sort((a, b) => 
        (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
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
          status: 'on progress',
          createdAt: widget.initial!.createdAt,
          customer: _customerController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
        log("data updated: ${updated.toJson()}");
        await _db.updateTransaction(updated);
      } else {
        final model = await TransactionModel.createNewWithValidation(
            itemsList: _cart,
            total: total.toDouble(),
            dbProvider: _db,
            customer: _customerController.text.trim());
        final withNotes = TransactionModel(
          id: model.id,
          txnNumber: model.txnNumber,
          items: model.items,
          total: model.total,
          status: model.status,
          createdAt: model.createdAt,
          customer: model.customer,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          synced: model.synced,
        );
        await _db.insertTransaction(withNotes);
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
    // sync customer suggestions from CustomerBloc state
    final customerState = context.watch<CustomerBloc>().state;
    if (customerState is CustomerLoaded) {
      final names = customerState.Customers
          .map((c) => c.name.trim())
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList();
      // update suggestions list once per build
      _customerSuggestions
        ..clear()
        ..add("")
        ..add('Umum')
        ..addAll(names.where((n) => n.toLowerCase() != 'umum'));
      if (_customerController.text.isEmpty) {
        _customerController.text = '';
      }
    }

    // total calculated on demand via _calcTotal()
    final isEditing = widget.initial != null;
    final txnNumber = widget.initial?.txnNumber ?? '';
    final isOnProgress = isEditing && widget.initial!.status == 'on progress';
    
    log("BUILD - isEditing: $isEditing, status: '${widget.initial?.status}', isOnProgress: $isOnProgress");

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'EDIT $txnNumber' : 'New Transaction',
          style: TextStyle(color: AppColors.brandYellow),
        ),
        backgroundColor: AppColors.brandDark,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.brandYellow),
          onPressed: () => Navigator.pop(context),
        ),
        // actions: [
        //   if (isOnProgress)
        //   IconButton(
        //     icon: Icon(Icons.create_rounded, color: AppColors.brandYellow),
        //     onPressed: () async {
        //       final changed = await Navigator.of(context).push<bool>(
        //         MaterialPageRoute(
        //           builder: (_) => TransactionDetailPage(
        //             model: widget.initial!,
        //           ),
        //         ),
        //       );

        //       if (changed == true && mounted) {
        //         Navigator.of(context).pop(true);
        //       }
        //     },
        //   ),
        // ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(3.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Customer field
            Text('Customer', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 1.2.h),
            RawAutocomplete<String>(
              textEditingController: _customerController,
              focusNode: _customerFocusNode,
              optionsBuilder: (TextEditingValue textEditingValue) {
                final input = textEditingValue.text.toLowerCase();
                log("input : " + input);
                if (input.isEmpty) return const Iterable<String>.empty();
                return _customerSuggestions.where((s) =>
                    s.toLowerCase().contains(input));
              },
              onSelected: (String selection) {
                _customerController.text = selection;
                setState(() {});
              },
              optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.9,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            title: Text(option),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              fieldViewBuilder: (context, textEditingController, focusNode,
                  onFieldSubmitted) {
                return TextField(
                  key: _customerFieldKey,
                  controller: textEditingController,
                  focusNode: focusNode,
                  onSubmitted: (_) => onFieldSubmitted(),
                  decoration: InputDecoration(
                    hintText: 'Nama pelanggan',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // if (textEditingController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _customerController.clear();
                              setState(() {});
                            },
                          ),
                        IconButton(
                          icon: Icon(Icons.arrow_drop_down),
                          onPressed: () => _showCustomerDropdown(context),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 1.8.h),
      
            // Notes field
            Text('Catatan (opsional)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 1.2.h),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Tambahkan catatan untuk transaksi ini',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
              ),
            ),
            SizedBox(height: 1.8.h),
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                titlePadding:
                                    EdgeInsets.fromLTRB(24, 20, 24, 0),
                                contentPadding: EdgeInsets.fromLTRB(
                                    24, 12, 24, 4),
                                actionsPadding:
                                    EdgeInsets.fromLTRB(16, 0, 16, 12),
                                title: Text(
                                  'Cari Produk',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: AppColors.brandDark,
                                  ),
                                ),
                                content: TextField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                    hintText: 'Ketik nama produk',
                                  ),
                                  autofocus: true,
                                ),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(),
                                      child: Text(
                                        'Batal',
                                        style:
                                            TextStyle(color: Colors.grey[700]),
                                      )),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.brandYellow,
                                      foregroundColor: AppColors.brandDark,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                    ),
                                    onPressed: () => Navigator.of(ctx)
                                        .pop(controller.text.trim()),
                                    child: Text('Cari'),
                                  ),
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
            SizedBox(
              height: 50.h,
              child: Card(
                elevation: 1,
                child: ListView.separated(
                  padding: EdgeInsets.all(2.w),
                  itemCount: _cart.length,
                  separatorBuilder: (_, __) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final it = _cart[index];
                    return ListTile(
                      // leading: CircleAvatar(backgroundColor: AppColors.brandYellow.withOpacity(0.12)),
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
                          SizedBox(width: 2.w),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                                Text(
                                  _formatCurrency((it['qty'] as int) *
                                    (it['price'] as int)),
                                  style: TextStyle(
                                    color: AppColors.brandDark,
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
                                            fontSize: 12.sp)),
                                        Text('- ${_formatCurrency(discAmount)}',
                                          style: TextStyle(
                                            color: Colors.red, fontSize: 12.sp)),
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
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  titlePadding:
                                      EdgeInsets.fromLTRB(24, 20, 24, 0),
                                  contentPadding: EdgeInsets.fromLTRB(
                                      24, 12, 24, 4),
                                  actionsPadding: EdgeInsets.fromLTRB(
                                      16, 0, 16, 12),
                                  title: Text(
                                    'Edit ${it['name']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: AppColors.brandDark,
                                    ),
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Qty',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.brandDark,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      TextField(
                                        controller: qtyController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          border: UnderlineInputBorder(),
                                        ),
                                      ),
                                      SizedBox(height: 1.4.h),
                                      Text(
                                        'Tipe Diskon',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.brandDark,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: AppColors.brandDark
                                                .withOpacity(0.15),
                                          ),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            value: selectedType,
                                            items: const [
                                              DropdownMenuItem(
                                                  value: 'nominal',
                                                  child: Text('Nominal')),
                                              DropdownMenuItem(
                                                  value: 'percentage',
                                                  child:
                                                      Text('Percentage')),
                                            ],
                                            onChanged: (v) {
                                              if (v != null) {
                                                setStateDialog(() {
                                                  selectedType = v;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 1.4.h),
                                      Text(
                                        selectedType == 'percentage'
                                            ? 'Discount (%)'
                                            : 'Discount (Rp)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.brandDark,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      TextField(
                                        controller: discController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          border: UnderlineInputBorder(),
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(),
                                        child: Text(
                                          'Batal',
                                          style: TextStyle(
                                              color: Colors.grey[700]),
                                        )),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppColors.brandYellow,
                                        foregroundColor:
                                            AppColors.brandDark,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                      onPressed: () {
                                        final q =
                                            int.tryParse(qtyController.text) ??
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
                                      child: Text('Simpan'),
                                    ),
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
            SizedBox(height: 1.8.h),
          ],
          ),
        ),
      ),
      floatingActionButton: null,
      bottomNavigationBar: SafeArea(
        child: Container(
          color: AppColors.brandDark,
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey[300])),
                  SizedBox(height: 0.6.h),
                  Text(_formatCurrency(_calcTotal()),
                      style: TextStyle(
                          fontSize: 20.sp,
                          color: AppColors.brandYellow,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.payment, color: AppColors.brandDark),
                label: Text((!isOnProgress ? 'Checkout' : "Edit"), style: TextStyle(color: AppColors.brandDark)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandYellow,
                  foregroundColor: AppColors.brandDark,
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.4.h),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      titlePadding: EdgeInsets.fromLTRB(24, 20, 24, 0),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      actionsPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        'Konfirmasi ${isOnProgress ? "Edit" : "Checkout"}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.brandDark,
                        ),
                      ),
                      content: Text(
                        "Yakin ingin menyimpan transaksi ${isOnProgress ? "" : "dan checkout"}?",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.brandDark,
                        ),
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(
                              'Batal',
                              style: TextStyle(color: Colors.grey[700]),
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
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text('Ya, ${isOnProgress ? "Edit" : "Checkout"}'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) await _checkout();
                },
              ),
              SizedBox(width: 3.w),
              TextButton.icon(
                icon: Icon(Icons.save, color: Colors.white),
                label: Text('Draft', style: TextStyle(color: Colors.white)),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
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
                        notes: _notesController.text.trim().isEmpty
                            ? null
                            : _notesController.text.trim(),
                      );
                      await _db.updateTransaction(updated);
                    } else {
                      final model = await TransactionModel.createNewWithValidation(
                          itemsList: _cart,
                          total: total.toDouble(),
                          dbProvider: _db,
                          customer: _customerController.text.trim());
                      // override status to draft
                      final draft = TransactionModel(
                        id: model.id,
                        txnNumber: model.txnNumber,
                        items: model.items,
                        total: model.total,
                        status: 'draft',
                        createdAt: model.createdAt,
                        customer: model.customer,
                        notes: _notesController.text.trim().isEmpty
                            ? null
                            : _notesController.text.trim(),
                        synced: model.synced,
                      );
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
