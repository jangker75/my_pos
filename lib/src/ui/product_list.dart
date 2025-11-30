import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import '../models/product.dart';

class ProductList extends StatelessWidget {
  final List<Product> products;
  final Function(Product) onSelect;

  ProductList({required this.products, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 1.1),
      itemCount: products.length,
      itemBuilder: (context, idx) {
        final p = products[idx];
        return Padding(
          padding: const EdgeInsets.all(4.0),
          child: ElevatedButton(
            onPressed: () => onSelect(p),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(p.name, textAlign: TextAlign.center),
                Text('Rp ${p.price.toStringAsFixed(0)}', style: TextStyle(fontSize: 16.sp),)
              ],
            ),
          ),
        );
      },
    );
  }
}
