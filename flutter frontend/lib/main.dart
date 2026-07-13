import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ──────────────────────────────────────────────────────────────────────────────
// ENTRY POINT & THEME NOTIFIER
// ──────────────────────────────────────────────────────────────────────────────
final ValueNotifier<bool> darkModeNotifier = ValueNotifier<bool>(true);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const PulseTradeApp());
}

// ──────────────────────────────────────────────────────────────────────────────
// COLORS & THEME MANAGER
// ──────────────────────────────────────────────────────────────────────────────
class AppColors {
  static const bg = Color(0xFF070D17);
  static const bg2 = Color(0xFF0B1322);
  static const card = Color(0xFF101827);
  static const card2 = Color(0xFF131D2F);
  static const border = Color(0xFF26344C);
  static const green = Color(0xFF9BF285);
  static const green2 = Color(0xFF50D64A);
  static const red = Color(0xFFFF6B6B);
  static const yellow = Color(0xFFF4C84B);
  static const blue = Color(0xFF5F7CFF);
  static const muted = Color(0xFF9AA8BD);
  static const white = Color(0xFFEAF0F7);
}

class ThemeColors {
  final Color bg;
  final Color bg2;
  final Color card;
  final Color card2;
  final Color border;
  final Color text;
  final Color muted;

  const ThemeColors({
    required this.bg,
    required this.bg2,
    required this.card,
    required this.card2,
    required this.border,
    required this.text,
    required this.muted,
  });

  static const dark = ThemeColors(
    bg: Color(
      0x00000000,
    ), // Transparent in dark mode to show FuturisticBackground
    bg2: Color(0xFF081225),
    card: Color(0xCC0F172A), // Sleek semi-translucent dark slate
    card2: Color(0x991E293B), // Sleek semi-translucent card2
    border: Color(0x2494A3B8), // Sleek translucent border (14% opacity)
    text: Color(0xFFF8FAFC),
    muted: Color(0xFF94A3B8),
  );

  static const light = ThemeColors(
    bg: Color(0xFFF4F7FC),
    bg2: Color(0xFFEAEFF8),
    card: Color(0xFFFFFFFF),
    card2: Color(0xFFF9FAFC),
    border: Color(0xFFE2E8F0),
    text: Color(0xFF0F172A),
    muted: Color(0xFF64748B),
  );

  static ThemeColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? dark : light;
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// ENUMS & HELPERS
// ──────────────────────────────────────────────────────────────────────────────
enum AppCurrency { eur, usd, tryc, gbp }

String currencySymbol(AppCurrency c) {
  switch (c) {
    case AppCurrency.eur:
      return '€';
    case AppCurrency.usd:
      return r'$';
    case AppCurrency.tryc:
      return '₺';
    case AppCurrency.gbp:
      return '£';
  }
}

final Map<AppCurrency, double> appExchangeRates = {
  AppCurrency.eur: 1.0,
  AppCurrency.usd: 1.08,
  AppCurrency.tryc: 35.20,
  AppCurrency.gbp: 0.86,
};

double fx(AppCurrency c) {
  return appExchangeRates[c] ?? 1.0;
}

String money(double value, AppCurrency c) {
  final converted = value * fx(c);
  return '${currencySymbol(c)}${converted.toStringAsFixed(2)}';
}

// ──────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ──────────────────────────────────────────────────────────────────────────────
class StockNewsItem {
  final String title;
  final String category;
  final String source;
  final String time;
  final String body;
  final IconData icon;
  const StockNewsItem(
    this.title,
    this.category,
    this.source,
    this.time,
    this.body,
    this.icon,
  );
}

class TradeActivity {
  final String title;
  final String detail;
  final double value;
  final bool positive;
  const TradeActivity(this.title, this.detail, this.value, this.positive);
}

class StockData {
  final String symbol;
  final String name;
  final String exchange;
  final String sector;
  final String industry;
  final String logo;
  final double price;
  final double change;
  final double changePct;
  final String about;
  final String ceo;
  final String employees;
  final String founded;
  final String headquarters;
  final double marketCap;
  final double peRatio;
  final double dividendYield;
  final double revenue;
  final double eps;
  final double beta;
  final double weekHigh;
  final double weekLow;
  final double targetPrice;
  final String rating;
  final String risk;
  final double aiConfidence;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<StockNewsItem> news;
  final Map<String, List<double>> charts;

  const StockData({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.sector,
    required this.industry,
    required this.logo,
    required this.price,
    required this.change,
    required this.changePct,
    required this.about,
    required this.ceo,
    required this.employees,
    required this.founded,
    required this.headquarters,
    required this.marketCap,
    required this.peRatio,
    required this.dividendYield,
    required this.revenue,
    required this.eps,
    required this.beta,
    required this.weekHigh,
    required this.weekLow,
    required this.targetPrice,
    required this.rating,
    required this.risk,
    required this.aiConfidence,
    required this.strengths,
    required this.weaknesses,
    required this.news,
    required this.charts,
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// DEMO DATA
// ──────────────────────────────────────────────────────────────────────────────
Map<String, List<double>> makeCharts(
  double base,
  double trend, {
  bool negative = false,
}) {
  List<double> make(int count, double amp, double t) {
    return List<double>.generate(count, (i) {
      final wave = math.sin(i * 0.85) * amp + math.cos(i * 0.35) * amp * .55;
      final drift = negative ? -i * t : i * t;
      final shock = (i % 5 == 0 ? amp * .9 : 0) - (i % 7 == 0 ? amp * .6 : 0);
      return double.parse((base + wave + drift + shock).toStringAsFixed(2));
    });
  }

  return {
    '1D': make(12, trend * .35, trend * .08),
    '1W': make(18, trend * .55, trend * .11),
    '1M': make(24, trend * .75, trend * .16),
    '3M': make(26, trend * .95, trend * .22),
    '1Y': make(30, trend * 1.25, trend * .35),
  };
}

class IndexInfo {
  final String name, value, change;
  final List<double> chart;
  const IndexInfo(this.name, this.value, this.change, this.chart);
}

const marketIndices = [
  IndexInfo('DAX', '18,236.5', '+1.35%', [1, 1.6, 1.4, 1.9, 1.8, 2.3]),
  IndexInfo('Dow Jones', '39,872.99', '+0.68%', [
    1,
    1.2,
    1.15,
    1.7,
    2.1,
    2.0,
    2.5,
  ]),
  IndexInfo('NASDAQ', '17,192.5', '+0.92%', [
    1,
    1.15,
    1.3,
    1.2,
    1.55,
    1.7,
    2.05,
  ]),
  IndexInfo('S&P 500', '5,278.40', '+1.02%', [
    1,
    .95,
    1.35,
    1.18,
    1.65,
    1.7,
    2.1,
  ]),
];

final List<StockData> demoStocks = [
  StockData(
    symbol: 'ENR.DE',
    name: 'Siemens Energy AG',
    exchange: 'XETRA',
    sector: 'Energy',
    industry: 'Utilities',
    logo: 'SIE',
    price: 18.24,
    change: 0.42,
    changePct: 2.34,
    about:
        'Siemens Energy operates worldwide in power generation, transmission, grid technologies and renewable energy systems. Positioned around electrification, wind power and energy infrastructure modernization.',
    ceo: 'Christian Bruch',
    employees: '98,000+',
    founded: '2020',
    headquarters: 'Munich, Germany',
    marketCap: 14.72,
    peRatio: 21.34,
    dividendYield: 1.24,
    revenue: 29.58,
    eps: 0.85,
    beta: 1.28,
    weekHigh: 21.45,
    weekLow: 13.22,
    targetPrice: 22.80,
    rating: 'Buy',
    risk: 'Medium',
    aiConfidence: 86,
    strengths: [
      'Large energy infrastructure backlog',
      'Strong grid modernization exposure',
      'Improving profitability trend',
    ],
    weaknesses: [
      'Execution risk in wind segment',
      'Sensitive to raw material costs',
      'High project-cycle volatility',
    ],
    news: const [
      StockNewsItem(
        'Siemens Energy wins €2B offshore wind contract',
        'Energy',
        'Pulse Markets',
        '2h ago',
        'The company secured a major offshore wind and grid integration contract.',
        Icons.business_center_outlined,
      ),
      StockNewsItem(
        'Grid technology demand improves order backlog',
        'Market',
        'European Desk',
        '4h ago',
        'Analysts point to higher demand for substations across Europe.',
        Icons.electrical_services_outlined,
      ),
      StockNewsItem(
        'Analysts raise target price after margin recovery',
        'Analyst',
        'Equity Radar',
        'Today',
        'A stronger service mix and cost discipline support the latest target price revision.',
        Icons.trending_up,
      ),
    ],
    charts: {},
  ),
  StockData(
    symbol: 'SAP.DE',
    name: 'SAP SE',
    exchange: 'XETRA',
    sector: 'Software',
    industry: 'Enterprise Cloud',
    logo: 'SAP',
    price: 213.65,
    change: 3.92,
    changePct: 1.85,
    about:
        'SAP is a global enterprise software company focused on ERP, cloud platforms, analytics and AI-powered business applications for large organizations.',
    ceo: 'Christian Klein',
    employees: '108,000+',
    founded: '1972',
    headquarters: 'Walldorf, Germany',
    marketCap: 258.65,
    peRatio: 31.78,
    dividendYield: 1.10,
    revenue: 33.80,
    eps: 6.72,
    beta: 0.92,
    weekHigh: 229.40,
    weekLow: 171.80,
    targetPrice: 235.00,
    rating: 'Buy',
    risk: 'Low-Medium',
    aiConfidence: 89,
    strengths: [
      'Cloud migration momentum',
      'Enterprise customer stickiness',
      'AI suite cross-selling potential',
    ],
    weaknesses: [
      'Valuation premium',
      'Slow public sector cycles',
      'FX sensitivity',
    ],
    news: const [
      StockNewsItem(
        'SAP expands AI-powered business suite',
        'Software',
        'Tech Markets',
        '4h ago',
        'SAP announced new AI capabilities for enterprise workflows.',
        Icons.auto_awesome,
      ),
      StockNewsItem(
        'Cloud revenue keeps accelerating in Europe',
        'Stocks',
        'Cloud Wire',
        'Today',
        'Recurring cloud subscriptions continued to grow.',
        Icons.cloud_outlined,
      ),
      StockNewsItem(
        'Enterprise software demand remains resilient',
        'Economy',
        'DAX Brief',
        'Yesterday',
        'Large companies continue to prioritize digital transformation.',
        Icons.apartment,
      ),
    ],
    charts: {},
  ),
  StockData(
    symbol: 'TSLA',
    name: 'Tesla Inc.',
    exchange: 'NASDAQ',
    sector: 'Automotive',
    industry: 'EV & Energy',
    logo: 'TSL',
    price: 178.24,
    change: -2.21,
    changePct: -1.23,
    about:
        'Tesla designs electric vehicles, energy storage systems, charging infrastructure and software-driven mobility products.',
    ceo: 'Elon Musk',
    employees: '140,000+',
    founded: '2003',
    headquarters: 'Austin, USA',
    marketCap: 568.84,
    peRatio: 56.21,
    dividendYield: 0.00,
    revenue: 96.77,
    eps: 3.08,
    beta: 2.05,
    weekHigh: 271.00,
    weekLow: 138.80,
    targetPrice: 192.00,
    rating: 'Hold',
    risk: 'High',
    aiConfidence: 71,
    strengths: [
      'Strong brand and EV ecosystem',
      'Energy storage growth',
      'Software optionality',
    ],
    weaknesses: [
      'Margin pressure',
      'High valuation sensitivity',
      'Execution risk in autonomous roadmap',
    ],
    news: const [
      StockNewsItem(
        'Tesla shares move lower after earnings update',
        'Automotive',
        'US Desk',
        '6h ago',
        'Investors focused on automotive margins.',
        Icons.directions_car_outlined,
      ),
      StockNewsItem(
        'EV price competition weighs on margins',
        'Stocks',
        'Auto Radar',
        'Today',
        'Pricing pressure across EV markets remains a key concern.',
        Icons.price_change_outlined,
      ),
      StockNewsItem(
        'Energy storage unit shows stronger growth',
        'Energy',
        'Clean Tech',
        'Yesterday',
        'Megapack deployments provide a counterweight to auto cyclicality.',
        Icons.battery_charging_full,
      ),
    ],
    charts: {},
  ),
  StockData(
    symbol: 'NVDA',
    name: 'NVIDIA Corp.',
    exchange: 'NASDAQ',
    sector: 'Technology',
    industry: 'Semiconductors',
    logo: 'NVD',
    price: 987.54,
    change: 32.96,
    changePct: 3.45,
    about:
        'NVIDIA designs GPUs, AI accelerators, data-center systems and software platforms for accelerated computing.',
    ceo: 'Jensen Huang',
    employees: '29,600+',
    founded: '1993',
    headquarters: 'Santa Clara, USA',
    marketCap: 2430.00,
    peRatio: 68.42,
    dividendYield: 0.03,
    revenue: 60.92,
    eps: 11.93,
    beta: 1.72,
    weekHigh: 1048.00,
    weekLow: 401.00,
    targetPrice: 1100.00,
    rating: 'Strong Buy',
    risk: 'Medium-High',
    aiConfidence: 92,
    strengths: [
      'AI accelerator leadership',
      'Data-center revenue scale',
      'Developer ecosystem moat',
    ],
    weaknesses: [
      'High expectations risk',
      'Supply-chain constraints',
      'Regulatory export limits',
    ],
    news: const [
      StockNewsItem(
        'NVIDIA data-center revenue beats expectations',
        'Technology',
        'AI Market Watch',
        '1h ago',
        'Demand for AI accelerators remained elevated.',
        Icons.memory,
      ),
      StockNewsItem(
        'AI accelerator demand remains elevated',
        'Stocks',
        'Semiconductor Desk',
        '3h ago',
        'Order visibility remains strong.',
        Icons.auto_graph,
      ),
      StockNewsItem(
        'Analysts lift target prices on margin expansion',
        'Analyst',
        'Equity Radar',
        'Today',
        'Higher mix of premium accelerators supports gross margin.',
        Icons.trending_up,
      ),
    ],
    charts: {},
  ),
  StockData(
    symbol: 'AAPL',
    name: 'Apple Inc.',
    exchange: 'NASDAQ',
    sector: 'Technology',
    industry: 'Consumer Electronics',
    logo: 'AAP',
    price: 212.35,
    change: 2.35,
    changePct: 1.12,
    about:
        'Apple designs consumer electronics, software, services and integrated digital ecosystems around iPhone, Mac, iPad, Watch and Services.',
    ceo: 'Tim Cook',
    employees: '164,000+',
    founded: '1976',
    headquarters: 'Cupertino, USA',
    marketCap: 3280.00,
    peRatio: 29.81,
    dividendYield: 0.52,
    revenue: 383.29,
    eps: 7.12,
    beta: 1.18,
    weekHigh: 237.23,
    weekLow: 164.08,
    targetPrice: 235.00,
    rating: 'Buy',
    risk: 'Low-Medium',
    aiConfidence: 84,
    strengths: [
      'Massive cash generation',
      'Premium ecosystem loyalty',
      'Growing services revenue',
    ],
    weaknesses: [
      'iPhone cycle dependence',
      'Regulatory pressure',
      'China demand uncertainty',
    ],
    news: const [
      StockNewsItem(
        'Apple services revenue reaches new record',
        'Technology',
        'US Tech Brief',
        '5h ago',
        'Services growth continues to support margin resilience.',
        Icons.phone_iphone,
      ),
      StockNewsItem(
        'Investors watch AI roadmap and iPhone cycle',
        'Stocks',
        'Consumer Tech',
        'Today',
        'The next product cycle and AI integration remain central.',
        Icons.auto_awesome,
      ),
      StockNewsItem(
        'Supply chain outlook improves for next quarter',
        'Market',
        'Asia Supply Desk',
        'Yesterday',
        'Component signals point to steadier production planning.',
        Icons.inventory_2_outlined,
      ),
    ],
    charts: {},
  ),
];

// Lazy-init charts
StockData stockWithCharts(StockData s) {
  if (s.charts.isNotEmpty) return s;
  final base = s.price;
  final trend = s.changePct.abs() * base * 0.01;
  final c = makeCharts(base, trend, negative: s.changePct < 0);
  return StockData(
    symbol: s.symbol,
    name: s.name,
    exchange: s.exchange,
    sector: s.sector,
    industry: s.industry,
    logo: s.logo,
    price: s.price,
    change: s.change,
    changePct: s.changePct,
    about: s.about,
    ceo: s.ceo,
    employees: s.employees,
    founded: s.founded,
    headquarters: s.headquarters,
    marketCap: s.marketCap,
    peRatio: s.peRatio,
    dividendYield: s.dividendYield,
    revenue: s.revenue,
    eps: s.eps,
    beta: s.beta,
    weekHigh: s.weekHigh,
    weekLow: s.weekLow,
    targetPrice: s.targetPrice,
    rating: s.rating,
    risk: s.risk,
    aiConfidence: s.aiConfidence,
    strengths: s.strengths,
    weaknesses: s.weaknesses,
    news: s.news,
    charts: c,
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// APP ROOT
// ──────────────────────────────────────────────────────────────────────────────
class PulseTradeApp extends StatelessWidget {
  const PulseTradeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkModeNotifier,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'PulseTrade',
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            return isDarkMode ? FuturisticBackground(child: child!) : child!;
          },
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF4F7FC),
            cardColor: Colors.white,
            dividerColor: const Color(0xFFE2E8F0),
            colorScheme: const ColorScheme.light(
              primary: AppColors.green2,
              secondary: AppColors.green2,
              surface: Colors.white,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF4F7FC),
              foregroundColor: Color(0xFF0F172A),
              elevation: 0,
              centerTitle: false,
              titleTextStyle: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Colors.white,
              selectedItemColor: AppColors.green2,
              unselectedItemColor: Color(0xFF64748B),
              type: BottomNavigationBarType.fixed,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.transparent,
            cardColor: const Color(0xCC0F172A),
            dividerColor: const Color(0x2494A3B8),
            colorScheme: const ColorScheme.dark(
              primary: AppColors.green,
              secondary: AppColors.green,
              surface: Color(0xCC0F172A),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.white,
              elevation: 0,
              centerTitle: false,
              titleTextStyle: TextStyle(
                color: AppColors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Color(0xEE0A0F1D),
              selectedItemColor: AppColors.green,
              unselectedItemColor: AppColors.muted,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// SPLASH SCREEN
// ──────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scale = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2200), _goToLogin);
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) => FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [AppColors.green, AppColors.green2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green.withOpacity(.45),
                          blurRadius: 32,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.show_chart,
                      color: Colors.black,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 24),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                      children: [
                        TextSpan(
                          text: 'Pulse',
                          style: TextStyle(color: AppColors.white),
                        ),
                        TextSpan(
                          text: 'Trade',
                          style: TextStyle(color: AppColors.green),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Smart Investments, Better Future',
                    style: TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 48),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// LOGIN SCREEN
// ──────────────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  bool _loading = false;
  bool _remember = true;
  bool _obscure = true;
  bool _isSignIn = true; // Toggle between Sign In and Create Account

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _loading = false);

    String name = 'User';
    if (_isSignIn) {
      final email = _emailCtrl.text.trim();
      if (email.isNotEmpty && email.contains('@')) {
        final emailPrefix = email.split('@')[0];
        final parts = emailPrefix.split(RegExp(r'[.\-_]'));
        name = parts
            .where((p) => p.isNotEmpty)
            .map((p) => '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
            .join(' ');
      }
    } else {
      final inputName = _nameCtrl.text.trim();
      if (inputName.isNotEmpty) {
        name = inputName;
      }
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MainShell(userName: name)),
    );
  }

  InputDecoration _inputDec(
    String hint,
    IconData icon,
    ThemeColors tc, {
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: tc.muted.withOpacity(0.6), fontSize: 14),
      prefixIcon: Icon(icon, color: tc.muted, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0x130A0F1D),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0x2694A3B8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0x2694A3B8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.green, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Glowing Logo Container
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [AppColors.green, AppColors.green2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withOpacity(.40),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.show_chart,
                  color: Colors.black,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                  children: [
                    TextSpan(
                      text: 'Pulse',
                      style: TextStyle(color: tc.text),
                    ),
                    const TextSpan(
                      text: 'Trade',
                      style: TextStyle(color: AppColors.green),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Smart Investments, Better Future',
                style: TextStyle(color: tc.muted, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Glassmorphic Login Card
              GlassmorphicCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSignIn ? 'Welcome Back' : 'Create Account',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: tc.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSignIn
                          ? 'Please sign in to continue'
                          : 'Please fill in the details to sign up',
                      style: TextStyle(color: tc.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 22),

                    if (!_isSignIn) ...[
                      Text(
                        'Full Name',
                        style: TextStyle(
                          color: tc.text.withOpacity(0.95),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameCtrl,
                        style: TextStyle(color: tc.text),
                        decoration: _inputDec(
                          'Enter your full name',
                          Icons.person_outline,
                          tc,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Text(
                      'Email',
                      style: TextStyle(
                        color: tc.text.withOpacity(0.95),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _isSignIn ? _emailCtrl : _regEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: tc.text),
                      decoration: _inputDec(
                        'Enter your email',
                        Icons.email_outlined,
                        tc,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Password',
                      style: TextStyle(
                        color: tc.text.withOpacity(0.95),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _isSignIn ? _passCtrl : _regPassCtrl,
                      obscureText: _obscure,
                      style: TextStyle(color: tc.text),
                      decoration: _inputDec(
                        'Enter your password',
                        Icons.lock_outline,
                        tc,
                        suffix: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: tc.muted,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),

                    if (_isSignIn) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _remember,
                              activeColor: AppColors.green,
                              checkColor: Colors.black,
                              onChanged: (v) =>
                                  setState(() => _remember = v ?? true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Remember me',
                            style: TextStyle(color: tc.muted, fontSize: 13),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: AppColors.green,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Gradient Action Button
                    BouncingButton(
                      onTap: _loading ? null : _login,
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF22C55E), Color(0xFF10B981)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _isSignIn ? 'Sign In' : 'Create Account',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),

                    // Divider
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(
                            color: Color(0x1F94A3B8),
                            endIndent: 10,
                          ),
                        ),
                        Text(
                          'or continue with',
                          style: TextStyle(
                            color: tc.muted.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: Color(0x1F94A3B8), indent: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Social Sign-in Row
                    Row(
                      children: [
                        Expanded(
                          child: BouncingButton(
                            onTap: _login,
                            child: OutlinedButton.icon(
                              onPressed: null,
                              icon: const GoogleIcon(),
                              label: Text(
                                'Google',
                                style: TextStyle(
                                  color: tc.text,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                disabledForegroundColor: tc.text,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: const BorderSide(
                                  color: Color(0x2494A3B8),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                backgroundColor: const Color(0x060F172A),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BouncingButton(
                            onTap: _login,
                            child: OutlinedButton.icon(
                              onPressed: null,
                              icon: const MicrosoftIcon(),
                              label: Text(
                                'Microsoft',
                                style: TextStyle(
                                  color: tc.text,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                disabledForegroundColor: tc.text,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: const BorderSide(
                                  color: Color(0x2494A3B8),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                backgroundColor: const Color(0x060F172A),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Switch Auth Mode link
                    Center(
                      child: BouncingButton(
                        onTap: () => setState(() => _isSignIn = !_isSignIn),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 13, color: tc.muted),
                            children: [
                              TextSpan(
                                text: _isSignIn
                                    ? "Don't have an account? "
                                    : "Already have an account? ",
                              ),
                              TextSpan(
                                text: _isSignIn ? "Create Account" : "Sign In",
                                style: const TextStyle(
                                  color: AppColors.green,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom responsive features strip
              const SizedBox(height: 36),
              const _BottomFeaturesStrip(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// DETAILED FEATURES STRIP LAYOUT
// ──────────────────────────────────────────────────────────────────────────────
class _BottomFeaturesStrip extends StatelessWidget {
  const _BottomFeaturesStrip();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;

    final items = const [
      _FeatureGridItem(
        icon: Icons.verified_user_outlined,
        title: 'Bank-level Security',
        desc:
            'Your data is protected with enterprise-grade encryption and advanced protocols.',
      ),
      _FeatureGridItem(
        icon: Icons.trending_up_outlined,
        title: 'Real-time Market Data',
        desc:
            'Access live data, advanced charts and market insights in real time.',
      ),
      _FeatureGridItem(
        icon: Icons.pie_chart_outline,
        title: 'Intelligent Analytics',
        desc: 'Make smarter decisions with powerful AI-driven insights.',
      ),
      _FeatureGridItem(
        icon: Icons.public_outlined,
        title: 'Trusted Worldwide',
        desc: 'Join thousands of investors from over 120+ countries.',
      ),
    ];

    if (isWide) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items
            .map(
              (item) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: item,
                ),
              ),
            )
            .toList(),
      );
    } else {
      // 2x2 Grid for phone portrait
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.25,
        children: items,
      );
    }
  }
}

class _FeatureGridItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _FeatureGridItem({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x0C0A0F1D), // Faint container
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1894A3B8), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tc.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              desc,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tc.muted.withOpacity(0.8),
                fontSize: 10,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// MAIN SHELL  (BottomNavigationBar)
// ──────────────────────────────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  final String userName;
  const MainShell({super.key, this.userName = 'User'});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  AppCurrency _currency = AppCurrency.eur;
  bool _darkMode = true;
  bool _priceAlerts = true;
  String? _countryCode;
  bool _locationLoading = true;
  String _apiKey = '';

  final List<TradeActivity> _activities = [
    const TradeActivity(
      'Buy Siemens Energy AG',
      '10 shares at €18.10',
      181.00,
      true,
    ),
    const TradeActivity('Buy SAP SE', '5 shares at €210.50', 1052.50, true),
    const TradeActivity(
      'Sell Tesla Inc.',
      '3 shares at €180.00',
      -540.00,
      false,
    ),
  ];
  final Map<String, int> _holdings = {
    'ENR.DE': 120,
    'SAP.DE': 80,
    'TSLA': 10,
    'NVDA': 15,
    'AAPL': 8,
  };
  final List<String> _watchlist = ['AAPL', 'TSLA'];

  List<StockData> _stocks = List.from(demoStocks);
  bool _apiLoading = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('apiKey') ?? '';
      _darkMode = prefs.getBool('darkMode') ?? true;
      darkModeNotifier.value = _darkMode;
      _priceAlerts = prefs.getBool('priceAlerts') ?? true;
      final savedCurrency = prefs.getString('currency');
      if (savedCurrency != null) {
        _currency = AppCurrency.values.firstWhere(
          (e) => e.toString() == savedCurrency,
          orElse: () => AppCurrency.eur,
        );
      }

      // Load holdings
      final savedHoldings = prefs.getString('holdings');
      if (savedHoldings != null) {
        try {
          final Map<String, dynamic> decoded = json.decode(savedHoldings);
          _holdings.clear();
          decoded.forEach((key, val) {
            _holdings[key] = val as int;
          });
        } catch (_) {}
      }

      // Load watchlist
      final savedWatch = prefs.getStringList('watchlist');
      if (savedWatch != null) {
        _watchlist.clear();
        _watchlist.addAll(savedWatch);
      }

      // Load activities
      final savedAct = prefs.getString('activities');
      if (savedAct != null) {
        try {
          final List<dynamic> decoded = json.decode(savedAct);
          _activities.clear();
          for (final a in decoded) {
            _activities.add(
              TradeActivity(
                a['title'] as String,
                a['detail'] as String,
                (a['value'] as num).toDouble(),
                a['positive'] as bool,
              ),
            );
          }
        } catch (_) {}
      }
    });

    await _fetchLocation();
    _fetchExchangeRates();
    _fetchStockPrices();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('apiKey', _apiKey);
    await prefs.setBool('darkMode', _darkMode);
    await prefs.setBool('priceAlerts', _priceAlerts);
    await prefs.setString('currency', _currency.toString());
    await prefs.setStringList('watchlist', _watchlist);
    await prefs.setString('holdings', json.encode(_holdings));

    final serializedAct = _activities
        .map(
          (a) => {
            'title': a.title,
            'detail': a.detail,
            'value': a.value,
            'positive': a.positive,
          },
        )
        .toList();
    await prefs.setString('activities', json.encode(serializedAct));
  }

  Future<void> _fetchLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.denied &&
          perm != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 8),
          ),
        );
        final marks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (marks.isNotEmpty && mounted) {
          final code = marks.first.isoCountryCode;
          setState(() {
            _countryCode = code;
            if (code != null) {
              final upper = code.toUpperCase();
              if (upper == 'US') {
                _currency = AppCurrency.usd;
              } else if (upper == 'TR') {
                _currency = AppCurrency.tryc;
              } else if (upper == 'GB') {
                _currency = AppCurrency.gbp;
              } else {
                _currency = AppCurrency.eur;
              }
            }
          });
          _saveState();
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _locationLoading = false);
  }

  Future<void> _fetchExchangeRates() async {
    try {
      final res = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/EUR'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final rates = data['rates'] as Map<String, dynamic>;
        setState(() {
          appExchangeRates[AppCurrency.eur] = 1.0;
          appExchangeRates[AppCurrency.usd] =
              (rates['USD'] as num?)?.toDouble() ?? 1.08;
          appExchangeRates[AppCurrency.tryc] =
              (rates['TRY'] as num?)?.toDouble() ?? 35.20;
          appExchangeRates[AppCurrency.gbp] =
              (rates['GBP'] as num?)?.toDouble() ?? 0.86;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchStockPrices() async {
    if (_apiKey.isEmpty || _apiKey == 'YOUR_MARKETSTACK_API_KEY') {
      // Periodic small simulation noise
      setState(() {
        _stocks = _stocks.map((s) {
          final noise = (math.Random().nextDouble() - 0.5) * 0.15;
          final newPrice = math.max(1.0, s.price + noise);
          final newChange = s.change + noise;
          final newChangePct = s.price > 0 ? (newChange / s.price) * 100 : 0.0;
          return StockData(
            symbol: s.symbol,
            name: s.name,
            exchange: s.exchange,
            sector: s.sector,
            industry: s.industry,
            logo: s.logo,
            price: double.parse(newPrice.toStringAsFixed(2)),
            change: double.parse(newChange.toStringAsFixed(2)),
            changePct: double.parse(newChangePct.toStringAsFixed(2)),
            about: s.about,
            ceo: s.ceo,
            employees: s.employees,
            founded: s.founded,
            headquarters: s.headquarters,
            marketCap: s.marketCap,
            peRatio: s.peRatio,
            dividendYield: s.dividendYield,
            revenue: s.revenue,
            eps: s.eps,
            beta: s.beta,
            weekHigh: s.weekHigh,
            weekLow: s.weekLow,
            targetPrice: s.targetPrice,
            rating: s.rating,
            risk: s.risk,
            aiConfidence: s.aiConfidence,
            strengths: s.strengths,
            weaknesses: s.weaknesses,
            news: s.news,
            charts: s.charts,
          );
        }).toList();
      });
      return;
    }

    setState(() => _apiLoading = true);
    try {
      final symbols = _stocks.map((s) => s.symbol).join(',');
      final uri = Uri.parse(
        'http://api.marketstack.com/v1/eod/latest?access_key=$_apiKey&symbols=$symbols',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final list = data['data'] as List<dynamic>? ?? [];
        if (list.isNotEmpty) {
          setState(() {
            _stocks = _stocks.map((s) {
              final match = list.firstWhere(
                (item) =>
                    item['symbol'].toString().toLowerCase() ==
                    s.symbol.toLowerCase(),
                orElse: () => null,
              );
              if (match != null) {
                final close = (match['close'] as num?)?.toDouble() ?? s.price;
                final open = (match['open'] as num?)?.toDouble() ?? close;
                final change = close - open;
                final changePct = open != 0 ? (change / open) * 100 : 0.0;
                return StockData(
                  symbol: s.symbol,
                  name: s.name,
                  exchange: s.exchange,
                  sector: s.sector,
                  industry: s.industry,
                  logo: s.logo,
                  price: close,
                  change: change,
                  changePct: changePct,
                  about: s.about,
                  ceo: s.ceo,
                  employees: s.employees,
                  founded: s.founded,
                  headquarters: s.headquarters,
                  marketCap:
                      (match['market_cap'] as num?)?.toDouble() ?? s.marketCap,
                  peRatio: s.peRatio,
                  dividendYield: s.dividendYield,
                  revenue: s.revenue,
                  eps: s.eps,
                  beta: s.beta,
                  weekHigh: (match['high'] as num?)?.toDouble() ?? s.weekHigh,
                  weekLow: (match['low'] as num?)?.toDouble() ?? s.weekLow,
                  targetPrice: s.targetPrice,
                  rating: s.rating,
                  risk: s.risk,
                  aiConfidence: s.aiConfidence,
                  strengths: s.strengths,
                  weaknesses: s.weaknesses,
                  news: s.news,
                  charts: s.charts,
                );
              }
              return s;
            }).toList();
          });
        }
      }
    } catch (_) {}
    setState(() => _apiLoading = false);
  }

  void _trade(StockData stock, bool buy, int shares) {
    final value = stock.price * shares;
    setState(() {
      _holdings[stock.symbol] =
          (_holdings[stock.symbol] ?? 0) + (buy ? shares : -shares);
      if ((_holdings[stock.symbol] ?? 0) < 0) _holdings[stock.symbol] = 0;
      _activities.insert(
        0,
        TradeActivity(
          '${buy ? 'Buy' : 'Sell'} ${stock.name}',
          '$shares shares at ${money(stock.price, _currency)}',
          buy ? value : -value,
          buy,
        ),
      );
    });
    _saveState();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: buy ? AppColors.green2 : AppColors.red,
        content: Text(
          '${buy ? 'Buy' : 'Sell'} order executed: $shares × ${stock.symbol}',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  void _openStock(StockData stock) {
    final s = stockWithCharts(stock);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockDetailScreen(
          stock: s,
          currency: _currency,
          onTrade: _trade,
          isStarred: _watchlist.contains(s.symbol),
          onStarToggle: (sym) {
            setState(() {
              if (_watchlist.contains(sym)) {
                _watchlist.remove(sym);
              } else {
                _watchlist.add(sym);
              }
            });
            _saveState();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        userName: widget.userName,
        currency: _currency,
        activities: _activities,
        holdings: _holdings,
        countryCode: _countryCode,
        locationLoading: _locationLoading,
        onOpenStock: _openStock,
        stocks: _stocks,
      ),
      MarketsScreen(
        currency: _currency,
        onOpenStock: _openStock,
        countryCode: _countryCode,
        stocks: _stocks,
        watchlist: _watchlist,
      ),
      PortfolioScreen(
        currency: _currency,
        holdings: _holdings,
        activities: _activities,
        onOpenStock: _openStock,
        stocks: _stocks,
        watchlist: _watchlist,
      ),
      const ProScreen(),
      SettingsScreen(
        currency: _currency,
        darkMode: _darkMode,
        priceAlerts: _priceAlerts,
        apiKey: _apiKey,
        onCurrency: (c) {
          setState(() => _currency = c);
          _saveState();
        },
        onDarkMode: (v) {
          setState(() {
            _darkMode = v;
            darkModeNotifier.value = v;
          });
          _saveState();
        },
        onPriceAlerts: (v) {
          setState(() => _priceAlerts = v);
          _saveState();
        },
        onApiKeyChanged: (k) {
          setState(() => _apiKey = k);
          _saveState();
          _fetchStockPrices();
        },
        onLogout: () => Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        ),
      ),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.trending_up_outlined),
              activeIcon: Icon(Icons.trending_up),
              label: 'Markets',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Portfolio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.workspace_premium_outlined),
              activeIcon: Icon(Icons.workspace_premium),
              label: 'Pro',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// HOME SCREEN
// ──────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  final String userName;
  final AppCurrency currency;
  final List<TradeActivity> activities;
  final Map<String, int> holdings;
  final String? countryCode;
  final bool locationLoading;
  final void Function(StockData) onOpenStock;
  final List<StockData> stocks;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.currency,
    required this.activities,
    required this.holdings,
    required this.countryCode,
    required this.locationLoading,
    required this.onOpenStock,
    required this.stocks,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');

  @override
  void dispose() {
    _searchController.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  void _showAIPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => AITradingAdvisorPanel(
          scrollController: scrollController,
          stocks: widget.stocks,
          currency: widget.currency,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double total = 0;
    for (final s in widget.stocks) {
      total += (widget.holdings[s.symbol] ?? 0) * s.price;
    }

    final tc = ThemeColors.of(context);

    return Scaffold(
      backgroundColor: tc.bg,
      floatingActionButton: BouncingButton(
        onTap: () => _showAIPanel(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.green,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.green.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.auto_awesome, color: Colors.black, size: 20),
              SizedBox(width: 8),
              Text(
                'Ask AI Advisor',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: tc.bg,
        title: Text('PulseTrade', style: TextStyle(color: tc.text)),
        leading: const Padding(
          padding: EdgeInsets.all(10),
          child: _LogoMark(size: 36),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            color: tc.muted,
            onPressed: () {},
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: tc.card2,
            child: const Text('👤', style: TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          ScrollingTickerTape(stocks: widget.stocks, currency: widget.currency),
          Expanded(
            child: OrientationBuilder(
              builder: (context, orientation) {
                final isLandscape = orientation == Orientation.landscape;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Hero Banner (asset image & donut chart) ──
                      _HeroBanner(
                        userName: widget.userName,
                        currency: widget.currency,
                        total: total,
                        countryCode: widget.countryCode,
                        locationLoading: widget.locationLoading,
                        holdings: widget.holdings,
                        stocks: widget.stocks,
                      ),
                      const SizedBox(height: 16),
                      // ── Market Indices ──
                      _SectionHeader(
                        title: 'Market Indices',
                        subtitle: 'Global benchmarks',
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: marketIndices.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (_, i) =>
                              _IndexCard(index: marketIndices[i]),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ── Market Sentiment ──
                      Row(
                        children: [
                          Expanded(child: _SentimentCard()),
                          const SizedBox(width: 10),
                          Expanded(child: _AISignalCard()),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Search Bar Field
                      TextField(
                        controller: _searchController,
                        onChanged: (val) => _searchQueryNotifier.value = val,
                        style: TextStyle(color: tc.text),
                        decoration: InputDecoration(
                          hintText: 'Search stock symbols or names...',
                          hintStyle: TextStyle(
                            color: tc.muted.withOpacity(0.5),
                          ),
                          prefixIcon: Icon(Icons.search, color: tc.muted),
                          suffixIcon: ValueListenableBuilder<String>(
                            valueListenable: _searchQueryNotifier,
                            builder: (context, query, child) {
                              return query.isEmpty
                                  ? const SizedBox()
                                  : IconButton(
                                      icon: Icon(Icons.clear, color: tc.muted),
                                      onPressed: () {
                                        _searchController.clear();
                                        _searchQueryNotifier.value = '';
                                      },
                                    );
                            },
                          ),
                          filled: true,
                          fillColor: const Color(0x0C1E293B),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0x1F94A3B8),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0x1F94A3B8),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.green,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Top Movers ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _SectionHeader(
                            title: 'Top Movers',
                            subtitle: '',
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              'View All',
                              style: TextStyle(color: AppColors.green),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      ValueListenableBuilder<String>(
                        valueListenable: _searchQueryNotifier,
                        builder: (context, query, child) {
                          final q = query.trim().toLowerCase();
                          final filtered = widget.stocks.where((s) {
                            return s.symbol.toLowerCase().contains(q) ||
                                s.name.toLowerCase().contains(q);
                          }).toList();

                          if (filtered.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Text(
                                  'No matching stocks found',
                                  style: TextStyle(
                                    color: tc.muted,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            );
                          }

                          final displayList = q.isEmpty
                              ? filtered.take(3).toList()
                              : filtered;

                          if (isLandscape) {
                            return Row(
                              children: displayList
                                  .map(
                                    (s) => Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: _StockListTile(
                                          stock: s,
                                          currency: widget.currency,
                                          onTap: () => widget.onOpenStock(s),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            );
                          } else {
                            return Column(
                              children: displayList
                                  .map(
                                    (s) => _StockListTile(
                                      stock: s,
                                      currency: widget.currency,
                                      onTap: () => widget.onOpenStock(s),
                                    ),
                                  )
                                  .toList(),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── News Preview ──
                      const _SectionHeader(title: 'Latest News', subtitle: ''),
                      const SizedBox(height: 10),
                      ...widget.stocks
                          .take(3)
                          .map(
                            (s) => _NewsMiniTile(
                              stock: s,
                              item: s.news.first,
                              onTap: () => widget.onOpenStock(s),
                            ),
                          ),
                      const SizedBox(height: 16),
                      // ── Recent Activity ──
                      const _SectionHeader(
                        title: 'Recent Activity',
                        subtitle: '',
                      ),
                      const SizedBox(height: 10),
                      _GlassCard(
                        child: Column(
                          children: widget.activities
                              .take(3)
                              .map(
                                (a) => _ActivityTile(
                                  activity: a,
                                  currency: widget.currency,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatefulWidget {
  final String userName;
  final AppCurrency currency;
  final double total;
  final String? countryCode;
  final bool locationLoading;
  final Map<String, int> holdings;
  final List<StockData> stocks;

  const _HeroBanner({
    required this.userName,
    required this.currency,
    required this.total,
    required this.countryCode,
    required this.locationLoading,
    required this.holdings,
    required this.stocks,
  });

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner> {
  String _timeframe = '1M';

  List<double> _getHistoricalData() {
    switch (_timeframe) {
      case '1D':
        return [1.0, 1.02, 1.01, 1.03, 1.02, 1.042];
      case '1W':
        return [0.95, 0.98, 0.97, 1.01, 0.99, 1.02, 1.042];
      case '1M':
        return [0.90, 0.93, 0.91, 0.96, 0.94, 0.98, 1.01, 1.042];
      case 'ALL':
      default:
        return [0.75, 0.82, 0.80, 0.88, 0.85, 0.92, 0.96, 1.042];
    }
  }

  @override
  Widget build(BuildContext context) {
    final country = _countryName(widget.countryCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final history = _getHistoricalData();
    final currentVal = widget.total;
    final points = history.map((val) => val * currentVal * 0.96).toList();

    return Container(
      height: 205,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF0B1F14),
                  const Color(0xFF071830),
                  const Color(0xFF0B1F14),
                ]
              : [
                  const Color(0xFFE2F9E5),
                  const Color(0xFFE6EFFF),
                  const Color(0xFFE2F9E5),
                ],
        ),
        border: Border.all(
          color: isDark ? AppColors.border : const Color(0xFFCBD5E1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withOpacity(isDark ? .12 : .06),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Sparkline Custom Paint
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.35 : 0.15,
              child: CustomPaint(
                painter: _PortfolioSparklinePainter(
                  data: points,
                  color: AppColors.green,
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Welcome back, ${widget.userName.split(' ')[0]} 👋',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.locationLoading)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.green,
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.green.withOpacity(.25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.green.withOpacity(.5),
                                ),
                              ),
                              child: Text(
                                '📍 $country',
                                style: const TextStyle(
                                  color: AppColors.green,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        money(widget.total, widget.currency),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '+4.21% Today • +€1,240.00 this month',
                        style: TextStyle(
                          color: AppColors.green,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Timeframe Toggles on the card
                      Row(
                        children: ['1D', '1W', '1M', 'ALL'].map((tf) {
                          final selected = _timeframe == tf;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: BouncingButton(
                              onTap: () => setState(() => _timeframe = tf),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.green.withOpacity(.25)
                                      : Colors.black.withOpacity(.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.green
                                        : Colors.transparent,
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  tf,
                                  style: TextStyle(
                                    color: selected
                                        ? AppColors.green
                                        : Colors.white60,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 100,

                        child: _DonutChart(
                          holdings: widget.holdings,
                          stocks: widget.stocks,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Asset Allocation',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _countryName(String? code) {
    switch (code?.toUpperCase()) {
      case 'DE':
        return 'Germany';
      case 'US':
        return 'United States';
      case 'GB':
        return 'United Kingdom';
      case 'TR':
        return 'Turkey';
      default:
        return code ?? 'Germany';
    }
  }
}

class _PortfolioSparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  const _PortfolioSparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVal = data.reduce(math.max);
    final minVal = data.reduce(math.min);
    final span = maxVal == minVal ? 1.0 : (maxVal - minVal);

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y =
          size.height * 0.9 - ((data[i] - minVal) / span) * (size.height * 0.7);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      if (i == data.length - 1) {
        fillPath.lineTo(x, size.height);
        fillPath.close();
      }
    }

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.20), color.withOpacity(0.01)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _PortfolioSparklinePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}

class _IndexCard extends StatelessWidget {
  final IndexInfo index;
  const _IndexCard({required this.index});
  @override
  Widget build(BuildContext context) {
    final pos = index.change.startsWith('+');
    final tc = ThemeColors.of(context);
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            index.name,
            style: TextStyle(
              color: tc.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            index.value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: tc.text,
            ),
          ),
          Text(
            index.change,
            style: TextStyle(
              color: pos ? AppColors.green : AppColors.red,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SentimentCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sentiment', style: TextStyle(color: tc.muted, fontSize: 12)),
          const SizedBox(height: 6),
          const Text(
            'BULLISH',
            style: TextStyle(
              color: AppColors.green,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '78% Buy Signal',
            style: TextStyle(color: tc.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AISignalCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Confidence',
            style: TextStyle(color: tc.muted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          const Text(
            '91%',
            style: TextStyle(
              color: AppColors.green,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'Strong Buy Market',
            style: TextStyle(color: tc.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// MARKETS SCREEN
// ──────────────────────────────────────────────────────────────────────────────
class MarketsScreen extends StatefulWidget {
  final AppCurrency currency;
  final void Function(StockData) onOpenStock;
  final String? countryCode;
  final List<StockData> stocks;
  final List<String> watchlist;

  const MarketsScreen({
    super.key,
    required this.currency,
    required this.onOpenStock,
    required this.countryCode,
    required this.stocks,
    required this.watchlist,
  });

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  String _newsFilter = 'All';
  String _marketRegion = 'DE';

  static const _regions = {
    'DE': ('🇩🇪', 'Germany'),
    'US': ('🇺🇸', 'USA'),
    'GB': ('🇬🇧', 'UK'),
    'TR': ('🇹🇷', 'Turkey'),
  };

  @override
  void initState() {
    super.initState();
    _marketRegion = widget.countryCode ?? 'DE';
    if (!_regions.containsKey(_marketRegion)) _marketRegion = 'DE';
  }

  List<StockData> get _filteredStocks {
    if (_newsFilter == 'All') return widget.stocks;
    return widget.stocks
        .where(
          (s) =>
              s.sector.toLowerCase().contains(_newsFilter.toLowerCase()) ||
              s.news.any(
                (n) => n.category.toLowerCase().contains(
                  _newsFilter.toLowerCase(),
                ),
              ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tc.bg,
      appBar: AppBar(
        backgroundColor: tc.bg,
        title: Text('Markets & News', style: TextStyle(color: tc.text)),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: tc.muted),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Country/Region Selector ──
            const _SectionHeader(title: 'Select Market', subtitle: ''),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _regions.entries.map((e) {
                  final active = _marketRegion == e.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: BouncingButton(
                      onTap: () => setState(() => _marketRegion = e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.green.withOpacity(.2)
                              : tc.card2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active ? AppColors.green : tc.border,
                          ),
                        ),
                        child: Text(
                          '${e.value.$1} ${e.value.$2}',
                          style: TextStyle(
                            color: active ? AppColors.green : tc.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            // ── Stock Prices ──
            const _SectionHeader(
              title: 'Stock Prices',
              subtitle: 'Tap to view details',
            ),
            const SizedBox(height: 10),
            ..._filteredStocks
                .take(3)
                .map(
                  (s) => _StockListTile(
                    stock: s,
                    currency: widget.currency,
                    onTap: () => widget.onOpenStock(s),
                  ),
                ),
            const SizedBox(height: 16),
            // ── News Filter ──
            const _SectionHeader(title: 'News', subtitle: ''),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    [
                          'All',
                          'Market',
                          'Stocks',
                          'Economy',
                          'Technology',
                          'Energy',
                        ]
                        .map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: BouncingButton(
                              onTap: () => setState(() => _newsFilter = f),
                              child: ChoiceChip(
                                label: Text(f),
                                selected: _newsFilter == f,
                                selectedColor: AppColors.green.withOpacity(.25),
                                backgroundColor: tc.card2,
                                labelStyle: TextStyle(
                                  color: _newsFilter == f
                                      ? AppColors.green
                                      : tc.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                                side: BorderSide(
                                  color: _newsFilter == f
                                      ? AppColors.green
                                      : tc.border,
                                ),
                                onSelected: (_) {},
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            const SizedBox(height: 12),
            ..._filteredStocks.map(
              (s) => Column(
                children: s.news
                    .map(
                      (n) => _NewsTile(
                        item: n,
                        stock: s,
                        onStockTap: () => widget.onOpenStock(s),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _NewsTile extends StatelessWidget {
  final StockNewsItem item;
  final StockData stock;
  final VoidCallback onStockTap;
  const _NewsTile({
    required this.item,
    required this.stock,
    required this.onStockTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BouncingButton(
        onTap: () => showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: tc.card,
            title: Text(
              item.title,
              style: TextStyle(fontSize: 16, color: tc.text),
            ),
            content: Text(
              '${item.source} · ${item.time}\n\n${item.body}',
              style: TextStyle(color: tc.muted, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onStockTap();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Open Stock'),
              ),
            ],
          ),
        ),

        child: _GlassCard(
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: AppColors.green, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: tc.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.time} · ${item.category}',
                      style: TextStyle(color: tc.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              BouncingButton(
                onTap: onStockTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.green.withOpacity(.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.green.withOpacity(.4)),
                  ),
                  child: Text(
                    stock.symbol,
                    style: const TextStyle(
                      color: AppColors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// STOCK DETAIL SCREEN
// ──────────────────────────────────────────────────────────────────────────────
class StockDetailScreen extends StatefulWidget {
  final StockData stock;
  final AppCurrency currency;
  final void Function(StockData, bool, int) onTrade;
  final bool isStarred;
  final ValueChanged<String> onStarToggle;

  const StockDetailScreen({
    super.key,
    required this.stock,
    required this.currency,
    required this.onTrade,
    required this.isStarred,
    required this.onStarToggle,
  });

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen>
    with SingleTickerProviderStateMixin {
  String _range = '1D';
  late TabController _tab;
  late bool _starred;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _starred = widget.isStarred;
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _launchTradingView(String symbol) async {
    final cleanSym = symbol
        .replaceAll('.DE', '')
        .replaceAll('.XETRA', '')
        .replaceAll('.LSE', '')
        .replaceAll('.IS', '');
    final url = Uri.parse('https://www.tradingview.com/symbols/$cleanSym');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stock;
    final positive = s.changePct >= 0;
    final color = positive ? AppColors.green : AppColors.red;
    final tc = ThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tc.bg,
      appBar: AppBar(
        backgroundColor: tc.bg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.symbol,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: tc.text,
              ),
            ),
            Text(
              s.name,
              style: TextStyle(
                color: tc.muted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _starred ? Icons.star : Icons.star_border,
              color: AppColors.green,
            ),
            onPressed: () {
              setState(() => _starred = !_starred);
              widget.onStarToggle(s.symbol);
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            color: tc.muted,
            onPressed: () => _launchTradingView(s.symbol),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Price Header ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StockBadge(stock: s, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: tc.text,
                            ),
                          ),
                          Text(
                            '${s.symbol} · ${s.exchange}',
                            style: TextStyle(color: tc.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          money(s.price, widget.currency),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                        Text(
                          '${positive ? '+' : ''}${s.changePct.toStringAsFixed(2)}% today',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Chart ──
                _GlassCard(
                  child: Column(
                    children: [
                      // Range selector
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['1D', '1W', '1M', '3M', '1Y'].map((r) {
                            final sel = _range == r;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _range = r),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? AppColors.green.withOpacity(.22)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: sel ? AppColors.green : tc.border,
                                    ),
                                  ),
                                  child: Text(
                                    r,
                                    style: TextStyle(
                                      color: sel ? AppColors.green : tc.muted,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: _LineChart(
                          data: s.charts[_range] ?? s.charts['1D'] ?? [],
                          positive: positive,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // ── Key Stats ──
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Key Statistics',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: tc.text,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _MetricRow(
                        'Market Cap',
                        '${money(s.marketCap, widget.currency)}B',
                      ),
                      _MetricRow('P/E Ratio', s.peRatio.toStringAsFixed(2)),
                      _MetricRow(
                        '52W High',
                        money(s.weekHigh, widget.currency),
                      ),
                      _MetricRow('52W Low', money(s.weekLow, widget.currency)),
                      _MetricRow('EPS (TTM)', money(s.eps, widget.currency)),
                      _MetricRow(
                        'Dividend Yield',
                        '${s.dividendYield.toStringAsFixed(2)}%',
                      ),
                      _MetricRow('Beta', s.beta.toStringAsFixed(2)),
                      _MetricRow(
                        'Revenue',
                        '${money(s.revenue, widget.currency)}B',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // ── About ──
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: tc.text,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.about,
                        style: TextStyle(
                          color: tc.muted,
                          height: 1.5,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _MetricRow('CEO', s.ceo),
                      _MetricRow('Employees', s.employees),
                      _MetricRow('Founded', s.founded),
                      _MetricRow('HQ', s.headquarters),
                      _MetricRow('Rating', s.rating),
                      _MetricRow('Risk', s.risk),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // ── Analyst View ──
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'AI Analysis',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: tc.text,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.green.withOpacity(.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Confidence: ${s.aiConfidence.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: AppColors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Strengths',
                        style: TextStyle(
                          color: tc.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...s.strengths.map(
                        (x) => _BulletRow(text: x, positive: true),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Weaknesses',
                        style: TextStyle(
                          color: tc.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...s.weaknesses.map(
                        (x) => _BulletRow(text: x, positive: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // ── News ──
                const _SectionHeader(title: 'Latest News', subtitle: ''),
                const SizedBox(height: 8),
                ...s.news.map(
                  (n) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: tc.card,
                          title: Text(
                            n.title,
                            style: TextStyle(fontSize: 15, color: tc.text),
                          ),
                          content: Text(
                            '${n.source} · ${n.time}\n\n${n.body}',
                            style: TextStyle(color: tc.muted, height: 1.5),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: _GlassCard(
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.green.withOpacity(.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                n.icon,
                                color: AppColors.green,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: tc.text,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${n.time} · ${n.category}',
                                    style: TextStyle(
                                      color: tc.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: tc.muted),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // ── Buy / Sell ──
                Row(
                  children: [
                    Expanded(
                      child: BouncingButton(
                        onTap: () => _showTradeDialog(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF22C55E), Color(0xFF10B981)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Buy',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BouncingButton(
                        onTap: () => _showTradeDialog(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.red,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.red.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Sell',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    BouncingButton(
                      onTap: () => _launchTradingView(s.symbol),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: tc.border),
                        ),
                        child: const Icon(
                          Icons.open_in_new,
                          color: AppColors.green,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTradeDialog(BuildContext context, bool buy) {
    int shares = 1;
    final tc = ThemeColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          return AlertDialog(
            backgroundColor: tc.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              '${buy ? 'Buy' : 'Sell'} ${widget.stock.name}',
              style: TextStyle(color: tc.text),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Price: ${money(widget.stock.price, widget.currency)}',
                  style: TextStyle(color: tc.muted),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: shares > 1 ? () => setD(() => shares--) : null,
                      icon: const Icon(Icons.remove_circle_outline, size: 30),
                      color: AppColors.green,
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        '$shares',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: tc.text,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setD(() => shares++),
                      icon: const Icon(Icons.add_circle_outline, size: 30),
                      color: AppColors.green,
                    ),
                  ],
                ),
                Text('shares', style: TextStyle(color: tc.muted)),
                const SizedBox(height: 12),
                Text(
                  'Total: ${money(shares * widget.stock.price, widget.currency)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: tc.text,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onTrade(widget.stock, buy, shares);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: buy ? AppColors.green : AppColors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text(buy ? 'Confirm Buy' : 'Confirm Sell'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// PORTFOLIO SCREEN
// ──────────────────────────────────────────────────────────────────────────────
class PortfolioScreen extends StatefulWidget {
  final AppCurrency currency;
  final Map<String, int> holdings;
  final List<TradeActivity> activities;
  final void Function(StockData) onOpenStock;
  final List<StockData> stocks;
  final List<String> watchlist;

  const PortfolioScreen({
    super.key,
    required this.currency,
    required this.holdings,
    required this.activities,
    required this.onOpenStock,
    required this.stocks,
    required this.watchlist,
  });

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  String _filter = 'Holdings'; // 'Holdings', 'Watchlist', 'All'

  @override
  Widget build(BuildContext context) {
    double total = 0;
    for (final s in widget.stocks) {
      total += (widget.holdings[s.symbol] ?? 0) * s.price;
    }

    final tc = ThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter stock list
    final filteredList = widget.stocks.where((s) {
      if (_filter == 'Holdings') {
        return (widget.holdings[s.symbol] ?? 0) > 0;
      } else if (_filter == 'Watchlist') {
        return widget.watchlist.contains(s.symbol);
      }
      return true; // 'All'
    }).toList();

    return Scaffold(
      backgroundColor: tc.bg,
      appBar: AppBar(
        backgroundColor: tc.bg,
        title: Text('Portfolio', style: TextStyle(color: tc.text)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Balance Summary with Donut Chart ──
            _GlassCard(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Balance',
                          style: TextStyle(color: tc.muted, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          money(total, widget.currency),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: tc.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '+5.23% Today',
                          style: TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 80,
                      child: _DonutChart(
                        holdings: widget.holdings,
                        stocks: widget.stocks,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── Secondary Stats ──
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: "Today's P/L",
                    value: '+${money(1240, widget.currency)}',
                    sub: 'Open market gain',
                    positive: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    title: 'Monthly ROI',
                    value: '+8.7%',
                    sub: 'Portfolio return',
                    positive: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Filter Chips ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Holdings', 'Watchlist', 'All Stocks'].map((f) {
                  final active = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: BouncingButton(
                      onTap: () => setState(() => _filter = f),
                      child: ChoiceChip(
                        label: Text(f == 'All Stocks' ? 'All' : f),
                        selected: active,
                        selectedColor: AppColors.green.withOpacity(.25),
                        backgroundColor: tc.card2,
                        labelStyle: TextStyle(
                          color: active ? AppColors.green : tc.muted,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(
                          color: active ? AppColors.green : tc.border,
                        ),
                        onSelected: (_) {},
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            // ── Asset List ──
            _SectionHeader(
              title: _filter,
              subtitle: 'Tap a stock to view details',
            ),
            const SizedBox(height: 10),
            if (filteredList.isEmpty)
              _GlassCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No stocks in this filter group',
                      style: TextStyle(
                        color: tc.muted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              )
            else
              _GlassCard(
                child: Column(
                  children: filteredList.map((s) {
                    final sh = widget.holdings[s.symbol] ?? 0;
                    final val = sh * s.price;
                    final pos = s.changePct >= 0;
                    return InkWell(
                      onTap: () => widget.onOpenStock(s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            _StockBadge(stock: s, size: 44),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: tc.text,
                                    ),
                                  ),
                                  Text(
                                    '$sh shares',
                                    style: TextStyle(
                                      color: tc.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  money(val, widget.currency),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: tc.text,
                                  ),
                                ),
                                Text(
                                  '${pos ? '+' : ''}${s.changePct.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    color: pos
                                        ? AppColors.green
                                        : AppColors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 16),
            // ── Recent Activity ──
            const _SectionHeader(title: 'Recent Activity', subtitle: ''),
            const SizedBox(height: 10),
            _GlassCard(
              child: Column(
                children: widget.activities
                    .take(5)
                    .map(
                      (a) =>
                          _ActivityTile(activity: a, currency: widget.currency),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// PRO SCREEN
// ──────────────────────────────────────────────────────────────────────────────
class ProScreen extends StatefulWidget {
  const ProScreen({super.key});
  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  bool _yearly = false;

  @override
  Widget build(BuildContext context) {
    final price = _yearly ? '€49.99 / year' : '€4.99 / month';
    final saving = _yearly ? 'Save 17%' : null;
    final tc = ThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tc.bg,
      appBar: AppBar(
        backgroundColor: tc.bg,
        title: Text('PulseTrade Pro', style: TextStyle(color: tc.text)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Hero ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [Color(0xFF0B2A1F), Color(0xFF071830)]
                      : const [Color(0xFFE2F5EE), Color(0xFFEBF3FC)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? AppColors.green.withOpacity(.4)
                      : AppColors.green.withOpacity(.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? AppColors.green.withOpacity(.12)
                        : Colors.black.withOpacity(.05),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.workspace_premium,
                    color: AppColors.green,
                    size: 56,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'PulseTrade Pro',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: tc.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock the full potential of smart investing.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tc.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // ── Billing Toggle ──
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: tc.card2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _yearly = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_yearly ? tc.card : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Monthly',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: !_yearly ? tc.text : tc.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _yearly = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _yearly ? tc.card : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Yearly',
                              style: TextStyle(
                                color: _yearly ? tc.text : tc.muted,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (_yearly) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.green,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'SAVE 17%',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Price ──
            Text(
              price,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: tc.text,
              ),
            ),
            if (saving != null)
              Text(
                saving,
                style: TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w800,
                ),
              ),
            const SizedBox(height: 20),
            // ── Features ──
            _GlassCard(
              child: Column(
                children: const [
                  _ProFeatureRow('Advanced Analytics & Insights'),
                  _ProFeatureRow('Real-time Price Alerts'),
                  _ProFeatureRow('AI Stock Recommendations'),
                  _ProFeatureRow('Unlimited Watchlists'),
                  _ProFeatureRow('Portfolio Performance Reports'),
                  _ProFeatureRow('Ad-free Experience'),
                  _ProFeatureRow('Priority Support'),
                  _ProFeatureRow('Dark & Light Mode'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // ── CTA ──
            BouncingButton(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎉 Welcome to PulseTrade Pro!'),
                    backgroundColor: AppColors.green2,
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF10B981)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Upgrade to Pro',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Cancel anytime. Secure payment.',
              style: TextStyle(color: tc.muted, fontSize: 12),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ProFeatureRow extends StatelessWidget {
  final String text;
  const _ProFeatureRow(this.text);
  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.black, size: 14),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(fontWeight: FontWeight.w700, color: tc.text),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// SETTINGS SCREEN
// ──────────────────────────────────────────────────────────────────────────────
class SettingsScreen extends StatelessWidget {
  final AppCurrency currency;
  final bool darkMode;
  final bool priceAlerts;
  final String apiKey;
  final ValueChanged<AppCurrency> onCurrency;
  final ValueChanged<bool> onDarkMode;
  final ValueChanged<bool> onPriceAlerts;
  final ValueChanged<String> onApiKeyChanged;
  final VoidCallback onLogout;

  const SettingsScreen({
    super.key,
    required this.currency,
    required this.darkMode,
    required this.priceAlerts,
    required this.apiKey,
    required this.onCurrency,
    required this.onDarkMode,
    required this.onPriceAlerts,
    required this.onApiKeyChanged,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tc.bg,
      appBar: AppBar(
        backgroundColor: tc.bg,
        title: Text('Settings', style: TextStyle(color: tc.text)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile ──
            _GlassCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: tc.card2,
                    child: const Text('👤', style: TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PulseTrade User',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: tc.text,
                          ),
                        ),
                        Text(
                          'user@pulsetrade.app',
                          style: TextStyle(color: tc.muted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Edit',
                      style: TextStyle(color: AppColors.green),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Marketstack API Key settings ──
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marketstack API Key',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: tc.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Register free at https://marketstack.com/',
                    style: TextStyle(color: tc.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: TextEditingController(text: apiKey)
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: apiKey.length),
                      ),
                    onChanged: onApiKeyChanged,
                    style: TextStyle(color: tc.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter API Key',
                      hintStyle: TextStyle(color: tc.muted),
                      filled: true,
                      fillColor: tc.card2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: tc.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: tc.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.green,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Preferences ──
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preferences',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: tc.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: darkMode,
                    activeColor: AppColors.green,
                    onChanged: onDarkMode,
                    title: Text('Dark Mode', style: TextStyle(color: tc.text)),
                    subtitle: Text(
                      'Dark terminal style',
                      style: TextStyle(color: tc.muted, fontSize: 12),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: priceAlerts,
                    activeColor: AppColors.green,
                    onChanged: onPriceAlerts,
                    title: Text(
                      'Price Alerts',
                      style: TextStyle(color: tc.text),
                    ),
                    subtitle: Text(
                      'Notify on watched stocks',
                      style: TextStyle(color: tc.muted, fontSize: 12),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Currency ──
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trading Currency',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: tc.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppCurrency.values.map((c) {
                      final active = c == currency;
                      final label = {
                        AppCurrency.eur: '€ EUR',
                        AppCurrency.usd: r'$ USD',
                        AppCurrency.tryc: '₺ TRY',
                        AppCurrency.gbp: '£ GBP',
                      }[c]!;
                      return GestureDetector(
                        onTap: () => onCurrency(c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.green.withOpacity(.2)
                                : tc.card2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: active ? AppColors.green : tc.border,
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: active ? AppColors.green : tc.muted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── App Info ──
            _GlassCard(
              child: Column(
                children: const [
                  _SettingsRow(
                    icon: Icons.info_outline,
                    label: 'App Version',
                    value: '1.0.0',
                  ),
                  _SettingsRow(
                    icon: Icons.shield_outlined,
                    label: 'Privacy Policy',
                    value: '',
                  ),
                  _SettingsRow(
                    icon: Icons.description_outlined,
                    label: 'Terms of Service',
                    value: '',
                  ),
                  _SettingsRow(
                    icon: Icons.help_outline,
                    label: 'Help & Support',
                    value: '',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // ── Logout ──
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout, color: AppColors.red),
                label: const Text(
                  'Log Out',
                  style: TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: tc.muted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w700, color: tc.text),
            ),
          ),
          if (value.isNotEmpty)
            Text(value, style: TextStyle(color: tc.muted))
          else
            Icon(Icons.chevron_right, color: tc.muted),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ──────────────────────────────────────────────────────────────────────────────
class _LogoMark extends StatelessWidget {
  final double size;
  const _LogoMark({required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .22),
        gradient: const LinearGradient(
          colors: [AppColors.green, AppColors.green2],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.green.withOpacity(.3), blurRadius: 12),
        ],
      ),
      child: Icon(Icons.show_chart, color: Colors.black, size: size * .55),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: tc.text,
          ),
        ),
        if (subtitle.isNotEmpty)
          Text(subtitle, style: TextStyle(color: tc.muted, fontSize: 12)),
      ],
    );
  }
}

class _StockBadge extends StatelessWidget {
  final StockData stock;
  final double size;
  const _StockBadge({required this.stock, required this.size});
  @override
  Widget build(BuildContext context) {
    final pos = stock.changePct >= 0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: pos
            ? AppColors.green.withOpacity(.16)
            : AppColors.red.withOpacity(.12),
        borderRadius: BorderRadius.circular(size * .2),
        border: Border.all(
          color: pos
              ? AppColors.green.withOpacity(.35)
              : AppColors.red.withOpacity(.35),
        ),
      ),
      child: Center(
        child: Text(
          stock.logo,
          style: TextStyle(
            color: pos ? AppColors.green : AppColors.red,
            fontSize: size * .28,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _StockListTile extends StatelessWidget {
  final StockData stock;
  final AppCurrency currency;
  final VoidCallback onTap;
  const _StockListTile({
    required this.stock,
    required this.currency,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final pos = stock.changePct >= 0;
    final tc = ThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BouncingButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tc.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tc.border),
          ),
          child: Row(
            children: [
              _StockBadge(stock: stock, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: tc.text,
                      ),
                    ),
                    Text(
                      stock.symbol,
                      style: TextStyle(color: tc.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(stock.price, currency),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: tc.text,
                    ),
                  ),
                  Text(
                    '${pos ? '+' : ''}${stock.changePct.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: pos ? AppColors.green : AppColors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: tc.muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsMiniTile extends StatelessWidget {
  final StockData stock;
  final StockNewsItem item;
  final VoidCallback onTap;
  const _NewsMiniTile({
    required this.stock,
    required this.item,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: _GlassCard(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: AppColors.green, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: tc.text,
                      ),
                    ),
                    Text(
                      '${item.time} · ${item.category}',
                      style: TextStyle(color: tc.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final TradeActivity activity;
  final AppCurrency currency;
  const _ActivityTile({required this.activity, required this.currency});
  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            activity.positive
                ? Icons.check_circle_outline
                : Icons.remove_circle_outline,
            color: activity.positive ? AppColors.green : AppColors.red,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: tc.text,
                  ),
                ),
                Text(
                  activity.detail,
                  style: TextStyle(color: tc.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${activity.value >= 0 ? '+' : '-'}${money(activity.value.abs(), currency)}',
            style: TextStyle(
              color: activity.positive ? AppColors.green : AppColors.red,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String sub;
  final bool positive;
  const _StatCard({
    required this.title,
    required this.value,
    required this.sub,
    required this.positive,
  });
  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: tc.muted, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: tc.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              color: positive ? AppColors.green : AppColors.red,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetricRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: tc.muted, fontSize: 13)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: tc.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final String text;
  final bool positive;
  const _BulletRow({required this.text, required this.positive});
  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            positive ? Icons.check_circle : Icons.cancel,
            color: positive ? AppColors.green : AppColors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: tc.text)),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// CHART WIDGET (Custom Painter — no external package needed)
// ──────────────────────────────────────────────────────────────────────────────
class _LineChart extends StatelessWidget {
  final List<double> data;
  final bool positive;
  const _LineChart({required this.data, required this.positive});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      final tc = ThemeColors.of(context);
      return Center(
        child: Text('No chart data', style: TextStyle(color: tc.muted)),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _LineChartPainter(
        data: data,
        positive: positive,
        isDark: isDark,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final bool positive;
  final bool isDark;
  _LineChartPainter({
    required this.data,
    required this.positive,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final minV = data.reduce(math.min);
    final maxV = data.reduce(math.max);
    final span = maxV - minV == 0 ? 1.0 : maxV - minV;
    final color = positive ? AppColors.green : AppColors.red;

    // Grid lines
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(.06)
      ..strokeWidth = 1;
    for (int i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Fill
    final fillPath = Path();
    final linePath = Path();
    for (int i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y =
          size.height -
          ((data[i] - minV) / span) * (size.height * .80) -
          size.height * .08;
      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw fill
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(.30), color.withOpacity(.02)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Draw line
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Last point dot
    final lastX = size.width;
    final lastY =
        size.height -
        ((data.last - minV) / span) * (size.height * .80) -
        size.height * .08;
    canvas.drawCircle(Offset(lastX, lastY), 5, Paint()..color = color);
    canvas.drawCircle(
      Offset(lastX, lastY),
      5,
      Paint()
        ..color = color.withOpacity(.3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.data != data || old.positive != positive || old.isDark != isDark;
}

// ──────────────────────────────────────────────────────────────────────────────
// DONUT CHART WIDGET (Custom Painter — represents holdings partition)
// ──────────────────────────────────────────────────────────────────────────────
class _DonutChart extends StatelessWidget {
  final Map<String, int> holdings;
  final List<StockData> stocks;
  const _DonutChart({required this.holdings, required this.stocks});

  @override
  Widget build(BuildContext context) {
    double totalValue = 0;
    final List<MapEntry<String, double>> segments = [];
    final colors = [
      AppColors.green,
      AppColors.blue,
      AppColors.yellow,
      AppColors.red,
      Colors.purpleAccent,
      Colors.cyanAccent,
    ];

    for (final s in stocks) {
      final shares = holdings[s.symbol] ?? 0;
      if (shares > 0) {
        final val = shares * s.price;
        totalValue += val;
        segments.add(MapEntry(s.logo, val));
      }
    }

    if (totalValue == 0) {
      return Center(
        child: Text(
          'No Assets',
          style: TextStyle(
            color: ThemeColors.of(context).muted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return CustomPaint(
      painter: _DonutPainter(
        segments: segments,
        totalValue: totalValue,
        colors: colors,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<MapEntry<String, double>> segments;
  final double totalValue;
  final List<Color> colors;

  _DonutPainter({
    required this.segments,
    required this.totalValue,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = math.min(size.width, size.height) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double strokeWidth = radius * 0.35;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < segments.length; i++) {
      final sweepAngle = (segments[i].value / totalValue) * 2 * math.pi;
      paint.color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.totalValue != totalValue || old.segments != segments;
}

// ──────────────────────────────────────────────────────────────────────────────
// FUTURISTIC BACKGROUND & PAINTER
// ──────────────────────────────────────────────────────────────────────────────
class FuturisticBackground extends StatelessWidget {
  final Widget child;
  const FuturisticBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: FuturisticBackgroundPainter()),
        ),
        child,
      ],
    );
  }
}

class FuturisticBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Dark space blue background gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF030712), // Very dark slate/black
          Color(0xFF050F26), // Deep navy
          Color(0xFF081229), // Rich dark blue
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Translucent neon glowing radial blobs
    // Top-left purple glow
    final purpleGlow = const RadialGradient(
      center: Alignment(-0.8, -0.8),
      radius: 1.2,
      colors: [
        Color(0x226366F1), // Translucent violet/indigo
        Colors.transparent,
      ],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = purpleGlow);

    // Bottom-right green/cyan glow
    final greenGlow = const RadialGradient(
      center: Alignment(0.9, 0.9),
      radius: 1.4,
      colors: [
        Color(0x1B10B981), // Translucent emerald
        Colors.transparent,
      ],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = greenGlow);

    // Middle-left blue glow
    final blueGlow = const RadialGradient(
      center: Alignment(-0.5, 0.2),
      radius: 1.1,
      colors: [
        Color(0x1E3B82F6), // Translucent blue
        Colors.transparent,
      ],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = blueGlow);

    // 3. Grid lines overlay
    final gridPaint = Paint()
      ..color =
          const Color(0x0A94A3B8) // ~4% opacity slate blue
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const double gridSize = 45.0;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 4. Background glowing chart patterns (simulated stock lines)
    // Green upward trend on the right side
    final greenChartPaint = Paint()
      ..color =
          const Color(0x1410B981) // 8% opacity green
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final greenPath = Path();
    greenPath.moveTo(size.width * 0.35, size.height * 0.88);
    greenPath.lineTo(size.width * 0.48, size.height * 0.83);
    greenPath.lineTo(size.width * 0.53, size.height * 0.85);
    greenPath.lineTo(size.width * 0.65, size.height * 0.70);
    greenPath.lineTo(size.width * 0.72, size.height * 0.75);
    greenPath.lineTo(size.width * 0.82, size.height * 0.58);
    greenPath.lineTo(size.width * 0.89, size.height * 0.62);
    greenPath.lineTo(size.width * 0.96, size.height * 0.44);
    greenPath.lineTo(size.width, size.height * 0.48);
    canvas.drawPath(greenPath, greenChartPaint);

    // Red volatile trend on the left side
    final redChartPaint = Paint()
      ..color =
          const Color(0x0FEE4444) // 6% opacity red
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final redPath = Path();
    redPath.moveTo(0, size.height * 0.62);
    redPath.lineTo(size.width * 0.08, size.height * 0.68);
    redPath.lineTo(size.width * 0.16, size.height * 0.59);
    redPath.lineTo(size.width * 0.23, size.height * 0.63);
    redPath.lineTo(size.width * 0.32, size.height * 0.48);
    redPath.lineTo(size.width * 0.40, size.height * 0.54);
    redPath.lineTo(size.width * 0.46, size.height * 0.38);
    canvas.drawPath(redPath, redChartPaint);

    // Draw some faint candlesticks along the paths
    final candleFillGreen = Paint()
      ..color =
          const Color(0x1810B981) // 9% green
      ..style = PaintingStyle.fill;
    final candleStemGreen = Paint()
      ..color = const Color(0x1810B981)
      ..strokeWidth = 1.0;

    _drawCandle(
      canvas,
      Offset(size.width * 0.65, size.height * 0.70),
      10,
      24,
      candleFillGreen,
      candleStemGreen,
    );
    _drawCandle(
      canvas,
      Offset(size.width * 0.82, size.height * 0.58),
      12,
      32,
      candleFillGreen,
      candleStemGreen,
    );
    _drawCandle(
      canvas,
      Offset(size.width * 0.96, size.height * 0.44),
      8,
      38,
      candleFillGreen,
      candleStemGreen,
    );

    final candleFillRed = Paint()
      ..color =
          const Color(0x10EE4444) // 6% red
      ..style = PaintingStyle.fill;
    final candleStemRed = Paint()
      ..color = const Color(0x10EE4444)
      ..strokeWidth = 1.0;

    _drawCandle(
      canvas,
      Offset(size.width * 0.16, size.height * 0.59),
      8,
      18,
      candleFillRed,
      candleStemRed,
    );
    _drawCandle(
      canvas,
      Offset(size.width * 0.32, size.height * 0.48),
      10,
      22,
      candleFillRed,
      candleStemRed,
    );
  }

  void _drawCandle(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Paint fillPaint,
    Paint stemPaint,
  ) {
    final rect = Rect.fromCenter(
      center: center,
      width: width,
      height: height * 0.65,
    );
    canvas.drawRect(rect, fillPaint);
    canvas.drawLine(
      Offset(center.dx, center.dy - height / 2),
      Offset(center.dx, center.dy + height / 2),
      stemPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ──────────────────────────────────────────────────────────────────────────────
// GLASSMORPHIC CARD CONTAINER
// ──────────────────────────────────────────────────────────────────────────────
class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  const GlassmorphicCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x170A0F1D), // Deep dark semi-translucent fill
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(
            0x2494A3B8,
          ), // Translucent slate border (14% opacity)
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0x0A3B82F6), // Extremely faint blue center glow
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: child,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// SOCIAL BRAND ICONS
// ──────────────────────────────────────────────────────────────────────────────
class GoogleIcon extends StatelessWidget {
  const GoogleIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: Image.network(
        'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.png',
        width: 18,
        height: 18,
        errorBuilder: (context, error, stackTrace) {
          // Robust letter G styled fallback in case network error
          return const Center(
            child: Text(
              'G',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF4285F4),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MicrosoftIcon extends StatelessWidget {
  const MicrosoftIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Container(color: const Color(0xFFF25022)), // Red-orange
          Container(color: const Color(0xFF7FBA00)), // Green
          Container(color: const Color(0xFF00A4EF)), // Blue
          Container(color: const Color(0xFFFFB900)), // Yellow
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// SCROLLING STOCK TICKER TAPE
// ──────────────────────────────────────────────────────────────────────────────
class ScrollingTickerTape extends StatefulWidget {
  final List<StockData> stocks;
  final AppCurrency currency;
  const ScrollingTickerTape({
    super.key,
    required this.stocks,
    required this.currency,
  });

  @override
  State<ScrollingTickerTape> createState() => _ScrollingTickerTapeState();
}

class _ScrollingTickerTapeState extends State<ScrollingTickerTape> {
  late ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrolling();
    });
  }

  void _startScrolling() {
    if (!_scrollController.hasClients) return;

    const speed = 40.0; // pixels per second
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_scrollController.hasClients) {
        _timer?.cancel();
        return;
      }
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;

      if (currentScroll >= maxScroll) {
        _scrollController.jumpTo(0.0);
      } else {
        _scrollController.jumpTo(currentScroll + (speed * 0.05));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    // Triple items to ensure seamless loop
    final doubledStocks = [
      ...widget.stocks,
      ...widget.stocks,
      ...widget.stocks,
    ];

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0x13000000),
        border: Border(bottom: BorderSide(color: tc.border, width: 0.5)),
      ),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: doubledStocks.length,
        itemBuilder: (context, index) {
          final s = doubledStocks[index];
          final positive = s.changePct >= 0;
          final color = positive ? AppColors.green : AppColors.red;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.symbol,
                  style: TextStyle(
                    color: tc.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  money(s.price, widget.currency),
                  style: TextStyle(
                    color: tc.muted,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${positive ? '▲' : '▼'} ${s.changePct.abs().toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// AI TRADING ADVISOR PANEL & SIMULATOR
// ──────────────────────────────────────────────────────────────────────────────
class AITradingAdvisorPanel extends StatefulWidget {
  final ScrollController scrollController;
  final List<StockData> stocks;
  final AppCurrency currency;

  const AITradingAdvisorPanel({
    super.key,
    required this.scrollController,
    required this.stocks,
    required this.currency,
  });

  @override
  State<AITradingAdvisorPanel> createState() => _AITradingAdvisorPanelState();
}

class _AITradingAdvisorPanelState extends State<AITradingAdvisorPanel> {
  final List<Map<String, String>> _messages = [
    {
      'role': 'assistant',
      'content':
          'Hello! I am your PulseTrade AI Trading Advisor. Ask me anything about stock data, market sentiments, or select a quick prompt below to begin.',
    },
  ];
  final _inputCtrl = TextEditingController();
  bool _thinking = false;
  Timer? _typeTimer;

  @override
  void dispose() {
    _typeTimer?.cancel();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _sendPrompt(String question) {
    if (_thinking) return;
    setState(() {
      _messages.add({'role': 'user', 'content': question});
      _thinking = true;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;

      String responseText = '';
      final qLower = question.toLowerCase();
      if (qLower.contains('siemens') || qLower.contains('enr.de')) {
        responseText =
            '**AI Technical Report: Siemens Energy AG (ENR.DE)**\n\n'
            '• **Current Price:** ${money(18.24, widget.currency)} (+2.34% today)\n'
            '• **AI Confidence:** 86% (Strong Buy)\n\n'
            '**Key Analysis:**\n'
            '- High order backlog in electrical grid integration and power grid technologies.\n'
            '- Margin recovery in gas services provides solid tailwinds.\n\n'
            '**Identified Risks:**\n'
            '- Siemens Gamesa wind integration bottlenecks represent a medium volatility risk.\n'
            '**AI Consensus:** BUY on dips below ${money(17.80, widget.currency)}. Mid-term target: ${money(22.80, widget.currency)}.';
      } else if (qLower.contains('strongest buy') ||
          qLower.contains('signal') ||
          qLower.contains('confidence')) {
        responseText =
            '**AI Signal Screener: Top Recommendations**\n\n'
            '1. **NVIDIA Corp (NVDA)**\n'
            '   - AI Confidence: **92%** (Strong Buy)\n'
            '   - Catalyst: Strong AI chip backlog and cloud provider infrastructure expansion.\n\n'
            '2. **SAP SE (SAP.DE)**\n'
            '   - AI Confidence: **89%** (Buy)\n'
            '   - Catalyst: Cloud subscription SaaS revenue ARR accelerating 25%+ YoY.\n\n'
            '3. **Siemens Energy AG (ENR.DE)**\n'
            '   - AI Confidence: **86%** (Buy)\n'
            '   - Catalyst: Grid upgrade spending globally.';
      } else if (qLower.contains('tesla') || qLower.contains('tsla')) {
        responseText =
            '**AI Technical Report: Tesla Inc. (TSLA)**\n\n'
            '• **Current Price:** ${money(178.24, widget.currency)} (-1.23% today)\n'
            '• **AI Confidence:** 71% (Hold)\n\n'
            '**Key Chart Levels:**\n'
            '- **Support:** Strong buyer demand at \$168.00.\n'
            '- **Resistance:** Bull breakout level at \$185.00.\n\n'
            '**Technical Indicators:**\n'
            '- RSI is flat at 35.8 (near oversold).\n'
            '- Volume profiles indicate consolidation phase.\n'
            '**AI Consensus:** HOLD. Accumulate only if price tests key support at \$168.00 with rising volume.';
      } else if (qLower.contains('diversified') ||
          qLower.contains('allocation') ||
          qLower.contains('portfolio')) {
        responseText =
            '**AI Recommended Portfolio Allocation**\n\n'
            '• **Technology & AI Accelerator Equities:** 40% (High beta growth core - NVDA, SAP)\n'
            '• **Grid Infrastructure & Decarbonization:** 25% (Utilities/Power - ENR.DE)\n'
            '• **Consumer Platforms & Services:** 20% (Stable cashflows - AAPL)\n'
            '• **Tactical Dry Powder (Cash/USD):** 15% (To deploy during market corrections)\n\n'
            '*Note: Rebalance quarterly to maintain optimal risk-return ratios under current macroeconomic volatility.*';
      } else {
        responseText =
            'Based on current market screener data and AI technical analysis for your query, the assets show standard consolidation. '
            'Global market sentiment is neutral-bullish. Support and resistance levels are holding within average daily ranges. '
            'I suggest looking at high AI confidence stock picks (like NVDA or SAP) for stronger momentum indicators.';
      }

      setState(() {
        _thinking = false;
        _messages.add({'role': 'assistant', 'content': ''});
      });

      int charIndex = 0;
      _typeTimer = Timer.periodic(const Duration(milliseconds: 15), (timer) {
        if (charIndex >= responseText.length || !mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _messages[_messages.length - 1]['content'] = responseText.substring(
            0,
            charIndex + 1,
          );
        });
        charIndex += 2;
        if (charIndex > responseText.length) charIndex = responseText.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFA050B14),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x3D10B981),
            blurRadius: 24,
            spreadRadius: 2,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: tc.muted.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.green.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: AppColors.green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Trading Advisor',
                        style: TextStyle(
                          color: tc.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Powered by PulseTrade AI Core',
                        style: TextStyle(color: tc.muted, fontSize: 11),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: tc.muted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0x1F94A3B8), height: 1),

            Expanded(
              child: ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: isUser
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        if (!isUser) ...[
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.green.withOpacity(0.2),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: AppColors.green,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? AppColors.green.withOpacity(0.15)
                                  : const Color(0x1E1E293B),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isUser
                                    ? const Radius.circular(16)
                                    : Radius.zero,
                                bottomRight: isUser
                                    ? Radius.zero
                                    : const Radius.circular(16),
                              ),
                              border: Border.all(
                                color: isUser
                                    ? AppColors.green.withOpacity(0.3)
                                    : const Color(0x1894A3B8),
                              ),
                            ),
                            child: Text(
                              msg['content'] ?? '',
                              style: TextStyle(
                                color: tc.text,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                        if (isUser) ...[
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: tc.card2,
                            child: const Text(
                              '👤',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            if (_thinking) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.green),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'AI is analyzing market signals...',
                      style: TextStyle(color: tc.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Prompts:',
                    style: TextStyle(
                      color: tc.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _PromptChip(
                          label: 'Analyze ENR.DE risk',
                          onTap: () => _sendPrompt(
                            'Analyze Siemens Energy (ENR.DE) risk & outlook',
                          ),
                        ),
                        _PromptChip(
                          label: 'Top Buy signals?',
                          onTap: () => _sendPrompt(
                            'Which stock has the strongest Buy signal right now?',
                          ),
                        ),
                        _PromptChip(
                          label: 'Technical on TSLA',
                          onTap: () => _sendPrompt(
                            'Provide a technical analysis report on Tesla (TSLA)',
                          ),
                        ),
                        _PromptChip(
                          label: 'Best portfolio split?',
                          onTap: () => _sendPrompt(
                            'Suggest a diversified portfolio allocation for current markets',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      style: TextStyle(color: tc.text),
                      decoration: InputDecoration(
                        hintText: 'Ask AI Advisor anything...',
                        hintStyle: TextStyle(color: tc.muted.withOpacity(0.5)),
                        filled: true,
                        fillColor: const Color(0x131E293B),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0x1F94A3B8),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0x1F94A3B8),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.green),
                        ),
                      ),
                      onSubmitted: (text) {
                        if (text.trim().isNotEmpty) {
                          _sendPrompt(text.trim());
                          _inputCtrl.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.black),
                      onPressed: () {
                        final text = _inputCtrl.text.trim();
                        if (text.isNotEmpty) {
                          _sendPrompt(text);
                          _inputCtrl.clear();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PromptChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: BouncingButton(
        onTap: onTap,
        child: ActionChip(
          label: Text(label),
          backgroundColor: const Color(0x1C1E293B),
          labelStyle: const TextStyle(
            color: AppColors.green,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          side: const BorderSide(color: Color(0x2694A3B8)),
          onPressed: () {},
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// TACTILE SPRING-BOUNCING BUTTON WIDGET
// ──────────────────────────────────────────────────────────────────────────────
class BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const BouncingButton({super.key, required this.child, this.onTap});

  @override
  State<BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<BouncingButton>
    with SingleTickerProviderStateMixin {
  late double _scale;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 70),
          lowerBound: 0.0,
          upperBound: 0.04, // 4% shrink on press
        )..addListener(() {
          setState(() {});
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scale = 1 - _controller.value;
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onTap != null) {
          _controller.forward();
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        if (widget.onTap != null) {
          _controller.reverse();
        }
      },
      onTapCancel: () {
        if (widget.onTap != null) {
          _controller.reverse();
        }
      },
      onTap: widget.onTap,
      child: Transform.scale(scale: _scale, child: widget.child),
    );
  }
}
