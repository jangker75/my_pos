part of 'customer_bloc.dart';

abstract class CustomerState {}

class CustomerLoading extends CustomerState {}

class CustomerLoaded extends CustomerState {
  final List<Customer> Customers;
  CustomerLoaded(this.Customers);
}
