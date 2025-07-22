import 'package:equatable/equatable.dart';
import '../../models/product_model.dart';

abstract class ProductEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadProducts extends ProductEvent {}

class AddProduct extends ProductEvent {
  final Product product;

  AddProduct(this.product);

  @override
  List<Object?> get props => [product];
}

class UpdateProduct extends ProductEvent {
  final Product product;

  UpdateProduct(this.product);

  @override
  List<Object?> get props => [product];
}

class DeleteProduct extends ProductEvent {
  final int productId;

  DeleteProduct(this.productId);

  @override
  List<Object?> get props => [productId];
}
