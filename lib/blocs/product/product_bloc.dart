import 'package:flutter_bloc/flutter_bloc.dart';
import '../../db/db_helper.dart';
import 'product_event.dart';
import 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final dbHelper = DBHelper();

  ProductBloc() : super(ProductInitial()) {
    on<LoadProducts>(_onLoadProducts);
    on<AddProduct>(_onAddProduct);
    on<UpdateProduct>(_onUpdateProduct);
    on<DeleteProduct>(_onDeleteProduct);
  }

  void _onLoadProducts(LoadProducts event, Emitter<ProductState> emit) async {
    final products = await dbHelper.getProducts();
    emit(ProductLoaded(products));
  }

  void _onAddProduct(AddProduct event, Emitter<ProductState> emit) async {
    await dbHelper.insertProduct(event.product);
    add(LoadProducts());
  }

  void _onUpdateProduct(UpdateProduct event, Emitter<ProductState> emit) async {
    await dbHelper.updateProduct(event.product);
    add(LoadProducts());
  }

  void _onDeleteProduct(DeleteProduct event, Emitter<ProductState> emit) async {
    await dbHelper.deleteProduct(event.productId);
    add(LoadProducts());
  }
}

