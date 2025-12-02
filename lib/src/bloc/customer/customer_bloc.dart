import 'package:bloc/bloc.dart';
import 'package:my_pos/src/models/customer.dart';
import 'package:my_pos/src/repository/customer_repository.dart';

part 'customer_event.dart';
part 'customer_state.dart';

class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  final CustomerRepository repo;
  CustomerBloc({required this.repo}) : super(CustomerLoading()) {
    on<LoadCustomers>((event, emit) async {
      emit(CustomerLoading());
      final customers = await repo.getAll();
      emit(CustomerLoaded(customers));
    });

    on<ReplaceCustomers>((event, emit) async {
      await repo.replaceAll(event.customers);
      add(LoadCustomers());
    });
  }
}
