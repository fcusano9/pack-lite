import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_lite/models.dart';
import 'package:pack_lite/store.dart';

/// A duplicate is made to be packed again, so it must start fully unpacked
/// (issue #27) — while leaving the original's progress untouched.
PackingList _packedList() => PackingList(
      id: 'source',
      name: 'Ski Trip',
      icon: '🎿',
      items: [
        Item(id: 'loose-packed', name: 'Passport', checked: true),
        Item(id: 'loose-open', name: 'Goggles'),
      ],
      categories: [
        PackCategory(id: 'c1', name: 'Clothes', items: [
          Item(id: 'cat-packed', name: 'Jacket', checked: true),
          Item(id: 'cat-open', name: 'Gloves'),
        ]),
      ],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppStore> storeWithSource() async {
    final store = AppStore();
    await store.load();
    store.lists
      ..clear()
      ..add(_packedList());
    return store;
  }

  test('the duplicate starts with nothing packed', () async {
    final store = await storeWithSource();
    expect(store.lists.first.packedItems, 2); // sanity: source is part-packed

    final copy = store.duplicateList('source')!;

    expect(copy.packedItems, 0);
    expect(copy.totalItems, 4, reason: 'items are copied, only ticks cleared');
    // Both buckets must be cleared, not just the loose one.
    expect(copy.items.every((item) => !item.checked), isTrue);
    expect(copy.categories.first.items.every((item) => !item.checked), isTrue);
  });

  test('duplicating leaves the original list packed as it was', () async {
    final store = await storeWithSource();

    store.duplicateList('source');

    final source = store.byId('source')!;
    expect(source.packedItems, 2);
    expect(source.items.first.checked, isTrue);
    expect(source.categories.first.items.first.checked, isTrue);
  });

  test('the duplicate is independent of the original', () async {
    final store = await storeWithSource();
    final copy = store.duplicateList('source')!;

    // Re-packing the copy must not tick the source back up.
    copy.items.first.checked = true;

    expect(store.byId('source')!.items.first.checked, isTrue);
    expect(copy.id, isNot('source'));
    expect(copy.name, 'Ski Trip copy');
    expect(store.lists.indexOf(copy), 1, reason: 'inserted below the original');
  });

  test('uncheckAll on the store still clears a live list', () async {
    final store = await storeWithSource();

    store.uncheckAll('source');

    expect(store.byId('source')!.packedItems, 0);
  });
}
