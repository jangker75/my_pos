import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:my_pos/src/constant/const.dart';
import 'dart:convert';
import '../bloc/product/product_bloc.dart';
import '../models/product.dart';

class ProductListPage extends StatefulWidget {
  @override
  _ProductListPageState createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  @override
  void initState() {
    super.initState();
    // trigger initial load via BLoC
    context.read<ProductBloc>().add(LoadProducts());
  }

  Future<void> _sync() async {
    final uri = Uri.parse('${baseUrlBackend}menu_details');
    final resp = await http.get(uri).timeout(Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final List<dynamic> data =
        resp.body.isEmpty ? [] : (jsonDecode(resp.body) as List<dynamic>);

    // extract name and price only, then map to Product model
    final products = data.map<Product>((e) {
      final name = e['name'] ?? e['Name'] ?? '';
      final price = e['price'] is num
          ? (e['price'] as num).toDouble()
          : double.tryParse((e['price'] ?? '').toString()) ?? 0.0;
      // id & stock tidak tersedia dari API ini, isi default
      return Product(
        id: 0,
        code: '',
        name: name.toString(),
        price: price,
        stock: 0,
      );
    }).toList();

    // minta BLoC mengganti isi produk lokal
    context.read<ProductBloc>().add(ReplaceProducts(products));
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Products synced (${products.length})')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Products'),
        actions: [
          IconButton(icon: Icon(Icons.sync), onPressed: _sync),
        ],
      ),
      body: BlocBuilder<ProductBloc, ProductState>(
        builder: (context, state) {
          if (state is ProductLoading) {
            return Center(child: CircularProgressIndicator());
          }
          if (state is ProductLoaded) {
            final products = state.products;
            if (products.isEmpty) {
              return Center(child: Text('No products'));
            }
            return ListView.separated(
              itemCount: products.length,
              separatorBuilder: (_, __) => Divider(height: 1),
              itemBuilder: (context, index) {
                final p = products[index];
                return ListTile(
                  title: Text(p.name),
                  trailing: Text('Rp ${p.price.toStringAsFixed(0)}'),
                );
              },
            );
          }
          // fallback, should not normally reach here
          return Center(child: Text('Unexpected state'));
        },
      ),
    );
  }
}
