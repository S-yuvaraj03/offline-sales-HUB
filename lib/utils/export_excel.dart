import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../db/db_helper.dart';

Future<void> exportOrdersToExcel(BuildContext context) async {
  final status = await Permission.storage.request();
  if (!status.isGranted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Storage permission denied')),
    );
    return;
  }

  final dbHelper = DBHelper();
  final orders = await dbHelper.getOrdersWithBillDetails();

  final excel = Excel.createExcel();

  // Ensure a valid sheet exists and the default one is removed if unused
  const String sheetName = 'Orders';
  excel.delete('Sheet1'); // Remove default if not needed
  final Sheet sheet = excel[sheetName];

  // ✅ Header row
  sheet.appendRow([
    'Bill No',
    'KOT No',
    'Product Name',
    'Quantity',
    'Unit Price',
    'Total',
    'Order Date',
    'Payment Method',
    'UPI App',
  ]);

  // ✅ Data rows
  for (final order in orders) {
    final productName = order['name']?.toString() ?? '';
    final quantity = (order['quantity'] ?? 0) is int
        ? order['quantity'] as int
        : int.tryParse(order['quantity'].toString()) ?? 0;
    final price = (order['price'] ?? 0) is double
        ? order['price'] as double
        : double.tryParse(order['price'].toString()) ?? 0.0;
    final total = price * quantity;

    final billNo = order['billNo'] ?? '';
    final kotNo = order['kotNo'] ?? '';
    final date = order['date'] ?? '';
    final paymentMethod =
        (order['paymentMethod'] ?? '').toString().toUpperCase();
    final upiApp = order['upiApp'] ?? '';

    // 👇 Make sure data is not skipped due to nulls
    sheet.appendRow([
      billNo,
      kotNo,
      productName,
      quantity,
      price.toStringAsFixed(2),
      total.toStringAsFixed(2),
      date,
      paymentMethod,
      upiApp,
    ]);
  }

  // ✅ Save Excel file
  final dir = await getExternalStorageDirectory();
  if (dir == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Unable to access storage directory")),
    );
    return;
  }

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final filePath = '${dir.path}/juice_orders_$timestamp.xlsx';
  final file = File(filePath);

  // 👇 Save bytes
  final encoded = excel.encode();
  if (encoded == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Failed to encode Excel data")),
    );
    return;
  }

  await file.writeAsBytes(encoded);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Exported to: $filePath')),
  );
}
