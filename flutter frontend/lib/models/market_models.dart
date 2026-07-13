class StockQuote {
  final String symbol;
  final String name;
  final String logo;
  final double price;
  final double change;
  final double changePercent;
  final String currency;
  final double? open;
  final double? high;
  final double? low;
  final double? volume;

  const StockQuote({
    required this.symbol,
    required this.name,
    required this.logo,
    required this.price,
    required this.change,
    required this.changePercent,
    this.currency = 'EUR',
    this.open,
    this.high,
    this.low,
    this.volume,
  });

  bool get isUp => change >= 0;

  String get formattedPrice {
    final sym = currency == 'USD' ? '\$' : currency == 'GBP' ? '£' : currency == 'TRY' ? '₺' : '€';
    return '$sym${price.toStringAsFixed(2)}';
  }

  String get formattedChange {
    final sign = change >= 0 ? '+' : '';
    return '$sign${changePercent.toStringAsFixed(2)}%';
  }

  factory StockQuote.fromMarketstack(Map<String, dynamic> json, {String? displayName}) {
    final close = (json['close'] as num?)?.toDouble() ?? 0;
    final open = (json['open'] as num?)?.toDouble() ?? close;
    final change = close - open;
    final changePct = open != 0 ? (change / open) * 100 : 0.0;
    final symbol = json['symbol'] as String? ?? '';

    return StockQuote(
      symbol: symbol,
      name: displayName ?? symbol,
      logo: symbol.length >= 3 ? symbol.substring(0, 3).toUpperCase() : symbol.toUpperCase(),
      price: close,
      change: change,
      changePercent: changePct,
      open: open,
      high: (json['high'] as num?)?.toDouble(),
      low: (json['low'] as num?)?.toDouble(),
      volume: (json['volume'] as num?)?.toDouble(),
    );
  }
}

class ChartPoint {
  final DateTime date;
  final double value;

  const ChartPoint({required this.date, required this.value});
}

class NewsItem {
  final String title;
  final String category;
  final String timeAgo;
  final String relatedSymbol;

  const NewsItem({
    required this.title,
    required this.category,
    required this.timeAgo,
    required this.relatedSymbol,
  });
}

class MarketRegion {
  final String country;
  final String countryCode;
  final String label;
  final List<String> symbols;
  final List<String> names;
  final String currency;

  const MarketRegion({
    required this.country,
    required this.countryCode,
    required this.label,
    required this.symbols,
    required this.names,
    required this.currency,
  });

  static const regions = {
    'DE': MarketRegion(
      country: 'Germany',
      countryCode: 'DE',
      label: 'Top Movers Germany',
      symbols: ['ENR.XETRA', 'SAP.XETRA', 'TSLA'],
      names: ['Siemens Energy AG', 'SAP SE', 'Tesla Inc.'],
      currency: 'EUR',
    ),
    'US': MarketRegion(
      country: 'United States',
      countryCode: 'US',
      label: 'Top Movers USA',
      symbols: ['AAPL', 'TSLA', 'MSFT'],
      names: ['Apple Inc.', 'Tesla Inc.', 'Microsoft Corp.'],
      currency: 'USD',
    ),
    'GB': MarketRegion(
      country: 'United Kingdom',
      countryCode: 'GB',
      label: 'Top Movers UK',
      symbols: ['HSBA.LSE', 'BP.LSE', 'VOD.LSE'],
      names: ['HSBC Holdings', 'BP plc', 'Vodafone Group'],
      currency: 'GBP',
    ),
    'TR': MarketRegion(
      country: 'Turkey',
      countryCode: 'TR',
      label: 'Top Movers Turkey',
      symbols: ['THYAO.IS', 'ASELS.IS', 'GARAN.IS'],
      names: ['Turkish Airlines', 'Aselsan', 'Garanti BBVA'],
      currency: 'TRY',
    ),
  };

  static MarketRegion forCountryCode(String? code) {
    if (code == null) return regions['DE']!;
    final upper = code.toUpperCase();
    return regions[upper] ?? regions['DE']!;
  }
}
