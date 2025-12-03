import 'dart:convert';
import 'dart:math';

class TransactionModel {
  final int? id;
  final String txnNumber;
  final String items; // JSON string
  final double total;
  final String status;
  final String createdAt;
  final String customer;
  final String? paymentMethod;
  final int? synced;
  final String? notes;

  TransactionModel({
    this.id,
    required this.txnNumber,
    required this.items,
    required this.total,
    required this.status,
    required this.createdAt,
    this.paymentMethod,
    this.synced,
    this.notes,
    this.customer = '-',
  });

  /// Helper to create a new transaction with generated txnNumber and status on progress
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
      status: 'on progress',
      createdAt: now.toIso8601String(),
      customer: customer,
      synced: 0,
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

  /// Format: KP + YY + MM + DD + HH + mm + RR (random 2 digit)
  /// Example: KP250522145537
  static String _generateTxnNumber(DateTime dt) {
    final yy = dt.year % 100;
    final mm = _twoDigits(dt.month);
    final dd = _twoDigits(dt.day);
    final hh = _twoDigits(dt.hour);
    final random = _twoDigits(Random().nextInt(100)); // 00-99
    return 'KP${_twoDigits(yy)}$mm$dd$hh$random';
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
      status: json['status'] ?? 'on progress',
      createdAt: json['createdAt'] ??
          json['created_at'] ??
          DateTime.now().toIso8601String(),
      customer: json['customer'] ?? json['customer'] ?? '-',
      paymentMethod: json['paymentMethod'] ?? json['payment_method'] ?? null,
      synced: json['synced'] is int
          ? json['synced'] as int
          : (json['synced'] == null ? null : int.tryParse(json['synced'].toString())),
      notes: json['notes'] ?? json['note'],
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
        'paymentMethod': paymentMethod,
        if (synced != null) 'synced': synced,
        if (notes != null) 'notes': notes,
      };
}
