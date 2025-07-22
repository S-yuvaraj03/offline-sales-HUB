import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';

import 'blocs/cart/cart_bloc.dart';
import 'blocs/category/category_bloc.dart';
import 'blocs/category/category_event.dart';
import 'blocs/product/product_bloc.dart';
import 'blocs/product/product_event.dart';

import 'db/db_helper.dart';
import 'pages/billing_page.dart';
import 'pages/manage_products_page.dart';
import 'pages/splash_screen.dart';
import 'pages/dashboard.dart';
import 'pages/sales_history_page.dart';
import 'pages/sales_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dbPath = await getDatabasesPath();
  final path = join(dbPath, 'juice_pos.db');
  await deleteDatabase(path); // ✅ DELETE OLD DB

  await DBHelper().initDB();

  // Request permission only on Android
  if (Platform.isAndroid) {
    await requestStoragePermission();
    await Permission.camera.request();
  }

  runApp(const POSApp());
}

Future<void> requestStoragePermission() async {
  final status = await Permission.storage.request();

  if (status.isDenied || status.isPermanentlyDenied) {
    await openAppSettings();
  }
}

class POSApp extends StatelessWidget {
  const POSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CartBloc()),
        BlocProvider(create: (_) => CategoryBloc()..add(LoadCategories())),
        BlocProvider(create: (_) => ProductBloc()..add(LoadProducts())),
      ],
      child: MaterialApp(
        title: 'Juice POS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.orange),
        initialRoute: '/',
        routes: {
          '/': (_) => const SplashScreen(),
          '/dashboard': (_) => const DashboardPage(),
          '/sales': (_) => const SalesPage(),
          '/manual-billing': (_) => const ManualBillingPage(),
          '/sales-history': (_) => const SalesHistoryPage(),
          '/manage': (_) => const ManageProductsPage(),
        },
      ),
    );
  }
}
