/// A pharmacy's numbers (`chemist_dashboard()`): sales, orders, stock
/// health and what to restock.
class ChemistDashboard {
  const ChemistDashboard({
    this.salesToday = 0,
    this.salesWeek = 0,
    this.salesMonth = 0,
    this.salesPrevMonth = 0,
    this.released = 0,
    this.held = 0,
    this.ordersToday = 0,
    this.ordersMonth = 0,
    this.waiting = 0,
    this.preparing = 0,
    this.ready = 0,
    this.disputed = 0,
    this.daily = const [],
    this.listed = 0,
    this.inStock = 0,
    this.low = 0,
    this.out = 0,
    this.stockValue = 0,
    this.top = const [],
    this.lowStock = const [],
    this.outOfStock = const [],
    this.slow = const [],
  });

  final double salesToday;
  final double salesWeek;
  final double salesMonth;
  final double salesPrevMonth;

  /// Paid out to the pharmacy (patients confirmed) in the last 30 days.
  final double released;

  /// Waiting for patients to confirm they got their medicine.
  final double held;

  final int ordersToday;
  final int ordersMonth;
  final int waiting;
  final int preparing;
  final int ready;
  final int disputed;

  /// The last 14 days, oldest first.
  final List<DaySales> daily;

  final int listed;
  final int inStock;
  final int low;
  final int out;
  final double stockValue;

  /// Best sellers in the last 30 days.
  final List<StockStat> top;

  /// Running low: few left, or selling fast enough to run out within a week.
  final List<StockStat> lowStock;

  /// Listed but none left, most wanted first.
  final List<StockStat> outOfStock;

  /// In stock but not sold in 30 days (money sitting on the shelf).
  final List<StockStat> slow;

  int get openOrders => waiting + preparing + ready;

  double get averageOrder => ordersMonth == 0 ? 0 : salesMonth / ordersMonth;

  /// Change against the 30 days before, e.g. 0.12 for +12%; null when
  /// there's nothing to compare with.
  double? get trend => salesPrevMonth <= 0
      ? null
      : (salesMonth - salesPrevMonth) / salesPrevMonth;

  factory ChemistDashboard.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> part(String k) =>
        (j[k] as Map?)?.cast<String, dynamic>() ?? const {};
    double d(Map<String, dynamic> m, String k) =>
        (m[k] as num?)?.toDouble() ?? 0;
    int n(Map<String, dynamic> m, String k) => (m[k] as num?)?.toInt() ?? 0;
    List<StockStat> list(String k) => [
      for (final e in (j[k] as List?) ?? const [])
        StockStat.fromJson((e as Map).cast<String, dynamic>()),
    ];
    final revenue = part('revenue');
    final orders = part('orders');
    final stock = part('stock');
    return ChemistDashboard(
      salesToday: d(revenue, 'today'),
      salesWeek: d(revenue, 'week'),
      salesMonth: d(revenue, 'month'),
      salesPrevMonth: d(revenue, 'prev_month'),
      released: d(revenue, 'released'),
      held: d(revenue, 'held'),
      ordersToday: n(orders, 'today'),
      ordersMonth: n(orders, 'month'),
      waiting: n(orders, 'waiting'),
      preparing: n(orders, 'preparing'),
      ready: n(orders, 'ready'),
      disputed: n(orders, 'disputed'),
      daily: [
        for (final e in (j['daily'] as List?) ?? const [])
          DaySales.fromJson((e as Map).cast<String, dynamic>()),
      ],
      listed: n(stock, 'listed'),
      inStock: n(stock, 'in_stock'),
      low: n(stock, 'low'),
      out: n(stock, 'out'),
      stockValue: d(stock, 'value'),
      top: list('top'),
      lowStock: list('low_stock'),
      outOfStock: list('out_of_stock'),
      slow: list('slow'),
    );
  }
}

class DaySales {
  const DaySales({required this.day, this.revenue = 0, this.orders = 0});

  final DateTime day;
  final double revenue;
  final int orders;

  factory DaySales.fromJson(Map<String, dynamic> j) => DaySales(
    day: DateTime.parse(j['day'] as String),
    revenue: (j['revenue'] as num?)?.toDouble() ?? 0,
    orders: (j['orders'] as num?)?.toInt() ?? 0,
  );
}

/// One medicine in a dashboard list.
class StockStat {
  const StockStat({
    required this.drugId,
    required this.name,
    this.quantity = 0,
    this.units = 0,
    this.revenue = 0,
    this.value = 0,
    this.daysLeft,
    this.lastSold,
    this.since,
  });

  final String drugId;
  final String name;
  final int quantity;

  /// Units sold in the last 30 days.
  final int units;
  final double revenue;

  /// Stock value (quantity × price).
  final double value;

  /// Days until it runs out at the current pace.
  final int? daysLeft;
  final DateTime? lastSold;

  /// When the stock row last changed (for "out since").
  final DateTime? since;

  factory StockStat.fromJson(Map<String, dynamic> j) {
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v) : null;
    return StockStat(
      drugId: j['drug_id'] as String,
      name: (j['name'] as String?) ?? 'Medicine',
      quantity: (j['quantity'] as num?)?.toInt() ?? 0,
      units: ((j['units'] ?? j['units_30d']) as num?)?.toInt() ?? 0,
      revenue: (j['revenue'] as num?)?.toDouble() ?? 0,
      value: (j['value'] as num?)?.toDouble() ?? 0,
      daysLeft: (j['days_left'] as num?)?.toInt(),
      lastSold: date(j['last_sold']),
      since: date(j['since']),
    );
  }
}
