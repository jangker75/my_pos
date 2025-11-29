part of 'product_bloc.dart';

abstract class ProductEvent {}

class LoadProducts extends ProductEvent {}

class ReplaceProducts extends ProductEvent {
  final List<Product> products;
  ReplaceProducts(this.products);
}
