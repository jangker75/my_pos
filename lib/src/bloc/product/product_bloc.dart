import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import '../../repository/product_repository.dart';
import '../../models/product.dart';

part 'product_event.dart';
part 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final ProductRepository repo;

  ProductBloc({required this.repo}) : super(ProductLoading()) {
    on<LoadProducts>((event, emit) async {
      debugPrint('ProductBloc: LoadProducts start');
      emit(ProductLoading());
      final products = await repo.getAll();
      debugPrint('ProductBloc: LoadProducts got ${products.length} products');
      emit(ProductLoaded(products));
    });

    on<ReplaceProducts>((event, emit) async {
      debugPrint('ProductBloc: ReplaceProducts start with ${event.products.length} products');
      emit(ProductLoading());
      await repo.replaceAll(event.products);
      debugPrint('ProductBloc: ReplaceProducts - replaceAll done, fetching...');
      final products = await repo.getAll();
      debugPrint('ProductBloc: ReplaceProducts got ${products.length} products');
      emit(ProductLoaded(products));
      debugPrint('ProductBloc: ReplaceProducts complete');
    });
  }
}
