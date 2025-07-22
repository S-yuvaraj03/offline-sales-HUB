import 'package:equatable/equatable.dart';
import '../../models/category_model.dart';

abstract class CategoryEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadCategories extends CategoryEvent {}

class AddCategory extends CategoryEvent {
  final String name;

  AddCategory(this.name);

  @override
  List<Object?> get props => [name];
}

class UpdateCategory extends CategoryEvent {
  final Category category;

  UpdateCategory(this.category);

  @override
  List<Object?> get props => [category];
}

class DeleteCategory extends CategoryEvent {
  final int id;

  DeleteCategory(this.id);

  @override
  List<Object?> get props => [id];
}

