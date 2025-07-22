import 'package:equatable/equatable.dart';
import '../../models/category_model.dart';

abstract class CategoryState extends Equatable {
  @override
  List<Object?> get props => [];
}

class CategoryInitial extends CategoryState {}

class CategoryLoaded extends CategoryState {
  final List<Category> categories;

  CategoryLoaded(this.categories);

  @override
  List<Object?> get props => [categories];
}
