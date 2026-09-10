import 'package:shelfwise/core/domain/stock_status.dart';

/// Preview copy. The app's own screens are localised through ARB fragments
/// owned by each feature agent; these strings only exist to make the mock look
/// like a real store in both languages.
class MockStrings {
  const MockStrings(this.languageCode);

  final String languageCode;
  bool get _ar => languageCode == 'ar';

  String get dashboardTitle => _ar ? 'اليوم' : 'Today';
  String get productsTitle => _ar ? 'المنتجات' : 'Products';
  String get kpiProducts => _ar ? 'منتج' : 'Products';
  String get kpiLow => _ar ? 'مخزون منخفض' : 'Low stock';
  String get kpiOut => _ar ? 'نفد المخزون' : 'Out of stock';
  String get kpiValue => _ar ? 'قيمة المخزون' : 'Stock value';
  String get needsAttention => _ar ? 'يحتاج انتباهك' : 'Needs attention';
  String get viewAll => _ar ? 'عرض الكل' : 'View all';
  String get searchHint => _ar ? 'ابحث باسم أو باركود' : 'Search name or barcode';
  String get addProduct => _ar ? 'منتج جديد' : 'New product';
  String get receiveStock => _ar ? 'استلام بضاعة' : 'Receive stock';
  String get inStock => _ar ? 'المتاح' : 'In stock';
  String get all => _ar ? 'الكل' : 'All';

  List<String> get categories => _ar
      ? const ['الكل', 'بقالة', 'ألبان', 'مشروبات']
      : const ['All', 'Grocery', 'Dairy', 'Drinks'];
}

/// One row in the mocked product list.
class MockProduct {
  const MockProduct({
    required this.nameEn,
    required this.nameAr,
    required this.priceMinor,
    required this.qtyMilli,
    required this.reorderPointMilli,
  });

  final String nameEn;
  final String nameAr;
  final int priceMinor;
  final int qtyMilli;
  final int reorderPointMilli;

  String name(String languageCode) => languageCode == 'ar' ? nameAr : nameEn;

  StockStatus get status =>
      StockStatus.of(qtyMilli: qtyMilli, reorderPointMilli: reorderPointMilli);
}

const mockProducts = <MockProduct>[
  MockProduct(
    nameEn: 'Basmati rice 5 kg',
    nameAr: 'أرز بسمتي 5 كجم',
    priceMinor: 24500,
    qtyMilli: 3000,
    reorderPointMilli: 6000,
  ),
  MockProduct(
    nameEn: 'Sunflower oil 1 L',
    nameAr: 'زيت دوار الشمس 1 لتر',
    priceMinor: 8900,
    qtyMilli: 0,
    reorderPointMilli: 12000,
  ),
  MockProduct(
    nameEn: 'Full-fat milk 1 L',
    nameAr: 'حليب كامل الدسم 1 لتر',
    priceMinor: 3250,
    qtyMilli: 48000,
    reorderPointMilli: 20000,
  ),
  MockProduct(
    nameEn: 'Tomato paste 400 g',
    nameAr: 'صلصة طماطم 400 جم',
    priceMinor: 2150,
    qtyMilli: 7000,
    reorderPointMilli: 10000,
  ),
  MockProduct(
    nameEn: 'White sugar 1 kg',
    nameAr: 'سكر أبيض 1 كجم',
    priceMinor: 4100,
    qtyMilli: 96000,
    reorderPointMilli: 24000,
  ),
];
