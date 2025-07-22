import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/cart_item_model.dart';
import 'cart_event.dart';
import 'cart_state.dart';
import '../../db/db_helper.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  final dbHelper = DBHelper();

  CartBloc() : super(const CartState()) {
    on<AddToCart>(_onAddToCart);
    on<RemoveFromCart>(_onRemoveFromCart);
    on<ClearCart>(_onClearCart);
  }

  void _onAddToCart(AddToCart event, Emitter<CartState> emit) {
    final items = List<CartItem>.from(state.items);
    final index =
        items.indexWhere((item) => item.product.id == event.product.id);

    if (index != -1) {
      items[index].quantity += 1;
    } else {
      items.add(CartItem(product: event.product, quantity: 1));
    }

    emit(CartState(items: items));
  }

  void _onRemoveFromCart(RemoveFromCart event, Emitter<CartState> emit) {
    final items = List<CartItem>.from(state.items);
    items.removeWhere((item) => item.product.id == event.product.id);
    emit(CartState(items: items));
  }

  void _onClearCart(ClearCart event, Emitter<CartState> emit) async {
    for (final item in state.items) {
      await dbHelper.insertOrder(
        productId: item.product.id!,
        quantity: item.quantity,
        billId: event.billId, // ✅ Corrected usage
      );
    }
    emit(const CartState(items: []));
  }
}
