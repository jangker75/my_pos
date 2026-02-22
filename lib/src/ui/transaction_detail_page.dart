import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:my_pos/src/ui/new_transaction_page.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import '../models/transaction_model.dart';
import '../data/transaction_db.dart';
import '../theme.dart';
import '../services/receipt_printer_service.dart';

class TransactionDetailPage extends StatefulWidget {
  final TransactionModel model;
  TransactionDetailPage({Key? key, required this.model}) : super(key: key);

  @override
  _TransactionDetailPageState createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  final _db = TransactionDb();
  final _printer = ReceiptPrinterService();
  TransactionModel? _currentModel;

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
    String? paymentMethod;

    if (status == 'paid') {
      paymentMethod = await showDialog<String>(
        context: context,
        builder: (ctx) {
          String selected = 'cash';
          return StatefulBuilder(builder: (ctx2, setStateDialog) {
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
                'Pilih Metode Bayar',
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
                  Text(
                    'Payment Method',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.brandDark.withOpacity(0.15),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selected,
                        items: const [
                          DropdownMenuItem(
                              value: 'cash', child: Text('Cash')),
                          DropdownMenuItem(
                              value: 'qris', child: Text('QRIS')),
                          DropdownMenuItem(
                              value: 'transfer', child: Text('Transfer')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setStateDialog(() {
                              selected = v;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: Text(
                    'Batal',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandYellow,
                    foregroundColor: AppColors.brandDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(selected),
                  child: Text('Simpan'),
                ),
              ],
            );
          });
        },
      );

      if (paymentMethod == null) {
        return;
      }
    }

    await _db.updateStatusByTxn(widget.model.txnNumber, status, paymentMethod);
    // For simplicity, pop with result then caller will refresh
    Navigator.of(context).pop(true);
  }

  // initialize expanded groups after load
  @override
  void initState() {
    super.initState();
    log("Model : " + widget.model.toJson().toString());
    _loadTransaction();
  }

  Future<void> _loadTransaction() async {
    final freshData = await _db.getTransactionByTxnNumber(widget.model.txnNumber);
    if (freshData != null && mounted) {
      setState(() {
        _currentModel = freshData;
      });
      log("Fresh Model from DB: " + freshData.toJson().toString());
    }
  }
  @override
  Widget build(BuildContext context) {
    final model = _currentModel ?? widget.model;
    final items = model.getItemsList();
    DateTime _parse(String s) => DateTime.tryParse(s) ?? DateTime.now();
    String _fmt(DateTime dt) =>
        '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.brandDark,
        iconTheme: IconThemeData(color: AppColors.brandYellow),
        title: Text('Transaksi ${model.txnNumber}',
            style: TextStyle(color: AppColors.brandYellow)),
        actions: [
          if (model.status == 'draft' || model.status == 'on progress') 
          IconButton(
            onPressed: () async {
              final saved = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => NewTransactionPage(initial: model)
                )
              );
              if (saved == true) {
                await _loadTransaction();
                // Notify parent (transaction list) that data changed
                if (mounted) Navigator.of(context).pop(true);
              }
            },
            icon: Icon(Icons.create_rounded, color: AppColors.brandYellow)
          ),
          model.status != 'on progress'
              ? SizedBox.shrink()
              :
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
        padding: EdgeInsets.all(3.w),
        children: [
          Text(_formatCurrency(model.total),
              style: TextStyle(
                  fontSize: 24.sp,
                  color: AppColors.brandDark,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 0.6.h),
          Text('${model.customer}',
              style: TextStyle(fontSize: 18.sp, color: AppColors.brandDark, 
              fontWeight: FontWeight.bold)),
          SizedBox(height: 0.6.h),
          Row(
            children: [
              Expanded(child: Text(_fmt(_parse(model.createdAt)))),
              SizedBox(width: 2.w),
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
                  label: Text(
                    statusText,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: statusColor,
                  padding:
                      EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide.none,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }),
            ],
          ),
          SizedBox(height: 1.6.h),
          Text('Catatan',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
          SizedBox(height: 0.8.h),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 1,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(3.w),
              child: Text(
                (model.notes ?? '').isEmpty
                    ? '-'
                    : model.notes!,
                style: TextStyle(fontSize: 15.sp),
              ),
            ),
          ),
          SizedBox(height: 1.6.h),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 1,
            margin: EdgeInsets.zero,
            child: Column(
              children: items.map((it) {
                final qty = it['qty'] ?? 0;
                final price = it['price'] ?? 0;
                final disc = it['discount'] ?? 0;
                final line = qty * price - disc;
                return Column(
                  children: [
                    ListTile(
                      title: Text('${it['name']}',
                          style: TextStyle(fontSize: 18.sp)),
                      subtitle: Text('${qty} x ${price}',
                          style: TextStyle(fontSize: 16.sp)),
                      trailing: Text(
                        _formatCurrency(line.toDouble()),
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: AppColors.brandDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (it != items.last)
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Colors.grey.shade300,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 1.6.h),
          Text('Detail Pembayaran',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
          SizedBox(height: 1.h),
          Card(
            child: Padding(
              padding: EdgeInsets.all(3.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_fmt(_parse(model.createdAt)),
                      style: TextStyle(fontSize: 16.sp)),
                  SizedBox(height: 0.6.h),
                  Text(model.paymentMethod ?? '-', style: TextStyle(fontSize: 16.sp)),
                  SizedBox(height: 1.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: TextStyle(fontSize: 16.sp)),
                      Text(_formatCurrency(model.total),
                          style: TextStyle(
                              fontSize: 18.sp, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 2.h),

          // Print Receipt Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _printer.showPrintDialog(context, model),
              icon: Icon(Icons.print, color: Colors.white),
              label: Text('Print Struk',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandDark,
                padding: EdgeInsets.symmetric(vertical: 1.5.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          SizedBox(height: 3.h),
        ],
      ),
    );
  }
}
