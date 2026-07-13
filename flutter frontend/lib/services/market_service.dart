import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../config/api_config.dart';
import '../models/market_models.dart';

class MarketService {
  bool get _hasApiKey =>
      marketstackApiKey.isNotEmpty &&
      marketstackApiKey != 'YOUR_MARKETSTACK_API_KEY';

  Future<List<StockQuote>> fetchLatestQuotes(MarketRegion region) async {
    if (!_hasApiKey) {
      return _demoQuotes(region);
    }

    try {
      final symbols = region.symbols.join(',');
      final uri = Uri.parse(
        '$marketstackBaseUrl/eod/latest?access_key=$marketstackApiKey&symbols=$symbols',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final list = data['data'] as List<dynamic>? ?? [];
        if (list.isEmpty) return _demoQuotes(region);

        return List.generate(list.length, (i) {
          final item = list[i] as Map<String, dynamic>;
          final name = i < region.names.length ? region.names[i] : null;
          final quote = StockQuote.fromMarketstack(item, displayName: name);
          return StockQuote(
            symbol: quote.symbol,
            name: quote.name,
            logo: quote.logo,
            price: quote.price,
            change: quote.change,
            changePercent: quote.changePercent,
            currency: region.currency,
            open: quote.open,
            high: quote.high,
            low: quote.low,
            volume: quote.volume,
          );
        });
      }
    } catch (_) {
      // Fall through to demo data.
    }
    return _demoQuotes(region);
  }

  Future<List<ChartPoint>> fetchHistorical(
    String symbol, {
    int days = 30,
  }) async {
    if (!_hasApiKey) return _demoChart(days);

    try {
      final to = DateTime.now();
      final from = to.subtract(Duration(days: days));
      final fmt = DateFormat('yyyy-MM-dd');
      final uri = Uri.parse(
        '$marketstackBaseUrl/eod?access_key=$marketstackApiKey'
        '&symbols=$symbol'
        '&date_from=${fmt.format(from)}'
        '&date_to=${fmt.format(to)}'
        '&limit=$days'
        '&sort=ASC',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final list = data['data'] as List<dynamic>? ?? [];
        if (list.isNotEmpty) {
          return list
              .map((e) {
                final m = e as Map<String, dynamic>;
                return ChartPoint(
                  date: DateTime.parse(m['date'] as String),
                  value: (m['close'] as num).toDouble(),
                );
              })
              .toList();
        }
      }
    } catch (_) {}
    return _demoChart(days);
  }

  List<StockQuote> _demoQuotes(MarketRegion region) {
    const demos = {
      'DE': [
        (18.24, 2.34, 'ENR.XETRA', 'Siemens Energy AG', 'SIE'),
        (213.65, 1.85, 'SAP.XETRA', 'SAP SE', 'SAP'),
        (178.24, -1.23, 'TSLA', 'Tesla Inc.', 'TSL'),
      ],
      'US': [
        (189.50, 1.12, 'AAPL', 'Apple Inc.', 'AAP'),
        (178.24, -1.23, 'TSLA', 'Tesla Inc.', 'TSL'),
        (415.20, 0.88, 'MSFT', 'Microsoft Corp.', 'MSF'),
      ],
      'GB': [
        (6.82, 0.45, 'HSBA.LSE', 'HSBC Holdings', 'HSB'),
        (4.95, -0.32, 'BP.LSE', 'BP plc', 'BP'),
        (0.72, 1.10, 'VOD.LSE', 'Vodafone Group', 'VOD'),
      ],
      'TR': [
        (285.50, 2.10, 'THYAO.IS', 'Turkish Airlines', 'THY'),
        (58.30, -0.85, 'ASELS.IS', 'Aselsan', 'ASE'),
        (98.75, 1.45, 'GARAN.IS', 'Garanti BBVA', 'GAR'),
      ],
    };

    final key = region.countryCode;
    final items = demos[key] ?? demos['DE']!;

    return items
        .map(
          (d) => StockQuote(
            symbol: d.$3,
            name: d.$4,
            logo: d.$5,
            price: d.$1,
            change: d.$1 * d.$2 / 100,
            changePercent: d.$2,
            currency: region.currency,
            open: d.$1 * 0.99,
            high: d.$1 * 1.02,
            low: d.$1 * 0.97,
            volume: 3200000,
          ),
        )
        .toList();
  }

  List<ChartPoint> _demoChart(int days) {
    final now = DateTime.now();
    var price = 17.5;
    return List.generate(days, (i) {
      price += (i % 5 - 2) * 0.08 + 0.05;
      return ChartPoint(
        date: now.subtract(Duration(days: days - i)),
        value: price,
      );
    });
  }

  List<NewsItem> newsForRegion(MarketRegion region) {
    return [
      NewsItem(
        title: '${region.names.first} wins major contract in ${region.country}',
        category: 'Market',
        timeAgo: '2h ago',
        relatedSymbol: region.symbols.first,
      ),
      NewsItem(
        title: '${region.names.length > 1 ? region.names[1] : 'Market'} launches new AI-powered suite',
        category: 'Stocks',
        timeAgo: '4h ago',
        relatedSymbol: region.symbols.length > 1 ? region.symbols[1] : region.symbols.first,
      ),
      NewsItem(
        title: 'Central bank policy update impacts ${region.label}',
        category: 'Economy',
        timeAgo: '6h ago',
        relatedSymbol: region.symbols.first,
      ),
      NewsItem(
        title: 'Tech sector rally continues across ${region.country}',
        category: 'Stocks',
        timeAgo: '8h ago',
        relatedSymbol: region.symbols.last,
      ),
    ];
  }
}
