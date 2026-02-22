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
  /// [generateUniqueOnly] - jika true, akan validate apakah txnNumber sudah ada di database
  factory TransactionModel.createNew(
      {required List<Map<String, dynamic>> itemsList,
      required double total,
      String customer = '-',
      String? txnNumber}) {
    final now = DateTime.now();
    final txn = txnNumber ?? _generateTxnNumber(now);
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

  /// Async method to create a transaction dengan validasi txnNumber unique di database
  /// Jika txnNumber yang di-generate sudah ada di database, akan generate ulang
  static Future<TransactionModel> createNewWithValidation({
    required List<Map<String, dynamic>> itemsList,
    required double total,
    required dynamic dbProvider, // TransactionDb instance
    String customer = '-',
  }) async {
    String uniqueTxnNumber = '';
    int attempts = 0;
    const maxAttempts = 10;

    // Keep generating until we find a unique txnNumber
    while (attempts < maxAttempts) {
      final generatedTxn = _generateTxnNumber(DateTime.now());
      try {
        // Check if txnNumber already exists in database
        final existing = await dbProvider.getTransactionByTxnNumber(generatedTxn);
        if (existing == null) {
          // txnNumber is unique, use it
          uniqueTxnNumber = generatedTxn;
          break;
        }
      } catch (e) {
        // If error checking database, use the generated number anyway
        uniqueTxnNumber = generatedTxn;
        break;
      }
      attempts++;
      
      // Add small delay before retry to ensure different random number
      await Future.delayed(const Duration(milliseconds: 10));
    }

    if (uniqueTxnNumber.isEmpty) {
      throw Exception('Failed to generate unique transaction number after $maxAttempts attempts');
    }

    return TransactionModel.createNew(
      itemsList: itemsList,
      total: total,
      customer: customer,
      txnNumber: uniqueTxnNumber,
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

  /// Format: KP + YY + MM + DD + HH + mm + ss + RR (random 2 digit)
  /// Example: KP25052214553712
  static String _generateTxnNumber(DateTime dt) {
    final yy = dt.year % 100;
    final mm = _twoDigits(dt.month);
    final dd = _twoDigits(dt.day);
    final hh = _twoDigits(dt.hour);
    final min = _twoDigits(dt.minute);
    final ss = _twoDigits(dt.second);
    final random = Random().nextInt(100).toString().padLeft(2, '0'); // 00-99
    return 'KP${_twoDigits(yy)}$mm$dd$hh$min$ss$random';
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
