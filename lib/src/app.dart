import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'ui/transaction_list_page.dart';
import 'theme.dart';
import 'bloc/product/product_bloc.dart';
import 'bloc/customer/customer_bloc.dart';
import 'bloc/transaction/transaction_bloc.dart';
import 'repository/product_repository.dart';
import 'repository/customer_repository.dart';
import 'repository/transaction_repository.dart';
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ProductBloc>(
          create: (_) => ProductBloc(repo: ProductRepository()),
        ),
        BlocProvider<CustomerBloc>(
          create: (_) => CustomerBloc(repo: CustomerRepository()),
        ),
        BlocProvider<TransactionBloc>(
          create: (_) => TransactionBloc(repo: TransactionRepository()),
        ),
      ],
      child: ResponsiveSizer(
        builder: (context, orientation, screenType) {
          return MaterialApp(
            title: 'My POS',
            theme: AppTheme.lightTheme,
            home: TransactionListPage(),
          );
        },
      ),
    );
  }
}
