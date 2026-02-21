import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import '../models/category_model.dart';
import 'package:flutter/services.dart';

class ManualBillingPage extends StatefulWidget {
  const ManualBillingPage({super.key});

  @override
  State<ManualBillingPage> createState() => _ManualBillingPageState();
}

class _ManualBillingPageState extends State<ManualBillingPage> {
  List<Product> allProducts = [];
  List<Category> categories = [];
  List<CartItem> selectedItems = [];
  static const MethodChannel _printerChannel =
      MethodChannel('com.example.juice_shop/printer');

  Category? selectedCategory;
  Product? selectedProduct;
  int selectedQty = 1;

  double get total => selectedItems.fold(0, (sum, item) => sum + item.total);
  double get profit => selectedItems.fold(0, (sum, item) => sum + item.profit);

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  Map<int, int> productStockMap = {}; // productId -> stock

  Future<void> loadInitialData() async {
    final products = await DBHelper().getProducts();
    final cats = await DBHelper().getCategories();

    final stockMap = <int, int>{};
    for (final product in products) {
      final stock = await DBHelper().getStock(product.id!);
      stockMap[product.id!] = stock;
    }

    setState(() {
      allProducts = products;
      categories = cats;
      productStockMap = stockMap;
    });
  }

  List<Product> get filteredProducts {
    if (selectedCategory == null) return [];
    return allProducts
        .where((p) =>
            p.categoryId == selectedCategory!.id &&
            (productStockMap[p.id] ?? 0) > 0)
        .toList();
  }

  void addItem() {
    if (selectedProduct == null) return;

    final stock = productStockMap[selectedProduct!.id] ?? 0;
    final alreadyInCart = selectedItems.firstWhere(
        (item) => item.product.id == selectedProduct!.id,
        orElse: () => CartItem(product: selectedProduct!, quantity: 0));

    final availableStock = stock - alreadyInCart.quantity;

    if (selectedQty > availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Only $availableStock in stock")),
      );
      return;
    }

    final index = selectedItems
        .indexWhere((item) => item.product.id == selectedProduct!.id);

    setState(() {
      if (index >= 0) {
        selectedItems[index].quantity += selectedQty;
      } else {
        selectedItems.add(CartItem(
          product: selectedProduct!,
          quantity: selectedQty,
        ));
      }
      selectedProduct = null;
      selectedQty = 1;
    });
  }

  Future<Map<String, String>?> getPaymentDetailsDialog() async {
    String? selectedMethod;
    String? selectedUpiApp;

    return await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Select Payment Method"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text("Cash"),
                    value: "cash",
                    groupValue: selectedMethod,
                    onChanged: (val) =>
                        setDialogState(() => selectedMethod = val),
                  ),
                  RadioListTile<String>(
                    title: const Text("UPI"),
                    value: "upi",
                    groupValue: selectedMethod,
                    onChanged: (val) =>
                        setDialogState(() => selectedMethod = val),
                  ),
                  if (selectedMethod == "upi") ...[
                    const Divider(),
                    const Text("Select UPI App"),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedUpiApp,
                      hint: const Text("Choose App"),
                      items: ["GPay", "PhonePe", "Paytm"]
                          .map((app) => DropdownMenuItem(
                                value: app,
                                child: Text(app),
                              ))
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => selectedUpiApp = val),
                    ),
                  ]
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () {
                    if (selectedMethod == null) return;
                    if (selectedMethod == "upi" && selectedUpiApp == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Select a UPI app")));
                      return;
                    }
                    Navigator.pop(context, {
                      'method': selectedMethod!,
                      'upi': selectedUpiApp ?? '',
                    });
                  },
                  child: const Text("Continue"),
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<void> receivePayment() async {
    if (selectedItems.isEmpty) return;

    final paymentInfo = await getPaymentDetailsDialog();
    if (paymentInfo == null) return;

    final paymentMethod = paymentInfo['method']!;
    final upiApp = paymentInfo['upi'];

    final timestamp = DateTime.now();
    final billNo = "BILL-${timestamp.millisecondsSinceEpoch}";
    final kotNo = "KOT: ${await DBHelper().getNextKOTNumber()}";

    final billId = await DBHelper().insertBill(
      billNo: billNo,
      kotNo: kotNo,
      total: total,
      profit: profit,
      paymentStatus: "Received",
      paymentMethod: paymentMethod,
      upiApp: paymentMethod == "upi" ? upiApp : null,
    );

    for (final item in selectedItems) {
      await DBHelper().insertBillItem(
        billId: billId,
        productName: item.product.name,
        quantity: item.quantity,
        price: item.product.price,
      );

      await DBHelper().insertOrder(
        productId: item.product.id!,
        quantity: item.quantity,
        billId: billId,
      );

      await DBHelper().updateStockAfterSale(
        item.product.id!,
        item.quantity,
      );
    }

    final double paymentAmount = total;
    await printTotal(paymentAmount);

    setState(() => selectedItems.clear());

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Payment Received"),
          content: Text(
            "Amount: ₹${paymentAmount.toStringAsFixed(2)}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Payment recorded successfully")),
      );
    }
  }

  Future<void> holdBill() async {
    for (final item in selectedItems) {
      await DBHelper().insertHeldItem(
        productId: item.product.id!,
        quantity: item.quantity,
      );
    }
    setState(() => selectedItems.clear());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bill held successfully")),
      );
    }
  }

  Future<void> resumeHeldBills() async {
    final held = await DBHelper().getHeldItems();
    final resumedItems = <CartItem>[];

    for (final item in held) {
      final product = allProducts.firstWhere((p) => p.id == item['productId']);
      final qty = item['quantity'] as int;
      resumedItems.add(CartItem(product: product, quantity: qty));
    }

    await DBHelper().clearHeldItems();

    setState(() => selectedItems = resumedItems);
  }

  Future<void> printTotal(double total) async {
    final text = "\x1B\x61\x01" // Center
        "\x1B\x21\x10" // Bold
        "JUICE SHOP\n\n"
        "\x1B\x21\x00"
        "TOTAL AMOUNT\n"
        "\x1B\x21\x20"
        "₹${total.toStringAsFixed(2)}\n\n\n";

    try {
      await _printerChannel.invokeMethod(
        'printText',
        {'text': text},
      );
    } catch (e) {
      debugPrint("Print failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text("Manual Billing"),
        actions: [
          IconButton(
            icon: const Icon(Icons.pause_circle),
            tooltip: "Resume Held Bill",
            onPressed: resumeHeldBills,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<Category>(
                    value: selectedCategory,
                    isExpanded: true,
                    hint: const Text("Select Category"),
                    items: categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedCategory = val;
                        selectedProduct = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButton<Product>(
                    isExpanded: true,
                    hint: const Text("Select Product"),
                    value: selectedProduct,
                    items: filteredProducts.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text(p.name),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => selectedProduct = value),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: selectedQty,
                  items: List.generate(10, (i) => i + 1)
                      .map((q) =>
                          DropdownMenuItem(value: q, child: Text(q.toString())))
                      .toList(),
                  onChanged: (val) => setState(() => selectedQty = val ?? 1),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: addItem,
                  child: const Text("Add"),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(),
            const Text("Bill Items",
                style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: selectedItems.isEmpty
                  ? const Center(child: Text("No items added"))
                  : ListView.builder(
                      itemCount: selectedItems.length,
                      itemBuilder: (_, i) {
                        final item = selectedItems[i];
                        return ListTile(
                          title: Text(item.product.name),
                          subtitle: Text("Qty: ${item.quantity}"),
                          trailing: Text("₹${item.total.toStringAsFixed(2)}"),
                        );
                      },
                    ),
            ),
            ListTile(
              title: const Text("Total"),
              trailing: Text("₹${total.toStringAsFixed(2)}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.pause),
                label: const Text("Hold Bill"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: selectedItems.isEmpty ? null : holdBill,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.payment),
                label: const Text("Receive Payment"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: selectedItems.isEmpty ? null : receivePayment,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
