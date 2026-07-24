import 'models.dart';

/// Sample lists created on first launch so the Home screen shows real
/// progress states immediately. All of it is ordinary user data — rename,
/// edit, or swipe away freely.
List<PackingList> buildSeedLists() {
  PackCategory category(String name, String? icon, List<(String, bool)> items) =>
      PackCategory(
        id: newId(),
        name: name,
        icon: icon,
        items: [
          for (final (name, checked) in items)
            Item(id: newId(), name: name, checked: checked),
        ],
      );

  return [
    PackingList(
      id: newId(),
      name: 'Hawaii Vacation',
      icon: '🏖️',
      categories: [
        category('Clothes', null, [
          ('T-shirts', false),
          ('Swimsuit', false),
          ('Shorts', false),
          ('Sunglasses', false),
          ('Rash guard', false),
          ('Hat', false),
          ('Sandals', true),
          ('Pajamas', true),
        ]),
        category('Toiletries', '🧴', [
          ('Sunscreen', false),
          ('Toothbrush', false),
          ('Razor', false),
          ('Contact solution', false),
          ('Toothpaste', true),
          ('Deodorant', true),
          ('Shampoo bar', true),
          ('Floss', true),
        ]),
        category('Documents', null, [
          ('Passport', false),
          ('Boarding passes', true),
          ('Travel insurance', true),
        ]),
        category('Electronics', null, [
          ('Phone charger', true),
          ('Power bank', true),
          ('Camera', true),
          ('Headphones', true),
        ]),
      ],
    ),
    PackingList(
      id: newId(),
      name: 'Ski Trip',
      icon: '🎿',
      categories: [
        category('Clothes', null, [
          ('Ski jacket', false),
          ('Ski pants', false),
          ('Base layers', false),
          ('Gloves', false),
          ('Goggles', false),
          ('Helmet', false),
          ('Neck warmer', false),
          ('Wool socks', false),
        ]),
        category('Gear', null, [
          ('Skis', false),
          ('Poles', false),
          ('Ski boots', false),
          ('Ski pass', false),
        ]),
        category('Toiletries', '🧴', [
          ('Lip balm', false),
          ('Sunscreen', false),
          ('Moisturizer', false),
        ]),
      ],
    ),
    PackingList(
      id: newId(),
      name: 'Camping Weekend',
      icon: '🏕️',
      categories: [
        category('Shelter', null, [
          ('Tent', true),
          ('Sleeping bag', true),
          ('Sleeping pad', true),
          ('Headlamp', true),
        ]),
        category('Kitchen', null, [
          ('Camp stove', true),
          ('Fuel', true),
          ('Lighter', true),
          ('Cook set', true),
          ('Cooler', true),
        ]),
        category('Clothes', null, [
          ('Rain jacket', true),
          ('Fleece', true),
          ('Hiking boots', true),
        ]),
      ],
    ),
    PackingList(
      id: newId(),
      name: 'Weekend in NYC',
      icon: '🎒',
      categories: [
        category('Essentials', null, [
          ('Wallet', true),
          ('Keys', true),
          ('Phone charger', true),
          ('Umbrella', false),
          ('MetroCard', false),
        ]),
        category('Clothes', null, [
          ('Jacket', false),
          ('Sneakers', false),
          ('Dress shirt', false),
          ('Jeans', false),
        ]),
      ],
    ),
  ];
}

/// Starter presets so the preset picker and Settings aren't empty on first
/// run. Ordinary data — editable and deletable like anything else.
List<Preset> buildSeedPresets() {
  PackCategory category(String name, String? icon, List<String> items) =>
      PackCategory(
        id: newId(),
        name: name,
        icon: icon,
        items: [for (final itemName in items) Item(id: newId(), name: itemName)],
      );

  return [
    Preset(
      id: newId(),
      name: 'Toiletries',
      icon: '🧴',
      categories: [
        category('Toiletries', '🧴', [
          'Toothbrush',
          'Toothpaste',
          'Deodorant',
          'Razor',
          'Shampoo',
          'Body wash',
          'Floss',
          'Moisturizer',
          'Nail clippers',
        ]),
      ],
    ),
    Preset(
      id: newId(),
      name: 'Tech & Chargers',
      icon: '🔌',
      categories: [
        category('Electronics', '🔌', [
          'Phone charger',
          'Power bank',
          'Charging cables',
          'Wall adapter',
          'Headphones',
          'Laptop & charger',
        ]),
      ],
    ),
    Preset(
      id: newId(),
      name: 'Beach Gear',
      icon: '🏖️',
      categories: [
        category('Beach', '⛱️', [
          'Swimsuit',
          'Beach towel',
          'Sunscreen',
          'Sunglasses',
          'Flip flops',
          'Beach bag',
          'Water bottle',
        ]),
      ],
    ),
  ];
}
