import 'package:equatable/equatable.dart';
import '../../models/cart_item_model.dart';

class CartState extends Equatable {
  final List<CartItem> items;

  const CartState({this.items = const []});

  double get total =>
      items.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity));

  double get profit =>
      items.fold(0.0, (sum, item) => sum + item.profit);

  int get totalItems =>
      items.fold(0, (sum, item) => sum + item.quantity);

  @override
  List<Object?> get props => [items];
}
