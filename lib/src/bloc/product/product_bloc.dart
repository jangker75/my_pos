import 'package:bloc/bloc.dart';
import '../../repository/product_repository.dart';
import '../../models/product.dart';

part 'product_event.dart';
part 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final ProductRepository repo;

  ProductBloc({required this.repo}) : super(ProductLoading()) {
    on<LoadProducts>((event, emit) async {
      emit(ProductLoading());
      final products = await repo.getAll();
      emit(ProductLoaded(products));
    });

    on<ReplaceProducts>((event, emit) async {
      await repo.replaceAll(event.products);
      add(LoadProducts());
    });
  }
}
