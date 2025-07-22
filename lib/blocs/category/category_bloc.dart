import 'package:flutter_bloc/flutter_bloc.dart';
import '../../db/db_helper.dart';
import 'category_event.dart';
import 'category_state.dart';

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final dbHelper = DBHelper();

  CategoryBloc() : super(CategoryInitial()) {
    on<LoadCategories>(_onLoadCategories);
    on<AddCategory>(_onAddCategory);
    on<UpdateCategory>(_onUpdateCategory);
    on<DeleteCategory>(_onDeleteCategory);
  }

  void _onLoadCategories(LoadCategories event, Emitter<CategoryState> emit) async {
    final categories = await dbHelper.getCategories();
    emit(CategoryLoaded(categories));
  }

  void _onAddCategory(AddCategory event, Emitter<CategoryState> emit) async {
    await dbHelper.insertCategory(event.name);
    add(LoadCategories());
  }

  void _onUpdateCategory(UpdateCategory event, Emitter<CategoryState> emit) async {
    await dbHelper.updateCategory(event.category);
    add(LoadCategories());
  }

  void _onDeleteCategory(DeleteCategory event, Emitter<CategoryState> emit) async {
    await dbHelper.deleteCategory(event.id);
    add(LoadCategories());
  }
}
