part of 'customer_bloc.dart';

abstract class CustomerEvent {}

class LoadCustomers extends CustomerEvent {}

class ReplaceCustomers extends CustomerEvent {
  final List<Customer> customers;
  ReplaceCustomers(this.customers);
}
