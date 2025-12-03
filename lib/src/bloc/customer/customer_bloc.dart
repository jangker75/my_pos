import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:my_pos/src/models/customer.dart';
import 'package:my_pos/src/repository/customer_repository.dart';

part 'customer_event.dart';
part 'customer_state.dart';

class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  final CustomerRepository repo;
  CustomerBloc({required this.repo}) : super(CustomerLoading()) {
    on<LoadCustomers>((event, emit) async {
      debugPrint('CustomerBloc: LoadCustomers start');
      emit(CustomerLoading());
      final customers = await repo.getAll();
      debugPrint('CustomerBloc: LoadCustomers got ${customers.length} customers');
      emit(CustomerLoaded(customers));
    });

    on<ReplaceCustomers>((event, emit) async {
      debugPrint('CustomerBloc: ReplaceCustomers start with ${event.customers.length} customers');
      emit(CustomerLoading());
      await repo.replaceAll(event.customers);
      final customers = await repo.getAll();
      debugPrint('CustomerBloc: ReplaceCustomers got ${customers.length} customers');
      emit(CustomerLoaded(customers));
    });
  }
}
