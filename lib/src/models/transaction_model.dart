import 'dart:convert';

class TransactionModel {
  final int? id;
  final String txnNumber;
  final String items; // JSON string
  final double total;
  final String status;
  final String createdAt;
  final String customer;

  TransactionModel({
    this.id,
    required this.txnNumber,
    required this.items,
    required this.total,
    required this.status,
    required this.createdAt,
    this.customer = '-',
  });

  /// Helper to create a new transaction with generated txnNumber and status in_progress
  factory TransactionModel.createNew(
      {required List<Map<String, dynamic>> itemsList,
      required double total,
      String customer = '-'}) {
    final now = DateTime.now();
    final txn = _generateTxnNumber(now);
    return TransactionModel(
      txnNumber: txn,
      items: jsonEncode(itemsList),
      total: total,
      status: 'in_progress',
      createdAt: now.toIso8601String(),
      customer: customer,
    );
  }

  /// Parse items JSON string back to list
  List<Map<String, dynamic>> getItemsList() {
    try {
      final decoded = jsonDecode(items);
      return (decoded as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static String _twoDigits(int v) => v.toString().padLeft(2, '0');

  /// Format: KP + YY + MM + DD + HH + mm  (example: KP2505221455)
  static String _generateTxnNumber(DateTime dt) {
    final yy = dt.year % 100;
    final mm = _twoDigits(dt.month);
    final dd = _twoDigits(dt.day);
    final hh = _twoDigits(dt.hour);
    final min = _twoDigits(dt.minute);
    return 'KP${_twoDigits(yy)}$mm$dd$hh$min';
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] is int
          ? json['id'] as int
          : (json['id'] == null ? null : int.tryParse(json['id'].toString())),
      txnNumber: json['txnNumber'] ?? json['txn_number'] ?? '',
      items: json['items'] ?? '',
      total: (json['total'] is int)
          ? (json['total'] as int).toDouble()
          : (json['total'] is double
              ? json['total'] as double
              : double.tryParse(json['total'].toString()) ?? 0.0),
      status: json['status'] ?? 'in_progress',
      createdAt: json['createdAt'] ??
          json['created_at'] ??
          DateTime.now().toIso8601String(),
      customer: json['customer'] ?? json['customer'] ?? '-',
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'txnNumber': txnNumber,
        'items': items,
        'total': total,
        'status': status,
        'createdAt': createdAt,
        'customer': customer,
      };
}
