/// Pricing tiers from the business plan (Shelf / Aisle / Chain).
enum Tier {
  shelf,
  aisle,
  chain;

  static Tier? tryParse(String? name) {
    for (final t in Tier.values) {
      if (t.name == name) return t;
    }
    return null;
  }
}
