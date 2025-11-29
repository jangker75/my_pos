import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../data/transaction_db.dart';

class TransactionDetailPage extends StatefulWidget {
  final TransactionModel model;
  TransactionDetailPage({Key? key, required this.model}) : super(key: key);

  @override
  _TransactionDetailPageState createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  final _db = TransactionDb();

  String _formatCurrency(double value) {
    final s = value.toInt().toString();
    final parts = <String>[];
    for (int i = s.length; i > 0; i -= 3) {
      final start = i - 3 < 0 ? 0 : i - 3;
      parts.insert(0, s.substring(start, i));
    }
    return 'Rp ${parts.join('.')}';
  }

  Future<void> _changeStatus(String status) async {
    await _db.updateStatusByTxn(widget.model.txnNumber, status);
    // For simplicity, pop with result then caller will refresh
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final items = model.getItemsList();
    DateTime _parse(String s) => DateTime.tryParse(s) ?? DateTime.now();
    String _fmt(DateTime dt) =>
        '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(
        title: Text('Transaksi ${model.txnNumber}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'paid') await _changeStatus('paid');
              if (v == 'canceled') await _changeStatus('canceled');
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'paid', child: Text('Tandai Lunas')),
              PopupMenuItem(value: 'canceled', child: Text('Tandai Batal')),
            ],
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12.0),
        children: [
          Text(_formatCurrency(model.total),
              style: TextStyle(
                  fontSize: 24,
                  color: Colors.blue[800],
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text(_fmt(_parse(model.createdAt)))),
              SizedBox(width: 8),
              Builder(builder: (_) {
                String statusText;
                Color statusColor;
                if (model.status == 'paid') {
                  statusText = 'LUNAS';
                  statusColor = Colors.green;
                } else if (model.status == 'canceled') {
                  statusText = 'BATAL';
                  statusColor = Colors.red;
                } else {
                  statusText = 'ON PROGRESS';
                  statusColor = Colors.orange;
                }
                return Chip(
                    label:
                        Text(statusText, style: TextStyle(color: Colors.white)),
                    backgroundColor: statusColor);
              }),
            ],
          ),
          SizedBox(height: 12),
          Card(
            child: Column(
              children: items.map((it) {
                final qty = it['qty'] ?? 0;
                final price = it['price'] ?? 0;
                final disc = it['discount'] ?? 0;
                final line = qty * price - disc;
                return Column(
                  children: [
                    ListTile(
                      title: Text('${it['name']}'),
                      subtitle: Text('${qty} x ${price}'),
                      trailing: Text(_formatCurrency(line.toDouble())),
                    ),
                    Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 12),
          Text('Detil Pembayaran',
              style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_fmt(_parse(model.createdAt))),
                  SizedBox(height: 4),
                  Text('Tunai'),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total'),
                      Text(_formatCurrency(model.total)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}
