import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<Map<String, dynamic>> inventory = [];

  @override
  void initState() {
    super.initState();
    loadInventory();
  }

  Future<void> loadInventory() async {
    final result = await DBHelper().getInventoryWithProductDetails();
    setState(() => inventory = result);
  }

  Future<void> showUpdateDialog(int productId, int currentStock) async {
    final controller = TextEditingController(text: '$currentStock');

    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Update Stock"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "New Stock"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final newStock = int.tryParse(controller.text);
              if (newStock != null) {
                Navigator.pop(context, newStock);
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );

    if (result != null) {
      await DBHelper().setStock(productId, result);
      loadInventory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.orange, title: const Text("Inventory")),
      body: inventory.isEmpty
          ? const Center(child: Text("No inventory found"))
          : ListView.builder(
              itemCount: inventory.length,
              itemBuilder: (_, index) {
                final item = inventory[index];
                final name = item['name'] ?? 'Unnamed';
                final stock = item['stock'] ?? 0;

                return ListTile(
                  title: Text(name),
                  subtitle: Text("Stock: $stock"),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => showUpdateDialog(item['id'], stock),
                  ),
                );
              },
            ),
    );
  }
}
