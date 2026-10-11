import 'package:praticos/models/device.dart';

/// A model the company already registered, with the brand and category that
/// came with it.
class DeviceSuggestion {
  const DeviceSuggestion({
    required this.name,
    this.manufacturer,
    this.category,
    this.count = 1,
  });

  final String name;
  final String? manufacturer;
  final String? category;

  /// How many registered devices share this model (used to rank).
  final int count;

  /// "Fiat · Carro" (brand and category, whichever exist).
  String? get detail {
    final parts = [
      if (manufacturer?.isNotEmpty ?? false) manufacturer!,
      if (category?.isNotEmpty ?? false) category!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// Model suggestions for the new-vehicle form, derived from the company's own
/// devices (no extra collection): distinct by name + brand + category, ranked
/// by how many devices share them, filtered by [query] (case-insensitive,
/// matches the name or the brand). Empty [query] returns nothing.
List<DeviceSuggestion> deviceSuggestions(
  Iterable<Device> devices,
  String query, {
  int limit = 5,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];

  final counts = <String, int>{};
  final firstSeen = <String, Device>{};
  for (final d in devices) {
    final name = d.name?.trim() ?? '';
    if (name.isEmpty) continue;
    final key = [name, d.manufacturer?.trim(), d.category?.trim()]
        .map((e) => (e ?? '').toLowerCase())
        .join('|');
    counts[key] = (counts[key] ?? 0) + 1;
    firstSeen.putIfAbsent(key, () => d);
  }

  final result = <DeviceSuggestion>[];
  counts.forEach((key, count) {
    final d = firstSeen[key]!;
    final name = d.name!.trim();
    final brand = d.manufacturer?.trim() ?? '';
    if (!name.toLowerCase().contains(q) && !brand.toLowerCase().contains(q)) {
      return;
    }
    result.add(DeviceSuggestion(
      name: name,
      manufacturer: brand.isEmpty ? null : brand,
      category: (d.category?.trim().isEmpty ?? true) ? null : d.category!.trim(),
      count: count,
    ));
  });

  result.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    return byCount != 0 ? byCount : a.name.compareTo(b.name);
  });
  return result.take(limit).toList();
}
