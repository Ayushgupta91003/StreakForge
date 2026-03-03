import 'package:isar/isar.dart';
import 'package:streak_forge/features/habits/data/models/category.dart';

class CategoryRepository {
  final Isar _isar;

  CategoryRepository(this._isar);

  Future<List<Category>> getAll() async {
    return await _isar.categorys.where().sortByOrder().findAll();
  }

  Future<Category?> getById(int id) async {
    return await _isar.categorys.get(id);
  }

  Future<int> save(Category category) async {
    return await _isar.writeTxn(() async {
      return await _isar.categorys.put(category);
    });
  }

  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.categorys.delete(id);
    });
  }

  Stream<void> watchAll() {
    return _isar.categorys.watchLazy();
  }
}
