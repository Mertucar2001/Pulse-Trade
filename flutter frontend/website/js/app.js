// PulseTrade – API & shared logic (vanilla JavaScript)

const CONFIG = {
  marketstackKey: 'YOUR_MARKETSTACK_API_KEY',
  marketstackBase: 'http://api.marketstack.com/v1',
};

const REGIONS = {
  DE: {
    country: 'Germany',
    label: 'Top Movers Germany',
    symbols: ['ENR.XETRA', 'SAP.XETRA', 'TSLA'],
    names: ['Siemens Energy AG', 'SAP SE', 'Tesla Inc.'],
    currency: 'EUR',
    indices: [
      { name: 'DAX', value: '18,236.5', change: '+1.35%', up: true },
      { name: 'NASDAQ', value: '17,192.5', change: '+0.92%', up: true },
      { name: 'S&P 500', value: '5,278.40', change: '+1.02%', up: true },
    ],
  },
  US: {
    country: 'United States',
    label: 'Top Movers USA',
    symbols: ['AAPL', 'TSLA', 'MSFT'],
    names: ['Apple Inc.', 'Tesla Inc.', 'Microsoft Corp.'],
    currency: 'USD',
    indices: [
      { name: 'DOW', value: '39,127.8', change: '+0.78%', up: true },
      { name: 'NASDAQ', value: '17,192.5', change: '+0.92%', up: true },
      { name: 'S&P 500', value: '5,278.40', change: '+1.02%', up: true },
    ],
  },
  GB: {
    country: 'United Kingdom',
    label: 'Top Movers UK',
    symbols: ['HSBA.LSE', 'BP.LSE', 'VOD.LSE'],
    names: ['HSBC Holdings', 'BP plc', 'Vodafone Group'],
    currency: 'GBP',
    indices: [
      { name: 'FTSE 100', value: '8,142.2', change: '+0.45%', up: true },
      { name: 'FTSE 250', value: '20,891.1', change: '-0.12%', up: false },
      { name: 'AIM', value: '752.4', change: '+0.33%', up: true },
    ],
  },
  TR: {
    country: 'Turkey',
    label: 'Top Movers Turkey',
    symbols: ['THYAO.IS', 'ASELS.IS', 'GARAN.IS'],
    names: ['Turkish Airlines', 'Aselsan', 'Garanti BBVA'],
    currency: 'TRY',
    indices: [
      { name: 'BIST 100', value: '9,842.5', change: '+1.20%', up: true },
      { name: 'BIST 30', value: '10,512.3', change: '+0.95%', up: true },
      { name: 'BIST Bank', value: '5,421.8', change: '-0.40%', up: false },
    ],
  },
};

const CURRENCY_RATES = { EUR: 1, USD: 1.08, GBP: 0.86, TRY: 34.5 };

const AppState = {
  countryCode: 'DE',
  currency: 'EUR',
  stocks: [],
  news: [],
  chartInstance: null,
};

function currencySymbol(c) {
  return ({ USD: '$', GBP: '£', TRY: '₺' })[c] || '€';
}

function convertPrice(amount, from, to) {
  const inEur = amount / (CURRENCY_RATES[from] || 1);
  return inEur * (CURRENCY_RATES[to] || 1);
}

function formatPrice(amount, fromCurrency) {
  const val = convertPrice(amount, fromCurrency, AppState.currency);
  return `${currencySymbol(AppState.currency)}${val.toFixed(2)}`;
}

function hasApiKey() {
  return CONFIG.marketstackKey && CONFIG.marketstackKey !== 'YOUR_MARKETSTACK_API_KEY';
}

function demoStocks(region) {
  const demos = {
    DE: [[18.24, 2.34, 'ENR.XETRA', 'Siemens Energy AG', 'SIE'], [213.65, 1.85, 'SAP.XETRA', 'SAP SE', 'SAP'], [178.24, -1.23, 'TSLA', 'Tesla Inc.', 'TSL']],
    US: [[189.5, 1.12, 'AAPL', 'Apple Inc.', 'AAP'], [178.24, -1.23, 'TSLA', 'Tesla Inc.', 'TSL'], [415.2, 0.88, 'MSFT', 'Microsoft Corp.', 'MSF']],
    GB: [[6.82, 0.45, 'HSBA.LSE', 'HSBC Holdings', 'HSB'], [4.95, -0.32, 'BP.LSE', 'BP plc', 'BP'], [0.72, 1.1, 'VOD.LSE', 'Vodafone Group', 'VOD']],
    TR: [[285.5, 2.1, 'THYAO.IS', 'Turkish Airlines', 'THY'], [58.3, -0.85, 'ASELS.IS', 'Aselsan', 'ASE'], [98.75, 1.45, 'GARAN.IS', 'Garanti BBVA', 'GAR']],
  };
  const items = demos[region.countryCode] || demos.DE;
  return items.map(([price, pct, symbol, name, logo]) => ({
    symbol, name, logo, price, changePercent: pct, isUp: pct >= 0,
    open: price * 0.99, high: price * 1.02, low: price * 0.97, volume: 3200000,
    currency: region.currency,
  }));
}

async function fetchLatestStocks(region) {
  if (!hasApiKey()) return demoStocks(region);
  try {
    const symbols = region.symbols.join(',');
    const url = `${CONFIG.marketstackBase}/eod/latest?access_key=${CONFIG.marketstackKey}&symbols=${symbols}`;
    const res = await fetch(url);
    const data = await res.json();
    if (!data.data || !data.data.length) return demoStocks(region);
    return data.data.map((item, i) => {
      const close = item.close || 0;
      const open = item.open || close;
      const changePct = open ? ((close - open) / open) * 100 : 0;
      return {
        symbol: item.symbol,
        name: region.names[i] || item.symbol,
        logo: (region.names[i] || item.symbol).substring(0, 3).toUpperCase(),
        price: close,
        changePercent: changePct,
        isUp: changePct >= 0,
        open, high: item.high, low: item.low, volume: item.volume,
        currency: region.currency,
      };
    });
  } catch (e) {
    return demoStocks(region);
  }
}

async function fetchHistorical(symbol, days) {
  if (!hasApiKey()) return demoChart(days);
  try {
    const to = new Date();
    const from = new Date();
    from.setDate(from.getDate() - days);
    const fmt = (d) => d.toISOString().slice(0, 10);
    const url = `${CONFIG.marketstackBase}/eod?access_key=${CONFIG.marketstackKey}&symbols=${symbol}&date_from=${fmt(from)}&date_to=${fmt(to)}&limit=${days}&sort=ASC`;
    const res = await fetch(url);
    const data = await res.json();
    if (!data.data || !data.data.length) return demoChart(days);
    return data.data.map((d) => ({ date: d.date, value: d.close }));
  } catch (e) {
    return demoChart(days);
  }
}

function demoChart(days) {
  const points = [];
  let price = 17.5;
  const now = new Date();
  for (let i = 0; i < days; i++) {
    price += (i % 5 - 2) * 0.08 + 0.05;
    const d = new Date(now);
    d.setDate(d.getDate() - (days - i));
    points.push({ date: d.toISOString().slice(0, 10), value: price });
  }
  return points;
}

function newsForRegion(region) {
  return [
    { title: `${region.names[0]} wins major contract in ${region.country}`, category: 'Market', time: '2h ago', symbol: region.symbols[0] },
    { title: `${region.names[1]} launches new AI-powered suite`, category: 'Stocks', time: '4h ago', symbol: region.symbols[1] },
    { title: `Central bank update impacts ${region.label}`, category: 'Economy', time: '6h ago', symbol: region.symbols[0] },
    { title: `Tech rally continues across ${region.country}`, category: 'Stocks', time: '8h ago', symbol: region.symbols[2] },
  ];
}

function detectLocation() {
  return new Promise((resolve) => {
    if (!navigator.geolocation) {
      resolve('DE');
      return;
    }
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          const res = await fetch(
            `https://nominatim.openstreetmap.org/reverse?lat=${pos.coords.latitude}&lon=${pos.coords.longitude}&format=json`
          );
          const data = await res.json();
          resolve(data.address?.country_code?.toUpperCase() || 'DE');
        } catch {
          resolve('DE');
        }
      },
      () => resolve('DE'),
      { timeout: 8000 }
    );
  });
}

function renderNav(active) {
  const pages = [
    { href: 'index.html', label: 'Home' },
    { href: 'markets.html', label: 'Markets' },
    { href: 'portfolio.html', label: 'Portfolio' },
    { href: 'pro.html', label: 'Pro' },
    { href: 'login.html', label: 'Sign In' },
  ];
  return pages.map((p) =>
    `<li class="nav-item"><a class="nav-link ${p.href === active ? 'active' : ''}" href="${p.href}">${p.label}</a></li>`
  ).join('');
}

function stockRowHtml(stock, linkToDetail) {
  const cls = stock.isUp ? 'text-green' : 'text-red';
  const sign = stock.isUp ? '+' : '';
  const href = linkToDetail ? `stock.html?symbol=${encodeURIComponent(stock.symbol)}&name=${encodeURIComponent(stock.name)}` : '#';
  return `
    <div class="card-glass p-3 mb-2 stock-row" onclick="location.href='${href}'">
      <div class="d-flex align-items-center">
        <div class="rounded-circle d-flex align-items-center justify-content-center me-3" style="width:44px;height:44px;background:${stock.isUp ? 'rgba(105,240,111,.18)' : 'rgba(255,75,92,.18)'}">
          <strong class="${cls}" style="font-size:.7rem">${stock.logo}</strong>
        </div>
        <div class="flex-grow-1">
          <div class="fw-bold">${stock.name}</div>
          <div class="text-muted-custom small">${stock.symbol}</div>
        </div>
        <canvas class="sparkline" data-up="${stock.isUp}"></canvas>
        <div class="text-end ms-3">
          <div class="fw-bold">${formatPrice(stock.price, stock.currency)}</div>
          <div class="${cls} small">${sign}${stock.changePercent.toFixed(2)}%</div>
        </div>
      </div>
    </div>`;
}

function drawSparklines() {
  document.querySelectorAll('.sparkline').forEach((canvas) => {
    const ctx = canvas.getContext('2d');
    const up = canvas.dataset.up === 'true';
    const color = up ? '#69f06f' : '#ff4b5c';
    const w = canvas.width = canvas.offsetWidth * 2;
    const h = canvas.height = canvas.offsetHeight * 2;
    ctx.scale(2, 2);
    ctx.strokeStyle = color;
    ctx.lineWidth = 2;
    ctx.beginPath();
    const pts = [0.72, 0.58, 0.63, 0.46, 0.52, 0.38, 0.43, 0.25];
    pts.forEach((p, i) => {
      const x = (canvas.offsetWidth / (pts.length - 1)) * i;
      const y = canvas.offsetHeight * p;
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    });
    ctx.stroke();
  });
}

function countryChipsHtml(containerId) {
  const el = document.getElementById(containerId);
  if (!el) return;
  el.innerHTML = Object.entries(REGIONS).map(([code, r]) =>
    `<span class="country-chip ${AppState.countryCode === code ? 'active' : ''}" data-code="${code}">${r.country}</span>`
  ).join('');
  el.querySelectorAll('.country-chip').forEach((chip) => {
    chip.addEventListener('click', async () => {
      AppState.countryCode = chip.dataset.code;
      AppState.currency = REGIONS[AppState.countryCode].currency;
      await refreshPageData();
    });
  });
}

function currencyChipsHtml(containerId) {
  const el = document.getElementById(containerId);
  if (!el) return;
  el.innerHTML = Object.keys(CURRENCY_RATES).map((c) =>
    `<span class="currency-chip ${AppState.currency === c ? 'active' : ''}" data-currency="${c}">${c}</span>`
  ).join('');
  el.querySelectorAll('.currency-chip').forEach((chip) => {
    chip.addEventListener('click', () => {
      AppState.currency = chip.dataset.currency;
      refreshPageData();
    });
  });
}

async function initApp() {
  const saved = localStorage.getItem('pt_country');
  if (saved) {
    AppState.countryCode = saved;
  } else {
    AppState.countryCode = await detectLocation();
    if (!REGIONS[AppState.countryCode]) AppState.countryCode = 'DE';
  }
  AppState.currency = REGIONS[AppState.countryCode].currency;
  localStorage.setItem('pt_country', AppState.countryCode);
}

async function loadStocksAndNews() {
  const region = REGIONS[AppState.countryCode];
  AppState.stocks = await fetchLatestStocks({ ...region, countryCode: AppState.countryCode });
  AppState.news = newsForRegion(region);
}

async function refreshPageData() {
  localStorage.setItem('pt_country', AppState.countryCode);
  await loadStocksAndNews();
  if (typeof onDataReady === 'function') onDataReady();
}

function renderChart(canvasId, points, isUp) {
  const ctx = document.getElementById(canvasId);
  if (!ctx) return;
  if (AppState.chartInstance) AppState.chartInstance.destroy();
  const color = isUp ? '#69f06f' : '#ff4b5c';
  AppState.chartInstance = new Chart(ctx, {
    type: 'line',
    data: {
      labels: points.map((p) => p.date),
      datasets: [{
        data: points.map((p) => p.value),
        borderColor: color,
        backgroundColor: isUp ? 'rgba(105,240,111,.15)' : 'rgba(255,75,92,.15)',
        fill: true,
        tension: 0.35,
        pointRadius: 0,
        borderWidth: 2,
      }],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { ticks: { color: '#9ca9ba', maxTicksLimit: 6 }, grid: { color: 'rgba(255,255,255,.06)' } },
        y: { ticks: { color: '#9ca9ba' }, grid: { color: 'rgba(255,255,255,.06)' } },
      },
    },
  });
}
