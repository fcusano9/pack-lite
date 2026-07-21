import 'models.dart';

/// Sample lists created on first launch so the Home screen shows real
/// progress states immediately. All of it is ordinary user data — rename,
/// edit, or swipe away freely.
List<PackingList> buildSeedLists() {
  PackCategory cat(String name, String? icon, List<(String, bool)> items) =>
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
        cat('Clothes', null, [
          ('T-shirts', false),
          ('Swimsuit', false),
          ('Shorts', false),
          ('Sunglasses', false),
          ('Rash guard', false),
          ('Hat', false),
          ('Sandals', true),
          ('Pajamas', true),
        ]),
        cat('Toiletries', '🧴', [
          ('Sunscreen', false),
          ('Toothbrush', false),
          ('Razor', false),
          ('Contact solution', false),
          ('Toothpaste', true),
          ('Deodorant', true),
          ('Shampoo bar', true),
          ('Floss', true),
        ]),
        cat('Documents', null, [
          ('Passport', false),
          ('Boarding passes', true),
          ('Travel insurance', true),
        ]),
        cat('Electronics', null, [
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
        cat('Clothes', null, [
          ('Ski jacket', false),
          ('Ski pants', false),
          ('Base layers', false),
          ('Gloves', false),
          ('Goggles', false),
          ('Helmet', false),
          ('Neck warmer', false),
          ('Wool socks', false),
        ]),
        cat('Gear', null, [
          ('Skis', false),
          ('Poles', false),
          ('Ski boots', false),
          ('Ski pass', false),
        ]),
        cat('Toiletries', '🧴', [
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
        cat('Shelter', null, [
          ('Tent', true),
          ('Sleeping bag', true),
          ('Sleeping pad', true),
          ('Headlamp', true),
        ]),
        cat('Kitchen', null, [
          ('Camp stove', true),
          ('Fuel', true),
          ('Lighter', true),
          ('Cook set', true),
          ('Cooler', true),
        ]),
        cat('Clothes', null, [
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
        cat('Essentials', null, [
          ('Wallet', true),
          ('Keys', true),
          ('Phone charger', true),
          ('Umbrella', false),
          ('MetroCard', false),
        ]),
        cat('Clothes', null, [
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
  PackCategory cat(String name, String? icon, List<String> items) =>
      PackCategory(
        id: newId(),
        name: name,
        icon: icon,
        items: [for (final n in items) Item(id: newId(), name: n)],
      );

  return [
    Preset(
      id: newId(),
      name: 'Toiletries',
      icon: '🧴',
      categories: [
        cat('Toiletries', '🧴', [
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
        cat('Electronics', '🔌', [
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
        cat('Beach', '⛱️', [
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
