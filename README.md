# PulseTrade — Stock Broker Simulator

PulseTrade is a browser-based stock trading simulator. There's no real money and no backend server — it's a client-side web app that lets you practice trading using **real, live market prices** with **virtual cash**.

Each user starts with a simulated balance of **€50,000** and can buy/sell stocks whose prices are pulled live from the [Finnhub](https://finnhub.io/) API. All portfolio and balance data is kept in the browser's `sessionStorage` — no account system, no server, no persistence beyond the session.

## Features

- **Login screen** (`index.html`) — entry point into the app
- **Dashboard** (`home.html`) — overview of portfolio and market activity
- **Markets** (`markets.html`) — live stock listings with real-time prices
- **Stock detail** (`stock-detail.html`) — price chart per stock, with a Buy/Sell modal that executes trades and updates portfolio + cash balance
- **Portfolio** (`portfolio.html`) — current holdings, total net worth (holdings + cash), donut chart and sparkline visualizations
- **Settings** (`settings.html`) — currency and app preferences
- **Pro plan** (`pro-plan.html`) — premium plan page (UI concept)

## How it works

- Live prices are fetched via `loadAllLivePrices()` in `main.js`
- Net worth is calculated as:
- - State (portfolio, cash balance, price cache) is stored in `sessionStorage` under keys such as `pt_portfolio` and `pt_cash_balance`
- All state reads/writes go through a centralized module so the trade modal, portfolio page, and dashboard stay in sync

## Tech stack

- **Web:** Vanilla HTML/CSS/JavaScript + Bootstrap 5 (no framework, per course requirements)
- **Mobile:** Flutter/Dart companion app
- **Data:** Finnhub API (live stock prices)
- **State management:** Browser `sessionStorage`

## Running the web app

1. Clone the repo
2. Create a `pulsetrade-web/js/config.js` file with:
```javascript
   const FINNHUB_API_KEY = "your_finnhub_api_key_here";
```
3. Open `pulsetrade-web/index.html` in a browser (or serve the folder with a local server, e.g. the VS Code "Live Server" extension)

## Running the mobile app

1. Navigate to the `flutter frontend` folder
2. Run `flutter pub get`
3. Run `flutter run`

> Note: the mobile app's live-price integration is unfinished — the Finnhub API key is left as a placeholder, so stock prices won't load live on mobile. The rest of the UI/navigation runs normally.

## Note

This was a course project built as part of a Software Engineering final assignment. The web front end and a companion Flutter mobile app were developed together as a single product concept.
