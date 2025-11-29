part of 'transaction_bloc.dart';

abstract class TransactionEvent {}

class LoadTransactions extends TransactionEvent {}

class AddTransaction extends TransactionEvent {
  final TransactionModel transaction;
  AddTransaction(this.transaction);
}

class UpdateTransactionStatus extends TransactionEvent {
  final int id;
  final String status;
  UpdateTransactionStatus(this.id, this.status);
}

class UpdateTransactionItems extends TransactionEvent {
  final int id;
  final List<Map<String, dynamic>> itemsList;
  UpdateTransactionItems(this.id, this.itemsList);
}

class MarkTransactionPaid extends TransactionEvent {
  final int id;
  MarkTransactionPaid(this.id);
}
