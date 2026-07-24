import '../core/supabase.dart';

/// Typed models for the Supabase data layer.
///
/// Field names deliberately mirror the keys the existing screens already read from the
/// PHP JSON (`product_name`, `selling_price`, `image_url`, ...) so migrating a screen is
/// a change of *source*, not a rewrite of its widget tree.

class Category {
  Category({
    required this.id,
    required this.name,
    this.nameHi,
    this.nameHn,
    this.image,
  });

  final int id;
  final String name;
  final String? nameHi;
  final String? nameHn;
  final String? image;

  /// Name in the user's language, falling back to English. `name_hn` is romanized
  /// Hinglish, which some users read more comfortably than Devanagari.
  String localizedName(String languageCode) => switch (languageCode) {
        'hi' => nameHi?.isNotEmpty == true ? nameHi! : name,
        'hn' => nameHn?.isNotEmpty == true ? nameHn! : name,
        _ => name,
      };

  String get imageUrl => Db.imageUrl(image);

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: m['id'] as int,
        name: (m['name'] ?? '') as String,
        nameHi: m['name_hi'] as String?,
        nameHn: m['name_hn'] as String?,
        image: m['image'] as String?,
      );
}

class Variant {
  Variant({
    required this.id,
    required this.productId,
    required this.name,
    this.nameHi,
    this.nameHn,
    required this.price,
    required this.sellingPrice,
    required this.stock,
  });

  final int id;
  final int productId;
  final String name;
  final String? nameHi;
  final String? nameHn;

  /// MRP, shown struck through.
  final double price;

  /// What the customer actually pays.
  final double sellingPrice;
  final int stock;

  bool get inStock => stock > 0;

  int get discountPercent =>
      price > 0 && price > sellingPrice
          ? (((price - sellingPrice) / price) * 100).round()
          : 0;

  String localizedName(String languageCode) => switch (languageCode) {
        'hi' => nameHi?.isNotEmpty == true ? nameHi! : name,
        'hn' => nameHn?.isNotEmpty == true ? nameHn! : name,
        _ => name,
      };

  // `wholesale_price` exists on the table but is deliberately not mapped here:
  // DxMart is consumer-only and nothing should read it.

  factory Variant.fromMap(Map<String, dynamic> m) => Variant(
        id: m['id'] as int,
        productId: (m['product_id'] ?? 0) as int,
        name: (m['name'] ?? '') as String,
        nameHi: m['name_hi'] as String?,
        nameHn: m['name_hn'] as String?,
        price: _toDouble(m['price']),
        sellingPrice: _toDouble(m['selling_price']),
        stock: (m['stock'] ?? 0) as int,
      );
}

class Product {
  Product({
    required this.id,
    required this.name,
    this.nameHi,
    this.nameHn,
    required this.description,
    this.descriptionHi,
    this.descriptionHn,
    required this.mainCategoryId,
    required this.types,
    this.images = const [],
    this.variants = const [],
  });

  final int id;
  final String name;
  final String? nameHi;
  final String? nameHn;
  final String description;
  final String? descriptionHi;
  final String? descriptionHn;
  final int mainCategoryId;

  /// Comma-separated tag list carried over from the source schema, e.g.
  /// 'normal,Everyday Essentials,Best selling'.
  final String types;

  final List<String> images;
  final List<Variant> variants;

  List<String> get tags =>
      types.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

  bool hasTag(String tag) =>
      tags.any((t) => t.toLowerCase() == tag.toLowerCase());

  String get primaryImageUrl => images.isEmpty ? '' : Db.imageUrl(images.first);

  List<String> get imageUrls => images.map(Db.imageUrl).toList();

  Variant? get defaultVariant => variants.isEmpty ? null : variants.first;

  String localizedName(String languageCode) => switch (languageCode) {
        'hi' => nameHi?.isNotEmpty == true ? nameHi! : name,
        'hn' => nameHn?.isNotEmpty == true ? nameHn! : name,
        _ => name,
      };

  String localizedDescription(String languageCode) => switch (languageCode) {
        'hi' => descriptionHi?.isNotEmpty == true ? descriptionHi! : description,
        'hn' => descriptionHn?.isNotEmpty == true ? descriptionHn! : description,
        _ => description,
      };

  /// Bridge to the map shape `ProductCard` and the older screens still consume.
  ///
  /// Lets a screen move to typed repository reads without also rewriting the widget
  /// that renders it. `images` holds stored PATHS, not URLs — the card resolves them
  /// through `Db.imageUrl()` at render time.
  Map<String, dynamic> toCardMap() => {
        'id': id,
        'name': name,
        'name_hi': nameHi,
        'name_hn': nameHn,
        'description': description,
        'description_hi': descriptionHi,
        'description_hn': descriptionHn,
        'main_category_id': mainCategoryId,
        'types': types,
        'images': images,
        'variants': variants
            .map((v) => {
                  'id': v.id,
                  'product_id': v.productId,
                  'name': v.name,
                  'name_hi': v.nameHi,
                  'name_hn': v.nameHn,
                  'price': v.price,
                  'selling_price': v.sellingPrice,
                  'stock': v.stock,
                })
            .toList(),
      };

  factory Product.fromMap(Map<String, dynamic> m) {
    final imageRows = (m['product_images'] as List?) ?? const [];
    final variantRows = (m['product_variants'] as List?) ?? const [];
    return Product(
      id: m['id'] as int,
      name: (m['name'] ?? '') as String,
      nameHi: m['name_hi'] as String?,
      nameHn: m['name_hn'] as String?,
      description: (m['description'] ?? '') as String,
      descriptionHi: m['description_hi'] as String?,
      descriptionHn: m['description_hn'] as String?,
      mainCategoryId: (m['main_category_id'] ?? 0) as int,
      types: (m['types'] ?? '') as String,
      images: imageRows
          .map((r) => ((r as Map)['image_url'] ?? '') as String)
          .where((s) => s.isNotEmpty)
          .toList(),
      variants: variantRows
          .map((r) => Variant.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList(),
    );
  }
}

class CartLine {
  CartLine({
    required this.id,
    required this.productId,
    required this.variantId,
    required this.productName,
    required this.variantName,
    required this.price,
    required this.sellingPrice,
    required this.quantity,
    required this.imagePath,
    required this.stock,
  });

  final int id;
  final int productId;
  final int? variantId;
  final String productName;
  final String variantName;
  final double price;
  final double sellingPrice;
  final int quantity;
  final String imagePath;

  /// Live variant stock, so the cart can cap the quantity stepper against what is
  /// actually available rather than letting the user request more than exists.
  final int stock;

  double get lineTotal => sellingPrice * quantity;
  String get imageUrl => Db.imageUrl(imagePath);

  factory CartLine.fromMap(Map<String, dynamic> m) {
    final product = m['products'] as Map?;
    final variant = m['product_variants'] as Map?;
    return CartLine(
      id: m['id'] as int,
      productId: (m['product_id'] ?? 0) as int,
      variantId: m['variant_id'] as int?,
      productName: ((product?['name']) ?? '') as String,
      variantName: ((variant?['name']) ?? '') as String,
      price: _toDouble(variant?['price']),
      sellingPrice: _toDouble(variant?['selling_price']),
      quantity: (m['quantity'] ?? 0) as int,
      imagePath: (m['image_url'] ?? '') as String,
      stock: ((variant?['stock']) ?? 0) as int,
    );
  }

  /// Bridge to the map shape the cart UI still reads.
  Map<String, dynamic> toCartMap() => {
        'id': id,
        'product_id': productId,
        'variant_id': variantId,
        'name': productName,
        'variant_name': variantName,
        'price': price,
        'selling_price': sellingPrice,
        'quantity': quantity,
        'stock': stock,
        // Stored path; resolved to a URL at render time via Db.imageUrl().
        'image_url': imagePath,
      };
}

class Address {
  Address({
    required this.id,
    required this.name,
    required this.phone,
    required this.fullAddress,
    required this.pinCode,
    this.landmark,
  });

  final int id;
  final String name;
  final String phone;
  final String fullAddress;
  final String pinCode;
  final String? landmark;

  // No userId field: the row is only ever reachable if it belongs to the caller.

  factory Address.fromMap(Map<String, dynamic> m) => Address(
        id: m['id'] as int,
        name: (m['name'] ?? '') as String,
        phone: (m['phone'] ?? '') as String,
        fullAddress: (m['full_address'] ?? '') as String,
        pinCode: (m['pin_code'] ?? '') as String,
        landmark: m['landmark'] as String?,
      );

  Map<String, dynamic> toInsert() => {
        'name': name,
        'phone': phone,
        'full_address': fullAddress,
        'pin_code': pinCode,
        'landmark': landmark,
      };
}

class OrderLine {
  OrderLine({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.imagePath,
  });

  final String productName;
  final int quantity;

  /// Null for orders migrated from the old backend, which never recorded a line price.
  final double? unitPrice;
  final String imagePath;

  String get imageUrl => Db.imageUrl(imagePath);

  factory OrderLine.fromMap(Map<String, dynamic> m) => OrderLine(
        productName: (((m['products'] as Map?)?['name']) ?? 'Item') as String,
        quantity: (m['quantity'] ?? 0) as int,
        unitPrice: m['unit_price'] == null ? null : _toDouble(m['unit_price']),
        imagePath: (m['image_url'] ?? '') as String,
      );
}

class Order {
  Order({
    required this.id,
    required this.totalAmount,
    required this.discountAmount,
    required this.deliveryCharge,
    required this.handlingCharge,
    required this.finalAmount,
    required this.status,
    required this.paymentMethod,
    required this.orderedAt,
    this.deliveryDate,
    this.deliveryTimeWindow,
    this.couponCode,
    this.items = const [],
  });

  final int id;
  final double totalAmount;
  final double discountAmount;
  final double deliveryCharge;
  final double handlingCharge;
  final double finalAmount;
  final String status;
  final String paymentMethod;
  final DateTime orderedAt;
  final DateTime? deliveryDate;

  /// A window such as '9 AM - 2 PM', not a time.
  final String? deliveryTimeWindow;
  final String? couponCode;
  final List<OrderLine> items;

  factory Order.fromMap(Map<String, dynamic> m) {
    final itemRows = (m['order_items'] as List?) ?? const [];
    return Order(
      id: m['id'] as int,
      totalAmount: _toDouble(m['total_amount']),
      discountAmount: _toDouble(m['discount_amount']),
      deliveryCharge: _toDouble(m['delivery_charge']),
      handlingCharge: _toDouble(m['handling_charge']),
      finalAmount: _toDouble(m['final_amount']),
      status: (m['status'] ?? 'pending') as String,
      paymentMethod: (m['payment_method'] ?? 'COD') as String,
      orderedAt:
          DateTime.parse(m['order_datetime'] as String).toLocal(),
      deliveryDate: m['delivery_date'] == null
          ? null
          : DateTime.parse(m['delivery_date'] as String),
      deliveryTimeWindow: m['delivery_time_window'] as String?,
      couponCode: m['coupon_code'] as String?,
      items: itemRows
          .map((r) => OrderLine.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList(),
    );
  }
}

class Coupon {
  Coupon({
    required this.id,
    required this.title,
    required this.description,
    required this.codeName,
    required this.discount,
    required this.minAmount,
    this.expiryDate,
  });

  final int id;
  final String title;
  final String description;
  final String codeName;
  final int discount;
  final int minAmount;
  final DateTime? expiryDate;

  factory Coupon.fromMap(Map<String, dynamic> m) => Coupon(
        id: m['id'] as int,
        title: (m['title'] ?? '') as String,
        description: (m['description'] ?? '') as String,
        codeName: (m['code_name'] ?? '') as String,
        discount: (m['discount'] ?? 0) as int,
        minAmount: (m['min_amount'] ?? 0) as int,
        expiryDate: m['expiry_date'] == null
            ? null
            : DateTime.parse(m['expiry_date'] as String),
      );
}

/// Postgres `numeric` arrives as String, int, or double depending on the value, so
/// every money field goes through this rather than a bare cast.
double _toDouble(Object? v) => switch (v) {
      null => 0,
      final num n => n.toDouble(),
      final String s => double.tryParse(s) ?? 0,
      _ => 0,
    };
