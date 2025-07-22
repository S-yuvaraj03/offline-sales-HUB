class Product {
  final int? id;
  final String name;
  final double price;
  final double cost;
  final int categoryId;

  Product({
    this.id,
    required this.name,
    required this.price,
    required this.cost,
    required this.categoryId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'cost': cost,
        'categoryId': categoryId,
      };

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      cost: map['cost'],
      categoryId: map['categoryId'],
    );
  }
}
