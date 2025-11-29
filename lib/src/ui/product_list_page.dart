import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_pos/src/constant/const.dart';
import 'dart:convert';
import '../data/product_db.dart';

class ProductListPage extends StatefulWidget {
  @override
  _ProductListPageState createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final _db = ProductDb();
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _db.getAllProducts();
    setState(() {
      _products = p;
      _loading = false;
    });
  }

  Future<void> _sync() async {
    setState(() {
      _loading = true;
    });
    try {
      final uri = Uri.parse('${baseUrlBackend}menu_details');
      final resp = await http.get(uri).timeout(Duration(seconds: 15));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final List<dynamic> data =
          resp.body.isEmpty ? [] : (jsonDecode(resp.body) as List<dynamic>);
      // extract name and price only
      final products = data.map((e) {
        final name = e['name'] ?? e['Name'] ?? '';
        final price = e['price'] is int
            ? e['price']
            : int.tryParse((e['price'] ?? '').toString()) ?? 0;
        return {'name': name, 'price': price};
      }).toList();

      await _db.replaceProducts(products);
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Products synced (${products.length})')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to sync products: $e')));
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: Text('Products'),
        actions: [
          IconButton(icon: Icon(Icons.sync), onPressed: _sync),
        ],
      ),
      body: ListView.separated(
        itemCount: _products.length,
        separatorBuilder: (_, __) => Divider(height: 1),
        itemBuilder: (context, index) {
          final p = _products[index];
          return ListTile(
            title: Text(p['name'] ?? ''),
            trailing: Text('Rp ${p['price']}'),
          );
        },
      ),
    );
  }
}
