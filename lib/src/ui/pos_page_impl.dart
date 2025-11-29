import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/product_bloc.dart';
import '../bloc/transaction_bloc.dart';
import '../repository/product_repository.dart';
import '../repository/transaction_repository.dart';
import 'product_list.dart';
import '../models/product.dart';
import '../models/transaction_model.dart';

class PosPageImpl extends StatefulWidget {
  @override
  _PosPageImplState createState() => _PosPageImplState();
}

class _PosPageImplState extends State<PosPageImpl> {
  late ProductBloc productBloc;
  late TransactionBloc txBloc;
  List<Product> cart = [];

  @override
  void initState() {
    super.initState();
    final productRepo = ProductRepository();
    final txRepo = TransactionRepository();
    productBloc = ProductBloc(repo: productRepo);
    txBloc = TransactionBloc(repo: txRepo);

    productBloc.add(LoadProducts());
    txBloc.add(LoadTransactions());
  }

  void addToCart(Product p) {
    setState(() => cart.add(p));
  }

  double total() => cart.fold(0.0, (s, e) => s + e.price);

  void checkout() {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Keranjang kosong. Tambahkan produk terlebih dahulu.')));
      return;
    }

    // build items list with unit price locked, qty default 1, discount default 0
    final itemsList = cart
        .map((c) => {
              'id': c.id,
              'name': c.name,
              'unit_price': c.price,
              'qty': 1,
              'discount': 0.0
            })
        .toList();

    final totalAmount = total();
    if (totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Total transaksi harus lebih besar dari 0')));
      return;
    }

    final t =
        TransactionModel.createNew(itemsList: itemsList, total: totalAmount);
    txBloc.add(AddTransaction(t));
    // reload transactions after a short delay to allow DB insert
    Future.delayed(
        Duration(milliseconds: 200), () => txBloc.add(LoadTransactions()));
    setState(() => cart.clear());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Transaksi ${t.txnNumber} dibuat (in_progress)')));
  }

  Future<void> _openEditTransactionDialog(TransactionModel txn) async {
    final items = txn.getItemsList();
    final controllers = List.generate(items.length, (i) {
      final qtyCtrl =
          TextEditingController(text: (items[i]['qty'] ?? 1).toString());
      final discCtrl =
          TextEditingController(text: (items[i]['discount'] ?? 0).toString());
      return {'qty': qtyCtrl, 'discount': discCtrl};
    });

    final result = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          String? errorText;
          return StatefulBuilder(builder: (ctx2, setStateDialog) {
            return AlertDialog(
              title: Text('Edit Transaksi ${txn.txnNumber}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorText != null)
                      Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(errorText!,
                              style: TextStyle(color: Colors.red))),
                    ...List.generate(items.length, (i) {
                      final it = items[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(
                                    '${it['name']} (Rp ${it['unit_price']})')),
                            SizedBox(width: 8),
                            Container(
                                width: 60,
                                child: TextField(
                                    controller: controllers[i]['qty'],
                                    keyboardType: TextInputType.number,
                                    decoration:
                                        InputDecoration(labelText: 'Qty'))),
                            SizedBox(width: 8),
                            Container(
                                width: 80,
                                child: TextField(
                                    controller: controllers[i]['discount'],
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration:
                                        InputDecoration(labelText: 'Diskon'))),
                          ],
                        ),
                      );
                    })
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Batal')),
                ElevatedButton(
                    onPressed: () {
                      // validate inputs
                      for (var i = 0; i < items.length; i++) {
                        final q =
                            int.tryParse(controllers[i]['qty']!.text) ?? -1;
                        final d =
                            double.tryParse(controllers[i]['discount']!.text) ??
                                -1.0;
                        final unit =
                            (items[i]['unit_price'] ?? items[i]['price'] ?? 0)
                                .toDouble();
                        if (q <= 0) {
                          setStateDialog(() => errorText =
                              'Qty harus > 0 untuk ${items[i]['name']}');
                          return;
                        }
                        if (d < 0) {
                          setStateDialog(() => errorText =
                              'Diskon tidak boleh negatif untuk ${items[i]['name']}');
                          return;
                        }
                        if (d > unit * q) {
                          setStateDialog(() => errorText =
                              'Diskon tidak boleh melebihi subtotal untuk ${items[i]['name']}');
                          return;
                        }
                      }

                      // if all valid, apply changes
                      for (var i = 0; i < items.length; i++) {
                        final q =
                            int.tryParse(controllers[i]['qty']!.text) ?? 1;
                        final d =
                            double.tryParse(controllers[i]['discount']!.text) ??
                                0.0;
                        items[i]['qty'] = q;
                        items[i]['discount'] = d;
                      }

                      Navigator.of(ctx).pop(true);
                    },
                    child: Text('Simpan'))
              ],
            );
          });
        });

    if (result == true) {
      // send update items event to bloc
      txBloc.add(UpdateTransactionItems(txn.id!, items));
      // reload
      Future.delayed(
          Duration(milliseconds: 200), () => txBloc.add(LoadTransactions()));
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Perubahan disimpan untuk ${txn.txnNumber}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: productBloc),
        BlocProvider.value(value: txBloc),
      ],
      child: Scaffold(
        appBar: AppBar(title: Text('My POS')),
        body: Row(
          children: [
            Expanded(
              flex: 3,
              child: BlocBuilder<ProductBloc, ProductState>(
                  builder: (context, state) {
                if (state is ProductLoading)
                  return Center(child: CircularProgressIndicator());
                if (state is ProductLoaded)
                  return ProductList(
                      products: state.products.cast<Product>(),
                      onSelect: addToCart);
                return Container();
              }),
            ),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  // Active transactions list
                  Expanded(
                    child: BlocBuilder<TransactionBloc, TransactionState>(
                        builder: (context, state) {
                      if (state is TransactionLoading)
                        return Center(child: CircularProgressIndicator());
                      if (state is TransactionLoaded) {
                        final txs = state.transactions;
                        return ListView.builder(
                          itemCount: txs.length,
                          itemBuilder: (c, i) {
                            final t = txs[i];
                            return ListTile(
                              title: Text(
                                  '${t.txnNumber}  - Rp ${t.total.toStringAsFixed(0)}'),
                              subtitle: Text('Status: ${t.status}'),
                              trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        icon: Icon(Icons.edit),
                                        onPressed: () =>
                                            _openEditTransactionDialog(t)),
                                    IconButton(
                                        icon: Icon(Icons.check),
                                        onPressed: t.status == 'paid'
                                            ? null
                                            : () => txBloc.add(
                                                MarkTransactionPaid(t.id!))),
                                  ]),
                              onTap: () {
                                // show details
                                showDialog(
                                    context: context,
                                    builder: (_) {
                                      final items = t.getItemsList();
                                      return AlertDialog(
                                        title: Text('Detail ${t.txnNumber}'),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: items
                                                .map((it) => ListTile(
                                                    title:
                                                        Text(it['name'] ?? ''),
                                                    subtitle: Text(
                                                        'Qty: ${it['qty']}  Diskon: ${it['discount']}'),
                                                    trailing: Text(
                                                        'Rp ${(it['unit_price'] ?? it['price']).toString()}')))
                                                .toList(),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: Text('Tutup'))
                                        ],
                                      );
                                    });
                              },
                            );
                          },
                        );
                      }
                      return Container();
                    }),
                  ),

                  // Cart and actions
                  Divider(),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                            child: ListView.builder(
                                itemCount: cart.length,
                                itemBuilder: (c, i) => ListTile(
                                    title: Text(cart[i].name),
                                    trailing: Text(
                                        'Rp ${cart[i].price.toStringAsFixed(0)}')))),
                        Text('Total: Rp ${total().toStringAsFixed(0)}'),
                        Row(children: [
                          ElevatedButton(
                              onPressed: checkout,
                              child: Text('Buat Transaksi')),
                          SizedBox(width: 8),
                          ElevatedButton(
                              onPressed: () => setState(() => cart.clear()),
                              child: Text('Batal'))
                        ])
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
