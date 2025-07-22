import 'package:equatable/equatable.dart';
import '../../models/product_model.dart';

abstract class CartEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AddToCart extends CartEvent {
  final Product product;

  AddToCart(this.product);

  @override
  List<Object?> get props => [product];
}

class RemoveFromCart extends CartEvent {
  final Product product;

  RemoveFromCart(this.product);

  @override
  List<Object?> get props => [product];
}

class ClearCart extends CartEvent {
  final int billId;

  ClearCart({required this.billId});

  @override
  List<Object?> get props => [billId];
}
