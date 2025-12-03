import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:my_pos/src/constant/const.dart';
import 'dart:convert';

import 'package:my_pos/src/bloc/customer/customer_bloc.dart';
import 'package:my_pos/src/models/customer.dart';

class CustomerListPage extends StatefulWidget {
  @override
  _CustomerListPageState createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage> {
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    // trigger initial load via BLoC
    context.read<CustomerBloc>().add(LoadCustomers());
  }

  Future<void> _sync() async {
    if (_isSyncing) return; // prevent double tap

    setState(() => _isSyncing = true);

    try {
      final uri = Uri.parse('${baseUrlBackend}customers');
      final resp = await http.get(uri).timeout(Duration(seconds: 15));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final List<dynamic> data =
          resp.body.isEmpty ? [] : (jsonDecode(resp.body) as List<dynamic>);

      final customers = data.asMap().entries.map<Customer>((entry) {
        final e = entry.value;
        final name = e['name'] ?? e['Name'] ?? '';
        final description = e['description'] ?? e['Description'] ?? '';
        return Customer(
          name: name.toString(),
          description: description.toString(),
        );
      }).toList();

      // minta BLoC mengganti isi customer lokal
      if (mounted) {
        context.read<CustomerBloc>().add(ReplaceCustomers(customers));
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Customers synced (${customers.length})')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sync failed: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Customers'),
        actions: [
          _isSyncing
              ? Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(icon: Icon(Icons.sync), onPressed: _sync),
        ],
      ),
      body: BlocBuilder<CustomerBloc, CustomerState>(
        builder: (context, state) {
          if (state is CustomerLoading) {
            return Center(child: CircularProgressIndicator());
          }
          if (state is CustomerLoaded) {
            final customers = state.Customers;
            if (customers.isEmpty) {
              return Center(child: Text('No customers'));
            }
            return ListView.separated(
              itemCount: customers.length,
              separatorBuilder: (_, __) => Divider(height: 1),
              itemBuilder: (context, index) {
                final c = customers[index];
                return ListTile(
                  leading: CircleAvatar(
                      child: Text(c.name.isNotEmpty
                          ? c.name[0].toUpperCase()
                          : '?')),
                  title: Text(c.name),
                  subtitle: Text(c.description),
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
