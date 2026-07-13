import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/market_models.dart';
import '../services/location_service.dart';
import '../services/market_service.dart';

class AppProvider extends ChangeNotifier {
  AppProvider({
    LocationService? locationService,
    MarketService? marketService,
  })  : _locationService = locationService ?? LocationService(),
        _marketService = marketService ?? MarketService();

  final LocationService _locationService;
  final MarketService _marketService;

  bool loading = true;
  String? countryCode;
  String countryName = 'Germany';
  MarketRegion region = MarketRegion.regions['DE']!;
  List<StockQuote> stocks = [];
  List<NewsItem> news = [];
  String selectedCurrency = 'EUR';
  bool isPro = false;
  String? userEmail;

  static const _currencyRates = {
    'EUR': 1.0,
    'USD': 1.08,
    'GBP': 0.86,
    'TRY': 34.5,
  };

  Future<void> initialize({String? manualCountryCode}) async {
    loading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    isPro = prefs.getBool('isPro') ?? false;
    userEmail = prefs.getString('userEmail');
    selectedCurrency = prefs.getString('currency') ?? 'EUR';

    countryCode = manualCountryCode ?? await _locationService.getCountryCode();
    region = MarketRegion.forCountryCode(countryCode);
    countryName = region.country;
    selectedCurrency = region.currency;

    stocks = await _marketService.fetchLatestQuotes(region);
    news = _marketService.newsForRegion(region);

    loading = false;
    notifyListeners();
  }

  Future<void> setCountry(String code) async {
    countryCode = code;
    region = MarketRegion.forCountryCode(code);
    countryName = region.country;
    selectedCurrency = region.currency;
    stocks = await _marketService.fetchLatestQuotes(region);
    news = _marketService.newsForRegion(region);
    notifyListeners();
  }

  Future<void> setCurrency(String currency) async {
    selectedCurrency = currency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', currency);
    notifyListeners();
  }

  double convertPrice(double amount, {String? from}) {
    final base = from ?? region.currency;
    final inEur = amount / (_currencyRates[base] ?? 1);
    return inEur * (_currencyRates[selectedCurrency] ?? 1);
  }

  String currencySymbol() {
    switch (selectedCurrency) {
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      case 'TRY':
        return '₺';
      default:
        return '€';
    }
  }

  Future<void> signIn(String email) async {
    userEmail = email;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userEmail', email);
    notifyListeners();
  }

  Future<void> upgradeToPro() async {
    isPro = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPro', true);
    notifyListeners();
  }

  Future<List<ChartPoint>> chartFor(String symbol, {int days = 30}) {
    return _marketService.fetchHistorical(symbol, days: days);
  }
}
