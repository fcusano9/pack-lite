import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_lite/models.dart';
import 'package:pack_lite/store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reorderCategories moves a category to a new position', () async {
    final store = AppStore();
    await store.load();
    store.lists
      ..clear()
      ..add(PackingList(
        id: 'L',
        name: 'Trip',
        icon: '🧳',
        categories: [
          PackCategory(id: 'a', name: 'Clothes'),
          PackCategory(id: 'b', name: 'Gear'),
          PackCategory(id: 'c', name: 'Toiletries'),
        ],
      ));

    // Move "Clothes" from the top to the end.
    store.reorderCategories('L', 0, 2);

    final order = store.byId('L')!.categories.map((category) => category.id);
    expect(order, ['b', 'c', 'a']);
  });
}
