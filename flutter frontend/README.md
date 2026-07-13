# PulseTrade

**Smart Investments, Better Future.**

Frontend Programming Final Exam Project (UE – Summer Semester 2026)

PulseTrade is a stock market application with:
- **Part 1:** Flutter mobile app (Dart)
- **Part 2:** Responsive web app (HTML5, CSS3, Bootstrap 5, vanilla JavaScript)

## Features (Exam Requirements)

### Mobile App (Flutter)
- 6 screens: Sign In, Home, Markets & News, Stock Detail, Portfolio, Pro
- Bottom navigation bar + AppBar titles
- Material Theme (dark) with consistent green/red color language
- Geolocator + geocoding for automatic country detection
- Marketstack API for live stock data
- fl_chart interactive charts (1D, 1M, 3M, 1Y)
- Provider state management + SharedPreferences
- Asset image with responsive layout (portrait/landscape)
- Link to web app for detailed charts
- Packages: provider, http, geolocator, geocoding, fl_chart, shared_preferences, url_launcher

### Web App (`website/`)
- 6 pages: Home, Markets & News, Stock Detail, Sign In, Portfolio, Pro
- Bootstrap 5 responsive layout
- Chart.js price charts (1 day, 1 month, 3 months, 1 year)
- JavaScript geolocation for country detection
- Marketstack API integration
- Currency switcher (EUR, USD, GBP, TRY)
- Search by country/company name
- Green/red styling for up/down stocks

## Setup

### 1. API Key (required for live data)

Register free at [marketstack.com](https://marketstack.com/) and add your key:

**Mobile:** `lib/config/api_config.dart`
```dart
const String marketstackApiKey = 'YOUR_KEY_HERE';
```

**Web:** `website/js/app.js`
```javascript
marketstackKey: 'YOUR_KEY_HERE',
```

Without a key, demo data is shown so the app still works at presentation.

### 2. Mobile App

```bash
flutter pub get
flutter run
```

Run on Android Emulator, iOS Simulator, or physical device.

### 3. Web App

Open `website/index.html` in a browser, or serve locally:

```bash
cd website
python -m http.server 8080
```

Deploy `website/` folder to free hosting (GitHub Pages, Netlify, etc.) and update `webAppBaseUrl` in `lib/config/api_config.dart`.

## Project Structure

```
pulsetrade/
├── lib/
│   ├── main.dart
│   ├── config/api_config.dart
│   ├── models/market_models.dart
│   ├── providers/app_provider.dart
│   ├── services/location_service.dart
│   ├── services/market_service.dart
│   ├── screens/          # 6 app screens
│   ├── theme/app_colors.dart
│   └── widgets/common_widgets.dart
├── assets/images/
├── website/              # Web app (Part 2)
│   ├── index.html
│   ├── markets.html
│   ├── stock.html
│   ├── login.html
│   ├── portfolio.html
│   ├── pro.html
│   ├── css/style.css
│   └── js/app.js
└── README.md
```

## Markets by Country

| Country | Exchange | Sample Stocks |
|---------|----------|---------------|
| Germany | XETRA    | Siemens Energy, SAP, Tesla |
| USA     | NASDAQ   | Apple, Tesla, Microsoft |
| UK      | LSE      | HSBC, BP, Vodafone |
| Turkey  | BIST     | THYAO, ASELS, GARAN |

## Submission Checklist

- [ ] Add Marketstack API key
- [ ] Test mobile app on emulator/device (no errors)
- [ ] Deploy web app to free hosting
- [ ] Update web URL in mobile config
- [ ] Include Figma design files in zip
- [ ] Zip: Figma + web app + mobile app
- [ ] Submit to Teams before **22.06.2026, 23:59**

## Author

Frontend Programming – University of Europe for Applied Sciences
