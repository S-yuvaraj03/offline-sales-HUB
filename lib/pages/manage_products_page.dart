import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';

class ManageProductsPage extends StatefulWidget {
  const ManageProductsPage({super.key});

  @override
  State<ManageProductsPage> createState() => _ManageProductsPageState();
}

class _ManageProductsPageState extends State<ManageProductsPage> {
  List<Category> categories = [];
  List<Product> allProducts = [];

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    final catList = await DBHelper().getCategories();
    final prodList = await DBHelper().getProducts();
    setState(() {
      categories = catList;
      allProducts = prodList;
    });
  }

  Future<void> addCategoryDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Category"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Category name"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await DBHelper().insertCategory(name);
                await loadAll();
              }
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Future<void> addProductDialog({Product? existingProduct}) async {
    final nameCtrl = TextEditingController(text: existingProduct?.name ?? '');
    final priceCtrl =
        TextEditingController(text: existingProduct?.price.toString() ?? '');
    final costCtrl =
        TextEditingController(text: existingProduct?.cost.toString() ?? '');

    Category? selectedCat = existingProduct != null
        ? categories.firstWhere((c) => c.id == existingProduct.categoryId)
        : null;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setStateDialog) {
        return AlertDialog(
          title: Text(existingProduct == null ? "Add Product" : "Edit Product"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<Category>(
                isExpanded: true,
                hint: const Text("Select Category"),
                value: selectedCat,
                items: categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat.name),
                  );
                }).toList(),
                onChanged: (val) => setStateDialog(() => selectedCat = val),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Product name"),
              ),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Selling Price"),
              ),
              TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Cost Price"),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (selectedCat == null ||
                    nameCtrl.text.isEmpty ||
                    priceCtrl.text.isEmpty ||
                    costCtrl.text.isEmpty) return;

                final product = Product(
                  id: existingProduct?.id,
                  name: nameCtrl.text.trim(),
                  price: double.parse(priceCtrl.text),
                  cost: double.parse(costCtrl.text),
                  categoryId: selectedCat!.id!,
                );

                if (existingProduct == null) {
                  await DBHelper().insertProduct(product);
                } else {
                  await DBHelper().updateProduct(product);
                }

                await loadAll();
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      }),
    );
  }

  Future<void> deleteProduct(int id) async {
    await DBHelper().deleteProduct(id);
    await loadAll();
  }

  Future<void> deleteCategory(int id) async {
    await DBHelper().deleteCategory(id);
    await loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text("Product Management"),
        actions: [
          IconButton(
              onPressed: addCategoryDialog,
              icon: const Icon(Icons.add),
              tooltip: "Add Category")
        ],
      ),
      body: categories.isEmpty
          ? const Center(child: Text("No categories yet"))
          : ListView(
              children: categories.map((cat) {
                final products =
                    allProducts.where((p) => p.categoryId == cat.id).toList();

                return ExpansionTile(
                  title: Text(cat.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => deleteCategory(cat.id!),
                  ),
                  children: [
                    ...products.map((prod) => ListTile(
                          title: Text(prod.name),
                          subtitle: Text("₹${prod.price.toStringAsFixed(2)}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () =>
                                    addProductDialog(existingProduct: prod),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => deleteProduct(prod.id!),
                              ),
                            ],
                          ),
                        )),
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text("Add Product"),
                      onTap: () => addProductDialog(),
                    )
                  ],
                );
              }).toList(),
            ),
    );
  }
}
