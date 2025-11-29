import 'package:flutter/material.dart';
import 'ui/transaction_list_page.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My POS',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: TransactionListPage(),
    );
  }
}
