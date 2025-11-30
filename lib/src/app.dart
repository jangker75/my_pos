import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'ui/transaction_list_page.dart';
import 'theme.dart';
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ResponsiveSizer(
      builder: (context, orientation, screenType) {
        return MaterialApp(
          title: 'My POS',
          theme: AppTheme.lightTheme,
          home: TransactionListPage(),
        );
      },
    );
  }
}
