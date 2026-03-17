import 'package:flutter/material.dart';

class IconHelper {
  static const Map<String, IconData> iconMap = {
    // defaults
    'default': Icons.category,

    // Finance / General
    'wallet': Icons.wallet,
    'savings': Icons.savings,
    'bank': Icons.account_balance,
    'credit_card': Icons.credit_card,
    'money': Icons.attach_money,

    // Expenses
    'food': Icons.fastfood,
    'restaurant': Icons.restaurant,
    'coffee': Icons.coffee,
    'shopping': Icons.shopping_cart,
    'bag': Icons.shopping_bag,
    'transport': Icons.directions_car,
    'bike': Icons.two_wheeler,
    'train': Icons.train,
    'gas': Icons.local_gas_station,
    'home': Icons.home,
    'utilities': Icons.lightbulb,
    'water': Icons.water_drop,
    'wifi': Icons.wifi,
    'phone': Icons.phone_android,
    'health': Icons.medical_services,
    'pharmacy': Icons.local_pharmacy,
    'education': Icons.school,
    'book': Icons.menu_book,
    'entertaiment': Icons.movie,
    'music': Icons.music_note,
    'sports': Icons.sports_soccer,
    'gift': Icons.card_giftcard,
    'pets': Icons.pets,
    'travel': Icons.flight,

    // Income
    'salary': Icons.work,
    'business': Icons.store,
    'investment': Icons.trending_up,
    'bonus': Icons.star,
    'award': Icons.emoji_events,
  };

  static IconData getIcon(String key) {
    return iconMap[key] ?? Icons.help_outline;
  }

  static String getKey(IconData icon) {
    // Reverse lookup (inefficient but safe for small map)
    var entry = iconMap.entries.firstWhere(
      (element) => element.value == icon,
      orElse: () => const MapEntry('default', Icons.category),
    );
    return entry.key;
  }
}
