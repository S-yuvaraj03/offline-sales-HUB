import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../models/cart_item_model.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  List<Category> categories = [];
  Category? selectedCategory;

  List<Product> allProducts = [];
  List<Product> filteredProducts = [];
  Map<int, int> productStockMap = {}; // productId -> stock

  List<CartItem> cartItems = [];

  double get total => cartItems.fold(0, (sum, item) => sum + item.total);

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final db = DBHelper();
    final cats = await db.getCategories();
    final prods = await db.getProducts();
    final stockMap = <int, int>{};

    for (final p in prods) {
      final stock = await db.getStock(p.id!);
      stockMap[p.id!] = stock;
    }

    setState(() {
      categories = cats;
      allProducts = prods;
      productStockMap = stockMap;
      selectedCategory = cats.isNotEmpty ? cats.first : null;
      filterProductsByCategory();
    });
  }

  void filterProductsByCategory() {
    if (selectedCategory == null) {
      filteredProducts = [];
    } else {
      filteredProducts = allProducts
          .where((p) => p.categoryId == selectedCategory!.id)
          .toList();
    }
  }

  void addToCart(Product product) {
    final stock = productStockMap[product.id] ?? 0;
    final index = cartItems.indexWhere((item) => item.product.id == product.id);
    final currentQty = index != -1 ? cartItems[index].quantity : 0;

    if (stock <= currentQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Only $stock in stock")),
      );
      return;
    }

    setState(() {
      if (index >= 0) {
        cartItems[index].quantity += 1;
      } else {
        cartItems.add(CartItem(product: product, quantity: 1));
      }
    });
  }

  void removeFromCart(Product product) {
    final index = cartItems.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      setState(() {
        cartItems[index].quantity -= 1;
        if (cartItems[index].quantity <= 0) {
          cartItems.removeAt(index);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text("Sales"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadData,
          )
        ],
      ),
      body: Column(
        children: [
          // 🧭 Category Dropdown
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButton<Category>(
              isExpanded: true,
              value: selectedCategory,
              hint: const Text("Select Category"),
              items: categories
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat.name),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value;
                  filterProductsByCategory();
                });
              },
            ),
          ),

          // 🧃 Product Grid
          Expanded(
            flex: 2,
            child: filteredProducts.isEmpty
                ? const Center(child: Text("No products"))
                : GridView.count(
                    crossAxisCount: 3,
                    padding: const EdgeInsets.all(8),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.2,
                    children: filteredProducts.map((product) {
                      final stock = productStockMap[product.id] ?? 0;
                      return GestureDetector(
                        onTap: stock > 0 ? () => addToCart(product) : null,
                        child: Card(
                          color: stock > 0 ? Colors.white : Colors.grey[300],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(product.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text("₹${product.price.toStringAsFixed(2)}"),
                              const SizedBox(height: 4),
                              Text(
                                stock > 0 ? "Stock: $stock" : "Out of Stock",
                                style: TextStyle(
                                  color: stock > 0 ? Colors.green : Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),

          // 🛒 Cart
          Expanded(
            flex: 3,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text("Order Summary",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: cartItems.isEmpty
                      ? const Center(child: Text("No items added"))
                      : ListView.builder(
                          itemCount: cartItems.length,
                          itemBuilder: (_, index) {
                            final item = cartItems[index];
                            return ListTile(
                              title: Text(item.product.name),
                              subtitle: Text(
                                  "₹${item.product.price.toStringAsFixed(2)}"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: () =>
                                        removeFromCart(item.product),
                                  ),
                                  Text("${item.quantity}"),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () => addToCart(item.product),
                                  ),
                                ],
                              ),
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
        ],
      ),
    );
  }
}
