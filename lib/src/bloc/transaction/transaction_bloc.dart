import 'package:bloc/bloc.dart';
import '../../repository/transaction_repository.dart';
import '../../models/transaction_model.dart';

part 'transaction_event.dart';
part 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final TransactionRepository repo;

  TransactionBloc({required this.repo}) : super(TransactionLoading()) {
    on<LoadTransactions>((event, emit) async {
      emit(TransactionLoading());
      final tx = await repo.getActive();
      emit(TransactionLoaded(tx));
    });

    on<AddTransaction>((event, emit) async {
      await repo.insert(event.transaction);
      add(LoadTransactions());
    });

    on<UpdateTransactionItems>((event, emit) async {
      await repo.updateItems(event.id, event.itemsList);
      add(LoadTransactions());
    });

    on<MarkTransactionPaid>((event, emit) async {
      await repo.markPaid(event.id);
      add(LoadTransactions());
    });

    on<UpdateTransactionStatus>((event, emit) async {
      await repo.updateStatus(event.id, event.status);
      add(LoadTransactions());
    });
  }
}
