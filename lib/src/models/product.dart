import 'package:json_annotation/json_annotation.dart';

part 'product.g.dart';

@JsonSerializable()
class Product {
  final int id;
  final String code;
  final String name;
  final double price;
  final int stock;

  Product(
      {required this.id,
      required this.code,
      required this.name,
      required this.price,
      required this.stock});

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);
}
