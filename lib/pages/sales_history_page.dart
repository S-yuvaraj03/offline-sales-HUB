import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/export_excel.dart';
import '../db/db_helper.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  List<Map<String, dynamic>> bills = [];
  double totalSales = 0;
  double totalProfit = 0;

  DateTime? fromDate;
  DateTime? toDate;
  String selectedPaymentMethod = 'All';

  @override
  void initState() {
    super.initState();
    loadBills();
  }

  Future<void> loadBills() async {
    final result = await DBHelper().getAllBills();

    double sales = 0;
    double profit = 0;

    final filtered = result.where((bill) {
      final billDate =
          DateTime.tryParse(bill['timestamp'] ?? '') ?? DateTime.now();

      // Filter by payment method
      final matchesPayment = selectedPaymentMethod == 'All' ||
          bill['paymentMethod'] == selectedPaymentMethod.toLowerCase();

      // Filter by date
      final matchesDate = (fromDate == null ||
              billDate.isAfter(fromDate!.subtract(const Duration(days: 1)))) &&
          (toDate == null ||
              billDate.isBefore(toDate!.add(const Duration(days: 1))));

      return matchesPayment && matchesDate;
    }).toList();

    for (var bill in filtered) {
      sales += (bill['total'] as num).toDouble();
      profit += (bill['profit'] as num).toDouble();
    }

    setState(() {
      bills = filtered;
      totalSales = sales;
      totalProfit = profit;
    });
  }

  Future<void> showBillItems(int billId, String billNo) async {
    final items = await DBHelper().getBillItems(billId);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Items for $billNo'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: items.map((item) {
              final qty = item['quantity'] as int;
              final price = item['price'] as num;
              final total = qty * price;
              return ListTile(
                title: Text(item['productName']),
                subtitle: Text("Qty: $qty × ₹${price.toStringAsFixed(2)}"),
                trailing: Text("₹${total.toStringAsFixed(2)}"),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget buildBillTile(Map<String, dynamic> bill) {
    final date = DateTime.tryParse(bill['timestamp'] ?? '');
    final paymentMethod = bill['paymentMethod'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text("Bill No: ${bill['billNo']}"),
        subtitle: Text(
          "KOT: ${bill['kotNo']}\n"
          "Date: ${date != null ? DateFormat('yyyy-MM-dd – hh:mm a').format(date) : 'N/A'}\n"
          "Received via: ${paymentMethod.toUpperCase()}",
          maxLines: 3,
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              bill['paymentStatus'] ?? "Pending",
              style: TextStyle(
                color: bill['paymentStatus'] == "Received"
                    ? Colors.green
                    : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text("₹${bill['total']}", style: const TextStyle(fontSize: 12)),
          ],
        ),
        onTap: () => showBillItems(bill['id'], bill['billNo']),
      ),
    );
  }

  Future<void> selectDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: fromDate != null && toDate != null
          ? DateTimeRange(start: fromDate!, end: toDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        fromDate = picked.start;
        toDate = picked.end;
      });
      await loadBills();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text("Sales History"),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download Excel',
            onPressed: () => exportOrdersToExcel(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(fromDate != null && toDate != null
                        ? "${DateFormat('MMM dd').format(fromDate!)} - ${DateFormat('MMM dd').format(toDate!)}"
                        : "Select Date"),
                    onPressed: selectDateRange,
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: selectedPaymentMethod,
                  items: const ['All', 'Cash', 'UPI']
                      .map((method) => DropdownMenuItem(
                            value: method,
                            child: Text(method),
                          ))
                      .toList(),
                  onChanged: (val) {
                    setState(() => selectedPaymentMethod = val!);
                    loadBills();
                  },
                ),
              ],
            ),
          ),
          Card(
            margin: const EdgeInsets.all(12),
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text("Total Sales: ₹${totalSales.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: bills.isEmpty
                ? const Center(child: Text("No sales recorded"))
                : ListView.builder(
                    itemCount: bills.length,
                    itemBuilder: (_, i) => buildBillTile(bills[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
