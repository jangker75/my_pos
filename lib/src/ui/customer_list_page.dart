import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_pos/src/constant/const.dart';
import 'dart:convert';

import 'package:my_pos/src/data/customer_db.dart';

class CustomerListPage extends StatefulWidget {
  @override
  _CustomerListPageState createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage> {
  final _db = CustomerDb();
  List<Map<String, dynamic>> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final c = await _db.getAllCustomers();
    setState(() {
      _customers = c;
      _loading = false;
    });
  }

  Future<void> _sync() async {
    setState(() {
      _loading = true;
    });
    try {
      final uri = Uri.parse('${baseUrlBackend}customers');
      final resp = await http.get(uri).timeout(Duration(seconds: 15));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final List<dynamic> data =
          resp.body.isEmpty ? [] : (jsonDecode(resp.body) as List<dynamic>);

      final customers = data.map((e) {
        final name = e['name'] ?? e['Name'] ?? '';
        final description = e['description'] ?? e['Description'] ?? '';
        return {
          'name': name,
          'description': description,
        };
      }).toList();

      // perbarui data lokal dengan hasil dari server
      await _db.replaceCustomers(customers);

      // reload dari local DB supaya format data konsisten
      final c = await _db.getAllCustomers();
      setState(() {
        _customers = c;
        _loading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load customers: $e')));
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Customers'),
        actions: [
          IconButton(icon: Icon(Icons.sync), onPressed: _sync),
        ],
      ),
      body: ListView.separated(
        itemCount: _customers.length,
        separatorBuilder: (_, __) => Divider(height: 1),
        itemBuilder: (context, index) {
          final c = _customers[index];
          return ListTile(
            leading: CircleAvatar(child: Text(c['name'] != null && c['name'].isNotEmpty ? c['name'][0].toUpperCase() : '?')),
            title: Text(c['name'] ?? ''),
            subtitle: Text(c['description'] ?? ''),
          );
        },
      ),
    );
  }
}
